using GuardSync.Api.Data;
using GuardSync.Api.Dtos;
using GuardSync.Api.Entities;
using GuardSync.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GuardSync.Api.Controllers;

[ApiController]
[Route("api/employees")]
[Authorize]
public class EmployeesController(AppDbContext db) : ControllerBase
{
    /// <summary>activeOnly=true mirrors the guard-facing list; admins pass false for everyone.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] bool activeOnly = false)
    {
        var query = db.Employees.AsNoTracking();
        if (activeOnly) query = query.Where(e => e.IsActive);

        var employees = await query.OrderBy(e => e.FullName).ToListAsync();

        return Ok(employees.Select(EmployeeDto.From));
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(string id)
    {
        if (!ValueParser.TryId(id, out var employeeId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "id must be a GUID."));
        }

        var employee = await db.Employees.AsNoTracking()
            .FirstOrDefaultAsync(e => e.Id == employeeId);

        return employee is null
            ? NotFound(ApiError.Of("error_not_found"))
            : Ok(EmployeeDto.From(employee));
    }

    [HttpPost]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Create(CreateEmployeeRequest request)
    {
        var number = Normalize(request.EmployeeId);
        if (number is not null && await db.Employees.AnyAsync(e => e.EmployeeNumber == number))
        {
            return Conflict(ApiError.Of("error_duplicate_employee_number"));
        }

        var employee = new Employee
        {
            EmployeeNumber = number,
            FullName = request.FullName.Trim(),
            Department = request.Department.Trim(),
            PhotoUrl = Normalize(request.PhotoUrl),
            HasHousing = request.HasHousing,
            HasTravelPermission = request.HasTravelPermission,
            Phone = Normalize(request.Phone),
            Position = Normalize(request.Position),
            QrCode = Normalize(request.QrCode),
            IsActive = request.IsActive,
        };

        db.Employees.Add(employee);
        await db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = employee.Id }, EmployeeDto.From(employee));
    }

    [HttpPatch("{id}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Update(string id, UpdateEmployeeRequest request)
    {
        if (!ValueParser.TryId(id, out var employeeId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "id must be a GUID."));
        }

        var employee = await db.Employees.FirstOrDefaultAsync(e => e.Id == employeeId);
        if (employee is null) return NotFound(ApiError.Of("error_not_found"));

        if (request.EmployeeId is not null)
        {
            var number = Normalize(request.EmployeeId);
            if (number is not null &&
                await db.Employees.AnyAsync(e => e.EmployeeNumber == number && e.Id != employeeId))
            {
                return Conflict(ApiError.Of("error_duplicate_employee_number"));
            }
            employee.EmployeeNumber = number;
        }

        if (request.FullName is not null) employee.FullName = request.FullName.Trim();
        if (request.Department is not null) employee.Department = request.Department.Trim();
        if (request.PhotoUrl is not null) employee.PhotoUrl = Normalize(request.PhotoUrl);
        if (request.HasHousing is not null) employee.HasHousing = request.HasHousing.Value;
        if (request.HasTravelPermission is not null) employee.HasTravelPermission = request.HasTravelPermission.Value;
        if (request.Phone is not null) employee.Phone = Normalize(request.Phone);
        if (request.Position is not null) employee.Position = Normalize(request.Position);
        if (request.QrCode is not null) employee.QrCode = Normalize(request.QrCode);
        if (request.IsActive is not null) employee.IsActive = request.IsActive.Value;

        employee.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync();

        return Ok(EmployeeDto.From(employee));
    }

    [HttpDelete("{id}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Delete(string id)
    {
        if (!ValueParser.TryId(id, out var employeeId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "id must be a GUID."));
        }

        var employee = await db.Employees.FirstOrDefaultAsync(e => e.Id == employeeId);
        if (employee is null) return NotFound(ApiError.Of("error_not_found"));

        // Cascades to attendance records and permission requests by design —
        // matches the previous Firestore behaviour of removing the employee outright.
        db.Employees.Remove(employee);
        await db.SaveChangesAsync();

        return NoContent();
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
