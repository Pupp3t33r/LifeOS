using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Categories;

public static class ArchiveCategoryEndpoint {
    [WolverinePost("/categories/{id}/archive")]
    public static async Task<CategoryResponse> Handle(
        Guid id,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        if (SystemCategories.All.Any(x => x.Id == id)) {
            throw new ForbiddenException("System categories cannot be archived (ADR-0024).");
        }

        var category = await session.LoadAsync<Category>(id);
        if (category is null || category.OwnerId != userId) {
            throw new NotFoundException($"Category '{id}' was not found.");
        }

        // Idempotent: archiving an already-archived category is a no-op.
        if (!category.Archived) {
            category.Archived = true;
            session.Store(category);
            await session.SaveChangesAsync();
        }

        return CategoryResponse.From(category);
    }
}
