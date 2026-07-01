using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Domain.Recurring;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class ChangeRuleEndpoint
{
    // Replace a Live rule in place (ADR-0017, forward-only). Confirmed actuals on the
    // ledger are immutable and unaffected; only future occurrences use the new rule.
    [WolverinePut("/recurring/{id}/rule")]
    public static (RecurringResponse, Events) Handle(
        Guid id,
        ChangeRuleRequest request,
        HttpContext context,
        [WriteAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        RecurringGuards.RequireActive(recurring);
        RecurringGuards.RequireMode(recurring, ScheduleMode.Live);
        RecurringRuleValidation.Validate(request.Rule);

        var changed = recurring.ChangeRule(request.Rule, DateTimeOffset.UtcNow);
        var view = recurring.Clone();
        view.Apply(changed);
        return (RecurringMapping.ToResponse(view), [changed]);
    }
}
