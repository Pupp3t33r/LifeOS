using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume("postgres-data")
    .WithLifetime(ContainerLifetime.Persistent);

var moneyDb = postgres.AddDatabase("money-db");

// Keycloak: dev realm "lifeos" with a confidential "money-api" client and seeded test users
// (see keycloak/lifeos-realm.json). Host port is fixed to 8080 so the JWT issuer URL
// (http://localhost:8080/realms/lifeos) matches what downstream services configure as their
// Authority (ADR-0004). Admin credentials default to admin/admin for dev; override via
// configuration (Parameters:keycloak-username / keycloak-password) elsewhere.
var keycloakUsername = builder.AddParameter("keycloak-username", "admin");
var keycloakPassword = builder.AddParameter("keycloak-password", "admin", secret: true);

var keycloak = builder.AddKeycloak("keycloak", 8080, keycloakUsername, keycloakPassword)
    .WithRealmImport("keycloak")
    .WithHttpHealthCheck("/realms/lifeos")
    // Custom "lifeos" login theme (keycloak/themes/lifeos), selected by the realm's loginTheme.
    .WithBindMount("keycloak/themes", "/opt/keycloak/themes")
    // Shared design tokens are the single source of truth (/design/themes); mount the "calm"
    // theme's CSS binding into the login theme so the page and the Wallet app stay visually in
    // sync (see design/README.md). Point this at a different theme to reskin the login.
    .WithBindMount("../../design/themes/calm/bindings/tokens.css", "/opt/keycloak/themes/lifeos/login/resources/css/tokens.css");

var keycloakAuthority = ReferenceExpression.Create($"{keycloak.GetEndpoint("http")}/realms/lifeos");

var money = builder.AddProject<Projects.LifeOS_Money_Api>("money")
    .WithReference(moneyDb)
    .WithEnvironment("Keycloak__Authority", keycloakAuthority)
    .WithEnvironment("Keycloak__Audience", "money-api")
    .WaitFor(keycloak);

var gateway = builder.AddProject<Projects.LifeOS_Gateway>("gateway")
    .WithReference(money)
    .WithEnvironment("Keycloak__Authority", keycloakAuthority)
    .WithEnvironment("Keycloak__Audience", "money-api")
    .WaitFor(keycloak)
    .WithExternalHttpEndpoints();

builder.Build().Run();
