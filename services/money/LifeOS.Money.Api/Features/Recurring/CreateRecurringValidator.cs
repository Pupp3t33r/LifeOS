using System.Text.RegularExpressions;
using FluentValidation;

namespace LifeOS.Money.Api.Features.Recurring;

public sealed partial class CreateRecurringValidator : AbstractValidator<CreateRecurringRequest>
{
    public CreateRecurringValidator()
    {
        RuleFor(x => x.RecurringId)
            .NotEqual(Guid.Empty)
            .WithMessage("RecurringId must be a non-empty UUID (client-assigned, ADR-0003).");

        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);

        RuleFor(x => x.Direction)
            .Must(x => x is "in" or "out")
            .WithMessage("Direction must be 'in' or 'out'.");

        RuleFor(x => x.Currency)
            .NotEmpty()
            .Must(x => IsoCurrency().IsMatch(x))
            .WithMessage("Currency must be a 3-letter ISO 4217 code.");

        RuleFor(x => x.Mode)
            .Must(x => x is "live" or "materialized")
            .WithMessage("Mode must be 'live' or 'materialized'.");

        When(x => x.Mode == "live", () =>
        {
            RuleFor(x => x.Rule).NotNull().WithMessage("A live recurring payment requires a rule.");
            RuleFor(x => x.EstimateLines)
                .NotEmpty()
                .WithMessage("A live recurring payment requires at least one estimate line.");
            RuleForEach(x => x.EstimateLines).ChildRules(line =>
            {
                line.RuleFor(x => x.Amount).GreaterThan(0);
                line.RuleFor(x => x.Description).MaximumLength(500);
            });
        });

        When(x => x.Mode == "materialized", () =>
        {
            RuleForEach(x => x.ScheduleLines).ChildRules(scheduleLine =>
            {
                scheduleLine.RuleFor(x => x.LineId).NotEqual(Guid.Empty);
                scheduleLine.RuleFor(x => x.Lines).NotEmpty();
                scheduleLine.RuleForEach(x => x.Lines).ChildRules(line =>
                {
                    line.RuleFor(x => x.Amount).GreaterThan(0);
                    line.RuleFor(x => x.Description).MaximumLength(500);
                });
            });
        });
    }

    [GeneratedRegex(@"^[A-Z]{3}$", RegexOptions.Compiled)]
    private static partial Regex IsoCurrency();
}
