namespace LifeOS.Money.Api.Domain;

/// One line of a spending entry (ADR-0019/0024). All lines in an entry share its
/// currency (ADR-0019); [Amount] is signed (negative = out, positive = in) so the
/// entry total is a plain Σ (ADR-0026). [CategoryId] is the single budgeting
/// category (ADR-0024; null = uncategorised). The Phase-2 fields (ExternalRef for a
/// domain-object link, WishlistItemId) join when those services land.
public sealed record Line(
    string? Description,
    CurrencyAmount Amount,
    Guid? CategoryId);
