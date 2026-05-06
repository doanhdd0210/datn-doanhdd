using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class FriendsService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<FriendsService> _logger;
    private readonly INotificationService _notifService;
    private readonly AchievementsService _achievements;

    public FriendsService(AppDbContext db, ICacheService cache, ILogger<FriendsService> logger, INotificationService notifService, AchievementsService achievements)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
        _notifService = notifService;
        _achievements = achievements;
    }

    public async Task<List<UserFollowDto>> GetFollowingAsync(string userId)
    {
        var follows = await _db.UserFollows
            .Where(f => f.FollowerId == userId)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();

        var ids = follows.Select(f => f.FollowingId).ToList();
        var profiles = await _db.UserProfiles
            .Where(p => ids.Contains(p.Uid))
            .ToDictionaryAsync(p => p.Uid);

        return follows.Select(f => {
            profiles.TryGetValue(f.FollowingId, out var profile);
            return new UserFollowDto
            {
                Id = f.Id,
                FollowingId = f.FollowingId,
                FollowingName = profile?.DisplayName ?? f.FollowingName,
                FollowingAvatar = profile?.PhotoUrl ?? f.FollowingAvatar,
                TotalXp = profile?.TotalXp ?? 0,
                Streak = profile?.CurrentStreak ?? 0,
            };
        }).ToList();
    }

    public async Task<List<UserFollowDto>> GetFollowersAsync(string userId)
    {
        var follows = await _db.UserFollows
            .Where(f => f.FollowingId == userId)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();

        var ids = follows.Select(f => f.FollowerId).ToList();
        var profiles = await _db.UserProfiles
            .Where(p => ids.Contains(p.Uid))
            .ToDictionaryAsync(p => p.Uid);

        return follows.Select(f => {
            profiles.TryGetValue(f.FollowerId, out var profile);
            return new UserFollowDto
            {
                Id = f.Id,
                FollowingId = f.FollowerId,
                FollowingName = profile?.DisplayName ?? "Unknown",
                FollowingAvatar = profile?.PhotoUrl ?? "",
                TotalXp = profile?.TotalXp ?? 0,
                Streak = profile?.CurrentStreak ?? 0,
            };
        }).ToList();
    }

    public async Task<UserFollow> FollowUserAsync(string followerId, FollowRequest request)
    {
        if (followerId == request.FollowingId)
            throw new InvalidOperationException("Cannot follow yourself");

        var existing = await _db.UserFollows
            .FirstOrDefaultAsync(f => f.FollowerId == followerId && f.FollowingId == request.FollowingId);

        if (existing != null) return existing;

        var follow = new UserFollow
        {
            Id = Guid.NewGuid().ToString(),
            FollowerId = followerId,
            FollowingId = request.FollowingId,
            FollowingName = request.FollowingName,
            FollowingAvatar = request.FollowingAvatar,
            CreatedAt = DateTime.UtcNow,
        };

        _db.UserFollows.Add(follow);

        // In-app notification cho người được follow
        var followerProfile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == followerId);
        var followerName = followerProfile?.DisplayName ?? "Ai đó";
        var followerAvatar = followerProfile?.PhotoUrl ?? "";

        _db.UserNotifications.Add(new UserNotification
        {
            Id = Guid.NewGuid().ToString(),
            UserId = request.FollowingId,
            Type = "follow",
            Title = "Người theo dõi mới",
            Body = $"{followerName} đã bắt đầu theo dõi bạn!",
            ActorId = followerId,
            ActorName = followerName,
            ActorAvatar = followerAvatar,
            RefId = followerId,
            IsRead = false,
            CreatedAt = DateTime.UtcNow,
        });

        await _db.SaveChangesAsync();

        // Check achievements cho người follow (social_1)
        await _achievements.CheckAndGrantAsync(followerId);

        // Push notification qua FCM nếu có token
        try
        {
            var targetProfile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == request.FollowingId);
            if (targetProfile?.FcmTokens.Count > 0)
            {
                await _notifService.SendToTokensAsync(new SendNotificationRequest
                {
                    Title = "Người theo dõi mới 👤",
                    Body = $"{followerName} đã bắt đầu theo dõi bạn!",
                    Data = new Dictionary<string, string> { ["screen"] = "friends", ["type"] = "follow" },
                }, targetProfile.FcmTokens);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to send follow push notification");
        }

        return follow;
    }

    public async Task UnfollowUserAsync(string followerId, string followingId)
    {
        var follow = await _db.UserFollows
            .FirstOrDefaultAsync(f => f.FollowerId == followerId && f.FollowingId == followingId)
            ?? throw new KeyNotFoundException("Follow relationship not found");

        _db.UserFollows.Remove(follow);
        await _db.SaveChangesAsync();
    }

    public async Task<LeaderboardEntry?> GetPublicProfileAsync(string userId)
    {
        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
        if (profile == null) return null;

        var globalRank = await _db.UserProfiles.CountAsync(p => p.TotalXp > profile.TotalXp) + 1;
        return new LeaderboardEntry
        {
            Rank = globalRank,
            UserId = profile.Uid,
            DisplayName = profile.DisplayName,
            PhotoUrl = profile.PhotoUrl,
            TotalXp = profile.TotalXp,
            LessonsCompleted = profile.LessonsCompleted,
            CurrentStreak = profile.CurrentStreak,
        };
    }

    public async Task<List<LeaderboardEntry>> GetLeaderboardAsync(int limit = 20)
    {
        var cacheKey = $"leaderboard:{limit}";
        var cached = await _cache.GetAsync<List<LeaderboardEntry>>(cacheKey);
        if (cached != null) return cached;

        // Only users that still exist in UserProfiles (inner join = no deleted users)
        var profiles = await _db.UserProfiles
            .Where(p => !p.IsAdmin)
            .OrderByDescending(p => p.TotalXp)
            .Take(limit)
            .ToListAsync();

        var entries = profiles.Select((p, i) => new LeaderboardEntry
        {
            Rank = i + 1,
            UserId = p.Uid,
            DisplayName = p.DisplayName,
            PhotoUrl = p.PhotoUrl,
            TotalXp = p.TotalXp,
            LessonsCompleted = p.LessonsCompleted,
            CurrentStreak = p.CurrentStreak,
        }).ToList();

        await _cache.SetAsync(cacheKey, entries, TimeSpan.FromMinutes(1));
        return entries;
    }

    public async Task<List<LeaderboardEntry>> GetWeeklyLeaderboardAsync(int limit = 20)
    {
        var cacheKey = $"leaderboard_weekly:{limit}";
        var cached = await _cache.GetAsync<List<LeaderboardEntry>>(cacheKey);
        if (cached != null) return cached;

        var since = DateTime.UtcNow.AddDays(-7).ToString("yyyy-MM-dd");

        var weeklyXpList = await _db.DailyProgresses
            .Where(d => string.Compare(d.Date, since) >= 0)
            .Where(d => _db.UserProfiles.Any(p => p.Uid == d.UserId && !p.IsAdmin))
            .GroupBy(d => d.UserId)
            .Select(g => new { UserId = g.Key, Xp = g.Sum(d => d.XpEarned) })
            .ToListAsync();

        var weeklyBonusList = await _db.DailyGoalBonusClaims
            .Where(c => string.Compare(c.Date, since) >= 0)
            .Where(c => _db.UserProfiles.Any(p => p.Uid == c.UserId && !p.IsAdmin))
            .GroupBy(c => c.UserId)
            .Select(g => new { UserId = g.Key, Bonus = g.Sum(c => c.BonusXp) })
            .ToListAsync();

        var sinceDate = DateTime.UtcNow.AddDays(-7);
        var weeklyAchievementList = await _db.UserAchievements
            .Where(ua => ua.UnlockedAt >= sinceDate)
            .Where(ua => _db.UserProfiles.Any(p => p.Uid == ua.UserId && !p.IsAdmin))
            .Join(_db.Achievements, ua => ua.AchievementId, a => a.Id, (ua, a) => new { ua.UserId, a.XpReward })
            .GroupBy(x => x.UserId)
            .Select(g => new { UserId = g.Key, AchievementXp = g.Sum(x => x.XpReward) })
            .ToListAsync();

        var bonusDict = weeklyBonusList.ToDictionary(x => x.UserId, x => x.Bonus);
        var achievementDict = weeklyAchievementList.ToDictionary(x => x.UserId, x => x.AchievementXp);
        var xpDict = weeklyXpList.ToDictionary(x => x.UserId, x => x.Xp);

        var allProfiles = await _db.UserProfiles
            .Where(p => !p.IsAdmin)
            .ToListAsync();

        var entries = allProfiles
            .Select(p => new
            {
                Profile = p,
                WeeklyXp = (xpDict.TryGetValue(p.Uid, out var xp) ? xp : 0)
                         + (bonusDict.TryGetValue(p.Uid, out var b) ? b : 0)
                         + (achievementDict.TryGetValue(p.Uid, out var a) ? a : 0),
            })
            .OrderByDescending(x => x.WeeklyXp)
            .Take(limit)
            .Select((x, i) => new LeaderboardEntry
            {
                Rank = i + 1,
                UserId = x.Profile.Uid,
                DisplayName = x.Profile.DisplayName,
                PhotoUrl = x.Profile.PhotoUrl,
                TotalXp = x.WeeklyXp,
                LessonsCompleted = x.Profile.LessonsCompleted,
                CurrentStreak = x.Profile.CurrentStreak,
            })
            .ToList();

        await _cache.SetAsync(cacheKey, entries, TimeSpan.FromMinutes(5));
        return entries;
    }
}

public class LeaderboardEntry
{
    public int Rank { get; set; }
    public string UserId { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string? PhotoUrl { get; set; }
    public int TotalXp { get; set; }
    public int LessonsCompleted { get; set; }
    public int CurrentStreak { get; set; }
}

public class UserFollowDto
{
    public string Id { get; set; } = "";
    public string FollowingId { get; set; } = "";
    public string FollowingName { get; set; } = "";
    public string FollowingAvatar { get; set; } = "";
    public int TotalXp { get; set; }
    public int Streak { get; set; }
}
