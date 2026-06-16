namespace LifeOS.Money.Tests.Infrastructure;

/// <summary>
/// A test identity shared between the integration test suite and the seeded Keycloak realm
/// (aspire/LifeOS.AppHost/keycloak/lifeos-realm.json). <see cref="Id"/> is the Keycloak user id,
/// which becomes the token's <c>sub</c> claim and therefore the Money <c>OwnerId</c>.
/// </summary>
public sealed record TestUser(string Id, string Username, string Password, string Email, string DisplayName);
