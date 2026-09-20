using System.ComponentModel.DataAnnotations;

namespace GuardSync.Api.Dtos;

public record LoginRequest
{
    [Required, EmailAddress]
    public string Email { get; init; } = string.Empty;

    [Required, MinLength(6)]
    public string Password { get; init; } = string.Empty;
}

public record RegisterRequest
{
    [Required, EmailAddress]
    public string Email { get; init; } = string.Empty;

    [Required, MinLength(6)]
    public string Password { get; init; } = string.Empty;

    public string? DisplayName { get; init; }

    /// <summary>Ignored unless the caller is an authenticated admin.</summary>
    public string? Role { get; init; }
}

public record ForgotPasswordRequest
{
    [Required, EmailAddress]
    public string Email { get; init; } = string.Empty;
}

public record ResetPasswordRequest
{
    [Required]
    public string Token { get; init; } = string.Empty;

    [Required, MinLength(6)]
    public string NewPassword { get; init; } = string.Empty;
}

public record AuthUserDto
{
    public string Uid { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Role { get; init; } = "guard";
}

public record AuthResponse
{
    public string Token { get; init; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; init; }
    public AuthUserDto User { get; init; } = new();
}
