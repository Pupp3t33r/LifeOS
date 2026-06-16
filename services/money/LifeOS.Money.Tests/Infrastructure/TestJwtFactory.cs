using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

namespace LifeOS.Money.Tests.Infrastructure;

public sealed class TestJwtFactory
{
    public const string Issuer = "money-test-issuer";
    public const string Audience = "money-api";

    private readonly RsaSecurityKey _signingKey;
    private readonly SigningCredentials _signingCredentials;

    public TestJwtFactory()
    {
        var rsa = RSA.Create(2048);
        _signingKey = new RsaSecurityKey(rsa) { KeyId = "money-test-key-1" };
        _signingCredentials = new SigningCredentials(_signingKey, SecurityAlgorithms.RsaSha256);
    }

    public RsaSecurityKey SigningKey => _signingKey;

    public string Create(string userId, TimeSpan? lifetime = null)
    {
        var handler = new JwtSecurityTokenHandler();
        var expires = DateTime.UtcNow.Add(lifetime ?? TimeSpan.FromMinutes(30));
        // Anchor issuance before expiry so already-expired tokens (negative lifetime) are still well-formed.
        var issuedAt = expires.AddHours(-1);
        var token = handler.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = Issuer,
            Audience = Audience,
            Subject = new ClaimsIdentity(new[] { new Claim("sub", userId) }),
            NotBefore = issuedAt,
            IssuedAt = issuedAt,
            Expires = expires,
            SigningCredentials = _signingCredentials
        });
        return handler.WriteToken(token);
    }
}
