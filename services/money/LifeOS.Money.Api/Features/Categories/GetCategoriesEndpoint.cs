using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Categories;

public static class GetCategoriesEndpoint {
    [WolverineGet("/categories")]
    public static async Task<IReadOnlyList<CategoryResponse>> Handle(
        HttpContext context,
        IQuerySession session) {
        var userId = context.GetUserId();

        // The ADR-0024 overlay: system categories (code constants) ∪ the owner's
        // user categories (Marten documents, archived excluded from the picker).
        // User categories have no writer yet, so today this resolves to the system
        // set only — the query simply returns empty.
        var userCategories = await session.Query<Category>()
            .Where(x => x.OwnerId == userId && !x.Archived)
            .ToListAsync();

        return
        [
            ..SystemCategories.All.Select(ToResponse),
            ..userCategories.Select(ToResponse),
        ];
    }

    private static CategoryResponse ToResponse(Category category) {
        return new CategoryResponse(category.Id, category.Name, category.System, category.ServiceTypes);
    }
}
