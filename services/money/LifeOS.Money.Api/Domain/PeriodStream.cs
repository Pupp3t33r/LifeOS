using System.Security.Cryptography;
using System.Text;

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

    public static Guid IdFor(string ownerId, int year, int month) {
        return DeterministicGuid(NamespaceId, $"{ownerId}/{year}/{month}");
    }

    private static Guid DeterministicGuid(Guid namespaceId, string name) {
        var namespaceBytes = namespaceId.ToByteArray();
        SwapByteOrder(namespaceBytes);

        var nameBytes = Encoding.UTF8.GetBytes(name);
        var payload = new byte[namespaceBytes.Length + nameBytes.Length];
        Buffer.BlockCopy(namespaceBytes, 0, payload, 0, namespaceBytes.Length);
        Buffer.BlockCopy(nameBytes, 0, payload, namespaceBytes.Length, nameBytes.Length);

#pragma warning disable CA5350 // SHA-1 derives a deterministic UUIDv5 here — not a security hash.
        var hash = SHA1.HashData(payload);
#pragma warning restore CA5350

        var guidBytes = new byte[16];
        Array.Copy(hash, guidBytes, 16);
        guidBytes[6] = (byte)((guidBytes[6] & 0x0F) | 0x50); // version 5
        guidBytes[8] = (byte)((guidBytes[8] & 0x3F) | 0x80); // RFC-4122 variant
        SwapByteOrder(guidBytes);
        return new Guid(guidBytes);
    }

    private static void SwapByteOrder(byte[] guid) {
        (guid[0], guid[3]) = (guid[3], guid[0]);
        (guid[1], guid[2]) = (guid[2], guid[1]);
        (guid[4], guid[5]) = (guid[5], guid[4]);
        (guid[6], guid[7]) = (guid[7], guid[6]);
    }
}
