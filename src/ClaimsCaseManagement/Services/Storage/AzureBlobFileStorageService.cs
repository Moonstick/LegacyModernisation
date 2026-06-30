using Azure.Storage.Blobs;

namespace ClaimsCaseManagement.Services.Storage;

// Phase 3: file attachments move off the local instance disk into Azure Blob
// Storage, so every App Service instance (and every region from Phase 6
// onward) sees the same files regardless of which instance handled the
// upload. Selected via Storage:Provider=AzureBlob - see Program.cs.
public class AzureBlobFileStorageService : IFileStorageService
{
    private readonly BlobContainerClient _container;

    public AzureBlobFileStorageService(IConfiguration configuration)
    {
        var connectionString = configuration["Storage:AzureBlob:ConnectionString"]
            ?? throw new InvalidOperationException("Storage:AzureBlob:ConnectionString is required when Storage:Provider is AzureBlob.");
        var containerName = configuration["Storage:AzureBlob:ContainerName"] ?? "attachments";

        var serviceClient = new BlobServiceClient(connectionString);
        _container = serviceClient.GetBlobContainerClient(containerName);
        _container.CreateIfNotExists();
    }

    public async Task<string> SaveAsync(int claimId, string fileName, Stream content, CancellationToken cancellationToken = default)
    {
        var blobName = $"{claimId}/{Guid.NewGuid():N}-{Path.GetFileName(fileName)}";
        var blobClient = _container.GetBlobClient(blobName);
        await blobClient.UploadAsync(content, overwrite: true, cancellationToken);

        return blobName;
    }

    public async Task<Stream?> OpenReadAsync(string storageReference, CancellationToken cancellationToken = default)
    {
        var blobClient = _container.GetBlobClient(storageReference);
        if (!await blobClient.ExistsAsync(cancellationToken))
        {
            return null;
        }

        return await blobClient.OpenReadAsync(cancellationToken: cancellationToken);
    }

    public async Task DeleteAsync(string storageReference, CancellationToken cancellationToken = default)
    {
        await _container.GetBlobClient(storageReference).DeleteIfExistsAsync(cancellationToken: cancellationToken);
    }
}
