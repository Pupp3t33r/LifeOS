using FluentValidation;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public sealed class PayPlannedPurchaseValidator : AbstractValidator<PayPlannedPurchaseRequest>
{
    public PayPlannedPurchaseValidator()
    {
        RuleFor(x => x.EntryId)
            .NotEqual(Guid.Empty)
            .WithMessage("EntryId must be a non-empty UUID (client-assigned, ADR-0003).");

        RuleFor(x => x.OccurredAt)
            .NotEqual(DateTimeOffset.MinValue)
            .LessThan(DateTimeOffset.UtcNow.AddMinutes(5))
            .WithMessage("OccurredAt must be a valid past or near-current timestamp.");

        RuleFor(x => x.Amount)
            .GreaterThan(0)
            .When(x => x.Amount.HasValue)
            .WithMessage("The adjusted amount must be a positive magnitude.");

        RuleFor(x => x.Description).MaximumLength(500);
    }
}
