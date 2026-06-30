namespace ClaimsCaseManagement.Services.Storage;

public interface IFileStorageService
{
    Task<string> SaveAsync(int claimId, string fileName, Stream content, CancellationToken cancellationToken = default);

    Task<Stream?> OpenReadAsync(string storageReference, CancellationToken cancellationToken = default);

    Task DeleteAsync(string storageReference, CancellationToken cancellationToken = default);
}
