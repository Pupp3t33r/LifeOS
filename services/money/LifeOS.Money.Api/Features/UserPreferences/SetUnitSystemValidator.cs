using FluentValidation;
using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Features.UserPreferences;

public sealed class SetUnitSystemValidator : AbstractValidator<SetUnitSystemRequest>
{
    public SetUnitSystemValidator()
    {
        RuleFor(x => x.UnitSystem)
            .Must(Enum.IsDefined)
            .WithMessage("Unit system must be a defined value (ADR-0036).");
    }
}
