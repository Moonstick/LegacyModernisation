using Microsoft.EntityFrameworkCore;
using ClaimsCaseManagement.Models;

namespace ClaimsCaseManagement.Data;

// Legacy smell: a single "god" DbContext for the whole application,
// configured with lazy-loading proxies (an EF6-era habit carried into EF Core).
// Every entity in the domain lives in one context with no module boundaries.
public class ClaimsDbContext : DbContext
{
    public ClaimsDbContext(DbContextOptions<ClaimsDbContext> options) : base(options) { }

    public DbSet<Claim> Claims { get; set; } = null!;
    public DbSet<Claimant> Claimants { get; set; } = null!;
    public DbSet<Policy> Policies { get; set; } = null!;
    public DbSet<Adjuster> Adjusters { get; set; } = null!;
    public DbSet<ClaimNote> ClaimNotes { get; set; } = null!;
    public DbSet<ClaimAttachment> ClaimAttachments { get; set; } = null!;
    public DbSet<ClaimStatusHistory> ClaimStatusHistories { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Claim>()
            .HasIndex(c => c.ClaimNumber)
            .IsUnique();

        modelBuilder.Entity<Policy>()
            .HasIndex(p => p.PolicyNumber)
            .IsUnique();

        modelBuilder.Entity<Claim>()
            .HasOne(c => c.Adjuster)
            .WithMany(a => a.AssignedClaims)
            .OnDelete(DeleteBehavior.SetNull);

        modelBuilder.Entity<Claim>()
            .HasOne(c => c.Policy)
            .WithMany(p => p.Claims)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Claim>()
            .HasOne(c => c.Claimant)
            .WithMany(cl => cl.Claims)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
