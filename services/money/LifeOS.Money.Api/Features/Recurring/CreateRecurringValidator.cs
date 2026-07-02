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
            RuleFor(x => x.Items)
                .NotEmpty()
                .WithMessage("A payment plan requires at least one item.");
            RuleForEach(x => x.Items).ChildRules(item =>
            {
                item.RuleFor(x => x.Amount).GreaterThan(0);
                item.RuleFor(x => x.Description).MaximumLength(500);
            });

            RuleFor(x => x.ScheduleLines)
                .NotEmpty()
                .WithMessage("A payment plan requires at least one scheduled payment.");
            RuleForEach(x => x.ScheduleLines).ChildRules(scheduleLine =>
            {
                scheduleLine.RuleFor(x => x.LineId).NotEqual(Guid.Empty);
                scheduleLine.RuleFor(x => x.Amount).GreaterThan(0);
            });

            RuleFor(x => x)
                .Must(BalancedPlan)
                .WithMessage("A payment plan must balance: the scheduled payments must sum to the items total (ADR-0028).");
        });
    }

    // Σ payments == Σ items (magnitudes; direction sets the sign). Emptiness is reported
    // by the other rules, so a missing side passes here to avoid a duplicate message.
    private static bool BalancedPlan(CreateRecurringRequest request)
    {
        var items = request.Items ?? [];
        var schedule = request.ScheduleLines ?? [];
        if (items.Count == 0 || schedule.Count == 0)
        {
            return true;
        }

        return items.Sum(x => x.Amount) == schedule.Sum(x => x.Amount);
    }

    [GeneratedRegex(@"^[A-Z]{3}$", RegexOptions.Compiled)]
    private static partial Regex IsoCurrency();
}
