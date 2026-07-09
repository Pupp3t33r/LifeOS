using LifeOS.Money.Api.Domain;
using Marten;

namespace LifeOS.Money.Api.Features.Categories;

/// The category-name uniqueness invariant (ADR-0033): per owner, case-insensitive,
/// trim-normalised, spanning the owner's **active *and* archived** user categories
/// **plus** the immutable system names. Archived names stay reserved so unarchive
/// can never collide. The endpoint validator uses this as the primary guard; the
/// Marten unique index on `(OwnerId, lower(Name))` is the backstop under the
/// offline create race.
public static class CategoryNaming {
    /// The stored form: trimmed, casing preserved for display.
    public static string Normalize(string name) => name.Trim();

    /// Case-insensitive, trim-insensitive name equality.
    public static bool SameName(string a, string b) =>
        string.Equals(a.Trim(), b.Trim(), StringComparison.OrdinalIgnoreCase);

    /// True if [name] is already taken for [userId] — by a system category, or by
    /// one of the owner's user categories other than [excludeId] (archived
    /// included). Pass the category's own id as [excludeId] on rename so a no-op
    /// rename doesn't collide with itself.
    public static async Task<bool> IsTakenAsync(
        IQuerySession session,
        string userId,
        string name,
        Guid? excludeId) {
        var trimmed = name.Trim();

        if (SystemCategories.All.Any(x => SameName(x.Name, trimmed))) {
            return true;
        }

        var owned = await session.Query<Category>()
            .Where(x => x.OwnerId == userId)
            .ToListAsync();

        return owned.Any(x => x.Id != excludeId && SameName(x.Name, trimmed));
    }
}
