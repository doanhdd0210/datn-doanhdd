using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/achievements")]
[Produces("application/json")]
public class AchievementsController : ControllerBase
{
    private readonly AchievementsService _service;

    public AchievementsController(AchievementsService service)
    {
        _service = service;
    }

    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;

    /// <summary>List all achievements (definitions)</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<Achievement>>>> GetAll()
    {
        var items = await _service.GetAllAsync();
        return Ok(ApiResponse<List<Achievement>>.Ok(items));
    }

    /// <summary>Lấy achievements của user hiện tại kèm trạng thái unlock</summary>
    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<List<UserAchievementDto>>>> GetMine()
    {
        var uid = HttpContext.Items["FirebaseUid"] as string;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        var items = await _service.GetMyAchievementsAsync(uid);
        return Ok(ApiResponse<List<UserAchievementDto>>.Ok(items));
    }

    /// <summary>Lấy và đánh dấu đã đọc các achievement mới (chưa được thông báo)</summary>
    [HttpPost("me/consume-new")]
    public async Task<ActionResult<ApiResponse<List<UserAchievementDto>>>> ConsumeNew()
    {
        var uid = HttpContext.Items["FirebaseUid"] as string;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        var newOnes = await _service.ConsumeNewAchievementsAsync(uid);
        return Ok(ApiResponse<List<UserAchievementDto>>.Ok(newOnes));
    }

    /// <summary>Trigger achievement check for current user (sync historical data)</summary>
    [HttpPost("me/sync")]
    public async Task<ActionResult<ApiResponse<object>>> Sync()
    {
        var uid = HttpContext.Items["FirebaseUid"] as string;
        if (string.IsNullOrEmpty(uid))
            return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        await _service.CheckAndGrantAsync(uid);
        return Ok(ApiResponse<object>.Ok(null, "Synced"));
    }

    /// <summary>Create a new achievement (admin only)</summary>
    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreateAchievementRequest req)
    {
        if (!IsAdmin) return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));
        var item = await _service.CreateAsync(req);
        return Ok(ApiResponse<Achievement>.Ok(item, "Achievement created"));
    }

    /// <summary>Update an achievement (admin only)</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult> Update(string id, [FromBody] UpdateAchievementRequest req)
    {
        if (!IsAdmin) return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));
        try
        {
            var item = await _service.UpdateAsync(id, req);
            return Ok(ApiResponse<Achievement>.Ok(item, "Achievement updated"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<Achievement>.Fail(ex.Message));
        }
    }

    /// <summary>Delete an achievement (admin only)</summary>
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(string id)
    {
        if (!IsAdmin) return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));
        try
        {
            await _service.DeleteAsync(id);
            return Ok(ApiResponse<object>.Ok(null, "Achievement deleted"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<object>.Fail(ex.Message));
        }
    }
}
