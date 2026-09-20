namespace GuardSync.Api.Entities;

public class PermissionRequest
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid EmployeeId { get; set; }

    /// <summary>vacation | sick | travel | early_leave | late_arrival | other</summary>
    public string PermissionType { get; set; } = "other";

    public DateOnly Date { get; set; }
    public TimeOnly? StartTime { get; set; }
    public TimeOnly? EndTime { get; set; }
    public string? Reason { get; set; }

    /// <summary>pending | approved | rejected</summary>
    public string Status { get; set; } = "approved";

    public string? ApprovedBy { get; set; }
    public string? Notes { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    public Employee? Employee { get; set; }
}
