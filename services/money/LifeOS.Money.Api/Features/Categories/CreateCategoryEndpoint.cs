using LifeOS.Money.Api.Auth;
using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Marten;
using Wolverine.Http;

namespace LifeOS.Money.Api.Features.Categories;

public static class CreateCategoryEndpoint {
    [WolverinePost("/categories")]
    public static async Task<IResult> Handle(
        CreateCategoryRequest request,
        HttpContext context,
        IDocumentSession session) {
        var userId = context.GetUserId();
        var name = CategoryNaming.Normalize(request.Name);

        // Idempotent on the client-assigned id (ADR-0003): a re-send of the same
        // create returns the existing row; a same-id/different-name send is the
        // idempotency-edge 409 (the drainer treats it as already applied).
        var existing = await session.LoadAsync<Category>(request.Id);
        if (existing is not null) {
            if (existing.OwnerId != userId) {
                throw new NotFoundException($"Category '{request.Id}' was not found.");
            }
            if (CategoryNaming.SameName(existing.Name, name)) {
                return Results.Ok(CategoryResponse.From(existing));
            }
            throw new ConflictException(
                $"Category '{request.Id}' already exists with a different name.");
        }

        if (await CategoryNaming.IsTakenAsync(session, userId, name, excludeId: null)) {
            throw new UnprocessableEntityException($"A category named '{name}' already exists.");
        }

        var category = new Category {
            Id = request.Id,
            OwnerId = userId,
            Name = name,
            System = false,
            Archived = false,
            CreatedAt = DateTimeOffset.UtcNow,
        };
        session.Store(category);
        await session.SaveChangesAsync();

        return Results.Created($"/api/categories/{category.Id}", CategoryResponse.From(category));
    }
}
