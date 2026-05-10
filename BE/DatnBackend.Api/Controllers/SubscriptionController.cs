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

        var plans = new PublicPlansDto(
            PackageName: packageName,
            Plans: new List<PlanInfoDto>
            {
                new(
                    Id: "standard",
                    ProductId: standardId,
                    Title: "Standard",
                    Icon: "⭐",
                    DailyAiLimit: SubscriptionService.LimitStandard,
                    IsUnlimited: false,
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
                    DailyAiLimit: null,
                    IsUnlimited: true,
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

    private static SubscriptionDto ToDto(UserSubscription s) => new(
        s.UserId,
        s.PlanType,
        s.ProductId,
        s.IsActive,
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
    bool IsActive,
    DateTime PurchasedAt,
    DateTime? ExpiresAt,
    int? DailyAiLimit); // null = unlimited

public record PublicPlansDto(
    string PackageName,
    List<PlanInfoDto> Plans);

public record PlanInfoDto(
    string Id,
    string ProductId,
    string Title,
    string Icon,
    int? DailyAiLimit,
    bool IsUnlimited,
    List<string> Features);
