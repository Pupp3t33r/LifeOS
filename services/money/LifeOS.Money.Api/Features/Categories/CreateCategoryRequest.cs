namespace LifeOS.Money.Api.Features.Categories;

/// Create a user category (ADR-0024/0033). [Id] is client-assigned (ADR-0003) so
/// the create is idempotent; colour never travels here (Wallet ADR-0003).
public sealed record CreateCategoryRequest(Guid Id, string Name);
