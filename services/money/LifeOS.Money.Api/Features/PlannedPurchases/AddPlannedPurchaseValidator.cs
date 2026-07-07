using System.Text.RegularExpressions;
using FluentValidation;

namespace LifeOS.Money.Api.Features.PlannedPurchases;

public sealed partial class AddPlannedPurchaseValidator : AbstractValidator<AddPlannedPurchaseRequest>
{
    public AddPlannedPurchaseValidator()
    {
        RuleFor(x => x.EntryId)
            .NotEqual(Guid.Empty)
            .WithMessage("EntryId must be a non-empty UUID (client-assigned, ADR-0003).");

        RuleFor(x => x.Currency)
            .NotEmpty()
            .Must(currency => IsoCurrency().IsMatch(currency))
            .WithMessage("Currency must be a 3-letter ISO 4217 code (e.g. USD, EUR).");

        RuleFor(x => x.Lines)
            .NotEmpty()
            .WithMessage("A planned purchase needs at least one line.");

        RuleForEach(x => x.Lines).ChildRules(line =>
        {
            line.RuleFor(x => x.Amount)
                .GreaterThan(0)
                .WithMessage("Each line amount must be a positive magnitude; spending sets the sign.");
            line.RuleFor(x => x.Description).MaximumLength(500);
        });

        RuleFor(x => x.Description).MaximumLength(500);
    }

    [GeneratedRegex(@"^[A-Z]{3}$", RegexOptions.Compiled)]
    private static partial Regex IsoCurrency();
}
