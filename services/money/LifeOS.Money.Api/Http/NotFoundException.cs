using Microsoft.AspNetCore.Http;

namespace LifeOS.Money.Api.Http;

public sealed class NotFoundException : AppException
{
    public NotFoundException(string message)
        : base(StatusCodes.Status404NotFound, "Not Found", message)
    {
    }
}
