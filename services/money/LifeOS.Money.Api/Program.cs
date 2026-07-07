using FluentValidation;
using JasperFx;
using JasperFx.Events.Projections;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Fx;
using LifeOS.Money.Api.Features.Accounts;
using LifeOS.Money.Api.Features.UserPreferences;
using LifeOS.Money.Api.Fx;
using LifeOS.Money.Api.Http;
using LifeOS.Money.Api.Projections;
using Marten;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Options;
using Weasel.Core;
using Serilog;
using Wolverine;
using Wolverine.Http;
using Wolverine.Http.FluentValidation;
using Wolverine.Marten;

namespace LifeOS.Money.Api;

public class Program
{
    public static void Main(string[] args)
    {
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

            // System.Text.Json for event/document storage so the RecurringPayment
            // recurrence-rule discriminated union (ADR-0017: STJ [JsonPolymorphic]
            // `kind` discriminator) round-trips identically in the event store and in
            // the API contract the Dart client mirrors — one serialization definition,
            // not two. Marten otherwise defaults to Newtonsoft, which cannot rehydrate
            // an abstract rule type. Pre-prod, no migration; a local dev money-db with
            // Newtonsoft-written events must be reset (drop the money-db volume).
            //
            // AllowOutOfOrderMetadataProperties is required: STJ writes the `kind`
            // discriminator first, but Postgres jsonb normalizes (reorders) object
            // keys, so on read the discriminator is rarely first. Without this option
            // the polymorphic reader fails with "must specify a type discriminator".
            // (net9+ feature; the project targets net10.)
            options.UseSystemTextJsonForSerialization(
                EnumStorage.AsInteger,
                Casing.Default,
                json => json.AllowOutOfOrderMetadataProperties = true);

            // Schema migration policy (see PLAN.md §8): Development creates/updates the schema at
            // startup for fast iteration; every other environment never touches the schema at
            // runtime and expects it to already exist. Applying migrations as a dedicated
            // pre-deploy step (`dotnet run -- resources setup`, DDL-privileged role) is CI/CD work
            // that is not wired yet.
            options.AutoCreateSchemaObjects = builder.Environment.IsDevelopment()
                ? AutoCreate.All
                : AutoCreate.None;

            options.Events.UseIdentityMapForAggregates = true;
            options.Projections.Snapshot<Account>(SnapshotLifecycle.Inline);
            options.Projections.Snapshot<AccountingPeriod>(SnapshotLifecycle.Inline);
            options.Projections.Snapshot<RecurringPayment>(SnapshotLifecycle.Inline);
            options.Projections.Add<SavingsMovementRecordProjection>(ProjectionLifecycle.Inline);
            options.Projections.Add<FlowEntryRecordProjection>(ProjectionLifecycle.Inline);
            options.Projections.Add<SkippedOccurrenceRecordProjection>(ProjectionLifecycle.Inline);
            options.Projections.Add<PlannedPurchaseRecordProjection>(ProjectionLifecycle.Inline);

            // UserPreferences (ADR-0013) is a plain document keyed by the owner's
            // Keycloak subject, not an event-sourced aggregate.
            options.Schema.For<UserPreferences>().Identity(x => x.OwnerId);

            // FxRate (ADR-0008/0015) is external observed data, not user-authored
            // domain state, so it lives in a query table the fetch service upserts —
            // not the event store. Keyed by the deterministic Base:Quote:Date:Source
            // id (idempotent re-fetch). Indexed for the by-pair conversion query.
            options.Schema.For<FxRate>()
                .Identity(x => x.Id)
                .Duplicate(x => x.Base)
                .Duplicate(x => x.Quote);
        }).IntegrateWithWolverine();

        // FX rate service (ADR-0015): hourly BackgroundService fetching Belarusbank
        // card SELL rates (preferred) + Frankfurter (fallback) into the FxRate table.
        builder.Services.Configure<FxOptions>(builder.Configuration.GetSection(FxOptions.SectionName));
        builder.Services.AddHttpClient<BelarusbankRateSource>();
        builder.Services.AddHttpClient<FrankfurterRateSource>((sp, client) =>
        {
            // Frankfurter source issues relative requests ("latest?base=..."); anchor
            // them on the configured base URL (trailing slash so the path appends).
            var fxOptions = sp.GetRequiredService<IOptions<FxOptions>>().Value;
            client.BaseAddress = new Uri(fxOptions.FrankfurterBaseUrl.TrimEnd('/') + "/");
        });
        builder.Services.AddTransient<IFxRateSource>(sp => sp.GetRequiredService<BelarusbankRateSource>());
        builder.Services.AddTransient<IFxRateSource>(sp => sp.GetRequiredService<FrankfurterRateSource>());
        builder.Services.AddHostedService<FxRateFetchService>();

        builder.Services.AddValidatorsFromAssemblyContaining<OpenAccountValidator>();
        builder.Services.AddWolverineHttp();

        // ADR-0013: re-anchoring MonthStartDay is locked once a month is closed.
        // MonthlyReview (PLAN §3.7) is not built yet, so nothing can be closed —
        // swap this registration when §3.7 lands. See NoClosedMonthsGuard.
        builder.Services.AddSingleton<IClosedMonthGuard, NoClosedMonthsGuard>();

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

        builder.Services.AddOpenApi(options => options.AddDocumentTransformer<BearerSecuritySchemeDocumentTransformer>());

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
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint("/openapi/v1.json", "Money API v1");
            options.OAuthClientId("money-api");
            options.OAuthClientSecret("devsecret");
            options.OAuthScopes("openid", "profile");
            options.OAuthUsePkce();
        });

        app.MapDefaultEndpoints();

        app.MapWolverineEndpoints(opts =>
        {
            opts.RoutePrefix("api");
            opts.RequireAuthorizeOnAll();
            opts.UseFluentValidationProblemDetailMiddleware();
        });

        app.Run();
    }
}
