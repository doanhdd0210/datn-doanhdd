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
        _ = _achievements.CheckAndGrantAsync(followerId);

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

        // Chỉ lấy DailyProgress của user còn tồn tại trong UserProfiles (loại tk đã xoá)
        var weeklyXp = await _db.DailyProgresses
            .Where(d => string.Compare(d.Date, since) >= 0)
            .Where(d => _db.UserProfiles.Any(p => p.Uid == d.UserId && !p.IsAdmin))
            .GroupBy(d => d.UserId)
            .Select(g => new { UserId = g.Key, WeeklyXp = g.Sum(d => d.XpEarned) })
            .OrderByDescending(x => x.WeeklyXp)
            .Take(limit)
            .ToListAsync();

        if (weeklyXp.Count == 0) return [];

        var userIds = weeklyXp.Select(x => x.UserId).ToList();
        var profiles = await _db.UserProfiles
            .Where(p => userIds.Contains(p.Uid))
            .ToDictionaryAsync(p => p.Uid);

        var entries = weeklyXp
            .Select((x, i) => new LeaderboardEntry
            {
                Rank = i + 1,
                UserId = x.UserId,
                DisplayName = profiles[x.UserId].DisplayName,
                PhotoUrl = profiles[x.UserId].PhotoUrl,
                TotalXp = x.WeeklyXp,
                LessonsCompleted = profiles[x.UserId].LessonsCompleted,
                CurrentStreak = profiles[x.UserId].CurrentStreak,
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
