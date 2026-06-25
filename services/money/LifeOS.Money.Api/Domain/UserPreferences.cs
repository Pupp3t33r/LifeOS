namespace LifeOS.Money.Api.Domain;

/// Per-user Money configuration (ADR-0013). A Marten <b>document</b> — not an
/// event-sourced aggregate — because nothing consumes the history of a
/// preference; only the current value parameterizes computation. One document
/// per owner, identified by <see cref="OwnerId"/> (the Marten identity is
/// configured in <c>Program.cs</c>).
///
/// An absent document is equivalent to <see cref="Defaults"/>: a calendar month
/// (<see cref="MonthStartDay"/> = 1) with no display currency chosen yet. A null
/// <see cref="DisplayCurrency"/> is the canonical "onboarding not yet complete"
/// signal for the Wallet.
public sealed class UserPreferences
{
    /// Document id. The owner's Keycloak subject (`sub`, ADR-0004).
    public string OwnerId { get; set; } = string.Empty;

    /// Day of month a period begins (ADR-0013). Range 1–31, clamped to the
    /// month's last day where shorter (see <see cref="MonthPeriod"/>). Default 1
    /// ⇒ periods are exactly calendar months.
    public int MonthStartDay { get; set; } = 1;

    /// ISO 4217 code the savings canvas and budgets aggregate into. Null until
    /// onboarding sets it (defaulted from the first savings account's currency).
    public string? DisplayCurrency { get; set; }

    /// The implied document for an owner who has none stored yet.
    public static UserPreferences Defaults(string ownerId) =>
        new() { OwnerId = ownerId, MonthStartDay = 1, DisplayCurrency = null };
}
