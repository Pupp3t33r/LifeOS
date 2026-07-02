using LifeOS.Money.Api.Domain.Events;
using LifeOS.Money.Api.Domain.Recurring;

namespace LifeOS.Money.Api.Domain;

/// The RecurringPayment aggregate (ADR-0017), stream <c>recurring/{RecurringId}</c>,
/// owner-scoped. Holds <b>definition + lifecycle only — no per-occurrence state</b>:
/// occurrence status lives on the AccountingPeriod (confirm/skip back-refs), so an
/// unbounded Live series is a non-problem and this stream stays small.
///
/// Two schedule modes: <see cref="ScheduleMode.Live"/> (a <see cref="Recurring.RecurrenceRule"/>
/// whose occurrences are computed) and <see cref="ScheduleMode.Materialized"/> (a
/// finite payment plan — debt/installments/a pre-order). Both hold their line-item
/// *contents* once, at the root (ADR-0028): Live in <see cref="EstimateLines"/>,
/// Materialized in <see cref="Items"/>. A Materialized <see cref="ScheduleLines"/> entry
/// is then **bare money** (a when-and-how-much), and confirming one records a
/// proportional slice of the items (see <see cref="SliceForOccurrence"/>). Live edits
/// are in-place and forward-only (rule/header); a Materialized plan is authored once and
/// **immutable except cancellation** — there is no per-line add/edit/remove (ADR-0028).
/// "Completed" is a derived display state, not a status here.
///
/// HTTP-facing guards (ownership, not-active → 409, wrong-mode → 409, unknown
/// occurrence → 404) live in the endpoints; the aggregate methods throw plain
/// exceptions as backstops.
public sealed class RecurringPayment
{
    public Guid Id { get; set; }
    public string OwnerId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public FlowDirection Direction { get; set; }
    public string Currency { get; set; } = string.Empty;
    public Guid? CategoryId { get; set; }
    public Guid? AccountId { get; set; }
    public ScheduleMode Mode { get; set; }

    /// The recurrence rule — set for <see cref="ScheduleMode.Live"/>, null otherwise.
    public RecurrenceRule? Rule { get; set; }

    /// The per-occurrence line breakdown for a Live payment (ADR-0019). Empty for
    /// Materialized (which states its contents in <see cref="Items"/>).
    public IReadOnlyList<Line> EstimateLines { get; set; } = [];

    /// The line-item contents of a Materialized plan (ADR-0028) — *what* the plan is
    /// buying, each with its own category (and, later, wishlist link). Empty for Live.
    /// The plan's payments (<see cref="ScheduleLines"/>) must sum to these (§3).
    public IReadOnlyList<Line> Items { get; set; } = [];

    /// The Materialized schedule — bare money payments (ADR-0028). Empty for Live.
    public List<ScheduleLine> ScheduleLines { get; set; } = new();

    public RecurringStatus Status { get; set; } = RecurringStatus.Active;
    public DateTimeOffset CreatedAt { get; set; }

    public static RecurringPaymentCreated CreateLive(
        Guid id,
        string ownerId,
        string name,
        FlowDirection direction,
        string currency,
        Guid? categoryId,
        Guid? accountId,
        RecurrenceRule rule,
        IReadOnlyList<Line> estimateLines,
        DateTimeOffset createdAt)
    {
        ValidateHeader(name, currency);
        ArgumentNullException.ThrowIfNull(rule);
        ValidateLines(estimateLines, currency);
        EnsureRuleIsEnumerable(rule);
        return new RecurringPaymentCreated(
            id, ownerId, name, direction, currency, categoryId, accountId,
            ScheduleMode.Live, rule, estimateLines, [], [], createdAt);
    }

    public static RecurringPaymentCreated CreateMaterialized(
        Guid id,
        string ownerId,
        string name,
        FlowDirection direction,
        string currency,
        Guid? categoryId,
        Guid? accountId,
        IReadOnlyList<Line> items,
        IReadOnlyList<ScheduleLine> scheduleLines,
        DateTimeOffset createdAt)
    {
        ValidateHeader(name, currency);
        ValidateLines(items, currency);

        if (scheduleLines.Count == 0)
        {
            throw new ArgumentException(
                "A payment plan requires at least one scheduled payment.", nameof(scheduleLines));
        }

        if (scheduleLines.Any(x => x.Amount.Amount == 0))
        {
            throw new ArgumentException(
                "Schedule payment amounts must be non-zero.", nameof(scheduleLines));
        }

        if (scheduleLines.Any(x => x.Amount.Currency != currency))
        {
            throw new InvalidOperationException(
                "All scheduled payments must share the recurring payment's currency (ADR-0019).");
        }

        if (scheduleLines.Select(x => x.LineId).Distinct().Count() != scheduleLines.Count)
        {
            throw new ArgumentException("Schedule line ids must be unique.", nameof(scheduleLines));
        }

        // Balance invariant (ADR-0028 §3): the plan's payments must sum to its items.
        var itemsTotal = items.Sum(x => x.Amount.Amount);
        var scheduleTotal = scheduleLines.Sum(x => x.Amount.Amount);
        if (itemsTotal != scheduleTotal)
        {
            throw new InvalidOperationException(
                $"A payment plan must balance: scheduled payments total {scheduleTotal} " +
                $"but items total {itemsTotal} (ADR-0028).");
        }

        return new RecurringPaymentCreated(
            id, ownerId, name, direction, currency, categoryId, accountId,
            ScheduleMode.Materialized, null, [], items, scheduleLines, createdAt);
    }

    public RuleChanged ChangeRule(RecurrenceRule rule, DateTimeOffset changedAt)
    {
        RequireActive();
        RequireMode(ScheduleMode.Live);
        ArgumentNullException.ThrowIfNull(rule);
        EnsureRuleIsEnumerable(rule);
        return new RuleChanged(Id, rule, changedAt);
    }

    /// The proportional slice of the plan's <see cref="Items"/> financed by the payment
    /// <paramref name="lineId"/> (ADR-0028 §4) — the categorised lines a confirm records
    /// on the AccountingPeriod. Deterministic and cumulative-exact across the plan;
    /// payments are ordered chronologically for the cumulative split. Materialized only.
    public IReadOnlyList<Line> SliceForOccurrence(Guid lineId)
    {
        var ordered = ScheduleLines.OrderBy(x => x.DueDate).ThenBy(x => x.LineId).ToList();
        var index = ordered.FindIndex(x => x.LineId == lineId);
        if (index < 0)
        {
            throw new ArgumentException($"Schedule line '{lineId}' does not exist.", nameof(lineId));
        }

        var amounts = ordered.Select(x => x.Amount.Amount).ToList();
        return ProportionalAllocation.Slice(Items, amounts, index);
    }

    public RecurringPaymentEdited EditHeader(string name, Guid? categoryId, Guid? accountId)
    {
        RequireActive();
        ValidateHeader(name, Currency);
        return new RecurringPaymentEdited(Id, name, categoryId, accountId);
    }

    /// Cancel a recurring payment (terminal, ADR-0017). <paramref name="refunded"/>
    /// records whether the cancellation carries a refund (ADR-0028 §6) — for a payment
    /// plan the user chooses refund / no-refund; the refund flow itself is a separate,
    /// later concern. Live cancels pass <c>false</c>.
    public RecurringPaymentCancelled Cancel(bool refunded, DateTimeOffset cancelledAt)
    {
        RequireActive();
        return new RecurringPaymentCancelled(Id, refunded, cancelledAt);
    }

    /// A detached copy for building an endpoint response: a mutation handler applies
    /// the just-emitted event to this clone to render the post-state, without touching
    /// the instance Wolverine tracks and re-projects (applying to that instance too
    /// would double-apply the event). <see cref="ScheduleLines"/> gets a fresh list;
    /// the rest are immutable records/values, so a shallow copy is safe.
    public RecurringPayment Clone() => new()
    {
        Id = Id,
        OwnerId = OwnerId,
        Name = Name,
        Direction = Direction,
        Currency = Currency,
        CategoryId = CategoryId,
        AccountId = AccountId,
        Mode = Mode,
        Rule = Rule,
        EstimateLines = EstimateLines,
        Items = Items,
        ScheduleLines = ScheduleLines.ToList(),
        Status = Status,
        CreatedAt = CreatedAt,
    };

    public void Apply(RecurringPaymentCreated @event)
    {
        Id = @event.RecurringId;
        OwnerId = @event.OwnerId;
        Name = @event.Name;
        Direction = @event.Direction;
        Currency = @event.Currency;
        CategoryId = @event.CategoryId;
        AccountId = @event.AccountId;
        Mode = @event.Mode;
        Rule = @event.Rule;
        EstimateLines = @event.EstimateLines;
        Items = @event.Items;
        ScheduleLines = @event.ScheduleLines.ToList();
        Status = RecurringStatus.Active;
        CreatedAt = @event.CreatedAt;
    }

    public void Apply(RuleChanged @event) => Rule = @event.Rule;

    public void Apply(RecurringPaymentEdited @event)
    {
        Name = @event.Name;
        CategoryId = @event.CategoryId;
        AccountId = @event.AccountId;
    }

    public void Apply(RecurringPaymentCancelled @event) => Status = RecurringStatus.Cancelled;

    private void RequireActive()
    {
        if (Status != RecurringStatus.Active)
        {
            throw new InvalidOperationException($"Recurring payment '{Id}' is not active.");
        }
    }

    private void RequireMode(ScheduleMode mode)
    {
        if (Mode != mode)
        {
            throw new InvalidOperationException(
                $"Operation requires {mode} mode; this recurring payment is {Mode}.");
        }
    }

    private static void ValidateHeader(string name, string currency)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Name is required.", nameof(name));
        }

        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
        {
            throw new ArgumentException("Currency must be a 3-letter ISO code.", nameof(currency));
        }
    }

    private static void ValidateLines(IReadOnlyList<Line> lines, string currency)
    {
        if (lines.Count == 0)
        {
            throw new ArgumentException("At least one line is required.", nameof(lines));
        }

        if (lines.Any(x => x.Amount.Amount == 0))
        {
            throw new ArgumentException("Line amounts must be non-zero.", nameof(lines));
        }

        if (lines.Any(x => x.Amount.Currency != currency))
        {
            throw new InvalidOperationException(
                "All lines must share the recurring payment's currency (ADR-0019).");
        }
    }

    // Cheap eagerness check: pulling the first occurrence forces the generator's
    // interval/weekday/day-set validation to run at write time rather than at read.
    private static void EnsureRuleIsEnumerable(RecurrenceRule rule) =>
        RecurrenceGenerator.From(rule, rule.Start).Take(1).ToList();
}
