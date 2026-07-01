using Microsoft.AspNetCore.Http;

namespace LifeOS.Money.Api.Http;

public sealed class BadRequestException : AppException
{
    public BadRequestException(string message)
        : base(StatusCodes.Status400BadRequest, "Bad Request", message)
    {
    }
}
