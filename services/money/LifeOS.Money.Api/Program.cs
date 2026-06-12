using Marten;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

builder.Host.UseSerilog((context, config) =>
{
    config.ReadFrom.Configuration(context.Configuration);
    config.WriteTo.Console();
    config.Enrich.FromLogContext();
});

var connectionString = builder.Configuration.GetConnectionString("money-db")
    ?? throw new InvalidOperationException("Connection string 'money-db' not found.");

builder.Services.AddMarten(options =>
{
    options.Connection(connectionString);
});

var app = builder.Build();

app.MapDefaultEndpoints();

app.MapGet("/healthz", () => Results.Ok("healthy"));

app.Run();
