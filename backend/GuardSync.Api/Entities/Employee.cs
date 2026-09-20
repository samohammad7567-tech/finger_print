namespace GuardSync.Api.Entities;

public class Employee
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Human-facing staff number (not the primary key).</summary>
    public string? EmployeeNumber { get; set; }

    public string FullName { get; set; } = string.Empty;
    public string Department { get; set; } = string.Empty;
    public string? PhotoUrl { get; set; }
    public bool HasHousing { get; set; }
    public bool HasTravelPermission { get; set; }
    public string? Phone { get; set; }
    public string? Position { get; set; }
    public string? QrCode { get; set; }
    public bool IsActive { get; set; } = true;

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    public ICollection<AttendanceRecord> AttendanceRecords { get; set; } = new List<AttendanceRecord>();
    public ICollection<PermissionRequest> PermissionRequests { get; set; } = new List<PermissionRequest>();
}
