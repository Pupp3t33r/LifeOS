using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Auth;

/// Auth **contract** tests against a real Keycloak importing the production realm (ADR-0004, ADR-0014).
/// These cover the boundary synthetic tokens can't: real issuance + the JWKS/issuer handshake + the
/// realm's audience mapper. The bulk of the suite stays on <see cref="TestJwtFactory"/> for speed;
/// this is a deliberately small, slow set sharing one Keycloak via the class fixture.
public class KeycloakContractTests : IClassFixture<KeycloakAuthFactory>
{
    private readonly KeycloakAuthFactory _factory;

    public KeycloakContractTests(KeycloakAuthFactory factory) => _factory = factory;

    [Fact]
    public async Task Money_AcceptsRealKeycloakIssuedToken()
    {
        var token = await _factory.GetAccessTokenAsync(
            TestUsers.Contract.Username, TestUsers.Contract.Password);
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/preferences");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task RealToken_CarriesMoneyApiAudience()
    {
        // The realm's oidc-audience-mapper must put 'money-api' in aud, or Money rejects the token.
        var token = await _factory.GetAccessTokenAsync(
            TestUsers.Contract.Username, TestUsers.Contract.Password);

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);

        Assert.Contains("money-api", jwt.Audiences);
    }

    [Fact]
    public async Task Money_RejectsMissingToken_UnderRealValidation()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/api/preferences");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
