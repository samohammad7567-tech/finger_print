namespace GuardSync.Api.Entities;

/// <summary>
/// A person who signs into the app. Role is either "guard" or "admin".
/// </summary>
public class AppUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Role { get; set; } = "guard";
    public bool IsActive { get; set; } = true;

    public string? ResetToken { get; set; }
    public DateTimeOffset? ResetTokenExpiresAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
