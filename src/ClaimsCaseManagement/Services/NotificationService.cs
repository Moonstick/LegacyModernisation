using ClaimsCaseManagement.Models;

namespace ClaimsCaseManagement.Services;

// Legacy smell: this service mixes transport concerns (sending email) with
// business rules (deciding *what* the email should say based on policy
// coverage), and is called synchronously and directly from other services
// and controllers with no queue or retry/backoff.
public class NotificationService : INotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly IConfiguration _configuration;

    public NotificationService(ILogger<NotificationService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    public Task SendClaimSubmittedEmailAsync(Claim claim)
    {
        var coverageWarning = string.Empty;

        // Business logic embedded in the notification layer.
        if (claim.Policy != null && claim.EstimatedAmount > claim.Policy.CoverageAmount)
        {
            coverageWarning = " NOTE: estimated amount exceeds the policy coverage limit.";
        }

        var subject = $"Claim {claim.ClaimNumber} submitted";
        var body = $"Dear {claim.Claimant?.FirstName}, your claim {claim.ClaimNumber} has been received." + coverageWarning;

        return SendEmailAsync(claim.Claimant?.Email, subject, body);
    }

    public Task SendStatusChangedEmailAsync(Claim claim, ClaimStatus oldStatus, ClaimStatus newStatus)
    {
        var subject = $"Claim {claim.ClaimNumber} status updated";
        var body = $"Your claim {claim.ClaimNumber} moved from {oldStatus} to {newStatus}.";

        return SendEmailAsync(claim.Claimant?.Email, subject, body);
    }

    private Task SendEmailAsync(string? to, string subject, string body)
    {
        var smtpHost = _configuration["Smtp:Host"];

        // In the original legacy app this used System.Net.Mail.SmtpClient
        // directly and synchronously. Here it's stubbed to a log line so the
        // sample runs without real SMTP infrastructure, while preserving the
        // architectural shape (notification triggered inline from business logic).
        _logger.LogInformation("Sending email via {SmtpHost} to {To}: {Subject}\n{Body}", smtpHost, to, subject, body);

        return Task.CompletedTask;
    }
}
