using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Categories;

public static class GetCategoriesEndpoint {
    [WolverineGet("/categories")]
    public static async Task<IReadOnlyList<CategoryResponse>> Handle(
        HttpContext context,
        IQuerySession session,
        bool includeArchived = false) {
        var userId = context.GetUserId();

        // The ADR-0024 overlay: system categories (code constants) ∪ the owner's
        // user categories (Marten documents). The picker asks for active only
        // (default); the management screen (Wallet ADR-0008) passes
        // includeArchived=true to also get the owner's archived categories.
        IQueryable<Category> query = session.Query<Category>().Where(x => x.OwnerId == userId);
        if (!includeArchived) {
            query = query.Where(x => !x.Archived);
        }
        var userCategories = await query.ToListAsync();

        return
        [
            ..SystemCategories.All.Select(CategoryResponse.From),
            ..userCategories.Select(CategoryResponse.From),
        ];
    }
}
