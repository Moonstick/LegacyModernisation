using ClaimsCaseManagement.Data;
using ClaimsCaseManagement.Models;
using ClaimsCaseManagement.Services;
using ClaimsCaseManagement.Services.Storage;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ClaimsCaseManagement.Controllers;

// Legacy smell: the controller talks directly to both the DbContext (for reads)
// and the ClaimService (for writes), mixing concerns and making the controller
// difficult to unit test in isolation from the database.
public class ClaimsController : Controller
{
    private const string RecentlyViewedSessionKey = "RecentlyViewedClaims";

    private readonly ClaimsDbContext _context;
    private readonly IClaimService _claimService;
    private readonly IFileStorageService _fileStorageService;
    private readonly ILogger<ClaimsController> _logger;

    public ClaimsController(
        ClaimsDbContext context,
        IClaimService claimService,
        IFileStorageService fileStorageService,
        ILogger<ClaimsController> logger)
    {
        _context = context;
        _claimService = claimService;
        _fileStorageService = fileStorageService;
        _logger = logger;
    }

    public async Task<IActionResult> Index(string? statusFilter)
    {
        var query = _context.Claims
            .Include(c => c.Claimant)
            .Include(c => c.Policy)
            .Include(c => c.Adjuster)
            .AsQueryable();

        if (!string.IsNullOrEmpty(statusFilter) && Enum.TryParse<ClaimStatus>(statusFilter, out var status))
        {
            query = query.Where(c => c.Status == status);
        }

        var claims = await query.OrderByDescending(c => c.DateSubmitted).ToListAsync();

        ViewBag.StatusFilter = statusFilter;
        ViewBag.SummaryReport = await _claimService.GetSummaryReportAsync();

        return View(claims);
    }

    public async Task<IActionResult> Details(int id)
    {
        var claim = await _context.Claims
            .Include(c => c.Claimant)
            .Include(c => c.Policy)
            .Include(c => c.Adjuster)
            .Include(c => c.Notes)
            .Include(c => c.Attachments)
            .Include(c => c.StatusHistory)
            .FirstOrDefaultAsync(c => c.ClaimId == id);

        if (claim is null)
        {
            return NotFound();
        }

        // Legacy smell: the "recently viewed" list lives in server-side session
        // state. In Phase 0-3 this is ASP.NET Core's in-memory session store,
        // which only exists on the instance that served the request - fine on
        // a single VM, but inconsistent the moment Phase 1's load balancer
        // spreads requests across more than one instance. Phase 4 swaps the
        // session backing store to Redis (see Program.cs) so this list stays
        // consistent no matter which instance serves the next request.
        var recentlyViewed = HttpContext.Session.GetString(RecentlyViewedSessionKey)
            ?.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList() ?? new List<string>();
        recentlyViewed.Remove(claim.ClaimNumber);
        recentlyViewed.Insert(0, claim.ClaimNumber);
        recentlyViewed = recentlyViewed.Take(5).ToList();
        HttpContext.Session.SetString(RecentlyViewedSessionKey, string.Join(',', recentlyViewed));
        ViewBag.RecentlyViewed = recentlyViewed;

        return View(claim);
    }

    public async Task<IActionResult> Create()
    {
        ViewBag.Policies = await _context.Policies.ToListAsync();
        ViewBag.Claimants = await _context.Claimants.ToListAsync();
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Claim claim)
    {
        // Legacy smell: navigation properties for Policy/Claimant aren't bound,
        // so model validation on them is skipped manually below rather than
        // using a dedicated input DTO/view model.
        ModelState.Remove(nameof(Claim.Policy));
        ModelState.Remove(nameof(Claim.Claimant));
        ModelState.Remove(nameof(Claim.ClaimNumber));

        if (!ModelState.IsValid)
        {
            ViewBag.Policies = await _context.Policies.ToListAsync();
            ViewBag.Claimants = await _context.Claimants.ToListAsync();
            return View(claim);
        }

        try
        {
            await _claimService.CreateClaimAsync(claim);
        }
        catch (InvalidOperationException ex)
        {
            // Legacy smell: business exceptions surfaced as generic model errors.
            ModelState.AddModelError(string.Empty, ex.Message);
            ViewBag.Policies = await _context.Policies.ToListAsync();
            ViewBag.Claimants = await _context.Claimants.ToListAsync();
            return View(claim);
        }

        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ChangeStatus(int claimId, ClaimStatus newStatus, string? comment)
    {
        // Legacy smell: "ChangedBy" falls back to a hardcoded value rather than
        // coming from a real authenticated user/claims principal.
        var changedBy = User?.Identity?.Name ?? "anonymous";

        try
        {
            await _claimService.ChangeStatusAsync(claimId, newStatus, changedBy, comment);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "Failed to change status for claim {ClaimId}", claimId);
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Details), new { id = claimId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddNote(int claimId, string author, string text)
    {
        // Legacy smell: write path bypasses ClaimService entirely - direct
        // DbContext access from the controller for "simple" operations.
        _context.ClaimNotes.Add(new ClaimNote
        {
            ClaimId = claimId,
            Author = author,
            Text = text
        });
        await _context.SaveChangesAsync();

        return RedirectToAction(nameof(Details), new { id = claimId });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Upload(int claimId, IFormFile file)
    {
        if (file is { Length: > 0 })
        {
            await using var stream = file.OpenReadStream();
            var storageReference = await _fileStorageService.SaveAsync(claimId, file.FileName, stream);

            _context.ClaimAttachments.Add(new ClaimAttachment
            {
                ClaimId = claimId,
                FileName = file.FileName,
                ContentType = string.IsNullOrEmpty(file.ContentType) ? "application/octet-stream" : file.ContentType,
                FilePath = storageReference
            });
            await _context.SaveChangesAsync();
        }

        return RedirectToAction(nameof(Details), new { id = claimId });
    }

    public async Task<IActionResult> Download(int attachmentId)
    {
        var attachment = await _context.ClaimAttachments.FindAsync(attachmentId);
        if (attachment is null)
        {
            return NotFound();
        }

        var stream = await _fileStorageService.OpenReadAsync(attachment.FilePath);
        if (stream is null)
        {
            return NotFound();
        }

        return File(stream, attachment.ContentType, attachment.FileName);
    }
}
