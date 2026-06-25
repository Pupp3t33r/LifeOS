using FluentValidation;

namespace LifeOS.Money.Api.Features.UserPreferences;

public sealed class SetMonthStartDayValidator : AbstractValidator<SetMonthStartDayRequest>
{
    public SetMonthStartDayValidator()
    {
        RuleFor(x => x.MonthStartDay)
            .InclusiveBetween(1, 31)
            .WithMessage("Month start day must be between 1 and 31 (clamped to the month's last day where shorter, ADR-0013).");
    }
}
