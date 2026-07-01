using System.Text.Json.Serialization;

namespace LifeOS.Money.Api.Domain.Recurring;

/// Which day of a month a <see cref="MonthlyRule"/> fires on (ADR-0017). Either a
/// fixed day (clamped to the month's length) or the month's last day. Serialized as
/// a `kind`-discriminated union to mirror the Dart client.
[JsonPolymorphic(TypeDiscriminatorPropertyName = "kind")]
[JsonDerivedType(typeof(OnDayOfMonth), "dayOfMonth")]
[JsonDerivedType(typeof(LastDayOfMonth), "lastDay")]
public abstract record MonthDayAnchor;
