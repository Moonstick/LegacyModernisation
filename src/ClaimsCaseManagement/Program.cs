using ClaimsCaseManagement.Data;
using ClaimsCaseManagement.Services;
using ClaimsCaseManagement.Services.Storage;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

// Legacy smell: connection string read directly from configuration with no
// secret management/Key Vault integration, and lazy-loading proxies enabled
// app-wide - both typical of an EF6-era app lifted into EF Core.
builder.Services.AddDbContext<ClaimsDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("ClaimsDb"))
           .UseLazyLoadingProxies());

builder.Services.AddScoped<IClaimService, ClaimService>();
builder.Services.AddScoped<INotificationService, NotificationService>();

// Storage:Provider selects where claim attachments live - "Local" (default,
// Phase 0-2) writes to the instance's own disk; "AzureBlob" (Phase 3+) writes
// to a Storage Account so every instance/region sees the same files.
var storageProvider = builder.Configuration["Storage:Provider"] ?? "Local";
if (string.Equals(storageProvider, "AzureBlob", StringComparison.OrdinalIgnoreCase))
{
    builder.Services.AddSingleton<IFileStorageService, AzureBlobFileStorageService>();
}
else
{
    builder.Services.AddSingleton<IFileStorageService, LocalDiskFileStorageService>();
}

// Redis:ConnectionString selects the session backing store - unset (default,
// Phase 0-3) uses ASP.NET Core's in-memory distributed cache, which only
// exists on the instance that handled the request; set (Phase 4+) backs
// session with Azure Cache for Redis so it's consistent across instances.
var redisConnectionString = builder.Configuration["Redis:ConnectionString"];
if (!string.IsNullOrEmpty(redisConnectionString))
{
    builder.Services.AddStackExchangeRedisCache(options =>
    {
        options.Configuration = redisConnectionString;
        options.InstanceName = "ClaimsCaseManagement:";
    });
}
else
{
    builder.Services.AddDistributedMemoryCache();
}

builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

builder.Services.AddHealthChecks();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ClaimsDbContext>();
    DbInitializer.Seed(db);
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}

app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.UseAuthorization();

app.MapHealthChecks("/health");

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Claims}/{action=Index}/{id?}");

app.Run();
