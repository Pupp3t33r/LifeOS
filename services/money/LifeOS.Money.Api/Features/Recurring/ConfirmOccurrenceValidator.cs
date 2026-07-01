using FluentValidation;

namespace LifeOS.Money.Api.Features.Recurring;

public sealed class ConfirmOccurrenceValidator : AbstractValidator<ConfirmOccurrenceRequest>
{
    public ConfirmOccurrenceValidator()
    {
        RuleFor(x => x.EntryId)
            .NotEqual(Guid.Empty)
            .WithMessage("EntryId must be a non-empty UUID (client-assigned, ADR-0003).");

        RuleFor(x => x.OccurrenceRef).NotEmpty();

        RuleFor(x => x.OccurredAt)
            .NotEqual(DateTimeOffset.MinValue)
            .WithMessage("OccurredAt must be a valid timestamp.");

        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(x => x.Amount).GreaterThan(0);
            line.RuleFor(x => x.Description).MaximumLength(500);
        });

        RuleFor(x => x.Description).MaximumLength(500);
    }
}
