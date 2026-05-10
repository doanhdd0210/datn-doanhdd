using Google.Apis.AndroidPublisher.v3;
using Google.Apis.AndroidPublisher.v3.Data;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Services;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class SubscriptionService
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _config;
    private readonly ILogger<SubscriptionService> _logger;

    // Plan types
    public const string PlanStandard = "standard";
    public const string PlanMax = "max";

    // AI limits per plan
    public const int LimitStandard = 100;
    public const int LimitMax = int.MaxValue; // unlimited

    public SubscriptionService(AppDbContext db, IConfiguration config, ILogger<SubscriptionService> logger)
    {
        _db = db;
        _config = config;
        _logger = logger;
    }

    /// <summary>
    /// Lấy subscription hiện tại của user (null nếu không có hoặc đã hết hạn).
    /// </summary>
    public async Task<UserSubscription?> GetActiveSubscriptionAsync(string userId)
    {
        var sub = await _db.UserSubscriptions
            .Where(s => s.UserId == userId && s.IsActive)
            .FirstOrDefaultAsync();

        if (sub is null) return null;

        // Kiểm tra hết hạn (nếu có ExpiresAt)
        if (sub.ExpiresAt.HasValue && sub.ExpiresAt.Value < DateTime.UtcNow)
        {
            sub.IsActive = false;
            await _db.SaveChangesAsync();
            return null;
        }

        return sub;
    }

    /// <summary>
    /// AI limit dựa trên subscription. Trả null nếu không có subscription (dùng default limit).
    /// </summary>
    public async Task<int?> GetAiLimitFromSubscriptionAsync(string userId)
    {
        var sub = await GetActiveSubscriptionAsync(userId);
        if (sub is null) return null;

        return sub.PlanType switch
        {
            PlanMax => LimitMax,
            PlanStandard => LimitStandard,
            _ => null
        };
    }

    /// <summary>
    /// Xác minh purchase token với Google Play và lưu subscription.
    /// productType: "subscription" hoặc "inapp"
    /// </summary>
    public async Task<UserSubscription> VerifyAndActivateAsync(
        string userId,
        string purchaseToken,
        string productId,
        string orderId,
        string productType = "subscription")
    {
        var packageName = await GetSettingAsync("subscription:package_name")
            ?? throw new InvalidOperationException("Chưa cấu hình package_name. Vào Admin > Gói VIP để cài đặt.");

        var planType = await ResolvePlanTypeAsync(productId)
            ?? throw new InvalidOperationException($"Product ID '{productId}' không hợp lệ. Kiểm tra cấu hình gói VIP trong Admin.");

        DateTime? expiresAt = null;
        bool isTrial = false;

        // Skip Google Play API verification if not configured (dev/test mode)
        var skipVerify = _config["Subscription:SkipPlayVerify"] == "true";

        if (!skipVerify)
        try
        {
            var credential = await GetGoogleCredentialAsync();
            var publisher = new AndroidPublisherService(new BaseClientService.Initializer
            {
                HttpClientInitializer = credential,
                ApplicationName = "JavaUp",
            });

            if (productType == "subscription")
            {
                var result = await publisher.Purchases.Subscriptions
                    .Get(packageName, productId, purchaseToken)
                    .ExecuteAsync();

                // paymentState: 0=pending, 1=received, 2=free trial, 3=pending deferred upgrade
                if (result.PaymentState != 1 && result.PaymentState != 2)
                    throw new InvalidOperationException("Giao dịch chưa được thanh toán.");

                isTrial = result.PaymentState == 2;

                if (result.ExpiryTimeMillis.HasValue)
                    expiresAt = DateTimeOffset.FromUnixTimeMilliseconds(result.ExpiryTimeMillis.Value).UtcDateTime;
            }
            else
            {
                var result = await publisher.Purchases.Products
                    .Get(packageName, productId, purchaseToken)
                    .ExecuteAsync();

                // purchaseState: 0 = purchased, 1 = cancelled, 2 = pending
                if (result.PurchaseState != 0)
                    throw new InvalidOperationException("Giao dịch không hợp lệ hoặc đã bị huỷ.");
            }
        }
        catch (Google.GoogleApiException ex)
        {
            _logger.LogWarning(ex, "Google Play verify failed: {msg}", ex.Message);
            throw new InvalidOperationException($"Không thể xác minh giao dịch: {ex.Message}");
        }

        // Lưu hoặc cập nhật subscription
        var existing = await _db.UserSubscriptions.FindAsync(userId);
        if (existing is null)
        {
            var sub = new UserSubscription
            {
                UserId = userId,
                PlanType = planType,
                ProductId = productId,
                PurchaseToken = purchaseToken,
                OrderId = orderId,
                IsActive = true,
                IsTrial = isTrial,
                PurchasedAt = DateTime.UtcNow,
                ExpiresAt = expiresAt,
                UpdatedAt = DateTime.UtcNow,
            };
            _db.UserSubscriptions.Add(sub);
            await _db.SaveChangesAsync();
            return sub;
        }
        else
        {
            existing.PlanType = planType;
            existing.ProductId = productId;
            existing.PurchaseToken = purchaseToken;
            existing.OrderId = orderId;
            existing.IsActive = true;
            existing.IsTrial = isTrial;
            existing.ExpiresAt = expiresAt;
            existing.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
            return existing;
        }
    }

    /// <summary>Resolve productId → planType dựa trên AppSettings.</summary>
    private async Task<string?> ResolvePlanTypeAsync(string productId)
    {
        var standardId = await GetSettingAsync("subscription:standard_product_id");
        var maxId = await GetSettingAsync("subscription:max_product_id");

        if (productId == maxId) return PlanMax;
        if (productId == standardId) return PlanStandard;
        return null;
    }

    private async Task<string?> GetSettingAsync(string key) =>
        await _db.AppSettings
            .Where(s => s.Key == key)
            .Select(s => s.Value)
            .FirstOrDefaultAsync();

    private async Task<GoogleCredential> GetGoogleCredentialAsync()
    {
        var serviceAccountJson = Environment.GetEnvironmentVariable("FIREBASE_SERVICE_ACCOUNT_JSON");
        GoogleCredential raw;
        if (!string.IsNullOrEmpty(serviceAccountJson))
            raw = GoogleCredential.FromJson(serviceAccountJson);
        else
        {
            var path = _config["Firebase:ServiceAccountPath"] ?? "firebase-service-account.json";
            raw = GoogleCredential.FromFile(path);
        }

        return raw.CreateScoped("https://www.googleapis.com/auth/androidpublisher");
    }

    /// <summary>Admin: lấy danh sách tất cả subscription.</summary>
    public async Task<List<UserSubscription>> GetAllSubscriptionsAsync() =>
        await _db.UserSubscriptions.OrderByDescending(s => s.PurchasedAt).ToListAsync();

    /// <summary>Admin: huỷ subscription thủ công.</summary>
    public async Task RevokeAsync(string userId)
    {
        var sub = await _db.UserSubscriptions.FindAsync(userId);
        if (sub is not null)
        {
            sub.IsActive = false;
            sub.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }
    }
}
