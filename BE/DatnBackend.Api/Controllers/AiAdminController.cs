using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/admin/ai")]
[Produces("application/json")]
public class AiAdminController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly AiUsageService _usage;

    public AiAdminController(AppDbContext db, AiUsageService usage)
    {
        _db = db;
        _usage = usage;
    }

    private bool IsAdmin() => HttpContext.Items["FirebaseIsAdmin"] is true;

    /// <summary>Lấy cài đặt AI (default daily limit)</summary>
    [HttpGet("settings")]
    public async Task<ActionResult<ApiResponse<AiSettingsDto>>> GetSettings()
    {
        if (!IsAdmin()) return Forbid();

        var setting = await _db.AppSettings
            .Where(s => s.Key == "ai:default_daily_limit")
            .FirstOrDefaultAsync();

        var limit = int.TryParse(setting?.Value, out var v) ? v : 10;
        return Ok(ApiResponse<AiSettingsDto>.Ok(new AiSettingsDto(limit)));
    }

    /// <summary>Cập nhật default daily limit cho tất cả user</summary>
    [HttpPut("settings")]
    public async Task<ActionResult<ApiResponse<AiSettingsDto>>> UpdateSettings([FromBody] AiSettingsDto dto)
    {
        if (!IsAdmin()) return Forbid();
        if (dto.DefaultDailyLimit < 1)
            return BadRequest(ApiResponse<AiSettingsDto>.Fail("Giới hạn phải lớn hơn 0."));

        var setting = await _db.AppSettings.FindAsync("ai:default_daily_limit");
        if (setting is null)
        {
            _db.AppSettings.Add(new AppSetting { Key = "ai:default_daily_limit", Value = dto.DefaultDailyLimit.ToString() });
        }
        else
        {
            setting.Value = dto.DefaultDailyLimit.ToString();
        }

        await _db.SaveChangesAsync();
        return Ok(ApiResponse<AiSettingsDto>.Ok(dto));
    }

    /// <summary>Danh sách usage AI hôm nay của tất cả user</summary>
    [HttpGet("usage")]
    public async Task<ActionResult<ApiResponse<List<AiUserUsageDto>>>> GetTodayUsage()
    {
        if (!IsAdmin()) return Forbid();

        var todayUtc7 = DateOnly.FromDateTime(
            TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,
                TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh")));

        var usages = await _db.UserAiUsages
            .Where(u => u.Date == todayUtc7)
            .OrderByDescending(u => u.Count)
            .ToListAsync();

        var overrides = await _db.UserAiLimits.ToListAsync();
        var defaultSetting = await _db.AppSettings
            .Where(s => s.Key == "ai:default_daily_limit")
            .Select(s => s.Value)
            .FirstOrDefaultAsync();
        var defaultLimit = int.TryParse(defaultSetting, out var dl) ? dl : 10;

        var result = usages.Select(u =>
        {
            var limitOverride = overrides.FirstOrDefault(o => o.UserId == u.UserId);
            return new AiUserUsageDto(u.UserId, u.Count, limitOverride?.DailyLimit ?? defaultLimit);
        }).ToList();

        return Ok(ApiResponse<List<AiUserUsageDto>>.Ok(result));
    }

    /// <summary>Lấy override limit của một user cụ thể</summary>
    [HttpGet("limit/{userId}")]
    public async Task<ActionResult<ApiResponse<AiUserLimitDto>>> GetUserLimit(string userId)
    {
        if (!IsAdmin()) return Forbid();

        var userLimit = await _db.UserAiLimits.FindAsync(userId);
        var defaultSetting = await _db.AppSettings
            .Where(s => s.Key == "ai:default_daily_limit")
            .Select(s => s.Value)
            .FirstOrDefaultAsync();
        var defaultLimit = int.TryParse(defaultSetting, out var dl) ? dl : 10;

        return Ok(ApiResponse<AiUserLimitDto>.Ok(new AiUserLimitDto(
            userId,
            userLimit?.DailyLimit,
            defaultLimit)));
    }

    /// <summary>Set override limit riêng cho một user</summary>
    [HttpPut("limit/{userId}")]
    public async Task<ActionResult<ApiResponse<AiUserLimitDto>>> SetUserLimit(
        string userId, [FromBody] SetAiUserLimitRequest req)
    {
        if (!IsAdmin()) return Forbid();
        if (req.DailyLimit < 1)
            return BadRequest(ApiResponse<AiUserLimitDto>.Fail("Giới hạn phải lớn hơn 0."));

        var existing = await _db.UserAiLimits.FindAsync(userId);
        if (existing is null)
        {
            _db.UserAiLimits.Add(new UserAiLimit { UserId = userId, DailyLimit = req.DailyLimit });
        }
        else
        {
            existing.DailyLimit = req.DailyLimit;
        }

        await _db.SaveChangesAsync();

        var defaultSetting = await _db.AppSettings
            .Where(s => s.Key == "ai:default_daily_limit")
            .Select(s => s.Value)
            .FirstOrDefaultAsync();
        var defaultLimit = int.TryParse(defaultSetting, out var dl) ? dl : 10;

        return Ok(ApiResponse<AiUserLimitDto>.Ok(new AiUserLimitDto(userId, req.DailyLimit, defaultLimit)));
    }

    /// <summary>Xoá override — user về dùng default limit</summary>
    [HttpDelete("limit/{userId}")]
    public async Task<ActionResult<ApiResponse<object>>> DeleteUserLimit(string userId)
    {
        if (!IsAdmin()) return Forbid();

        var existing = await _db.UserAiLimits.FindAsync(userId);
        if (existing is not null)
        {
            _db.UserAiLimits.Remove(existing);
            await _db.SaveChangesAsync();
        }

        return Ok(ApiResponse<object>.Ok(null, "Override đã được xoá."));
    }
}

public record AiSettingsDto(int DefaultDailyLimit);
public record AiUserUsageDto(string UserId, int Used, int Limit);
public record AiUserLimitDto(string UserId, int? OverrideLimit, int DefaultLimit);
public record SetAiUserLimitRequest(int DailyLimit);
