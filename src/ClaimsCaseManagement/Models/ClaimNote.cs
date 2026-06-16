using System.ComponentModel.DataAnnotations;

namespace ClaimsCaseManagement.Models;

public class ClaimNote
{
    public int ClaimNoteId { get; set; }

    public int ClaimId { get; set; }
    public virtual Claim Claim { get; set; } = null!;

    [Required, StringLength(100)]
    public string Author { get; set; } = string.Empty;

    [Required, StringLength(2000)]
    public string Text { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
