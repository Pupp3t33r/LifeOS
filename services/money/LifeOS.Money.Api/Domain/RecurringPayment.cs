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
/// finite, editable <see cref="ScheduleLines"/> list — debt/installments). Edits are
/// in-place and forward-only for Live; per-line for Materialized. "Completed" is a
/// derived display state, not a status here.
///
/// HTTP-facing guards (ownership, not-active → 409, wrong-mode, missing line → 404)
/// live in the endpoints; the aggregate methods throw plain exceptions as backstops.
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
    /// Materialized (each <see cref="ScheduleLine"/> carries its own lines).
    public IReadOnlyList<Line> EstimateLines { get; set; } = [];

    /// The Materialized schedule. Empty for Live.
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
            ScheduleMode.Live, rule, estimateLines, [], createdAt);
    }

    public static RecurringPaymentCreated CreateMaterialized(
        Guid id,
        string ownerId,
        string name,
        FlowDirection direction,
        string currency,
        Guid? categoryId,
        Guid? accountId,
        IReadOnlyList<ScheduleLine> lines,
        DateTimeOffset createdAt)
    {
        ValidateHeader(name, currency);
        foreach (var line in lines)
        {
            ValidateLines(line.Lines, currency);
        }

        if (lines.Select(x => x.LineId).Distinct().Count() != lines.Count)
        {
            throw new ArgumentException("Schedule line ids must be unique.", nameof(lines));
        }

        return new RecurringPaymentCreated(
            id, ownerId, name, direction, currency, categoryId, accountId,
            ScheduleMode.Materialized, null, [], lines, createdAt);
    }

    public RuleChanged ChangeRule(RecurrenceRule rule, DateTimeOffset changedAt)
    {
        RequireActive();
        RequireMode(ScheduleMode.Live);
        ArgumentNullException.ThrowIfNull(rule);
        EnsureRuleIsEnumerable(rule);
        return new RuleChanged(Id, rule, changedAt);
    }

    public ScheduleLineAdded AddScheduleLine(ScheduleLine line)
    {
        RequireActive();
        RequireMode(ScheduleMode.Materialized);
        ValidateLines(line.Lines, Currency);
        if (ScheduleLines.Any(x => x.LineId == line.LineId))
        {
            throw new ArgumentException($"Schedule line '{line.LineId}' already exists.", nameof(line));
        }

        return new ScheduleLineAdded(Id, line);
    }

    public ScheduleLineEdited EditScheduleLine(ScheduleLine line)
    {
        RequireActive();
        RequireMode(ScheduleMode.Materialized);
        ValidateLines(line.Lines, Currency);
        RequireLineExists(line.LineId);
        return new ScheduleLineEdited(Id, line);
    }

    public ScheduleLineRemoved RemoveScheduleLine(Guid lineId)
    {
        RequireActive();
        RequireMode(ScheduleMode.Materialized);
        RequireLineExists(lineId);
        return new ScheduleLineRemoved(Id, lineId);
    }

    public RecurringPaymentEdited EditHeader(string name, Guid? categoryId, Guid? accountId)
    {
        RequireActive();
        ValidateHeader(name, Currency);
        return new RecurringPaymentEdited(Id, name, categoryId, accountId);
    }

    public RecurringPaymentCancelled Cancel(DateTimeOffset cancelledAt)
    {
        RequireActive();
        return new RecurringPaymentCancelled(Id, cancelledAt);
    }

    public bool HasScheduleLine(Guid lineId) => ScheduleLines.Any(x => x.LineId == lineId);

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
        ScheduleLines = @event.ScheduleLines.ToList();
        Status = RecurringStatus.Active;
        CreatedAt = @event.CreatedAt;
    }

    public void Apply(RuleChanged @event) => Rule = @event.Rule;

    public void Apply(ScheduleLineAdded @event) => ScheduleLines.Add(@event.Line);

    public void Apply(ScheduleLineEdited @event)
    {
        var index = ScheduleLines.FindIndex(x => x.LineId == @event.Line.LineId);
        if (index >= 0)
        {
            ScheduleLines[index] = @event.Line;
        }
    }

    public void Apply(ScheduleLineRemoved @event) =>
        ScheduleLines.RemoveAll(x => x.LineId == @event.LineId);

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

    private void RequireLineExists(Guid lineId)
    {
        if (!HasScheduleLine(lineId))
        {
            throw new ArgumentException($"Schedule line '{lineId}' does not exist.", nameof(lineId));
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
