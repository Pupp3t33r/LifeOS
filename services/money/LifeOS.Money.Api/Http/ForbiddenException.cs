using Microsoft.AspNetCore.Http;

namespace LifeOS.Money.Api.Http;

/// The caller is authenticated but the action is not allowed — e.g. writing to an
/// immutable system category (ADR-0024/0033).
public sealed class ForbiddenException : AppException {
    public ForbiddenException(string message)
        : base(StatusCodes.Status403Forbidden, "Forbidden", message) {
    }
}
