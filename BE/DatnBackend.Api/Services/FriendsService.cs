using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class FriendsService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<FriendsService> _logger;

    public FriendsService(AppDbContext db, ICacheService cache, ILogger<FriendsService> logger)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
    }

    public async Task<List<UserFollow>> GetFollowingAsync(string userId)
    {
        return await _db.UserFollows
            .Where(f => f.FollowerId == userId)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<UserFollow>> GetFollowersAsync(string userId)
    {
        return await _db.UserFollows
            .Where(f => f.FollowingId == userId)
            .OrderByDescending(f => f.CreatedAt)
            .ToListAsync();
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
        await _db.SaveChangesAsync();
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

    public async Task<List<LeaderboardEntry>> GetLeaderboardAsync(int limit = 20)
    {
        var cacheKey = $"leaderboard:{limit}";
        var cached = await _cache.GetAsync<List<LeaderboardEntry>>(cacheKey);
        if (cached != null) return cached;

        var profiles = await _db.UserProfiles
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
