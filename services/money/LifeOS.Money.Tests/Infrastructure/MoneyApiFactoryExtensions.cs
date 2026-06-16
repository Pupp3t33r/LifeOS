using LifeOS.Money.Tests.Infrastructure;

namespace LifeOS.Money.Tests.Infrastructure;

public static class MoneyApiFactoryExtensions
{
    public static HttpClient CreateClientForUser(this MoneyApiFactory factory, string userId)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", factory.Jwt.Create(userId));
        return client;
    }

    public static HttpClient CreateClientFor(this MoneyApiFactory factory, TestUser user)
    {
        return factory.CreateClientForUser(user.Id);
    }

    public static HttpClient CreateClientWithoutAuth(this MoneyApiFactory factory)
    {
        return factory.CreateClient();
    }
}
