using FluentValidation;
using JasperFx;
using JasperFx.Events.Projections;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Features.Accounts;
using LifeOS.Money.Api.Http;
using LifeOS.Money.Api.Projections;
using Marten;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Serilog;
using Wolverine;
using Wolverine.Http;
using Wolverine.Marten;

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
    options.AutoCreateSchemaObjects = AutoCreate.All;
    options.Events.UseIdentityMapForAggregates = true;
    options.Projections.Snapshot<Account>(SnapshotLifecycle.Inline);
    options.Projections.Add<TransactionRecordProjection>(ProjectionLifecycle.Inline);
}).IntegrateWithWolverine();

builder.Services.AddValidatorsFromAssemblyContaining<OpenAccountValidator>();
builder.Services.AddWolverineHttp();

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ProblemExceptionHandler>();

var keycloakAuthority = builder.Configuration["Keycloak:Authority"]
    ?? throw new InvalidOperationException("Keycloak:Authority is not configured.");
var keycloakAudience = builder.Configuration["Keycloak:Audience"] ?? "money-api";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = keycloakAuthority;
        options.Audience = keycloakAudience;
        options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
        options.TokenValidationParameters.ValidateAudience = true;
        options.TokenValidationParameters.ValidAudience = keycloakAudience;
    });

builder.Services.AddAuthorization();

builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen();

builder.Host.UseWolverine(options =>
{
    options.Policies.AutoApplyTransactions();
    options.Durability.MessageStorageSchemaName = "wolverine";
    options.Durability.Mode = DurabilityMode.Solo;
});

var app = builder.Build();

app.UseExceptionHandler();

app.UseAuthentication();
app.UseAuthorization();

app.MapOpenApi("/openapi/v1.json");
app.UseSwaggerUI(options => options.SwaggerEndpoint("/openapi/v1.json", "Money API v1"));

app.MapDefaultEndpoints();

app.MapWolverineEndpoints(opts =>
{
    opts.RoutePrefix("api");
    opts.RequireAuthorizeOnAll();
});

app.Run();
