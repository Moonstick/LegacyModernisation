using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ClaimsCaseManagement.Models;

public class Policy
{
    public int PolicyId { get; set; }

    [Required, StringLength(20)]
    public string PolicyNumber { get; set; } = string.Empty;

    [Required, StringLength(120)]
    public string PolicyHolderName { get; set; } = string.Empty;

    public PolicyType PolicyType { get; set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal CoverageAmount { get; set; }

    public DateTime EffectiveDate { get; set; }

    public DateTime ExpiryDate { get; set; }

    // Legacy smell: lazy-loaded navigation collection, no encapsulation.
    public virtual ICollection<Claim> Claims { get; set; } = new List<Claim>();
}
