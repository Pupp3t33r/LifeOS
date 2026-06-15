namespace LifeOS.Money.Api.Http;

public abstract class AppException : Exception
{
    protected AppException(int statusCode, string title, string message) : base(message)
    {
        StatusCode = statusCode;
        Title = title;
    }

    public int StatusCode { get; }
    public string Title { get; }
}
