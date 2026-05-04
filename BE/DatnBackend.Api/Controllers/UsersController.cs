using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/users")]
[Produces("application/json")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly AppDbContext _db;

    public UsersController(IUserService userService, AppDbContext db)
    {
        _userService = userService;
        _db = db;
    }

    private string? UserId => HttpContext.Items["FirebaseUid"]?.ToString();
    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;

    /// <summary>Cập nhật level học của user hiện tại</summary>
    [HttpPut("me/level")]
    public async Task<ActionResult<ApiResponse<object>>> SetMyLevel([FromBody] SetLevelRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        var validLevels = new[] { "beginner", "intermediate", "advanced" };
        if (!validLevels.Contains(request.Level))
            return BadRequest(ApiResponse<object>.Fail("Level không hợp lệ"));

        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == uid);
        if (profile == null)
        {
            // Profile chưa tồn tại — tạo mới với level đã chọn
            // Ưu tiên dùng displayName/photoUrl từ client (luôn có từ Firebase client SDK)
            // Fallback: gọi Firebase Admin SDK nếu client không gửi
            string displayName = request.DisplayName ?? "";
            string? photoUrl = request.PhotoUrl;

            if (string.IsNullOrEmpty(displayName))
            {
                try
                {
                    var firebaseUser = await FirebaseAdmin.Auth.FirebaseAuth.DefaultInstance.GetUserAsync(uid);
                    displayName = firebaseUser.DisplayName
                        ?? firebaseUser.ProviderData?.FirstOrDefault()?.DisplayName
                        ?? firebaseUser.Email?.Split('@')[0]
                        ?? "User";
                    photoUrl ??= firebaseUser.PhotoUrl
                        ?? firebaseUser.ProviderData?.FirstOrDefault()?.PhotoUrl;
                }
                catch
                {
                    displayName = "User";
                }
            }

            profile = new UserProfile
            {
                Uid = uid,
                DisplayName = displayName,
                PhotoUrl = photoUrl,
                Level = request.Level,
                FcmTokens = [],
            };
            _db.UserProfiles.Add(profile);
        }
        else
        {
            profile.Level = request.Level;
            // Cập nhật displayName/photoUrl nếu trước đó bị thiếu
            if (!string.IsNullOrEmpty(request.DisplayName) && string.IsNullOrEmpty(profile.DisplayName))
                profile.DisplayName = request.DisplayName;
            if (request.PhotoUrl != null && profile.PhotoUrl == null)
                profile.PhotoUrl = request.PhotoUrl;
        }

        await _db.SaveChangesAsync();
        return Ok(ApiResponse<object>.Ok(new { level = request.Level }, "Level updated"));
    }

    /// <summary>Đăng ký FCM token cho thiết bị hiện tại</summary>
    [HttpPost("me/fcm-token")]
    public async Task<ActionResult<ApiResponse<object>>> RegisterFcmToken([FromBody] RegisterFcmTokenRequest request)
    {
        if (UserId == null) return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));
        if (string.IsNullOrWhiteSpace(request.Token))
            return BadRequest(ApiResponse<object>.Fail("Token is required"));
        await _userService.RegisterFcmTokenAsync(UserId, request.Token);
        return Ok(ApiResponse<object>.Ok(null, "FCM token registered"));
    }

    /// <summary>Lấy danh sách tất cả người dùng</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<AppUser>>>> List([FromQuery] int max = 500)
    {
        var users = await _userService.ListUsersAsync(max);
        return Ok(ApiResponse<List<AppUser>>.Ok(users, $"{users.Count} users"));
    }

    /// <summary>Lấy thông tin 1 người dùng theo UID</summary>
    [HttpGet("{uid}")]
    public async Task<ActionResult<ApiResponse<AppUser>>> Get(string uid)
    {
        var user = await _userService.GetUserAsync(uid);
        if (user == null)
            return NotFound(ApiResponse<AppUser>.Fail($"User '{uid}' not found"));
        return Ok(ApiResponse<AppUser>.Ok(user));
    }

    /// <summary>Tạo người dùng mới</summary>
    [HttpPost]
    public async Task<ActionResult<ApiResponse<AppUser>>> Create([FromBody] CreateUserRequest request)
    {
        try
        {
            var user = await _userService.CreateUserAsync(request);
            return CreatedAtAction(nameof(Get), new { uid = user.Uid },
                ApiResponse<AppUser>.Ok(user, "User created successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<AppUser>.Fail(ex.Message));
        }
    }

    /// <summary>Cập nhật thông tin người dùng</summary>
    [HttpPut("{uid}")]
    public async Task<ActionResult<ApiResponse<AppUser>>> Update(string uid, [FromBody] UpdateUserRequest request)
    {
        try
        {
            var user = await _userService.UpdateUserAsync(uid, request);
            return Ok(ApiResponse<AppUser>.Ok(user, "User updated successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<AppUser>.Fail(ex.Message));
        }
    }

    /// <summary>Xoá người dùng</summary>
    [HttpDelete("{uid}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(string uid)
    {
        try
        {
            await _userService.DeleteUserAsync(uid);
            return Ok(ApiResponse<object>.Ok(null, "User deleted successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    /// <summary>Khoá / mở khoá tài khoản</summary>
    [HttpPatch("{uid}/disable")]
    public async Task<ActionResult<ApiResponse<AppUser>>> SetDisabled(string uid, [FromBody] SetDisabledRequest request)
    {
        try
        {
            var user = await _userService.SetDisabledAsync(uid, request.Disabled);
            var msg = request.Disabled ? "User disabled" : "User enabled";
            return Ok(ApiResponse<AppUser>.Ok(user, msg));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<AppUser>.Fail(ex.Message));
        }
    }

    /// <summary>Xoá toàn bộ QA posts + answers của các user không còn tồn tại trong UserProfiles</summary>
    [HttpDelete("cleanup/orphan-qa")]
    public async Task<ActionResult<ApiResponse<object>>> CleanupOrphanQa()
    {
        var activeUids = await _db.UserProfiles.Select(p => p.Uid).ToListAsync();

        var orphanPostIds = await _db.QaPosts
            .Where(p => !activeUids.Contains(p.UserId))
            .Select(p => p.Id)
            .ToListAsync();

        int answersDeleted = 0;
        int postsDeleted = 0;

        if (orphanPostIds.Count > 0)
        {
            answersDeleted += await _db.QaAnswers
                .Where(a => orphanPostIds.Contains(a.PostId))
                .ExecuteDeleteAsync();

            postsDeleted = await _db.QaPosts
                .Where(p => orphanPostIds.Contains(p.Id))
                .ExecuteDeleteAsync();
        }

        // Xoá answers của user không còn tồn tại (trả lời trên post người khác)
        answersDeleted += await _db.QaAnswers
            .Where(a => !activeUids.Contains(a.UserId))
            .ExecuteDeleteAsync();

        return Ok(ApiResponse<object>.Ok(new { postsDeleted, answersDeleted }, "Cleanup hoàn tất"));
    }

    /// <summary>Xoá toàn bộ dữ liệu DB của các UserProfile không còn tồn tại trong Firebase Auth</summary>
    [HttpDelete("cleanup/orphan-profiles")]
    public async Task<ActionResult<ApiResponse<object>>> CleanupOrphanProfiles()
    {
        if (!IsAdmin) return StatusCode(403, ApiResponse<object>.Fail("Forbidden"));

        var firebaseUsers = await _userService.ListUsersAsync();
        var activeUids = firebaseUsers.Select(u => u.Uid).ToList();

        var orphanUids = await _db.UserProfiles
            .Where(p => !activeUids.Contains(p.Uid))
            .Select(p => p.Uid)
            .ToListAsync();

        if (orphanUids.Count == 0)
            return Ok(ApiResponse<object>.Ok(new { deleted = 0 }, "Không có dữ liệu thừa"));

        // Bulk delete — single query per table, much faster than per-uid loop
        await _db.UserNotifications.Where(n => orphanUids.Contains(n.UserId) || orphanUids.Contains(n.ActorId)).ExecuteDeleteAsync();
        await _db.UserAchievements.Where(a => orphanUids.Contains(a.UserId)).ExecuteDeleteAsync();
        await _db.DailyGoalBonusClaims.Where(d => orphanUids.Contains(d.UserId)).ExecuteDeleteAsync();
        await _db.DailyProgresses.Where(d => orphanUids.Contains(d.UserId)).ExecuteDeleteAsync();
        await _db.PracticeResults.Where(p => orphanUids.Contains(p.UserId)).ExecuteDeleteAsync();
        await _db.QuizResults.Where(q => orphanUids.Contains(q.UserId)).ExecuteDeleteAsync();
        await _db.UserProgresses.Where(p => orphanUids.Contains(p.UserId)).ExecuteDeleteAsync();
        await _db.UserFollows.Where(f => orphanUids.Contains(f.FollowerId) || orphanUids.Contains(f.FollowingId)).ExecuteDeleteAsync();
        await _db.QaAnswers.Where(a => orphanUids.Contains(a.UserId)).ExecuteDeleteAsync();
        var orphanPostIds = await _db.QaPosts.Where(p => orphanUids.Contains(p.UserId)).Select(p => p.Id).ToListAsync();
        if (orphanPostIds.Count > 0)
            await _db.QaAnswers.Where(a => orphanPostIds.Contains(a.PostId)).ExecuteDeleteAsync();
        await _db.QaPosts.Where(p => orphanUids.Contains(p.UserId)).ExecuteDeleteAsync();
        await _db.NotificationHistory.Where(n => orphanUids.Contains(n.SentByUid)).ExecuteDeleteAsync();
        await _db.UserProfiles.Where(p => orphanUids.Contains(p.Uid)).ExecuteDeleteAsync();

        return Ok(ApiResponse<object>.Ok(new { deleted = orphanUids.Count }, $"Đã xoá {orphanUids.Count} profile thừa"));
    }

    /// <summary>Xoá toàn bộ non-admin users (Firebase Auth + DB cascade)</summary>
    [HttpDelete("delete-all-users")]
    public async Task<ActionResult<ApiResponse<object>>> DeleteAllUsers()
    {
        if (!IsAdmin) return StatusCode(403, ApiResponse<object>.Fail("Forbidden"));

        var firebaseUsers = await _userService.ListUsersAsync();
        var nonAdmins = firebaseUsers.Where(u => !u.IsAdmin).ToList();

        // Lấy tất cả non-admin UIDs từ cả Firebase lẫn DB (bao gồm orphans)
        var firebaseNonAdminUids = nonAdmins.Select(u => u.Uid).ToList();
        var dbNonAdminUids = await _db.UserProfiles
            .Where(p => !p.IsAdmin)
            .Select(p => p.Uid)
            .ToListAsync();
        var allUids = firebaseNonAdminUids.Union(dbNonAdminUids).ToList();

        if (allUids.Count == 0)
            return Ok(ApiResponse<object>.Ok(new { deletedUsers = 0 }, "Không có user nào để xoá"));

        // Bulk delete DB — single query per table
        await _db.UserNotifications.Where(n => allUids.Contains(n.UserId) || allUids.Contains(n.ActorId)).ExecuteDeleteAsync();
        await _db.UserAchievements.Where(a => allUids.Contains(a.UserId)).ExecuteDeleteAsync();
        await _db.DailyGoalBonusClaims.Where(d => allUids.Contains(d.UserId)).ExecuteDeleteAsync();
        await _db.DailyProgresses.Where(d => allUids.Contains(d.UserId)).ExecuteDeleteAsync();
        await _db.PracticeResults.Where(p => allUids.Contains(p.UserId)).ExecuteDeleteAsync();
        await _db.QuizResults.Where(q => allUids.Contains(q.UserId)).ExecuteDeleteAsync();
        await _db.UserProgresses.Where(p => allUids.Contains(p.UserId)).ExecuteDeleteAsync();
        await _db.UserFollows.Where(f => allUids.Contains(f.FollowerId) || allUids.Contains(f.FollowingId)).ExecuteDeleteAsync();
        await _db.QaAnswers.Where(a => allUids.Contains(a.UserId)).ExecuteDeleteAsync();
        var postIds = await _db.QaPosts.Where(p => allUids.Contains(p.UserId)).Select(p => p.Id).ToListAsync();
        if (postIds.Count > 0)
            await _db.QaAnswers.Where(a => postIds.Contains(a.PostId)).ExecuteDeleteAsync();
        await _db.QaPosts.Where(p => allUids.Contains(p.UserId)).ExecuteDeleteAsync();
        await _db.NotificationHistory.Where(n => allUids.Contains(n.SentByUid)).ExecuteDeleteAsync();
        await _db.UserProfiles.Where(p => allUids.Contains(p.Uid)).ExecuteDeleteAsync();

        // Xoá Firebase Auth accounts (DB đã xoá ở trên)
        foreach (var u in nonAdmins)
            await _userService.DeleteUserAsync(u.Uid);

        return Ok(ApiResponse<object>.Ok(
            new { deletedUsers = nonAdmins.Count, deletedOrphans = dbNonAdminUids.Count - firebaseNonAdminUids.Count },
            $"Đã xoá {nonAdmins.Count} user"));
    }

    /// <summary>Cấp / thu hồi quyền admin</summary>
    [HttpPatch("{uid}/admin")]
    public async Task<ActionResult<ApiResponse<object>>> SetAdmin(string uid, [FromBody] SetAdminRequest request)
    {
        try
        {
            await _userService.SetAdminClaimAsync(uid, request.IsAdmin);
            var msg = request.IsAdmin ? "Admin granted" : "Admin revoked";
            return Ok(ApiResponse<object>.Ok(null, msg));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }
}
