using GuardSync.Api.Data;
using GuardSync.Api.Dtos;
using GuardSync.Api.Entities;
using GuardSync.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GuardSync.Api.Controllers;

[ApiController]
[Route("api/permissions")]
[Authorize]
public class PermissionsController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Query(
        [FromQuery] string? date,
        [FromQuery(Name = "employee_id")] string? employeeId,
        [FromQuery] string? start,
        [FromQuery] string? end,
        [FromQuery] string? status,
        [FromQuery] int? limit)
    {
        var query = db.PermissionRequests.AsNoTracking().Include(p => p.Employee).AsQueryable();

        if (date is not null)
        {
            if (!ValueParser.TryDate(date, out var day))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "date must be yyyy-MM-dd."));
            }
            query = query.Where(p => p.Date == day);
        }

        if (employeeId is not null)
        {
            if (!ValueParser.TryId(employeeId, out var id))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "employee_id must be a GUID."));
            }
            query = query.Where(p => p.EmployeeId == id);
        }

        if (start is not null)
        {
            if (!ValueParser.TryDate(start, out var from))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "start must be yyyy-MM-dd."));
            }
            query = query.Where(p => p.Date >= from);
        }

        if (end is not null)
        {
            if (!ValueParser.TryDate(end, out var to))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "end must be yyyy-MM-dd."));
            }
            query = query.Where(p => p.Date <= to);
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            query = query.Where(p => p.Status == status);
        }

        // No limit means "everything that matched" — report screens ask for a
        // whole month and must not be silently truncated.
        var ordered = query.OrderByDescending(p => p.Date).ThenByDescending(p => p.CreatedAt);
        var permissions = limit is > 0
            ? await ordered.Take(limit.Value).ToListAsync()
            : await ordered.ToListAsync();

        return Ok(permissions.Select(PermissionRequestDto.From));
    }

    /// <summary>Looks for an existing permission of a type on a day, 204 when absent.</summary>
    [HttpGet("find")]
    public async Task<IActionResult> Find(
        [FromQuery(Name = "employee_id")] string employeeId,
        [FromQuery] string date,
        [FromQuery(Name = "permission_type")] string permissionType)
    {
        if (!ValueParser.TryId(employeeId, out var id) || !ValueParser.TryDate(date, out var day))
        {
            return BadRequest(ApiError.Of("error_invalid_request"));
        }

        var permission = await db.PermissionRequests.AsNoTracking()
            .Include(p => p.Employee)
            .FirstOrDefaultAsync(p =>
                p.EmployeeId == id && p.Date == day && p.PermissionType == permissionType);

        return permission is null ? NoContent() : Ok(PermissionRequestDto.From(permission));
    }

    /// <summary>Approved vacation days taken inside a calendar month ("yyyy-MM").</summary>
    [HttpGet("vacations/count")]
    public async Task<IActionResult> CountVacations(
        [FromQuery(Name = "employee_id")] string employeeId,
        [FromQuery(Name = "year_month")] string yearMonth)
    {
        if (!ValueParser.TryId(employeeId, out var id) ||
            !ValueParser.TryMonthRange(yearMonth, out var start, out var end))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "Expected a GUID and yyyy-MM."));
        }

        var count = await db.PermissionRequests.CountAsync(p =>
            p.EmployeeId == id &&
            p.PermissionType == "vacation" &&
            p.Status == "approved" &&
            p.Date >= start && p.Date <= end);

        return Ok(new CountResponse { Count = count });
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreatePermissionRequest request)
    {
        if (!ValueParser.TryId(request.EmployeeId, out var employeeId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "employee_id must be a GUID."));
        }

        if (!ValueParser.TryDate(request.Date, out var date))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "date must be yyyy-MM-dd."));
        }

        if (!await db.Employees.AnyAsync(e => e.Id == employeeId))
        {
            return NotFound(ApiError.Of("error_employee_not_found"));
        }

        // Same rule the app applies before it posts: one permission of a given
        // type per employee per day.
        var duplicate = await db.PermissionRequests.AnyAsync(p =>
            p.EmployeeId == employeeId &&
            p.Date == date &&
            p.PermissionType == request.PermissionType);

        if (duplicate)
        {
            return Conflict(ApiError.Of("error_duplicate_permission"));
        }

        // Two approved vacation days a month is the rule the app enforces in its
        // UI; it is re-checked here so the limit holds regardless of client.
        if (request.PermissionType == "vacation" && request.Status == "approved")
        {
            var monthStart = new DateOnly(date.Year, date.Month, 1);
            var monthEnd = monthStart.AddMonths(1).AddDays(-1);
            var taken = await db.PermissionRequests.CountAsync(p =>
                p.EmployeeId == employeeId &&
                p.PermissionType == "vacation" &&
                p.Status == "approved" &&
                p.Date >= monthStart && p.Date <= monthEnd);

            if (taken >= 2)
            {
                return Conflict(ApiError.Of("vacation_limit_error"));
            }
        }

        var permission = new PermissionRequest
        {
            EmployeeId = employeeId,
            PermissionType = request.PermissionType,
            Date = date,
            StartTime = ValueParser.TimeOrNull(request.StartTime),
            EndTime = ValueParser.TimeOrNull(request.EndTime),
            Reason = string.IsNullOrWhiteSpace(request.Reason) ? null : request.Reason.Trim(),
            Status = string.IsNullOrWhiteSpace(request.Status) ? "approved" : request.Status,
            ApprovedBy = string.IsNullOrWhiteSpace(request.ApprovedBy) ? null : request.ApprovedBy.Trim(),
            Notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim(),
        };

        db.PermissionRequests.Add(permission);
        await db.SaveChangesAsync();
        await db.Entry(permission).Reference(p => p.Employee).LoadAsync();

        return Ok(PermissionRequestDto.From(permission));
    }

    [HttpPatch("{id}/status")]
    public async Task<IActionResult> UpdateStatus(string id, UpdatePermissionStatusRequest request)
    {
        if (!ValueParser.TryId(id, out var permissionId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "id must be a GUID."));
        }

        string[] allowed = ["pending", "approved", "rejected"];
        if (!allowed.Contains(request.Status))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "status must be pending, approved or rejected."));
        }

        var permission = await db.PermissionRequests
            .Include(p => p.Employee)
            .FirstOrDefaultAsync(p => p.Id == permissionId);

        if (permission is null) return NotFound(ApiError.Of("error_not_found"));

        permission.Status = request.Status;
        permission.ApprovedBy = string.IsNullOrWhiteSpace(request.ApprovedBy)
            ? permission.ApprovedBy
            : request.ApprovedBy.Trim();
        permission.UpdatedAt = DateTimeOffset.UtcNow;

        await db.SaveChangesAsync();

        return Ok(PermissionRequestDto.From(permission));
    }
}
