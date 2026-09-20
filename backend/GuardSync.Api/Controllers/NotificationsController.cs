using GuardSync.Api.Data;
using GuardSync.Api.Dtos;
using GuardSync.Api.Entities;
using GuardSync.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GuardSync.Api.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int limit = 50)
    {
        var notifications = await db.AdminNotifications.AsNoTracking()
            .OrderByDescending(n => n.Date)
            .ThenByDescending(n => n.CreatedAt)
            .Take(Math.Clamp(limit, 1, 200))
            .ToListAsync();

        return Ok(notifications.Select(AdminNotificationDto.From));
    }

    [HttpGet("unread-count")]
    public async Task<IActionResult> UnreadCount()
    {
        var count = await db.AdminNotifications.CountAsync(n => !n.IsRead);
        return Ok(new CountResponse { Count = count });
    }

    /// <summary>True when this employee already triggered this alert type in the given month.</summary>
    [HttpGet("exists")]
    public async Task<IActionResult> Exists(
        [FromQuery(Name = "employee_id")] string employeeId,
        [FromQuery(Name = "year_month")] string yearMonth,
        [FromQuery] string type = "early_leave_threshold")
    {
        if (!ValueParser.TryId(employeeId, out var id) ||
            !ValueParser.TryMonthRange(yearMonth, out var start, out var end))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "Expected a GUID and yyyy-MM."));
        }

        var exists = await db.AdminNotifications.AnyAsync(n =>
            n.EmployeeId == id && n.Type == type && n.Date >= start && n.Date <= end);

        return Ok(new ExistsResponse { Exists = exists });
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateNotificationRequest request)
    {
        if (!ValueParser.TryId(request.EmployeeId, out var employeeId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "employee_id must be a GUID."));
        }

        if (!ValueParser.TryDate(request.Date, out var date))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "date must be yyyy-MM-dd."));
        }

        var notification = new AdminNotification
        {
            Type = request.Type,
            EmployeeId = employeeId,
            EmployeeName = request.EmployeeName,
            Message = request.Message,
            Date = date,
            EarlyLeaveCount = request.EarlyLeaveCount,
            IsRead = request.IsRead,
        };

        db.AdminNotifications.Add(notification);
        await db.SaveChangesAsync();

        return Ok(AdminNotificationDto.From(notification));
    }

    [HttpPatch("{id}/read")]
    public async Task<IActionResult> MarkAsRead(string id)
    {
        if (!ValueParser.TryId(id, out var notificationId))
        {
            return BadRequest(ApiError.Of("error_invalid_request", "id must be a GUID."));
        }

        var notification = await db.AdminNotifications.FirstOrDefaultAsync(n => n.Id == notificationId);
        if (notification is null) return NotFound(ApiError.Of("error_not_found"));

        notification.IsRead = true;
        await db.SaveChangesAsync();

        return Ok(AdminNotificationDto.From(notification));
    }

    [HttpPatch("read-all")]
    public async Task<IActionResult> MarkAllAsRead()
    {
        // Single UPDATE statement — the Firestore version had to fan out into a
        // batch of per-document writes.
        var updated = await db.AdminNotifications
            .Where(n => !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));

        return Ok(new CountResponse { Count = updated });
    }
}
