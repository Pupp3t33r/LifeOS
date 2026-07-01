using LifeOS.Money.Api;
using LifeOS.Money.Tests.Infrastructure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.Configuration;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using Testcontainers.PostgreSql;
using Xunit;

namespace LifeOS.Money.Tests.Infrastructure;

public sealed class MoneyApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:16-alpine")
        .Build();

    public TestJwtFactory Jwt { get; } = new();

    public string TestUserId { get; set; } = "test-user-1";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Integration tests run as Development so Marten auto-creates the schema against the
        // throwaway Testcontainers database (production uses AutoCreate.None — see PLAN.md §8).
        builder.UseEnvironment("Development");
        builder.UseSetting("ConnectionStrings:money-db", _postgres.GetConnectionString());
        // Never run the hourly FX fetch loop under test — it would reach real external
        // APIs and pollute the FxRate table. Tests seed FxRate documents directly.
        builder.UseSetting("Fx:Enabled", "false");
        builder.UseSetting("Keycloak:Authority", "http://test-keycloak/realms/lifeos");
        builder.UseSetting("Keycloak:Audience", TestJwtFactory.Audience);

        builder.ConfigureTestServices(services =>
        {
            services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
            {
                options.RequireHttpsMetadata = false;
                options.SaveToken = true;
                options.MetadataAddress = null!;
                options.ConfigurationManager = new StaticConfigurationManager<OpenIdConnectConfiguration>(
                    new OpenIdConnectConfiguration
                    {
                        Issuer = TestJwtFactory.Issuer,
                        SigningKeys = { Jwt.SigningKey }
                    });
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = TestJwtFactory.Issuer,
                    ValidateAudience = true,
                    ValidAudience = TestJwtFactory.Audience,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = Jwt.SigningKey,
                    ClockSkew = TimeSpan.Zero
                };
            });
        });
    }

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();
    }

    public new async Task DisposeAsync()
    {
        await _postgres.DisposeAsync();
        await base.DisposeAsync();
    }
}
