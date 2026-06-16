using System.ComponentModel.DataAnnotations;

namespace ClaimsCaseManagement.Models;

public class Claimant
{
    public int ClaimantId { get; set; }

    [Required, StringLength(60)]
    public string FirstName { get; set; } = string.Empty;

    [Required, StringLength(60)]
    public string LastName { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(120)]
    public string Email { get; set; } = string.Empty;

    [StringLength(30)]
    public string? Phone { get; set; }

    [StringLength(250)]
    public string? Address { get; set; }

    public virtual ICollection<Claim> Claims { get; set; } = new List<Claim>();
}
