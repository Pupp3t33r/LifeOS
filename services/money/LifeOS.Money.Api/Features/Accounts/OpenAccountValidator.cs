using FluentValidation;

namespace LifeOS.Money.Api.Features.Accounts;

public sealed class OpenAccountValidator : AbstractValidator<OpenAccountRequest>
{
    public OpenAccountValidator()
    {
        RuleFor(x => x.AccountId)
            .NotEqual(Guid.Empty)
            .WithMessage("AccountId must be a non-empty UUID (client-assigned, ADR-0003).");

        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100)
            .WithMessage("Name is required and must be 100 characters or fewer.");
    }
}
