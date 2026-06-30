using System.Text.RegularExpressions;
using FluentValidation;

namespace LifeOS.Money.Api.Features.SavingsMovements;

public sealed partial class RecordSavingsMovementValidator : AbstractValidator<RecordSavingsMovementRequest>
{
    public RecordSavingsMovementValidator()
    {
        RuleFor(x => x.MovementId)
            .NotEqual(Guid.Empty)
            .WithMessage("MovementId must be a non-empty UUID (client-assigned, ADR-0003).");

        RuleFor(x => x.Amount)
            .Must(amount => amount != 0)
            .WithMessage("Amount must be non-zero. Use positive to deposit, negative to withdraw.");

        RuleFor(x => x.Currency)
            .NotEmpty()
            .Must(currency => IsoCurrency().IsMatch(currency))
            .WithMessage("Currency must be a 3-letter ISO 4217 code (e.g. USD, EUR).");

        RuleFor(x => x.Description)
            .MaximumLength(500);

        RuleFor(x => x.OccurredAt)
            .NotEqual(DateTimeOffset.MinValue)
            .LessThan(DateTimeOffset.UtcNow.AddMinutes(5))
            .WithMessage("OccurredAt must be a valid past or near-current timestamp.");
    }

    [GeneratedRegex(@"^[A-Z]{3}$", RegexOptions.Compiled)]
    private static partial Regex IsoCurrency();
}
