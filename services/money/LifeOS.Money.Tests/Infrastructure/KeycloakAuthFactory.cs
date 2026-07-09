using System.Net.Http.Json;
using System.Text.Json;
using DotNet.Testcontainers.Builders;
using DotNet.Testcontainers.Containers;
using LifeOS.Money.Api;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Testcontainers.PostgreSql;
using Xunit;

namespace LifeOS.Money.Tests.Infrastructure;

/// Fixture for the auth **contract** tests. Unlike <see cref="MoneyApiFactory"/> (which mints
/// synthetic tokens via <see cref="TestJwtFactory"/> and is the right tool for the bulk of tests
/// that aren't about auth), this fixture stands up a throwaway **real Keycloak** importing the
/// production <c>lifeos-realm.json</c>, and points Money at it with **no JWT override** — so it
/// exercises the genuine issuance→validation handshake (JWKS, issuer, the <c>aud: money-api</c>
/// mapper) and detects realm drift. Slow (Keycloak boots ~15-20s), so the suite is deliberately tiny.
public sealed class KeycloakAuthFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private const string Realm = "lifeos";

    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:16-alpine").Build();

    private readonly IContainer _keycloak = new ContainerBuilder("quay.io/keycloak/keycloak:26.6")
        .WithEnvironment("KC_BOOTSTRAP_ADMIN_USERNAME", "admin")
        .WithEnvironment("KC_BOOTSTRAP_ADMIN_PASSWORD", "admin")
        .WithResourceMapping(
            new FileInfo(Path.Combine(AppContext.BaseDirectory, "realm", "lifeos-realm.json")),
            "/opt/keycloak/data/import/")
        .WithCommand("start-dev", "--import-realm")
        .WithPortBinding(8080, true)
        .WithWaitStrategy(Wait.ForUnixContainer()
            .UntilHttpRequestIsSucceeded(request => request.ForPort(8080).ForPath($"/realms/{Realm}")))
        .Build();

    private string _authority = string.Empty;

    private string TokenEndpoint =>
        $"{_authority}/protocol/openid-connect/token";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Development so Marten auto-creates the schema against the throwaway Postgres. Crucially we
        // do NOT override JwtBearer here — Money validates against the real test Keycloak (Program.cs
        // sets RequireHttpsMetadata=false in Development, so http discovery is allowed).
        builder.UseEnvironment("Development");
        builder.UseSetting("ConnectionStrings:money-db", _postgres.GetConnectionString());
        builder.UseSetting("Keycloak:Authority", _authority);
        builder.UseSetting("Keycloak:Audience", "money-api");
    }

    /// Real access token from Keycloak via the money-api client's direct-grant (dev client, known
    /// secret). The realm's audience mapper stamps <c>aud: money-api</c> onto it.
    public async Task<string> GetAccessTokenAsync(string username, string password)
    {
        using var http = new HttpClient();
        var response = await http.PostAsync(TokenEndpoint, new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "password",
            ["client_id"] = "money-api",
            ["client_secret"] = "devsecret",
            ["username"] = username,
            ["password"] = password,
            ["scope"] = "openid"
        }));
        response.EnsureSuccessStatusCode();
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();
        return payload.GetProperty("access_token").GetString()!;
    }

    public async Task InitializeAsync()
    {
        await Task.WhenAll(_postgres.StartAsync(), _keycloak.StartAsync());
        var port = _keycloak.GetMappedPublicPort(8080);
        _authority = $"http://localhost:{port}/realms/{Realm}";
    }

    public new async Task DisposeAsync()
    {
        // Host first, then the containers: the host still holds live Marten/Wolverine
        // connections, so disposing Postgres before it makes shutdown throw
        // NpgsqlException during cleanup (see MoneyApiFactory).
        await base.DisposeAsync();
        await _keycloak.DisposeAsync();
        await _postgres.DisposeAsync();
    }
}
