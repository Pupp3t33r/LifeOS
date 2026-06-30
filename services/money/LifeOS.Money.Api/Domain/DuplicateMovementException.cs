namespace LifeOS.Money.Api.Domain;

public sealed class DuplicateMovementException(Guid movementId)
    : Exception($"A savings movement with id '{movementId}' has already been recorded.")
{
    public Guid MovementId { get; } = movementId;
}
