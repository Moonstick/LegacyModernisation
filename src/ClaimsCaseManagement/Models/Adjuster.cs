using System.ComponentModel.DataAnnotations;

namespace ClaimsCaseManagement.Models;

public class Adjuster
{
    public int AdjusterId { get; set; }

    [Required, StringLength(120)]
    public string Name { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(120)]
    public string Email { get; set; } = string.Empty;

    [StringLength(60)]
    public string Department { get; set; } = "General";

    public virtual ICollection<Claim> AssignedClaims { get; set; } = new List<Claim>();
}
