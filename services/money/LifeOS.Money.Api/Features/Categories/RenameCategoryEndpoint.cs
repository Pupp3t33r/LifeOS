using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Categories;

public static class RenameCategoryEndpoint {
    [WolverinePatch("/categories/{id}")]
    public static async Task<CategoryResponse> Handle(
        Guid id,
        RenameCategoryRequest request,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();

        if (SystemCategories.All.Any(x => x.Id == id)) {
            throw new ForbiddenException("System categories cannot be renamed (ADR-0024).");
        }

        var category = await session.LoadAsync<Category>(id);
        if (category is null || category.OwnerId != userId) {
            throw new NotFoundException($"Category '{id}' was not found.");
        }

        var name = CategoryNaming.Normalize(request.Name);
        if (!CategoryNaming.SameName(category.Name, name)
            && await CategoryNaming.IsTakenAsync(session, userId, name, excludeId: id)) {
            throw new UnprocessableEntityException($"A category named '{name}' already exists.");
        }

        category.Name = name;
        session.Store(category);
        await session.SaveChangesAsync();

        return CategoryResponse.From(category);
    }
}
