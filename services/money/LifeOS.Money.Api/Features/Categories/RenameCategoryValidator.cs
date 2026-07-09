using FluentValidation;

namespace LifeOS.Money.Api.Features.Categories;

public sealed class RenameCategoryValidator : AbstractValidator<RenameCategoryRequest> {
    public RenameCategoryValidator() {
        RuleFor(x => x.Name)
            .Must(x => !string.IsNullOrWhiteSpace(x))
            .WithMessage("Name is required.")
            .MaximumLength(100)
            .WithMessage("Name must be 100 characters or fewer.");
    }
}
