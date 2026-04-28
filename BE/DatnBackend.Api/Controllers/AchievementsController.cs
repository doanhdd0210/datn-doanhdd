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

    /// <summary>List all achievements</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<Achievement>>>> GetAll()
    {
        var items = await _service.GetAllAsync();
        return Ok(ApiResponse<List<Achievement>>.Ok(items));
    }

    /// <summary>Create a new achievement (admin only)</summary>
    [HttpPost]
    public async Task<ActionResult<ApiResponse<Achievement>>> Create([FromBody] CreateAchievementRequest req)
    {
        if (!IsAdmin) return Forbid();
        var item = await _service.CreateAsync(req);
        return Ok(ApiResponse<Achievement>.Ok(item, "Achievement created"));
    }

    /// <summary>Update an achievement (admin only)</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<Achievement>>> Update(string id, [FromBody] UpdateAchievementRequest req)
    {
        if (!IsAdmin) return Forbid();
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
        if (!IsAdmin) return Forbid();
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
