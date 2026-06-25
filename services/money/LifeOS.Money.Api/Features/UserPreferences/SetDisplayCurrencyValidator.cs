using System.Text.RegularExpressions;
using FluentValidation;

namespace LifeOS.Money.Api.Features.UserPreferences;

public sealed partial class SetDisplayCurrencyValidator : AbstractValidator<SetDisplayCurrencyRequest>
{
    public SetDisplayCurrencyValidator()
    {
        RuleFor(x => x.Currency)
            .NotEmpty()
            .Must(currency => IsoCurrency().IsMatch(currency))
            .WithMessage("Currency must be a 3-letter ISO 4217 code (e.g. USD, EUR).");
    }

    [GeneratedRegex(@"^[A-Z]{3}$", RegexOptions.Compiled)]
    private static partial Regex IsoCurrency();
}
