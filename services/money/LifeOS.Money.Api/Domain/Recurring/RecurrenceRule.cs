using System.Text.Json.Serialization;

namespace LifeOS.Money.Api.Domain.Recurring;

/// A recurrence rule for a <b>Live</b> schedule (ADR-0017): occurrences are computed
/// from the rule, never stored. A small structured type we own on both sides — not
/// cron/RRULE — chosen so the .NET server and the Dart client generate identical
/// occurrences. Serialized as a `kind`-discriminated union (System.Text.Json),
/// mirrored by Dart sealed classes.
///
/// <see cref="Start"/> fixes the phase of the cadence (all intervals count from it)
/// and <see cref="End"/> bounds the series. Dates are <see cref="DateOnly"/> — no
/// time, no DST. Generation is an exhaustive switch over the subtypes
/// (<see cref="RecurrenceGenerator"/>); "nth weekday of month" is a deliberate future
/// subtype, deferred from v1.
[JsonPolymorphic(TypeDiscriminatorPropertyName = "kind")]
[JsonDerivedType(typeof(DailyRule), "daily")]
[JsonDerivedType(typeof(WeeklyRule), "weekly")]
[JsonDerivedType(typeof(MonthlyRule), "monthly")]
[JsonDerivedType(typeof(YearlyRule), "yearly")]
public abstract record RecurrenceRule(DateOnly Start, RecurrenceEnd End);
