using System.ComponentModel.DataAnnotations;

namespace ClaimsCaseManagement.Models;

public class ClaimAttachment
{
    public int ClaimAttachmentId { get; set; }

    public int ClaimId { get; set; }
    public virtual Claim Claim { get; set; } = null!;

    [Required, StringLength(260)]
    public string FileName { get; set; } = string.Empty;

    [StringLength(100)]
    public string ContentType { get; set; } = "application/octet-stream";

    // Legacy smell: storing a local file path rather than a blob storage reference.
    [Required, StringLength(500)]
    public string FilePath { get; set; } = string.Empty;

    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
}
