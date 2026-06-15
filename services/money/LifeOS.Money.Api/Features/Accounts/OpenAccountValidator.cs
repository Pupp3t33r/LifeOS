using System.Text.RegularExpressions;
using FluentValidation;

namespace LifeOS.Money.Api.Features.Accounts;

public sealed partial class OpenAccountValidator : AbstractValidator<OpenAccountRequest>
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

        RuleFor(x => x.Currency)
            .NotEmpty()
            .Must(currency => IsoCurrency().IsMatch(currency))
            .WithMessage("Currency must be a 3-letter ISO 4217 code (e.g. USD, EUR).");

        RuleFor(x => x.OpeningBalanceAmount)
            .GreaterThanOrEqualTo(0)
            .When(x => x.OpeningBalanceAmount.HasValue)
            .WithMessage("Opening balance must be zero or positive.");
    }

    [GeneratedRegex(@"^[A-Z]{3}$", RegexOptions.Compiled)]
    private static partial Regex IsoCurrency();
}
