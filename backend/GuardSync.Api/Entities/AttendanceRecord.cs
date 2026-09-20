namespace GuardSync.Api.Entities;

public class AttendanceRecord
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid EmployeeId { get; set; }

    /// <summary>Calendar day of the record, stored as a real date.</summary>
    public DateOnly Date { get; set; }

    /// <summary>Wall-clock check-in time ("HH:mm"), null until the guard checks the employee in.</summary>
    public TimeOnly? CheckInTime { get; set; }

    public TimeOnly? CheckOutTime { get; set; }

    /// <summary>pending | present | late | absent | early_leave | checked_out</summary>
    public string Status { get; set; } = "pending";

    public string? Notes { get; set; }
    public string? GuardName { get; set; }
    public bool IsEarlyLeave { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    public Employee? Employee { get; set; }
}
