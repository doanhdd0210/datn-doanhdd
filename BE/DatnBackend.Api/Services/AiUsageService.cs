using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class AiUsageService
{
    private SubscriptionService? _subscriptionService;
    private static readonly TimeZoneInfo VietnamTz =
        TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh");

    private readonly AppDbContext _db;

    public AiUsageService(AppDbContext db, SubscriptionService subscriptionService)
    {
        _db = db;
        _subscriptionService = subscriptionService;
    }

    private static DateOnly TodayVietnam() =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, VietnamTz));

    private static DateTime NextResetUtc()
    {
        var now = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, VietnamTz);
        var midnight = now.Date.AddDays(1); // 00:00 ngày mai theo giờ VN
        return TimeZoneInfo.ConvertTimeToUtc(midnight, VietnamTz);
    }

    public async Task<int> GetLimitAsync(string userId)
    {
        // 1. Subscription plan takes highest priority
        if (_subscriptionService is not null)
        {
            var subLimit = await _subscriptionService.GetAiLimitFromSubscriptionAsync(userId);
            if (subLimit.HasValue)
                return subLimit.Value;
        }

        // 2. Per-user admin override
        var userOverride = await _db.UserAiLimits
            .Where(l => l.UserId == userId)
            .Select(l => (int?)l.DailyLimit)
            .FirstOrDefaultAsync();

        if (userOverride.HasValue)
            return userOverride.Value;

        // 3. Global default
        var setting = await _db.AppSettings
            .Where(s => s.Key == "ai:default_daily_limit")
            .Select(s => s.Value)
            .FirstOrDefaultAsync();

        return int.TryParse(setting, out var parsed) ? parsed : 10;
    }

    public async Task<int> GetTodayCountAsync(string userId)
    {
        var today = TodayVietnam();
        return await _db.UserAiUsages
            .Where(u => u.UserId == userId && u.Date == today)
            .Select(u => u.Count)
            .FirstOrDefaultAsync();
    }

    /// <summary>
    /// Kiểm tra limit và tăng count nếu còn lượt.
    /// Ném AiLimitExceededException nếu hết lượt.
    /// </summary>
    public async Task CheckAndIncrementAsync(string userId)
    {
        var today = TodayVietnam();
        var limit = await GetLimitAsync(userId);

        var usage = await _db.UserAiUsages
            .FirstOrDefaultAsync(u => u.UserId == userId && u.Date == today);

        var currentCount = usage?.Count ?? 0;

        if (currentCount >= limit)
        {
            var resetAt = NextResetUtc();
            var resetVn = TimeZoneInfo.ConvertTimeFromUtc(resetAt, VietnamTz);
            throw new AiLimitExceededException(
                $"Bạn đã đạt giới hạn {limit} lượt AI trong ngày. " +
                $"Giới hạn sẽ reset lúc 00:00 ngày {resetVn:dd/MM/yyyy} (giờ Việt Nam).",
                limit, resetAt);
        }

        if (usage is null)
        {
            _db.UserAiUsages.Add(new UserAiUsage
            {
                UserId = userId,
                Date = today,
                Count = 1,
            });
        }
        else
        {
            usage.Count++;
        }

        await _db.SaveChangesAsync();
    }

    public async Task<AiUsageInfo> GetUsageInfoAsync(string userId)
    {
        var used = await GetTodayCountAsync(userId);
        var limit = await GetLimitAsync(userId);
        var resetAt = NextResetUtc();

        string? planType = null;
        if (_subscriptionService is not null)
        {
            var sub = await _subscriptionService.GetActiveSubscriptionAsync(userId);
            planType = sub?.PlanType;
        }

        return new AiUsageInfo(used, limit, resetAt, planType);
    }
}

public record AiUsageInfo(int Used, int Limit, DateTime ResetAt, string? PlanType = null);

public class AiLimitExceededException : Exception
{
    public int Limit { get; }
    public DateTime ResetAt { get; }

    public AiLimitExceededException(string message, int limit, DateTime resetAt)
        : base(message)
    {
        Limit = limit;
        ResetAt = resetAt;
    }
}
