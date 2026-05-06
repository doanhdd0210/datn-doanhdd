using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/settings")]
[Produces("application/json")]
public class SettingsController : ControllerBase
{
    private readonly SettingsService _settingsService;

    public SettingsController(SettingsService settingsService)
    {
        _settingsService = settingsService;
    }

    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;

    /// <summary>Get daily goal bonus config</summary>
    [HttpGet("daily-goal-bonuses")]
    public async Task<ActionResult<ApiResponse<List<DailyGoalBonusConfig>>>> GetDailyGoalBonuses()
    {
        var bonuses = await _settingsService.GetDailyGoalBonusesAsync();
        var result = bonuses
            .Select(kv => new DailyGoalBonusConfig { GoalXp = kv.Key, BonusXp = kv.Value })
            .OrderBy(x => x.GoalXp)
            .ToList();
        return Ok(ApiResponse<List<DailyGoalBonusConfig>>.Ok(result));
    }

    /// <summary>Update daily goal bonus config (admin only)</summary>
    [HttpPut("daily-goal-bonuses")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateDailyGoalBonuses([FromBody] List<DailyGoalBonusConfig> configs)
    {
        if (!IsAdmin) return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));

        foreach (var cfg in configs)
        {
            if (cfg.GoalXp <= 0 || cfg.BonusXp < 0)
                return BadRequest(ApiResponse<object>.Fail("Invalid goal or bonus value"));
        }

        await _settingsService.ReplaceDailyGoalBonusesAsync(configs.Select(c => (c.GoalXp, c.BonusXp)).ToList());

        return Ok(ApiResponse<object>.Ok(null, "Settings updated"));
    }
}

public class DailyGoalBonusConfig
{
    public int GoalXp { get; set; }
    public int BonusXp { get; set; }
}
