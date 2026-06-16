using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace LifeOS.Money.Api.Http;

public sealed class BearerSecuritySchemeDocumentTransformer : IOpenApiDocumentTransformer
{
    public Task TransformAsync(
        OpenApiDocument document,
        OpenApiDocumentTransformerContext context,
        CancellationToken cancellationToken)
    {
        document.Components ??= new OpenApiComponents();
        document.Components.SecuritySchemes ??= new Dictionary<string, IOpenApiSecurityScheme>();
        document.Security ??= new List<OpenApiSecurityRequirement>();

        const string SchemeId = "Bearer";

        document.Components.SecuritySchemes[SchemeId] = new OpenApiSecurityScheme
        {
            Type = SecuritySchemeType.OAuth2,
            Description = "OAuth2 Authorization Code flow via Keycloak realm 'lifeos'. " +
                          "Use client id 'money-api' (dev secret 'devsecret') and log in as devuser/devpass.",
            Flows = new OpenApiOAuthFlows
            {
                AuthorizationCode = new OpenApiOAuthFlow
                {
                    AuthorizationUrl = new Uri("http://localhost:8080/realms/lifeos/protocol/openid-connect/auth"),
                    TokenUrl = new Uri("http://localhost:8080/realms/lifeos/protocol/openid-connect/token"),
                    Scopes = new Dictionary<string, string>
                    {
                        { "openid", "OpenID Connect authentication" },
                        { "profile", "User profile claim" }
                    }
                }
            }
        };

        document.Security.Add(new OpenApiSecurityRequirement
        {
            [new OpenApiSecuritySchemeReference(SchemeId, document, null)] = new List<string> { "openid", "profile" }
        });

        return Task.CompletedTask;
    }
}
