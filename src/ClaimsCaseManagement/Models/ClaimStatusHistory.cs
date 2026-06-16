namespace ClaimsCaseManagement.Models;

public class ClaimStatusHistory
{
    public int ClaimStatusHistoryId { get; set; }

    public int ClaimId { get; set; }
    public virtual Claim Claim { get; set; } = null!;

    public ClaimStatus OldStatus { get; set; }
    public ClaimStatus NewStatus { get; set; }

    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;

    public string ChangedBy { get; set; } = "system";

    public string? Comment { get; set; }
}
