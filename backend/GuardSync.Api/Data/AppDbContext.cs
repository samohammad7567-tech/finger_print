using GuardSync.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace GuardSync.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<AttendanceRecord> AttendanceRecords => Set<AttendanceRecord>();
    public DbSet<PermissionRequest> PermissionRequests => Set<PermissionRequest>();
    public DbSet<AdminNotification> AdminNotifications => Set<AdminNotification>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<AppUser>(e =>
        {
            e.ToTable("users");
            e.HasKey(x => x.Id);
            e.Property(x => x.Email).HasMaxLength(256).IsRequired();
            e.HasIndex(x => x.Email).IsUnique();
            e.Property(x => x.PasswordHash).IsRequired();
            e.Property(x => x.DisplayName).HasMaxLength(120);
            e.Property(x => x.Role).HasMaxLength(20).HasDefaultValue("guard");
            e.Property(x => x.ResetToken).HasMaxLength(200);
        });

        b.Entity<Employee>(e =>
        {
            e.ToTable("employees");
            e.HasKey(x => x.Id);
            e.Property(x => x.EmployeeNumber).HasMaxLength(60);
            e.Property(x => x.FullName).HasMaxLength(200).IsRequired();
            e.Property(x => x.Department).HasMaxLength(120);
            e.Property(x => x.Phone).HasMaxLength(40);
            e.Property(x => x.Position).HasMaxLength(120);
            e.Property(x => x.QrCode).HasMaxLength(200);
            e.HasIndex(x => x.EmployeeNumber).IsUnique().HasFilter("employee_number IS NOT NULL");
            e.HasIndex(x => x.IsActive);
        });

        b.Entity<AttendanceRecord>(e =>
        {
            e.ToTable("attendance_records");
            e.HasKey(x => x.Id);
            e.Property(x => x.Status).HasMaxLength(30).HasDefaultValue("pending");
            e.Property(x => x.GuardName).HasMaxLength(120);
            e.HasOne(x => x.Employee)
                .WithMany(x => x.AttendanceRecords)
                .HasForeignKey(x => x.EmployeeId)
                .OnDelete(DeleteBehavior.Cascade);

            // One record per employee per day — replaces the "findRecord then create"
            // race that Firestore allowed.
            e.HasIndex(x => new { x.EmployeeId, x.Date }).IsUnique();
            e.HasIndex(x => x.Date);
        });

        b.Entity<PermissionRequest>(e =>
        {
            e.ToTable("permission_requests");
            e.HasKey(x => x.Id);
            e.Property(x => x.PermissionType).HasMaxLength(40).IsRequired();
            e.Property(x => x.Status).HasMaxLength(20).HasDefaultValue("approved");
            e.Property(x => x.ApprovedBy).HasMaxLength(120);
            e.HasOne(x => x.Employee)
                .WithMany(x => x.PermissionRequests)
                .HasForeignKey(x => x.EmployeeId)
                .OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.EmployeeId, x.Date, x.PermissionType });
            e.HasIndex(x => x.Date);
        });

        b.Entity<AdminNotification>(e =>
        {
            e.ToTable("admin_notifications");
            e.HasKey(x => x.Id);
            e.Property(x => x.Type).HasMaxLength(60).IsRequired();
            e.Property(x => x.EmployeeName).HasMaxLength(200);
            e.HasIndex(x => x.IsRead);
            e.HasIndex(x => new { x.EmployeeId, x.Type, x.Date });
        });

        // Postgres convention: snake_case tables and columns.
        foreach (var entity in b.Model.GetEntityTypes())
        {
            foreach (var property in entity.GetProperties())
            {
                property.SetColumnName(ToSnakeCase(property.Name));
            }
        }
    }

    private static string ToSnakeCase(string value)
    {
        var sb = new System.Text.StringBuilder(value.Length + 8);
        for (var i = 0; i < value.Length; i++)
        {
            var c = value[i];
            if (char.IsUpper(c))
            {
                if (i > 0) sb.Append('_');
                sb.Append(char.ToLowerInvariant(c));
            }
            else
            {
                sb.Append(c);
            }
        }
        return sb.ToString();
    }
}
