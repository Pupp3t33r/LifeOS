using LifeOS.Money.Api.Domain;
using LifeOS.Money.Api.Http;
using Wolverine.Http;
using Wolverine.Marten;

namespace LifeOS.Money.Api.Features.Recurring;

public static class EditRecurringEndpoint
{
    // Edit header fields only (name, category, account context). Schedule (rule or
    // lines) is changed via its own endpoints.
    [WolverinePut("/recurring/{id}")]
    public static (RecurringResponse, Events) Handle(
        Guid id,
        EditRecurringRequest request,
        HttpContext context,
        [WriteAggregate] RecurringPayment recurring)
    {
        RecurringGuards.RequireOwner(recurring, context);
        RecurringGuards.RequireActive(recurring);
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            throw new BadRequestException("Name is required.");
        }

        var edited = recurring.EditHeader(request.Name, request.CategoryId, request.AccountId);
        var view = recurring.Clone();
        view.Apply(edited);
        return (RecurringMapping.ToResponse(view), [edited]);
    }
}
