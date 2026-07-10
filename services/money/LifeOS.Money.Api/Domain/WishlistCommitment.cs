namespace LifeOS.Money.Api.Domain;

/// A wishlist want's single commitment state (Wallet ADR-0005 §9, Money ADR-0034;
/// supersedes ADR-0022's NotPlanned/Planned/Ordered/Received). Derived by the
/// <see cref="Projections.WishlistItemStatus"/> projection, never hand-edited.
///
/// <see cref="Idle"/> — no active commitment (the Board tray shows Idle wants, plus all
/// reusables). <see cref="Planned"/> — a planned purchase references it on a period.
/// <see cref="Financed"/> — it is a priceless item inside an active payment plan
/// (RecurringPayment, via <c>PlanItem.WishlistItemId</c>). <see cref="Bought"/> — a flow
/// paid the single purchase that referenced it. (Received is a Phase-3 Asset concern,
/// out of scope in v1.)
public enum WishlistCommitment {
    Idle,
    Planned,
    Financed,
    Bought,
}
