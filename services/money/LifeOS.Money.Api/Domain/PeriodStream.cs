namespace LifeOS.Money.Api.Domain;

/// Maps a logical accounting-period key (owner + year + month — ADR-0016's
/// <c>period/{owner}/{year}/{month}</c>) to a stable Marten stream id.
///
/// The event store is Guid-identified (Account streams use Guids), so rather than
/// switch the whole store to string streams, the period stream uses a deterministic
/// RFC-4122 v5 UUID derived from the logical key: one stream per owner per period,
/// reproducible without a lookup.
public static class PeriodStream {
    private static readonly Guid NamespaceId = Guid.Parse("7f3a1e90-9c2b-4e7d-8a16-0b9d5c4e21aa");

    public static Guid IdFor(string ownerId, int year, int month) =>
        DeterministicGuid.Create(NamespaceId, $"{ownerId}/{year}/{month}");
}
