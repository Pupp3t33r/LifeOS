using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Wishlist;

/// One schedule chip for a wishlist want (ADR-0034 §Board horizon, enabled by ADR-0036): a
/// (month, paid-state, unit-dimension) group of planned-purchase lines that reference the
/// want, with the summed quantity. The client renders this as an "Oct ×0.5 kg" chip (outline
/// when <see cref="Paid"/> is false, ✓ when true); the unit symbol is a client-side rendering
/// of <see cref="UnitDimension"/> × the owner's UnitSystem. A line with no quantity counts as
/// 1; a line with no dimension groups as <see cref="UnitDimension.Pieces"/>.
public sealed record WishlistScheduleChipResponse(
    int Year,
    int Month,
    bool Paid,
    UnitDimension UnitDimension,
    decimal Quantity);
