namespace ClaimsCaseManagement.Services.Storage;

// Phase 0/1/2 default: writes uploaded files to disk on whichever instance
// handles the request. Works fine on a single VM, but a file uploaded via
// one instance is invisible to requests served by another instance the
// moment Phase 1 puts a load balancer in front of more than one of them -
// the upload "succeeds" but Download 404s if it lands on a different VM.
// Phase 3 fixes this by swapping IFileStorageService to AzureBlobFileStorageService.
public class LocalDiskFileStorageService : IFileStorageService
{
    private readonly string _rootPath;

    public LocalDiskFileStorageService(IConfiguration configuration)
    {
        _rootPath = configuration["Storage:LocalPath"] ?? Path.Combine(AppContext.BaseDirectory, "uploads");
        Directory.CreateDirectory(_rootPath);
    }

    public async Task<string> SaveAsync(int claimId, string fileName, Stream content, CancellationToken cancellationToken = default)
    {
        var storageReference = $"{claimId}-{Guid.NewGuid():N}-{Path.GetFileName(fileName)}";
        var fullPath = Path.Combine(_rootPath, storageReference);

        await using var fileStream = File.Create(fullPath);
        await content.CopyToAsync(fileStream, cancellationToken);

        return storageReference;
    }

    public Task<Stream?> OpenReadAsync(string storageReference, CancellationToken cancellationToken = default)
    {
        var fullPath = Path.Combine(_rootPath, storageReference);
        if (!File.Exists(fullPath))
        {
            return Task.FromResult<Stream?>(null);
        }

        return Task.FromResult<Stream?>(File.OpenRead(fullPath));
    }

    public Task DeleteAsync(string storageReference, CancellationToken cancellationToken = default)
    {
        var fullPath = Path.Combine(_rootPath, storageReference);
        if (File.Exists(fullPath))
        {
            File.Delete(fullPath);
        }

        return Task.CompletedTask;
    }
}
