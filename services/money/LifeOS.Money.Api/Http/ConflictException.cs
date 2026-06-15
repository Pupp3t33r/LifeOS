using Microsoft.AspNetCore.Http;

namespace LifeOS.Money.Api.Http;

public sealed class ConflictException : AppException
{
    public ConflictException(string message)
        : base(StatusCodes.Status409Conflict, "Conflict", message)
    {
    }
}
