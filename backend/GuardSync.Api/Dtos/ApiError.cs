namespace GuardSync.Api.Dtos;

/// <summary>
/// Every non-2xx body uses this shape. <see cref="Error"/> is a stable key the
/// Flutter client maps straight to a localization key — never a translated string.
/// </summary>
public record ApiError
{
    public string Error { get; init; } = "error_unknown";
    public string? Message { get; init; }

    public static ApiError Of(string key, string? message = null) =>
        new() { Error = key, Message = message };
}
