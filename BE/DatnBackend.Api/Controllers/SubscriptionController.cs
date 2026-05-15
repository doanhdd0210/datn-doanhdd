using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/subscriptions")]
[Produces("application/json")]
public class SubscriptionController : ControllerBase
{
    private readonly SubscriptionService _svc;
    private readonly AppDbContext _db;

    public SubscriptionController(SubscriptionService svc, AppDbContext db)
    {
        _svc = svc;
        _db = db;
    }

    private string UserId => HttpContext.Items["FirebaseUid"] as string ?? "";

    /// <summary>
    /// Public — trả về cấu hình gói VIP để app hiển thị UI.
    /// Không cần đăng nhập.
    /// </summary>
    [HttpGet("plans")]
    public async Task<ActionResult<ApiResponse<PublicPlansDto>>> GetPlans()
    {
        var settings = await _db.AppSettings
            .Where(s => s.Key.StartsWith("subscription:"))
            .ToListAsync();

        string? Get(string key) => settings.FirstOrDefault(s => s.Key == key)?.Value;

        var packageName     = Get("subscription:package_name") ?? "";
        var standardId      = Get("subscription:standard_product_id") ?? "";
        var maxId           = Get("subscription:max_product_id") ?? "";
        var standardPrice   = Get("subscription:standard_price") ?? "";
        var maxPrice        = Get("subscription:max_price") ?? "";
        var trialDaysStr    = Get("subscription:trial_days") ?? "0";
        int.TryParse(trialDaysStr, out var trialDays);

        var plans = new PublicPlansDto(
            PackageName: packageName,
            Plans: new List<PlanInfoDto>
            {
                new(
                    Id: "standard",
                    ProductId: standardId,
                    Title: "Standard",
                    Icon: "⭐",
                    DisplayPrice: standardPrice,
                    DailyAiLimit: SubscriptionService.LimitStandard,
                    IsUnlimited: false,
                    TrialDays: trialDays,
                    Features: new List<string>
                    {
                        "100 lượt AI mỗi ngày",
                        "Giải thích code lỗi",
                        "Gợi ý quiz & QA",
                    }
                ),
                new(
                    Id: "max",
                    ProductId: maxId,
                    Title: "Max",
                    Icon: "👑",
                    DisplayPrice: maxPrice,
                    DailyAiLimit: null,
                    IsUnlimited: true,
                    TrialDays: trialDays,
                    Features: new List<string>
                    {
                        "Không giới hạn AI",
                        "Giải thích code lỗi",
                        "Gợi ý quiz & QA",
                        "Ưu tiên xử lý",
                    }
                ),
            }
        );

        return Ok(ApiResponse<PublicPlansDto>.Ok(plans));
    }

    /// <summary>Lấy subscription hiện tại của user đang đăng nhập.</summary>
    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<SubscriptionDto?>>> GetMine()
    {
        var sub = await _svc.GetActiveSubscriptionAsync(UserId);
        return Ok(ApiResponse<SubscriptionDto?>.Ok(sub is null ? null : ToDto(sub)));
    }

    /// <summary>
    /// Xác minh purchase token từ Google Play và kích hoạt subscription.
    /// App gọi sau khi Google Play trả về purchaseToken.
    /// </summary>
    [HttpPost("verify")]
    public async Task<ActionResult<ApiResponse<SubscriptionDto>>> Verify([FromBody] VerifyPurchaseRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.PurchaseToken))
            return BadRequest(ApiResponse<SubscriptionDto>.Fail("purchaseToken không được để trống."));
        if (string.IsNullOrWhiteSpace(req.ProductId))
            return BadRequest(ApiResponse<SubscriptionDto>.Fail("productId không được để trống."));

        try
        {
            var sub = await _svc.VerifyAndActivateAsync(
                UserId,
                req.PurchaseToken,
                req.ProductId,
                req.OrderId ?? "",
                req.ProductType ?? "subscription");

            return Ok(ApiResponse<SubscriptionDto>.Ok(ToDto(sub), "Kích hoạt VIP thành công!"));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<SubscriptionDto>.Fail(ex.Message));
        }
    }

    /// <summary>
    /// Nhận Google Play Real-time Developer Notification qua Cloud Pub/Sub push.
    /// Cấu hình Google Play Console → Monetize → Real-time developer notifications → push endpoint này.
    /// </summary>
    [HttpPost("rtdn")]
    [AllowAnonymous]
    public async Task<IActionResult> Rtdn([FromBody] RtdnPushMessage body)
    {
        try
        {
            var json = System.Text.Encoding.UTF8.GetString(
                Convert.FromBase64String(body.Message?.Data ?? ""));
            var notification = System.Text.Json.JsonSerializer.Deserialize<RtdnPayload>(json,
                new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            var sub = notification?.SubscriptionNotification;
            if (sub is not null)
                await _svc.HandleRtdnAsync(sub.PurchaseToken, sub.SubscriptionId, sub.NotificationType);
        }
        catch (Exception ex)
        {
            // Pub/Sub cần 200 để không retry liên tục — log và trả về OK
            var logger = HttpContext.RequestServices.GetRequiredService<ILogger<SubscriptionController>>();
            logger.LogWarning(ex, "RTDN processing error");
        }
        return Ok();
    }

    private static SubscriptionDto ToDto(UserSubscription s) => new(
        s.UserId,
        s.PlanType,
        s.ProductId,
        s.PurchaseToken,
        s.IsActive,
        s.IsTrial,
        s.WillRenew,
        s.PurchasedAt,
        s.ExpiresAt,
        s.PlanType == SubscriptionService.PlanMax
            ? null
            : SubscriptionService.LimitStandard);
}

public record VerifyPurchaseRequest(
    string PurchaseToken,
    string ProductId,
    string? OrderId,
    string? ProductType); // "subscription" | "inapp"

public record SubscriptionDto(
    string UserId,
    string PlanType,
    string ProductId,
    string PurchaseToken,
    bool IsActive,
    bool IsTrial,
    bool WillRenew,
    DateTime PurchasedAt,
    DateTime? ExpiresAt,
    int? DailyAiLimit); // null = unlimited

// Pub/Sub push message shape
public record RtdnPushMessage(RtdnMessage? Message);
public record RtdnMessage(string? Data);
public record RtdnPayload(RtdnSubscriptionNotification? SubscriptionNotification);
public record RtdnSubscriptionNotification(
    int NotificationType,
    string PurchaseToken,
    string SubscriptionId);

public record PublicPlansDto(
    string PackageName,
    List<PlanInfoDto> Plans);

public record PlanInfoDto(
    string Id,
    string ProductId,
    string Title,
    string Icon,
    string DisplayPrice,
    int? DailyAiLimit,
    bool IsUnlimited,
    int TrialDays,
    List<string> Features);
