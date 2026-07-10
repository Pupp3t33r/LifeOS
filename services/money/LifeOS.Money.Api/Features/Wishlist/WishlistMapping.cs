using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.Wishlist;

/// Enum ⇄ wire-string mapping for the wishlist contract, matching this service's
/// convention of exposing enums as lowercase strings in DTOs (never raw integers).
public static class WishlistMapping {
    public static WishlistRecurrence ParseRecurrence(string? value) =>
        value == "reusable" ? WishlistRecurrence.Reusable : WishlistRecurrence.Once;

    public static string RecurrenceString(WishlistRecurrence recurrence) =>
        recurrence == WishlistRecurrence.Reusable ? "reusable" : "once";

    public static string CommitmentString(WishlistCommitment commitment) => commitment switch {
        WishlistCommitment.Planned => "planned",
        WishlistCommitment.Financed => "financed",
        WishlistCommitment.Bought => "bought",
        _ => "idle",
    };
}
