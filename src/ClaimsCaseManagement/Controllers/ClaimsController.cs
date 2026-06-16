using ClaimsCaseManagement.Data;
using ClaimsCaseManagement.Models;
using ClaimsCaseManagement.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ClaimsCaseManagement.Controllers;

// Legacy smell: the controller talks directly to both the DbContext (for reads)
// and the ClaimService (for writes), mixing concerns and making the controller
// difficult to unit test in isolation from the database.
public class ClaimsController : Controller
{
    private readonly ClaimsDbContext _context;
    private readonly IClaimService _claimService;
    private readonly ILogger<ClaimsController> _logger;

    public ClaimsController(ClaimsDbContext context, IClaimService claimService, ILogger<ClaimsController> logger)
    {
        _context = context;
        _claimService = claimService;
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
}
