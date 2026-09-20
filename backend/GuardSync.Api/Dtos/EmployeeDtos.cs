using System.ComponentModel.DataAnnotations;
using GuardSync.Api.Entities;

namespace GuardSync.Api.Dtos;

/// <summary>Serialises as the exact shape EmployeeModel.fromJson expects.</summary>
public record EmployeeDto
{
    public string Id { get; init; } = string.Empty;

    /// <summary>Staff number — maps to Employee.EmployeeNumber, not the primary key.</summary>
    public string? EmployeeId { get; init; }

    public string FullName { get; init; } = string.Empty;
    public string Department { get; init; } = string.Empty;
    public string? PhotoUrl { get; init; }
    public bool HasHousing { get; init; }
    public bool HasTravelPermission { get; init; }
    public string? Phone { get; init; }
    public string? Position { get; init; }
    public string? QrCode { get; init; }
    public bool IsActive { get; init; }

    public static EmployeeDto From(Employee e) => new()
    {
        Id = e.Id.ToString(),
        EmployeeId = e.EmployeeNumber,
        FullName = e.FullName,
        Department = e.Department,
        PhotoUrl = e.PhotoUrl,
        HasHousing = e.HasHousing,
        HasTravelPermission = e.HasTravelPermission,
        Phone = e.Phone,
        Position = e.Position,
        QrCode = e.QrCode,
        IsActive = e.IsActive,
    };
}

public record CreateEmployeeRequest
{
    [Required, MaxLength(200)]
    public string FullName { get; init; } = string.Empty;

    [MaxLength(120)]
    public string Department { get; init; } = string.Empty;

    public string? EmployeeId { get; init; }
    public string? PhotoUrl { get; init; }
    public bool HasHousing { get; init; }
    public bool HasTravelPermission { get; init; }
    public string? Phone { get; init; }
    public string? Position { get; init; }
    public string? QrCode { get; init; }
    public bool IsActive { get; init; } = true;
}

/// <summary>
/// Partial update. Every property is nullable and a null means "leave unchanged",
/// which matches how the Flutter side posts sparse maps such as { "is_active": false }.
/// </summary>
public record UpdateEmployeeRequest
{
    public string? FullName { get; init; }
    public string? Department { get; init; }
    public string? EmployeeId { get; init; }
    public string? PhotoUrl { get; init; }
    public bool? HasHousing { get; init; }
    public bool? HasTravelPermission { get; init; }
    public string? Phone { get; init; }
    public string? Position { get; init; }
    public string? QrCode { get; init; }
    public bool? IsActive { get; init; }
}
