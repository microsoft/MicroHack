namespace OctoSupply.Api.Utils;

public class ApiException : Exception
{
    public int StatusCode { get; }
    public string Code { get; }

    public ApiException(string message, string code, int statusCode)
        : base(message)
    {
        Code = code;
        StatusCode = statusCode;
    }
}

public sealed class NotFoundException : ApiException
{
    public NotFoundException(string entity, int id)
        : base($"{entity} with ID {id} not found", "NOT_FOUND", StatusCodes.Status404NotFound)
    {
    }
}

public sealed class ValidationException : ApiException
{
    public ValidationException(string message)
        : base($"Validation error: {message}", "VALIDATION_ERROR", StatusCodes.Status400BadRequest)
    {
    }
}

public sealed class ConflictException : ApiException
{
    public ConflictException(string message)
        : base($"Conflict: {message}", "CONFLICT", StatusCodes.Status409Conflict)
    {
    }
}

public sealed class DatabaseException : ApiException
{
    public DatabaseException(string message)
        : base(message, "DATABASE_ERROR", StatusCodes.Status500InternalServerError)
    {
    }
}
