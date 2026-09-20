using GuardSync.Api.Data;
using GuardSync.Api.Dtos;
using GuardSync.Api.Entities;
using GuardSync.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GuardSync.Api.Controllers;

[ApiController]
[Route("api/attendance")]
[Authorize]
public class AttendanceController(AppDbContext db) : ControllerBase
{
    /// <summary>
    /// One endpoint covers every list the app asks for: by day, by employee, or
    /// over a range. Filters combine, and omitting all of them returns the newest
    /// records first.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> Query(
        [FromQuery] string? date,
        [FromQuery(Name = "employee_id")] string? employeeId,
        [FromQuery] string? start,
        [FromQuery] string? end,
        [FromQuery] int? limit)
    {
        var query = db.AttendanceRecords.AsNoTracking().Include(r => r.Employee).AsQueryable();

        if (date is not null)
        {
            if (!ValueParser.TryDate(date, out var day))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "date must be yyyy-MM-dd."));
            }
            query = query.Where(r => r.Date == day);
        }

        if (employeeId is not null)
        {
            if (!ValueParser.TryId(employeeId, out var id))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "employee_id must be a GUID."));
            }
            query = query.Where(r => r.EmployeeId == id);
        }

        if (start is not null)
        {
            if (!ValueParser.TryDate(start, out var from))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "start must be yyyy-MM-dd."));
            }
            query = query.Where(r => r.Date >= from);
        }

        if (end is not null)
        {
            if (!ValueParser.TryDate(end, out var to))
            {
                return BadRequest(ApiError.Of("error_invalid_request", "end must be yyyy-MM-dd."));
            }
            query = query.Where(r => r.Date <= to);
        }

        query = query.OrderByDescending(r => r.Date).ThenBy(r => r.CheckInTime);
        if (limit is > 0) query = query.Take(Math.Min(limit.Value, 500));

        var records = await query.ToListAsync();
        return Ok(records.Select(AttendanceRecordDto.From));
    }

    /// <summary>The single record for an employee on a day, or 204 when there is none.</summary>
    [HttpGet("find")]
    public async Task<IActionResult> Find(
        [FromQuery(Name = "employee_id")] string employeeId,
        [FromQuery] string date)
    {
        if (!ValueParser.TryId(employeeId, out var id) || !ValueParser.TryDate(date, out var day))
        {
            return BadRequest(ApiError.Of("error_invalid_request"));
        }

        var record = await db.AttendanceRecords.AsNoTracking()
            .Include(r => r.Employee)
            .FirstOrDefaultAsync(r => r.EmployeeId == id && r.Date == day);

        return record is null ? NoContent() : Ok(AttendanceRecordDto.From(record));
    }

    /// <summary>Counts early leaves within a calendar month ("yyyy-MM").</summary>
    [HttpGet("early-leaves/count")]
    public async Task<IActionResult> CountEarlyLeaves(
        [FromQuery(Name = "employee_id")] string employeeId,
        [FromQuery(Name = "year_month")] string yearMonth)
    {
        if (!ValueParser.TryId(employeeId, out var id) ||
            !ValueParser.TryMonthRange(yearMonth, out var start, out var end))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "Expected a GUID and yyyy-MM."));
        }

        var count = await db.AttendanceRecords.CountAsync(r =>
            r.EmployeeId == id &&
            r.Date >= start && r.Date <= end &&
            (r.IsEarlyLeave || r.Status == "early_leave"));

        return Ok(new CountResponse { Count = count });
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateAttendanceRecordRequest request)
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

        // The (employee_id, date) unique index is the real guard; this check just
        // turns the common case into a clear 409 instead of a database error.
        if (await db.AttendanceRecords.AnyAsync(r => r.EmployeeId == employeeId && r.Date == date))
        {
            return Conflict(ApiError.Of("error_duplicate_record"));
        }

        var record = new AttendanceRecord
        {
            EmployeeId = employeeId,
            Date = date,
            CheckInTime = ValueParser.TimeOrNull(request.CheckInTime),
            CheckOutTime = ValueParser.TimeOrNull(request.CheckOutTime),
            Status = string.IsNullOrWhiteSpace(request.Status) ? "pending" : request.Status,
            Notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim(),
            GuardName = string.IsNullOrWhiteSpace(request.GuardName) ? null : request.GuardName.Trim(),
            IsEarlyLeave = request.IsEarlyLeave,
        };

        db.AttendanceRecords.Add(record);
        await db.SaveChangesAsync();
        await db.Entry(record).Reference(r => r.Employee).LoadAsync();

        return Ok(AttendanceRecordDto.From(record));
    }

    [HttpPatch("{id}")]
    public async Task<IActionResult> Update(string id, UpdateAttendanceRecordRequest request)
    {
        if (!ValueParser.TryId(id, out var recordId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "id must be a GUID."));
        }

        var record = await db.AttendanceRecords
            .Include(r => r.Employee)
            .FirstOrDefaultAsync(r => r.Id == recordId);

        if (record is null) return NotFound(ApiError.Of("error_not_found"));

        if (request.CheckInTime is not null) record.CheckInTime = ValueParser.TimeOrNull(request.CheckInTime);
        if (request.CheckOutTime is not null) record.CheckOutTime = ValueParser.TimeOrNull(request.CheckOutTime);
        if (request.Status is not null) record.Status = request.Status;
        if (request.Notes is not null) record.Notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim();
        if (request.GuardName is not null) record.GuardName = request.GuardName.Trim();
        if (request.IsEarlyLeave is not null) record.IsEarlyLeave = request.IsEarlyLeave.Value;

        record.UpdatedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync();

        return Ok(AttendanceRecordDto.From(record));
    }
}
