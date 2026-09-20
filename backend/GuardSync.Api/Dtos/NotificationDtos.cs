using System.ComponentModel.DataAnnotations;
using GuardSync.Api.Entities;

namespace GuardSync.Api.Dtos;

/// <summary>Serialises as the exact shape AdminNotificationModel.fromJson expects.</summary>
public record AdminNotificationDto
{
    public string Id { get; init; } = string.Empty;
    public string Type { get; init; } = string.Empty;
    public string EmployeeId { get; init; } = string.Empty;
    public string EmployeeName { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;

    /// <summary>yyyy-MM-dd</summary>
    public string Date { get; init; } = string.Empty;

    public int EarlyLeaveCount { get; init; }
    public bool IsRead { get; init; }

    public static AdminNotificationDto From(AdminNotification n) => new()
    {
        Id = n.Id.ToString(),
        Type = n.Type,
        EmployeeId = n.EmployeeId.ToString(),
        EmployeeName = n.EmployeeName,
        Message = n.Message,
        Date = n.Date.ToString("yyyy-MM-dd"),
        EarlyLeaveCount = n.EarlyLeaveCount,
        IsRead = n.IsRead,
    };
}

public record CreateNotificationRequest
{
    [Required]
    public string Type { get; init; } = string.Empty;

    [Required]
    public string EmployeeId { get; init; } = string.Empty;

    public string EmployeeName { get; init; } = string.Empty;
    public string Message { get; init; } = string.Empty;

    [Required]
    public string Date { get; init; } = string.Empty;

    public int EarlyLeaveCount { get; init; }
    public bool IsRead { get; init; }
}
