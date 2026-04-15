using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/admins")]
[Produces("application/json")]
public class AdminController : ControllerBase
{
    private readonly IUserService _userService;

    public AdminController(IUserService userService) => _userService = userService;

    /// <summary>Danh sách tất cả admin</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<AppUser>>>> ListAdmins()
    {
        var admins = await _userService.ListAdminsAsync();
        return Ok(ApiResponse<List<AppUser>>.Ok(admins, $"{admins.Count} admins"));
    }

    /// <summary>Cấp quyền admin cho user</summary>
    [HttpPost("{uid}")]
    public async Task<ActionResult<ApiResponse<object>>> GrantAdmin(string uid)
    {
        try
        {
            await _userService.SetAdminClaimAsync(uid, true);
            return Ok(ApiResponse<object>.Ok(null, "Admin access granted"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    /// <summary>Thu hồi quyền admin</summary>
    [HttpDelete("{uid}")]
    public async Task<ActionResult<ApiResponse<object>>> RevokeAdmin(string uid)
    {
        try
        {
            await _userService.SetAdminClaimAsync(uid, false);
            return Ok(ApiResponse<object>.Ok(null, "Admin access revoked"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }
}
