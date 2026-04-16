using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class FriendsService
{
    private readonly FirestoreDb _db;
    private readonly ILogger<FriendsService> _logger;
    private const string Collection = "userFollows";

    public FriendsService(FirestoreDb db, ILogger<FriendsService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<UserFollow>> GetFollowingAsync(string userId)
    {
        var snapshot = await _db.Collection(Collection)
            .WhereEqualTo("followerId", userId)
            .OrderByDescending("createdAt")
            .GetSnapshotAsync();

        return snapshot.Documents.Select(MapFollow).ToList();
    }

    public async Task<List<UserFollow>> GetFollowersAsync(string userId)
    {
        var snapshot = await _db.Collection(Collection)
            .WhereEqualTo("followingId", userId)
            .OrderByDescending("createdAt")
            .GetSnapshotAsync();

        return snapshot.Documents.Select(MapFollow).ToList();
    }

    public async Task<UserFollow> FollowUserAsync(string followerId, FollowRequest request)
    {
        if (followerId == request.FollowingId)
            throw new InvalidOperationException("Cannot follow yourself");

        // Check if already following
        var existing = await _db.Collection(Collection)
            .WhereEqualTo("followerId", followerId)
            .WhereEqualTo("followingId", request.FollowingId)
            .Limit(1)
            .GetSnapshotAsync();

        if (existing.Documents.Count > 0)
            return MapFollow(existing.Documents[0]);

        var docRef = _db.Collection(Collection).Document();
        var now = DateTime.UtcNow;

        await docRef.SetAsync(new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["followerId"] = followerId,
            ["followingId"] = request.FollowingId,
            ["followingName"] = request.FollowingName,
            ["followingAvatar"] = request.FollowingAvatar,
            ["createdAt"] = Timestamp.FromDateTime(now),
        });

        return new UserFollow
        {
            Id = docRef.Id,
            FollowerId = followerId,
            FollowingId = request.FollowingId,
            FollowingName = request.FollowingName,
            FollowingAvatar = request.FollowingAvatar,
            CreatedAt = now,
        };
    }

    public async Task UnfollowUserAsync(string followerId, string followingId)
    {
        var snapshot = await _db.Collection(Collection)
            .WhereEqualTo("followerId", followerId)
            .WhereEqualTo("followingId", followingId)
            .Limit(1)
            .GetSnapshotAsync();

        if (snapshot.Documents.Count == 0)
            throw new KeyNotFoundException($"Follow relationship not found");

        await snapshot.Documents[0].Reference.DeleteAsync();
    }

    public async Task<List<LeaderboardEntry>> GetLeaderboardAsync(int limit = 20)
    {
        var snapshot = await _db.Collection("users")
            .OrderByDescending("totalXp")
            .Limit(limit)
            .GetSnapshotAsync();

        return snapshot.Documents
            .Select((doc, index) => new LeaderboardEntry
            {
                Rank = index + 1,
                UserId = doc.Id,
                DisplayName = doc.ContainsField("displayName") ? doc.GetValue<string>("displayName") : "",
                PhotoUrl = doc.ContainsField("photoUrl") ? doc.GetValue<string>("photoUrl") : null,
                TotalXp = doc.ContainsField("totalXp") ? doc.GetValue<int>("totalXp") : 0,
                LessonsCompleted = doc.ContainsField("lessonsCompleted") ? doc.GetValue<int>("lessonsCompleted") : 0,
                CurrentStreak = doc.ContainsField("currentStreak") ? doc.GetValue<int>("currentStreak") : 0,
            })
            .ToList();
    }

    private static UserFollow MapFollow(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        FollowerId = doc.ContainsField("followerId") ? doc.GetValue<string>("followerId") : "",
        FollowingId = doc.ContainsField("followingId") ? doc.GetValue<string>("followingId") : "",
        FollowingName = doc.ContainsField("followingName") ? doc.GetValue<string>("followingName") : "",
        FollowingAvatar = doc.ContainsField("followingAvatar") ? doc.GetValue<string>("followingAvatar") : "",
        CreatedAt = doc.ContainsField("createdAt")
            ? doc.GetValue<Timestamp>("createdAt").ToDateTime()
            : DateTime.UtcNow,
    };
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
