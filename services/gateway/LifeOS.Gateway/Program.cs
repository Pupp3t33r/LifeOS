using Microsoft.Extensions.FileProviders;
using Yarp.ReverseProxy.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Load routes from appsettings.json, destinations from code (Aspire service discovery).
var moneyUrl = builder.Configuration["services:money:http:0"]
    ?? builder.Configuration["services:money:https:0"]
    ?? "http://localhost:5221";

// Keycloak is fronted by the Gateway (same-origin, no CORS): "/realms/*" and "/resources/*"
// proxy here. Prefer the plain-HTTP endpoint so we avoid Keycloak's self-signed dev cert.
var keycloakUrl = builder.Configuration["services:keycloak:http:0"]
    ?? builder.Configuration["services:keycloak:https:0"]
    ?? "http://localhost:8080";

builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"))
    .LoadFromMemory(
        routes: Array.Empty<RouteConfig>(),
        clusters: new[]
        {
            new ClusterConfig
            {
                ClusterId = "money",
                Destinations = new Dictionary<string, DestinationConfig>
                {
                    ["money"] = new DestinationConfig { Address = moneyUrl }
                }
            },
            new ClusterConfig
            {
                ClusterId = "keycloak",
                Destinations = new Dictionary<string, DestinationConfig>
                {
                    ["keycloak"] = new DestinationConfig { Address = keycloakUrl }
                }
            }
        });

var app = builder.Build();

// Serve the Wallet Flutter web build when configured. YARP API routes
// (/api/*, /app/v1/*) are registered as endpoints and take precedence over
// the SPA fallback below; static-asset requests (/flutter.js, /main.dart.js,
// /assets/*, etc.) are resolved from the build output by the middleware.
var walletWebRoot = builder.Configuration["Wallet:WebRoot"];
var walletWebConfigured = !string.IsNullOrEmpty(walletWebRoot) && Directory.Exists(walletWebRoot);

if (walletWebConfigured)
{
    var fileProvider = new PhysicalFileProvider(walletWebRoot!);
    app.UseDefaultFiles(new DefaultFilesOptions { FileProvider = fileProvider });
    app.UseStaticFiles(new StaticFileOptions { FileProvider = fileProvider });
}

app.MapDefaultEndpoints();
app.MapReverseProxy();

if (walletWebConfigured)
{
    // SPA fallback: client-side routes (e.g. /home, /transactions) without a
    // file extension serve index.html. Missing static assets (a .js/.png 404)
    // fall through to a real 404 rather than confusing the browser with HTML.
    app.MapFallback(async context =>
    {
        var path = context.Request.Path.Value;
        if (!string.IsNullOrEmpty(path) && !Path.HasExtension(path))
        {
            context.Response.ContentType = "text/html; charset=utf-8";
            await context.Response.SendFileAsync(Path.Combine(walletWebRoot!, "index.html"));
            return;
        }

        context.Response.StatusCode = StatusCodes.Status404NotFound;
    });
}

app.Run();
