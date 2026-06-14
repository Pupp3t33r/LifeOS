using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume("postgres-data")
    .WithLifetime(ContainerLifetime.Persistent);

var moneyDb = postgres.AddDatabase("money-db");

// Keycloak: dev realm "lifeos" with a public "money-api" client and a dev user.
// Host port is fixed to 8080 so the JWT issuer URL (http://localhost:8080/realms/lifeos)
// matches what downstream services configure as their Authority (ADR-0004).
var keycloak = builder.AddContainer("keycloak", "quay.io/keycloak/keycloak", "26.0")
    .WithHttpEndpoint(port: 8080, targetPort: 8080, name: "http")
    .WithHttpHealthCheck("/realms/lifeos")
    .WithEnvironment("KC_BOOTSTRAP_ADMIN_USERNAME", "admin")
    .WithEnvironment("KC_BOOTSTRAP_ADMIN_PASSWORD", "admin")
    .WithEnvironment("KC_HOSTNAME", "localhost")
    .WithBindMount(
        Path.Combine(builder.AppHostDirectory!, "keycloak"),
        "/opt/keycloak/data/import",
        isReadOnly: true)
    .WithArgs("start-dev", "--import-realm");

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
