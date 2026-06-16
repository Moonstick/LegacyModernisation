using ClaimsCaseManagement.Models;

namespace ClaimsCaseManagement.Services;

public interface INotificationService
{
    Task SendClaimSubmittedEmailAsync(Claim claim);
    Task SendStatusChangedEmailAsync(Claim claim, ClaimStatus oldStatus, ClaimStatus newStatus);
}
