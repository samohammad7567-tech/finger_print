using System.Security.Claims;
using GuardSync.Api.Data;
using GuardSync.Api.Dtos;
using GuardSync.Api.Entities;
using GuardSync.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GuardSync.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController(
    AppDbContext db,
    IPasswordHasher<AppUser> hasher,
    TokenService tokens,
    ILogger<AuthController> logger) : ControllerBase
{
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email);

        // Same key for "no such user" and "bad password" so the endpoint does not
        // confirm which emails are registered.
        if (user is null)
        {
            return Unauthorized(ApiError.Of("error_invalid_credentials"));
        }

        var result = hasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);
        if (result == PasswordVerificationResult.Failed)
        {
            return Unauthorized(ApiError.Of("error_invalid_credentials"));
        }

        if (!user.IsActive)
        {
            return StatusCode(StatusCodes.Status403Forbidden, ApiError.Of("error_account_disabled"));
        }

        if (result == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = hasher.HashPassword(user, request.Password);
            await db.SaveChangesAsync();
        }

        return Ok(BuildAuthResponse(user));
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<IActionResult> Register(RegisterRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        if (await db.Users.AnyAsync(u => u.Email == email))
        {
            return Conflict(ApiError.Of("error_email_in_use"));
        }

        // Role is only honoured for an authenticated admin; self-registration is
        // always a guard.
        var isAdminCaller = User.IsInRole("admin");
        var role = isAdminCaller && request.Role == "admin" ? "admin" : "guard";

        var user = new AppUser
        {
            Email = email,
            DisplayName = string.IsNullOrWhiteSpace(request.DisplayName)
                ? email.Split('@')[0]
                : request.DisplayName.Trim(),
            Role = role,
        };
        user.PasswordHash = hasher.HashPassword(user, request.Password);

        db.Users.Add(user);
        await db.SaveChangesAsync();

        return Ok(BuildAuthResponse(user));
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me()
    {
        var id = CurrentUserId();
        if (id is null) return Unauthorized(ApiError.Of("error_unauthorized"));

        var user = await db.Users.FindAsync(id.Value);
        if (user is null || !user.IsActive)
        {
            return Unauthorized(ApiError.Of("error_unauthorized"));
        }

        return Ok(ToDto(user));
    }

    [HttpPost("forgot-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email);

        if (user is not null)
        {
            user.ResetToken = Convert.ToHexString(Guid.NewGuid().ToByteArray());
            user.ResetTokenExpiresAt = DateTimeOffset.UtcNow.AddHours(2);
            await db.SaveChangesAsync();

            // No mail transport is wired up. The token is logged so an operator can
            // deliver it; swap this for an email service before going live.
            logger.LogWarning("Password reset token for {Email}: {Token}", email, user.ResetToken);
        }

        // Always 200 — the response must not reveal whether the email exists.
        return Ok(new { sent = true });
    }

    [HttpPost("reset-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.ResetToken == request.Token);
        if (user is null || user.ResetTokenExpiresAt is null ||
            user.ResetTokenExpiresAt < DateTimeOffset.UtcNow)
        {
            return BadRequest(ApiError.Of("error_invalid_reset_token"));
        }

        user.PasswordHash = hasher.HashPassword(user, request.NewPassword);
        user.ResetToken = null;
        user.ResetTokenExpiresAt = null;
        await db.SaveChangesAsync();

        return Ok(new { reset = true });
    }

    private AuthResponse BuildAuthResponse(AppUser user)
    {
        var (token, expiresAt) = tokens.Create(user);
        return new AuthResponse { Token = token, ExpiresAt = expiresAt, User = ToDto(user) };
    }

    private static AuthUserDto ToDto(AppUser user) => new()
    {
        Uid = user.Id.ToString(),
        Email = user.Email,
        Name = user.DisplayName,
        Role = user.Role,
    };

    private Guid? CurrentUserId() =>
        Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
}
