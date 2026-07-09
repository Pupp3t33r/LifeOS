using FluentValidation;

namespace LifeOS.Money.Api.Features.Categories;

public sealed class CreateCategoryValidator : AbstractValidator<CreateCategoryRequest> {
    public CreateCategoryValidator() {
        RuleFor(x => x.Id)
            .NotEqual(Guid.Empty)
            .WithMessage("Id must be a non-empty UUID (client-assigned, ADR-0003).");

        RuleFor(x => x.Name)
            .Must(x => !string.IsNullOrWhiteSpace(x))
            .WithMessage("Name is required.")
            .MaximumLength(100)
            .WithMessage("Name must be 100 characters or fewer.");
    }
}
