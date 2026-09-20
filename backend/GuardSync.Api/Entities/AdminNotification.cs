namespace GuardSync.Api.Entities;

public class AdminNotification
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>e.g. early_leave_threshold</summary>
    public string Type { get; set; } = string.Empty;

    public Guid EmployeeId { get; set; }
    public string EmployeeName { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public DateOnly Date { get; set; }
    public int EarlyLeaveCount { get; set; }
    public bool IsRead { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
