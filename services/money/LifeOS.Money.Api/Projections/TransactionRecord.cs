using LifeOS.Money.Api.Domain;

namespace LifeOS.Money.Api.Projections;

public sealed class TransactionRecord
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public Guid TransactionId { get; set; }
    public CurrencyAmount Amount { get; set; } = new(0, string.Empty);
    public string Description { get; set; } = string.Empty;
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset RecordedAt { get; set; }
}
