using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Categories;

public static class UnarchiveCategoryEndpoint {
    [WolverinePost("/categories/{id}/unarchive")]
    public static async Task<CategoryResponse> Handle(
        Guid id,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        if (SystemCategories.All.Any(x => x.Id == id)) {
            throw new ForbiddenException("System categories are never archived (ADR-0024).");
        }

        var category = await session.LoadAsync<Category>(id);
        if (category is null || category.OwnerId != userId) {
            throw new NotFoundException($"Category '{id}' was not found.");
        }

        // No uniqueness re-check: archived names stay reserved (ADR-0033), so a
        // restore can never collide.
        if (category.Archived) {
            category.Archived = false;
            session.Store(category);
            await session.SaveChangesAsync();
        }

        return CategoryResponse.From(category);
    }
}
