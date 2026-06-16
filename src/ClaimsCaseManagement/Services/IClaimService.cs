using ClaimsCaseManagement.Models;

namespace ClaimsCaseManagement.Services;

public record ClaimSummaryReport(int TotalClaims, int OpenClaims, decimal TotalEstimatedExposure, decimal TotalApprovedAmount);

public interface IClaimService
{
    Task<Claim> CreateClaimAsync(Claim claim);
    Task ChangeStatusAsync(int claimId, ClaimStatus newStatus, string changedBy, string? comment);
    Task<IEnumerable<Claim>> GetOpenClaimsForAdjusterAsync(int adjusterId);
    Task<ClaimSummaryReport> GetSummaryReportAsync();
}
