using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ClaimsCaseManagement.Models;

public class Claim
{
    public int ClaimId { get; set; }

    [StringLength(20)]
    public string ClaimNumber { get; set; } = string.Empty;

    public int PolicyId { get; set; }
    public virtual Policy Policy { get; set; } = null!;

    public int ClaimantId { get; set; }
    public virtual Claimant Claimant { get; set; } = null!;

    public int? AdjusterId { get; set; }
    public virtual Adjuster? Adjuster { get; set; }

    [DataType(DataType.Date)]
    public DateTime DateOfLoss { get; set; }

    public DateTime DateSubmitted { get; set; } = DateTime.UtcNow;

    [Required, StringLength(2000)]
    public string Description { get; set; } = string.Empty;

    public ClaimStatus Status { get; set; } = ClaimStatus.Submitted;

    [Column(TypeName = "decimal(18,2)")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Estimated amount must be greater than zero.")]
    public decimal EstimatedAmount { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal? ApprovedAmount { get; set; }

    public virtual ICollection<ClaimNote> Notes { get; set; } = new List<ClaimNote>();
    public virtual ICollection<ClaimAttachment> Attachments { get; set; } = new List<ClaimAttachment>();
    public virtual ICollection<ClaimStatusHistory> StatusHistory { get; set; } = new List<ClaimStatusHistory>();
}
