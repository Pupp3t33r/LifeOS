using Microsoft.AspNetCore.Http;

namespace LifeOS.Money.Api.Http;

/// A semantically-invalid request the caller must change to succeed — e.g. a
/// category name that collides with an existing one (ADR-0033). Distinct from
/// `409` on purpose: the Wallet offline outbox treats `409` as "already applied"
/// (ADR-0003 idempotency), so a genuine conflict must be `422` to surface as a
/// failed operation the user resolves.
public sealed class UnprocessableEntityException : AppException {
    public UnprocessableEntityException(string message)
        : base(StatusCodes.Status422UnprocessableEntity, "Unprocessable Entity", message) {
    }
}
