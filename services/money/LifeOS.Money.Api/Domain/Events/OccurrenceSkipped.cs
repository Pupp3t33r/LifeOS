using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Domain.Events;

/// A recurring occurrence was skipped in its period (ADR-0017): unpaid, no arrears —
/// the ~90% case where missing a month simply leaves the occurrence not-paid. Carries
/// the back-reference so the projection can mark that occurrence skipped. A pure skip
/// (this event with no corresponding carry-forward) is the abandon-it path; the
/// arrears carry-make-up variant (ADR-0020) is deferred.
public sealed record OccurrenceSkipped(
    Guid PeriodId,
    string OwnerId,
    int Year,
    int Month,
    RecurringReference Occurrence,
    DateTimeOffset RecordedAt);
