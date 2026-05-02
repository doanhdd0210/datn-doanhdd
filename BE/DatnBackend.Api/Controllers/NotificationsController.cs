using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/notifications")]
[Produces("application/json")]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;
    private readonly IUserService _userService;
    private readonly AppDbContext _db;

    public NotificationsController(INotificationService notificationService, IUserService userService, AppDbContext db)
    {
        _notificationService = notificationService;
        _userService = userService;
        _db = db;
    }

    /// <summary>Lấy in-app notifications của user hiện tại</summary>
    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<object>>> GetMyNotifications([FromQuery] int limit = 30)
    {
        var uid = HttpContext.Items["FirebaseUid"] as string;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        var notifs = await _db.UserNotifications
            .Where(n => n.UserId == uid)
            .OrderByDescending(n => n.CreatedAt)
            .Take(limit)
            .ToListAsync();

        var unreadCount = notifs.Count(n => !n.IsRead);

        return Ok(ApiResponse<object>.Ok(new { notifications = notifs, unreadCount }));
    }

    /// <summary>Đánh dấu một thông báo là đã đọc</summary>
    [HttpPost("me/{id}/read")]
    public async Task<ActionResult<ApiResponse<object>>> MarkOneRead(string id)
    {
        var uid = HttpContext.Items["FirebaseUid"] as string;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        await _db.UserNotifications
            .Where(n => n.Id == id && n.UserId == uid)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));

        return Ok(ApiResponse<object>.Ok(null, "Marked as read"));
    }

    /// <summary>Đánh dấu tất cả là đã đọc</summary>
    [HttpPost("me/read-all")]
    public async Task<ActionResult<ApiResponse<object>>> MarkAllRead()
    {
        var uid = HttpContext.Items["FirebaseUid"] as string;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        await _db.UserNotifications
            .Where(n => n.UserId == uid && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));

        return Ok(ApiResponse<object>.Ok(null, "Marked all as read"));
    }

    /// <summary>Số thông báo chưa đọc</summary>
    [HttpGet("me/unread-count")]
    public async Task<ActionResult<ApiResponse<object>>> GetUnreadCount()
    {
        var uid = HttpContext.Items["FirebaseUid"] as string;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        var count = await _db.UserNotifications
            .CountAsync(n => n.UserId == uid && !n.IsRead);

        return Ok(ApiResponse<object>.Ok(new { count }));
    }

    /// <summary>Gửi thông báo — chọn một trong: token, topic, uid, broadcastAll</summary>
    [HttpPost("send")]
    public async Task<ActionResult<ApiResponse<object>>> Send([FromBody] SendNotificationRequest request)
    {
        try
        {
            string result;

            if (!string.IsNullOrEmpty(request.Token))
            {
                result = await _notificationService.SendToTokenAsync(request);
            }
            else if (!string.IsNullOrEmpty(request.Topic))
            {
                result = await _notificationService.SendToTopicAsync(request);
            }
            else if (!string.IsNullOrEmpty(request.Uid))
            {
                var user = await _userService.GetUserAsync(request.Uid);
                if (user == null)
                    return NotFound(ApiResponse<object>.Fail("User not found"));
                if (user.FcmTokens.Count == 0)
                    return BadRequest(ApiResponse<object>.Fail("User has no registered FCM tokens"));

                result = await _notificationService.SendToTokensAsync(request, user.FcmTokens);
            }
            else if (request.BroadcastAll)
            {
                result = await _notificationService.BroadcastAsync(request);
            }
            else
            {
                return BadRequest(ApiResponse<object>.Fail(
                    "Phải chỉ định một trong: token, topic, uid, hoặc broadcastAll = true"));
            }

            return Ok(ApiResponse<object>.Ok(new { result }, "Notification sent"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    /// <summary>Lịch sử thông báo đã gửi</summary>
    [HttpGet("history")]
    public async Task<ActionResult<ApiResponse<List<NotificationRecord>>>> GetHistory([FromQuery] int limit = 50)
    {
        var history = await _notificationService.GetHistoryAsync(limit);
        return Ok(ApiResponse<List<NotificationRecord>>.Ok(history));
    }

    /// <summary>Đăng ký FCM tokens vào topic</summary>
    [HttpPost("topic/subscribe")]
    public async Task<ActionResult<ApiResponse<object>>> Subscribe([FromBody] TopicSubscriptionRequest request)
    {
        try
        {
            await _notificationService.SubscribeToTopicAsync(request.Tokens, request.Topic);
            return Ok(ApiResponse<object>.Ok(null, $"Subscribed {request.Tokens.Count} tokens to '{request.Topic}'"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    /// <summary>Huỷ đăng ký FCM tokens khỏi topic</summary>
    [HttpPost("topic/unsubscribe")]
    public async Task<ActionResult<ApiResponse<object>>> Unsubscribe([FromBody] TopicSubscriptionRequest request)
    {
        try
        {
            await _notificationService.UnsubscribeFromTopicAsync(request.Tokens, request.Topic);
            return Ok(ApiResponse<object>.Ok(null, $"Unsubscribed {request.Tokens.Count} tokens from '{request.Topic}'"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }
}
