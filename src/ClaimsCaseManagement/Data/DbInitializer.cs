using ClaimsCaseManagement.Models;

namespace ClaimsCaseManagement.Data;

// Legacy smell: schema is created at application startup via EnsureCreated()
// rather than through migrations, and seed data is mixed in with bootstrap logic.
public static class DbInitializer
{
    public static void Seed(ClaimsDbContext context)
    {
        context.Database.EnsureCreated();

        if (context.Policies.Any())
        {
            return;
        }

        var policies = new[]
        {
            new Policy { PolicyNumber = "POL-AUTO-1001", PolicyHolderName = "Maria Gomez", PolicyType = PolicyType.Auto, CoverageAmount = 25000m, EffectiveDate = DateTime.UtcNow.AddYears(-1), ExpiryDate = DateTime.UtcNow.AddYears(1) },
            new Policy { PolicyNumber = "POL-HOME-2001", PolicyHolderName = "James Carter", PolicyType = PolicyType.Home, CoverageAmount = 350000m, EffectiveDate = DateTime.UtcNow.AddYears(-2), ExpiryDate = DateTime.UtcNow.AddMonths(6) },
            new Policy { PolicyNumber = "POL-HEALTH-3001", PolicyHolderName = "Aisha Khan", PolicyType = PolicyType.Health, CoverageAmount = 100000m, EffectiveDate = DateTime.UtcNow.AddMonths(-6), ExpiryDate = DateTime.UtcNow.AddMonths(6) },
        };

        var claimants = new[]
        {
            new Claimant { FirstName = "Maria", LastName = "Gomez", Email = "maria.gomez@example.com", Phone = "555-0101", Address = "12 Birch St" },
            new Claimant { FirstName = "James", LastName = "Carter", Email = "james.carter@example.com", Phone = "555-0102", Address = "44 Oak Ave" },
            new Claimant { FirstName = "Aisha", LastName = "Khan", Email = "aisha.khan@example.com", Phone = "555-0103", Address = "9 Maple Rd" },
        };

        var adjusters = new[]
        {
            new Adjuster { Name = "Tom Reilly", Email = "tom.reilly@claimsco.example", Department = "Auto" },
            new Adjuster { Name = "Priya Nair", Email = "priya.nair@claimsco.example", Department = "Property" },
        };

        context.Policies.AddRange(policies);
        context.Claimants.AddRange(claimants);
        context.Adjusters.AddRange(adjusters);
        context.SaveChanges();

        var claim1 = new Claim
        {
            ClaimNumber = "CLM-100001",
            PolicyId = policies[0].PolicyId,
            ClaimantId = claimants[0].ClaimantId,
            AdjusterId = adjusters[0].AdjusterId,
            DateOfLoss = DateTime.UtcNow.AddDays(-10),
            Description = "Rear-end collision on Main St, bumper and tail light damage.",
            Status = ClaimStatus.UnderReview,
            EstimatedAmount = 2800m
        };

        var claim2 = new Claim
        {
            ClaimNumber = "CLM-100002",
            PolicyId = policies[1].PolicyId,
            ClaimantId = claimants[1].ClaimantId,
            DateOfLoss = DateTime.UtcNow.AddDays(-3),
            Description = "Storm damage to roof shingles and gutter.",
            Status = ClaimStatus.Submitted,
            EstimatedAmount = 7600m
        };

        context.Claims.AddRange(claim1, claim2);
        context.SaveChanges();

        context.ClaimStatusHistories.Add(new ClaimStatusHistory
        {
            ClaimId = claim1.ClaimId,
            OldStatus = ClaimStatus.Submitted,
            NewStatus = ClaimStatus.UnderReview,
            ChangedBy = "tom.reilly",
            Comment = "Assigned for initial review."
        });

        context.SaveChanges();
    }
}
