namespace LifeOS.Money.Tests.Infrastructure;

/// <summary>
/// Canonical test identities. These mirror the users seeded into the Keycloak realm
/// (aspire/LifeOS.AppHost/keycloak/lifeos-realm.json) so the same identity works both in the
/// integration tests (which mint their own JWTs) and in interactive/e2e logins via Keycloak.
/// </summary>
public static class TestUsers
{
    public static readonly TestUser Alice = new(
        Id: "a1a1a1a1-0000-4000-8000-000000000001",
        Username: "alice",
        Password: "alicepass",
        Email: "alice@lifeos.local",
        DisplayName: "Alice Tester");

    public static readonly TestUser Bob = new(
        Id: "b0b0b0b0-0000-4000-8000-000000000002",
        Username: "bob",
        Password: "bobpass",
        Email: "bob@lifeos.local",
        DisplayName: "Bob Tester");
}
