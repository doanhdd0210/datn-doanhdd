using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/users")]
[Produces("application/json")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;

    public UsersController(IUserService userService) => _userService = userService;

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
