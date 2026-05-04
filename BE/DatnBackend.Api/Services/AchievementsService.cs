using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class AchievementsService
{
    private readonly AppDbContext _db;
    private readonly ILogger<AchievementsService> _logger;
    private readonly INotificationService _notifService;
    private readonly ICacheService _cache;

    public AchievementsService(AppDbContext db, ILogger<AchievementsService> logger, INotificationService notifService, ICacheService cache)
    {
        _db = db;
        _logger = logger;
        _notifService = notifService;
        _cache = cache;
    }

    // ── Admin CRUD ────────────────────────────────────────────────────────────

    public async Task<List<Achievement>> GetAllAsync()
    {
        return await _db.Achievements
            .OrderBy(a => a.ConditionType)
            .ThenBy(a => a.ConditionValue)
            .ToListAsync();
    }

    public async Task<Achievement> CreateAsync(CreateAchievementRequest req)
    {
        var achievement = new Achievement
        {
            Id = Guid.NewGuid().ToString(),
            Title = req.Title,
            Description = req.Description,
            Icon = req.Icon,
            ConditionType = req.ConditionType,
            ConditionValue = req.ConditionValue,
            XpReward = req.XpReward,
            IsActive = req.IsActive,
            CreatedAt = DateTime.UtcNow,
        };
        _db.Achievements.Add(achievement);
        await _db.SaveChangesAsync();
        return achievement;
    }

    public async Task<Achievement> UpdateAsync(string id, UpdateAchievementRequest req)
    {
        var achievement = await _db.Achievements.FindAsync(id)
            ?? throw new KeyNotFoundException($"Achievement {id} not found");

        if (req.Title != null) achievement.Title = req.Title;
        if (req.Description != null) achievement.Description = req.Description;
        if (req.Icon != null) achievement.Icon = req.Icon;
        if (req.ConditionType != null) achievement.ConditionType = req.ConditionType;
        if (req.ConditionValue.HasValue) achievement.ConditionValue = req.ConditionValue.Value;
        if (req.XpReward.HasValue) achievement.XpReward = req.XpReward.Value;
        if (req.IsActive.HasValue) achievement.IsActive = req.IsActive.Value;

        await _db.SaveChangesAsync();
        return achievement;
    }

    public async Task DeleteAsync(string id)
    {
        var achievement = await _db.Achievements.FindAsync(id)
            ?? throw new KeyNotFoundException($"Achievement {id} not found");
        _db.Achievements.Remove(achievement);
        await _db.SaveChangesAsync();
    }

    // ── User achievements ─────────────────────────────────────────────────────

    /// Trả về tất cả achievements kèm trạng thái đã unlock của user
    public async Task<List<UserAchievementDto>> GetMyAchievementsAsync(string userId)
    {
        var allAchievements = await _db.Achievements
            .Where(a => a.IsActive)
            .OrderBy(a => a.ConditionType)
            .ThenBy(a => a.ConditionValue)
            .ToListAsync();

        var unlocked = await _db.UserAchievements
            .Where(ua => ua.UserId == userId)
            .ToDictionaryAsync(ua => ua.AchievementId);

        return allAchievements.Select(a => new UserAchievementDto
        {
            Id = a.Id,
            Title = a.Title,
            Description = a.Description,
            Icon = a.Icon,
            ConditionType = a.ConditionType,
            ConditionValue = a.ConditionValue,
            XpReward = a.XpReward,
            IsUnlocked = unlocked.ContainsKey(a.Id),
            UnlockedAt = unlocked.TryGetValue(a.Id, out var ua) ? ua.UnlockedAt : null,
        }).ToList();
    }

    /// Đánh dấu đã thông báo các achievement mới (trả về danh sách chưa được thông báo)
    public async Task<List<UserAchievementDto>> ConsumeNewAchievementsAsync(string userId)
    {
        var newOnes = await _db.UserAchievements
            .Where(ua => ua.UserId == userId && !ua.IsNotified)
            .ToListAsync();

        if (newOnes.Count == 0) return [];

        var achievementIds = newOnes.Select(ua => ua.AchievementId).ToList();
        var achievements = await _db.Achievements
            .Where(a => achievementIds.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id);

        foreach (var ua in newOnes)
            ua.IsNotified = true;

        await _db.SaveChangesAsync();

        return newOnes.Select(ua => {
            achievements.TryGetValue(ua.AchievementId, out var a);
            return new UserAchievementDto
            {
                Id = ua.AchievementId,
                Title = a?.Title ?? "",
                Description = a?.Description ?? "",
                Icon = a?.Icon ?? "🏅",
                ConditionType = a?.ConditionType ?? "",
                ConditionValue = a?.ConditionValue ?? 0,
                XpReward = a?.XpReward ?? 0,
                IsUnlocked = true,
                UnlockedAt = ua.UnlockedAt,
            };
        }).ToList();
    }

    /// Check và grant achievements cho user. Gọi sau mỗi event quan trọng.
    /// Fire-and-forget safe (try/catch bên trong).
    public async Task CheckAndGrantAsync(string userId)
    {
        try
        {
            var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
            if (profile == null) return;

            var allAchievements = await _db.Achievements
                .Where(a => a.IsActive)
                .ToListAsync();

            var alreadyUnlocked = (await _db.UserAchievements
                .Where(ua => ua.UserId == userId)
                .Select(ua => ua.AchievementId)
                .ToListAsync())
                .ToHashSet();

            // Lazy-load chỉ khi cần
            bool? _hasFollowed = null;
            bool? _hasPerfectQuiz = null;

            async Task<bool> HasFollowed()
            {
                _hasFollowed ??= await _db.UserFollows.AnyAsync(f => f.FollowerId == userId);
                return _hasFollowed.Value;
            }

            async Task<bool> HasPerfectQuiz()
            {
                _hasPerfectQuiz ??= await _db.UserProgresses
                    .AnyAsync(p => p.UserId == userId && p.Score == 100);
                return _hasPerfectQuiz.Value;
            }

            var newlyUnlocked = new List<UserAchievement>();

            foreach (var achievement in allAchievements)
            {
                if (alreadyUnlocked.Contains(achievement.Id)) continue;

                bool conditionMet = achievement.ConditionType switch
                {
                    "lessonCount"  => profile.LessonsCompleted >= achievement.ConditionValue,
                    "xpRequired"   => profile.TotalXp >= achievement.ConditionValue,
                    "streakDays"   => profile.CurrentStreak >= achievement.ConditionValue,
                    "followAny"    => await HasFollowed(),
                    "perfectQuiz"  => await HasPerfectQuiz(),
                    _ => false,
                };

                if (conditionMet)
                {
                    newlyUnlocked.Add(new UserAchievement
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = userId,
                        AchievementId = achievement.Id,
                        UnlockedAt = DateTime.UtcNow,
                        IsNotified = false,
                    });

                    // Thưởng XP nếu có
                    if (achievement.XpReward > 0)
                        profile.TotalXp += achievement.XpReward;
                }
            }

            if (newlyUnlocked.Count > 0)
            {
                _db.UserAchievements.AddRange(newlyUnlocked);

                // In-app notifications cho từng thành tích mới
                foreach (var ua in newlyUnlocked)
                {
                    var ach = allAchievements.First(a => a.Id == ua.AchievementId);
                    _db.UserNotifications.Add(new UserNotification
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId = userId,
                        Type = "achievement",
                        Title = $"{ach.Icon} Thành tích mới!",
                        Body = ach.XpReward > 0
                            ? $"Bạn đã mở khóa \"{ach.Title}\" · +{ach.XpReward} XP"
                            : $"Bạn đã mở khóa \"{ach.Title}\"",
                        IsRead = false,
                        CreatedAt = DateTime.UtcNow,
                    });
                }

                await _db.SaveChangesAsync();

                // Cộng XP thành tích vào daily progress (để tính mục tiêu hôm nay)
                int totalAchievementXp = newlyUnlocked.Sum(ua =>
                    allAchievements.First(a => a.Id == ua.AchievementId).XpReward);
                if (totalAchievementXp > 0)
                {
                    var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
                    var dailyId = $"{userId}_{today}";
                    var dailyProgress = await _db.DailyProgresses.FirstOrDefaultAsync(d => d.Id == dailyId);
                    if (dailyProgress != null)
                    {
                        dailyProgress.XpEarned += totalAchievementXp;
                        await _db.SaveChangesAsync();
                    }
                }

                // Invalidate leaderboard cache vì TotalXp đã thay đổi
                await _cache.RemoveAsync($"stats:{userId}", "leaderboard:20", "leaderboard:50", "leaderboard_weekly:20", "leaderboard_weekly:50");

                // Push notification
                try
                {
                    var userProfile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
                    if (userProfile?.FcmTokens.Count > 0)
                    {
                        var achSummary = string.Join(", ", newlyUnlocked.Select(ua => {
                            var a = allAchievements.First(x => x.Id == ua.AchievementId);
                            return a.XpReward > 0 ? $"{a.Title} (+{a.XpReward} XP)" : a.Title;
                        }));
                        var totalXp = newlyUnlocked.Sum(ua =>
                            allAchievements.First(a => a.Id == ua.AchievementId).XpReward);
                        await _notifService.SendToTokensAsync(new SendNotificationRequest
                        {
                            Title = "🏆 Thành tích mới!",
                            Body = totalXp > 0
                                ? $"Bạn vừa mở khóa: {achSummary}"
                                : $"Bạn vừa mở khóa: {achSummary}",
                            Data = new Dictionary<string, string> { ["screen"] = "profile", ["type"] = "achievement" },
                        }, userProfile.FcmTokens);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to send push notification for achievement");
                }

                _logger.LogInformation(
                    "Granted {Count} achievement(s) to user {UserId}: {Ids}",
                    newlyUnlocked.Count, userId,
                    string.Join(", ", newlyUnlocked.Select(ua => ua.AchievementId)));
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "CheckAndGrantAsync failed for user {UserId}", userId);
        }
    }
}

public class UserAchievementDto
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "🏅";
    public string ConditionType { get; set; } = "";
    public int ConditionValue { get; set; }
    public int XpReward { get; set; }
    public bool IsUnlocked { get; set; }
    public DateTime? UnlockedAt { get; set; }
}
