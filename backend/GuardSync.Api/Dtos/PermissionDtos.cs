using System.ComponentModel.DataAnnotations;
using GuardSync.Api.Entities;

namespace GuardSync.Api.Dtos;

/// <summary>Serialises as the exact shape PermissionRequestModel.fromJson expects.</summary>
public record PermissionRequestDto
{
    public string Id { get; init; } = string.Empty;
    public string EmployeeId { get; init; } = string.Empty;
    public string? EmployeeName { get; init; }
    public string? Department { get; init; }
    public string PermissionType { get; init; } = "other";

    /// <summary>yyyy-MM-dd</summary>
    public string Date { get; init; } = string.Empty;

    /// <summary>HH:mm</summary>
    public string? StartTime { get; init; }

    public string? EndTime { get; init; }
    public string? Reason { get; init; }
    public string Status { get; init; } = "approved";
    public string? ApprovedBy { get; init; }
    public string? Notes { get; init; }

    public static PermissionRequestDto From(PermissionRequest p) => new()
    {
        Id = p.Id.ToString(),
        EmployeeId = p.EmployeeId.ToString(),
        EmployeeName = p.Employee?.FullName,
        Department = p.Employee?.Department,
        PermissionType = p.PermissionType,
        Date = p.Date.ToString("yyyy-MM-dd"),
        StartTime = p.StartTime?.ToString("HH\\:mm"),
        EndTime = p.EndTime?.ToString("HH\\:mm"),
        Reason = p.Reason,
        Status = p.Status,
        ApprovedBy = p.ApprovedBy,
        Notes = p.Notes,
    };
}

public record CreatePermissionRequest
{
    [Required]
    public string EmployeeId { get; init; } = string.Empty;

    [Required]
    public string PermissionType { get; init; } = "other";

    [Required]
    public string Date { get; init; } = string.Empty;

    public string? StartTime { get; init; }
    public string? EndTime { get; init; }
    public string? Reason { get; init; }
    public string Status { get; init; } = "approved";
    public string? ApprovedBy { get; init; }
    public string? Notes { get; init; }
}

public record UpdatePermissionStatusRequest
{
    [Required]
    public string Status { get; init; } = string.Empty;

    public string? ApprovedBy { get; init; }
}
