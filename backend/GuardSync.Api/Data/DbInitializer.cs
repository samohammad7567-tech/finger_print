using GuardSync.Api.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace GuardSync.Api.Data;

public static class DbInitializer
{
    /// <summary>
    /// Applies migrations (or creates the schema when no migration has been
    /// generated yet) and guarantees one admin account exists so the app is
    /// usable on a fresh database.
    /// </summary>
    public static async Task InitializeAsync(IServiceProvider services, IConfiguration config, ILogger logger)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        if (db.Database.GetMigrations().Any())
        {
            await db.Database.MigrateAsync();
        }
        else
        {
            await db.Database.EnsureCreatedAsync();
        }

        var email = config["Seed:AdminEmail"];
        var password = config["Seed:AdminPassword"];
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            logger.LogInformation("Seed:AdminEmail/Seed:AdminPassword not set — skipping admin seed.");
            return;
        }

        var normalized = email.Trim().ToLowerInvariant();
        if (await db.Users.AnyAsync(u => u.Email == normalized))
        {
            return;
        }

        var admin = new AppUser
        {
            Email = normalized,
            DisplayName = config["Seed:AdminName"] ?? "Administrator",
            Role = "admin",
        };
        admin.PasswordHash = new PasswordHasher<AppUser>().HashPassword(admin, password);

        db.Users.Add(admin);
        await db.SaveChangesAsync();
        logger.LogInformation("Seeded admin account {Email}", normalized);
    }
}
