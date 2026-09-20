using System.ComponentModel.DataAnnotations;
using GuardSync.Api.Entities;

namespace GuardSync.Api.Dtos;

/// <summary>Serialises as the exact shape AttendanceRecordModel.fromJson expects.</summary>
public record AttendanceRecordDto
{
    public string Id { get; init; } = string.Empty;
    public string EmployeeId { get; init; } = string.Empty;
    public string? EmployeeName { get; init; }

    /// <summary>yyyy-MM-dd</summary>
    public string Date { get; init; } = string.Empty;

    /// <summary>HH:mm</summary>
    public string? CheckInTime { get; init; }

    public string? CheckOutTime { get; init; }
    public string Status { get; init; } = "pending";
    public string? Notes { get; init; }
    public bool IsSynced { get; init; } = true;
    public string? GuardName { get; init; }
    public bool IsEarlyLeave { get; init; }

    public static AttendanceRecordDto From(AttendanceRecord r) => new()
    {
        Id = r.Id.ToString(),
        EmployeeId = r.EmployeeId.ToString(),
        EmployeeName = r.Employee?.FullName,
        Date = r.Date.ToString("yyyy-MM-dd"),
        CheckInTime = r.CheckInTime?.ToString("HH\\:mm"),
        CheckOutTime = r.CheckOutTime?.ToString("HH\\:mm"),
        Status = r.Status,
        Notes = r.Notes,
        IsSynced = true,
        GuardName = r.GuardName,
        IsEarlyLeave = r.IsEarlyLeave,
    };
}

public record CreateAttendanceRecordRequest
{
    [Required]
    public string EmployeeId { get; init; } = string.Empty;

    [Required]
    public string Date { get; init; } = string.Empty;

    public string? CheckInTime { get; init; }
    public string? CheckOutTime { get; init; }
    public string Status { get; init; } = "pending";
    public string? Notes { get; init; }
    public string? GuardName { get; init; }
    public bool IsEarlyLeave { get; init; }
}

/// <summary>Partial update — null means "leave unchanged".</summary>
public record UpdateAttendanceRecordRequest
{
    public string? CheckInTime { get; init; }
    public string? CheckOutTime { get; init; }
    public string? Status { get; init; }
    public string? Notes { get; init; }
    public string? GuardName { get; init; }
    public bool? IsEarlyLeave { get; init; }
}

public record CountResponse
{
    public int Count { get; init; }
}

public record ExistsResponse
{
    public bool Exists { get; init; }
}
