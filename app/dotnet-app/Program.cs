var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "NexusMidplane .NET Service");

app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    service = "dotnet-app",
    timestamp = DateTime.UtcNow
}));

app.MapGet("/hello", () => Results.Ok(new
{
    message = "Hello from NexusMidplane .NET tier",
    runtime = ".NET 8",
    hostname = Environment.MachineName
}));

app.MapGet("/info", () => Results.Ok(new
{
    service = "nexusmidplane-dotnet",
    version = "1.0.0",
    environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production"
}));

app.Run();
