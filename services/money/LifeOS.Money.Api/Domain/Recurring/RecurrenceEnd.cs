using System.Text.Json.Serialization;

namespace LifeOS.Money.Api.Domain.Recurring;

/// When a recurrence stops (ADR-0017). A discriminated union serialized with a
/// `kind` discriminator (System.Text.Json), mirrored 1:1 by Dart sealed classes on
/// the client so the estimate side and the authoritative side are structurally
/// identical.
[JsonPolymorphic(TypeDiscriminatorPropertyName = "kind")]
[JsonDerivedType(typeof(NeverEnds), "never")]
[JsonDerivedType(typeof(EndsOnDate), "onDate")]
[JsonDerivedType(typeof(EndsAfter), "afterCount")]
public abstract record RecurrenceEnd;
