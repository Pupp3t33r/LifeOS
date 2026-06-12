using Yarp.ReverseProxy.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Load routes from appsettings.json, destinations from code
var moneyUrl = builder.Configuration["services:money:http:0"]
    ?? builder.Configuration["services:money:https:0"]
    ?? "http://localhost:5221";

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
            }
        });

var app = builder.Build();

app.MapDefaultEndpoints();
app.MapReverseProxy();

app.Run();
