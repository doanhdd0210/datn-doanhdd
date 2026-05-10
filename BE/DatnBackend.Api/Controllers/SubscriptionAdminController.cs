using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/admin/subscriptions")]
[Produces("application/json")]
public class SubscriptionAdminController : ControllerBase
{
    private readonly SubscriptionService _svc;
    private readonly AppDbContext _db;

    public SubscriptionAdminController(SubscriptionService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    private bool IsAdmin() => HttpContext.Items["FirebaseIsAdmin"] is true;

    /// <summary>Danh sách tất cả subscription (admin).</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<AdminSubscriptionDto>>>> GetAll()
    {
        if (!IsAdmin()) return Forbid();

        var subs = await _svc.GetAllSubscriptionsAsync();
        return Ok(ApiResponse<List<AdminSubscriptionDto>>.Ok(
            subs.Select(s => new AdminSubscriptionDto(
                s.UserId, s.PlanType, s.ProductId, s.OrderId,
                s.IsActive, s.PurchasedAt, s.ExpiresAt, s.Platform))
            .ToList()));
    }

    /// <summary>Lấy cấu hình gói VIP (product IDs, package name, prices).</summary>
    [HttpGet("plans")]
    public async Task<ActionResult<ApiResponse<SubscriptionPlansConfig>>> GetPlans()
    {
        if (!IsAdmin()) return Forbid();

        var settings = await _db.AppSettings
            .Where(s => s.Key.StartsWith("subscription:"))
            .ToListAsync();

        string? Get(string key) => settings.FirstOrDefault(s => s.Key == key)?.Value;

        return Ok(ApiResponse<SubscriptionPlansConfig>.Ok(new SubscriptionPlansConfig(
            Get("subscription:package_name") ?? "",
            Get("subscription:standard_product_id") ?? "",
            Get("subscription:max_product_id") ?? "",
            Get("subscription:standard_price") ?? "",
            Get("subscription:max_price") ?? "",
            SubscriptionService.LimitStandard)));
    }

    /// <summary>Cập nhật cấu hình gói VIP.</summary>
    [HttpPut("plans")]
    public async Task<ActionResult<ApiResponse<SubscriptionPlansConfig>>> UpdatePlans(
        [FromBody] SubscriptionPlansConfig config)
    {
        if (!IsAdmin()) return Forbid();

        await UpsertSetting("subscription:package_name", config.PackageName);
        await UpsertSetting("subscription:standard_product_id", config.StandardProductId);
        await UpsertSetting("subscription:max_product_id", config.MaxProductId);
        await UpsertSetting("subscription:standard_price", config.StandardPrice);
        await UpsertSetting("subscription:max_price", config.MaxPrice);
        await _db.SaveChangesAsync();

        return Ok(ApiResponse<SubscriptionPlansConfig>.Ok(config, "Đã lưu cấu hình gói VIP."));
    }

    /// <summary>Huỷ subscription của một user thủ công.</summary>
    [HttpDelete("{userId}")]
    public async Task<ActionResult<ApiResponse<object>>> Revoke(string userId)
    {
        if (!IsAdmin()) return Forbid();
        await _svc.RevokeAsync(userId);
        return Ok(ApiResponse<object>.Ok(null, "Đã huỷ subscription."));
    }

    private async Task UpsertSetting(string key, string value)
    {
        var existing = await _db.AppSettings.FindAsync(key);
        if (existing is null)
            _db.AppSettings.Add(new AppSetting { Key = key, Value = value });
        else
            existing.Value = value;
    }
}

public record AdminSubscriptionDto(
    string UserId,
    string PlanType,
    string ProductId,
    string OrderId,
    bool IsActive,
    DateTime PurchasedAt,
    DateTime? ExpiresAt,
    string Platform);

public record SubscriptionPlansConfig(
    string PackageName,
    string StandardProductId,
    string MaxProductId,
    string StandardPrice,
    string MaxPrice,
    int StandardAiLimit);
