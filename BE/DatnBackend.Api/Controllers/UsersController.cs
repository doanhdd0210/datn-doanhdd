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
            try
            {
                var firebaseUser = await FirebaseAdmin.Auth.FirebaseAuth.DefaultInstance.GetUserAsync(uid);
                profile = new UserProfile
                {
                    Uid = uid,
                    DisplayName = firebaseUser.DisplayName ?? firebaseUser.Email?.Split('@')[0] ?? "User",
                    PhotoUrl = firebaseUser.PhotoUrl,
                    Level = request.Level,
                    FcmTokens = [],
                };
                _db.UserProfiles.Add(profile);
            }
            catch
            {
                return StatusCode(503, ApiResponse<object>.Fail("Không thể tạo profile"));
            }
        }
        else
        {
            profile.Level = request.Level;
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

        // Lấy tất cả UID còn tồn tại trong Firebase Auth
        var firebaseUsers = await _userService.ListUsersAsync();
        var activeUids = firebaseUsers.Select(u => u.Uid).ToHashSet();

        // Tìm profiles không còn trong Firebase
        var orphanUids = await _db.UserProfiles
            .Where(p => !activeUids.Contains(p.Uid))
            .Select(p => p.Uid)
            .ToListAsync();

        if (orphanUids.Count == 0)
            return Ok(ApiResponse<object>.Ok(new { deleted = 0 }, "Không có dữ liệu thừa"));

        // Cascade delete cho từng orphan UID
        foreach (var uid in orphanUids)
            await _userService.DeleteUserAsync(uid, skipFirebase: true);

        return Ok(ApiResponse<object>.Ok(new { deleted = orphanUids.Count, uids = orphanUids }, $"Đã xoá {orphanUids.Count} profile thừa"));
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
