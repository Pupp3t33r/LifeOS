namespace LifeOS.Money.Api.Domain;

/// Whether a wishlist want can be committed once or repeatedly (Wallet ADR-0005 §9,
/// Money ADR-0034). A <see cref="Once"/> want (fridge, tires) is schedulable/buyable a
/// single time — planning it removes it from the Board try-on tray; a <see cref="Reusable"/>
/// want (coffee, tea) stays in the tray and each drag spawns an independent planned
/// purchase. User-authored on the item, unlike the derived commitment status.
public enum WishlistRecurrence {
    Once,
    Reusable,
}
