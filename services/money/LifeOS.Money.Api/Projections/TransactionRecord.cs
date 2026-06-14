namespace LifeOS.Money.Api.Projections;

public sealed class TransactionRecord
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public Guid TransactionId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset RecordedAt { get; set; }
}
