using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;

var builder = DistributedApplication.CreateBuilder(args);

// Centralized, environment-specific settings (see appsettings*.json → "Lifeos"). Static knobs
// live here so they change in one file; derived URLs come from Aspire references / the public
// frontend origin below — never hardcoded per project.
var lifeos = builder.Configuration.GetSection("Lifeos");
var realm = lifeos["Keycloak:Realm"] ?? "lifeos";
var keycloakFrontendUrl = lifeos["Keycloak:FrontendUrl"] ?? "http://localhost:5022";
var postgresImageTag = lifeos["Postgres:ImageTag"] ?? "18.3";
var audience = lifeos["Auth:Audience"] ?? "money-api";

// Pin the Postgres image tag: 18+ changed the data directory layout, which broke upgrades from
// pre-18 volumes. A stale pre-18 "postgres-data" volume must be removed once
// (docker volume rm postgres-data) before 18.x can initialize the new layout.
var postgres = builder.AddPostgres("postgres")
    .WithImageTag(postgresImageTag)
    .WithDataVolume("postgres-data")
    .WithLifetime(ContainerLifetime.Persistent);

var moneyDb = postgres.AddDatabase("money-db");

// Keycloak: dev realm (see keycloak/lifeos-realm.json), seeded test users, custom login theme.
// The browser never talks to Keycloak directly — the Gateway reverse-proxies "/realms/*" and
// "/resources/*" to it, so the login form and token exchange are same-origin with the app (no
// CORS, no self-signed cert or public Keycloak port). KC_HOSTNAME pins the advertised
// issuer/frontend URL to that public origin, so every token's "iss" is the Gateway origin.
// KC_HOSTNAME_BACKCHANNEL_DYNAMIC keeps "iss" public while letting backchannel endpoints
// (jwks_uri, token) resolve to the actual request host — so services validate directly and
// internally instead of routing key fetches back out through the Gateway. KC_HTTP_ENABLED
// exposes the plain-HTTP endpoint those internal callers (and the Gateway proxy) use.
var keycloakUsername = builder.AddParameter("keycloak-username", "admin");
var keycloakPassword = builder.AddParameter("keycloak-password", "admin", secret: true);

var keycloak = builder.AddKeycloak("keycloak", adminUsername: keycloakUsername, adminPassword: keycloakPassword)
    // Dev Keycloak keeps a data volume so the migrated schema + realm + runtime state (passkey
    // enrollments, sessions) survive container recreation — skips the ~9s migration+import on restart
    // and is a prerequisite for passkeys (ADR-0014). The container is deliberately NOT lifetime-persistent:
    // each `aspire start` recreates it, so theme (login.ftl) and code changes are picked up cleanly
    // (lifetime reuse previously served stale themes). Trade-off: the realm imports into the volume ONCE,
    // so later lifeos-realm.json edits need `docker volume rm keycloak-data` to re-import. Prod uses a
    // Postgres-backed Keycloak DB rather than this dev H2 volume.
    .WithDataVolume("keycloak-data")
    .WithRealmImport("keycloak")
    .WithEnvironment("KC_HTTP_ENABLED", "true")
    .WithEnvironment("KC_HOSTNAME", keycloakFrontendUrl)
    .WithEnvironment("KC_HOSTNAME_BACKCHANNEL_DYNAMIC", "true")
    .WithEnvironment("KC_PROXY_HEADERS", "xforwarded")
    .WithHttpHealthCheck($"/realms/{realm}")
    // Custom "lifeos" login theme (keycloak/themes/lifeos), selected by the realm's loginTheme.
    .WithBindMount("keycloak/themes", "/opt/keycloak/themes")
    // Shared design tokens are the single source of truth (/design/themes); mount the "calm"
    // theme's CSS binding into the login theme so the page and the Wallet app stay visually in
    // sync (see design/README.md). Point this at a different theme to reskin the login.
    .WithBindMount("../../design/themes/calm/bindings/tokens.css", "/opt/keycloak/themes/lifeos/login/resources/css/tokens.css");

// Services validate tokens against Keycloak's INTERNAL endpoint — they fetch discovery + JWKS
// directly (server-to-server), never through the Gateway. The discovery doc still reports the
// public "iss" (KC_HOSTNAME), so tokens minted for the browser validate here unchanged; only
// the backchannel key fetch stays internal (KC_HOSTNAME_BACKCHANNEL_DYNAMIC).
var keycloakAuthority = ReferenceExpression.Create($"{keycloak.GetEndpoint("http")}/realms/{realm}");

IResourceBuilder<T> WithAuth<T>(IResourceBuilder<T> project) where T : IResourceWithEnvironment {
    return project
        .WithEnvironment("Keycloak__Authority", keycloakAuthority)
        .WithEnvironment("Keycloak__Audience", audience);
}

var money = WithAuth(builder.AddProject<Projects.LifeOS_Money_Api>("money")
        .WithReference(moneyDb))
    .WaitFor(keycloak);

// Absolute path to the Wallet Flutter web build output. Served by the Gateway as static files
// (same origin → no CORS). Only exists after `flutter build web` runs; the Gateway starts fine
// without it (Directory.Exists guard in Program.cs).
var walletWebRoot = Path.GetFullPath(
    Path.Combine(builder.AppHostDirectory, "..", "..", "apps", "wallet", "build", "web"));

var gateway = WithAuth(builder.AddProject<Projects.LifeOS_Gateway>("gateway")
        .WithReference(money)
        .WithReference(keycloak))
    .WithEnvironment("Wallet__WebRoot", walletWebRoot)
    .WaitFor(keycloak)
    .WithExternalHttpEndpoints();

builder.Build().Run();
