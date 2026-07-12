namespace LifeOS.Money.Api.Domain;

/// One line of a spending entry (ADR-0019/0024). All lines in an entry share its
/// currency (ADR-0019); [Amount] is signed (negative = out, positive = in) so the
/// entry total is a plain Σ (ADR-0026). [CategoryId] is the single budgeting
/// category (ADR-0024; null = uncategorised). [WishlistItemId] links the line back to
/// a wishlist want (ADR-0019/0022): the reference the WishlistItemStatus projection
/// reads to derive Planned (on a planned-purchase line) / Bought (on a paying flow
/// line), ADR-0034. Additive and nullable — old events deserialize it as null.
///
/// [Quantity] + [UnitDimension] (ADR-0036) carry an optional physical amount on the line —
/// e.g. 0.5 kg of coffee beans, 2 m of cable. Both additive and nullable; old events
/// deserialize them as null. The unit SYMBOL (kg/lb/L/gal/m/ft) is never stored here — it
/// is a pure client rendering of (UnitDimension × the owner's UnitSystem), and Money
/// performs no conversions.
public sealed record Line(
    string? Description,
    CurrencyAmount Amount,
    Guid? CategoryId,
    Guid? WishlistItemId = null,
    decimal? Quantity = null,
    UnitDimension? UnitDimension = null);
