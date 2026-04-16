using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class QaService
{
    private readonly FirestoreDb _db;
    private readonly ILogger<QaService> _logger;

    public QaService(FirestoreDb db, ILogger<QaService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<QaPost>> ListPostsAsync(string? lessonId = null, int page = 1, int pageSize = 20)
    {
        Query query = _db.Collection("qaPosts");
        if (lessonId != null)
            query = query.WhereEqualTo("lessonId", lessonId);

        query = query.OrderByDescending("createdAt")
                     .Offset((page - 1) * pageSize)
                     .Limit(pageSize);

        var snapshot = await query.GetSnapshotAsync();
        return snapshot.Documents.Select(MapPost).ToList();
    }

    public async Task<QaPost?> GetPostAsync(string id)
    {
        var doc = await _db.Collection("qaPosts").Document(id).GetSnapshotAsync();
        return doc.Exists ? MapPost(doc) : null;
    }

    public async Task<QaPost> CreatePostAsync(string userId, string userName, string userAvatar, CreateQaPostRequest request)
    {
        var docRef = _db.Collection("qaPosts").Document();
        var now = DateTime.UtcNow;

        var data = new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["userId"] = userId,
            ["userName"] = userName,
            ["userAvatar"] = userAvatar,
            ["title"] = request.Title,
            ["content"] = request.Content,
            ["tags"] = request.Tags,
            ["answerCount"] = 0,
            ["upvoteCount"] = 0,
            ["isSolved"] = false,
            ["createdAt"] = Timestamp.FromDateTime(now),
        };

        if (request.LessonId != null)
            data["lessonId"] = request.LessonId;

        await docRef.SetAsync(data);

        return new QaPost
        {
            Id = docRef.Id,
            UserId = userId,
            UserName = userName,
            UserAvatar = userAvatar,
            Title = request.Title,
            Content = request.Content,
            LessonId = request.LessonId,
            Tags = request.Tags,
            AnswerCount = 0,
            UpvoteCount = 0,
            IsSolved = false,
            CreatedAt = now,
        };
    }

    public async Task<List<QaAnswer>> GetAnswersAsync(string postId)
    {
        var snapshot = await _db.Collection("qaAnswers")
            .WhereEqualTo("postId", postId)
            .OrderBy("createdAt")
            .GetSnapshotAsync();

        // Sort accepted answers first, then by date (avoids composite index requirement)
        return snapshot.Documents
            .Select(MapAnswer)
            .OrderByDescending(a => a.IsAccepted)
            .ThenBy(a => a.CreatedAt)
            .ToList();
    }

    public async Task<QaAnswer> CreateAnswerAsync(string userId, string userName, string userAvatar, CreateQaAnswerRequest request)
    {
        var docRef = _db.Collection("qaAnswers").Document();
        var now = DateTime.UtcNow;

        await docRef.SetAsync(new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["postId"] = request.PostId,
            ["userId"] = userId,
            ["userName"] = userName,
            ["userAvatar"] = userAvatar,
            ["content"] = request.Content,
            ["isAccepted"] = false,
            ["upvoteCount"] = 0,
            ["createdAt"] = Timestamp.FromDateTime(now),
        });

        // Increment answer count on post
        try
        {
            await _db.Collection("qaPosts").Document(request.PostId).UpdateAsync(new Dictionary<string, object>
            {
                ["answerCount"] = FieldValue.Increment(1),
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to update answer count for post {PostId}", request.PostId);
        }

        return new QaAnswer
        {
            Id = docRef.Id,
            PostId = request.PostId,
            UserId = userId,
            UserName = userName,
            UserAvatar = userAvatar,
            Content = request.Content,
            IsAccepted = false,
            UpvoteCount = 0,
            CreatedAt = now,
        };
    }

    public async Task AcceptAnswerAsync(string answerId, string requestingUserId)
    {
        var answerDoc = await _db.Collection("qaAnswers").Document(answerId).GetSnapshotAsync();
        if (!answerDoc.Exists)
            throw new KeyNotFoundException($"Answer '{answerId}' not found");

        var postId = answerDoc.GetValue<string>("postId");
        var postDoc = await _db.Collection("qaPosts").Document(postId).GetSnapshotAsync();
        if (!postDoc.Exists)
            throw new KeyNotFoundException($"Post '{postId}' not found");

        var postOwnerId = postDoc.GetValue<string>("userId");
        if (postOwnerId != requestingUserId)
            throw new UnauthorizedAccessException("Only the post author can accept an answer");

        // Unaccept any previously accepted answer
        var existingAccepted = await _db.Collection("qaAnswers")
            .WhereEqualTo("postId", postId)
            .WhereEqualTo("isAccepted", true)
            .GetSnapshotAsync();

        foreach (var doc in existingAccepted.Documents)
        {
            await doc.Reference.UpdateAsync(new Dictionary<string, object> { ["isAccepted"] = false });
        }

        // Accept this answer
        await _db.Collection("qaAnswers").Document(answerId).UpdateAsync(new Dictionary<string, object>
        {
            ["isAccepted"] = true,
        });

        await _db.Collection("qaPosts").Document(postId).UpdateAsync(new Dictionary<string, object>
        {
            ["isSolved"] = true,
        });
    }

    public async Task UpvotePostAsync(string postId)
    {
        var doc = await _db.Collection("qaPosts").Document(postId).GetSnapshotAsync();
        if (!doc.Exists)
            throw new KeyNotFoundException($"Post '{postId}' not found");

        await _db.Collection("qaPosts").Document(postId).UpdateAsync(new Dictionary<string, object>
        {
            ["upvoteCount"] = FieldValue.Increment(1),
        });
    }

    public async Task UpvoteAnswerAsync(string answerId)
    {
        var doc = await _db.Collection("qaAnswers").Document(answerId).GetSnapshotAsync();
        if (!doc.Exists)
            throw new KeyNotFoundException($"Answer '{answerId}' not found");

        await _db.Collection("qaAnswers").Document(answerId).UpdateAsync(new Dictionary<string, object>
        {
            ["upvoteCount"] = FieldValue.Increment(1),
        });
    }

    private static QaPost MapPost(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        UserId = doc.ContainsField("userId") ? doc.GetValue<string>("userId") : "",
        UserName = doc.ContainsField("userName") ? doc.GetValue<string>("userName") : "",
        UserAvatar = doc.ContainsField("userAvatar") ? doc.GetValue<string>("userAvatar") : "",
        Title = doc.ContainsField("title") ? doc.GetValue<string>("title") : "",
        Content = doc.ContainsField("content") ? doc.GetValue<string>("content") : "",
        LessonId = doc.ContainsField("lessonId") ? doc.GetValue<string>("lessonId") : null,
        Tags = doc.ContainsField("tags") ? doc.GetValue<List<string>>("tags") : new(),
        AnswerCount = doc.ContainsField("answerCount") ? doc.GetValue<int>("answerCount") : 0,
        UpvoteCount = doc.ContainsField("upvoteCount") ? doc.GetValue<int>("upvoteCount") : 0,
        IsSolved = doc.ContainsField("isSolved") && doc.GetValue<bool>("isSolved"),
        CreatedAt = doc.ContainsField("createdAt")
            ? doc.GetValue<Timestamp>("createdAt").ToDateTime()
            : DateTime.UtcNow,
    };

    private static QaAnswer MapAnswer(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        PostId = doc.ContainsField("postId") ? doc.GetValue<string>("postId") : "",
        UserId = doc.ContainsField("userId") ? doc.GetValue<string>("userId") : "",
        UserName = doc.ContainsField("userName") ? doc.GetValue<string>("userName") : "",
        UserAvatar = doc.ContainsField("userAvatar") ? doc.GetValue<string>("userAvatar") : "",
        Content = doc.ContainsField("content") ? doc.GetValue<string>("content") : "",
        IsAccepted = doc.ContainsField("isAccepted") && doc.GetValue<bool>("isAccepted"),
        UpvoteCount = doc.ContainsField("upvoteCount") ? doc.GetValue<int>("upvoteCount") : 0,
        CreatedAt = doc.ContainsField("createdAt")
            ? doc.GetValue<Timestamp>("createdAt").ToDateTime()
            : DateTime.UtcNow,
    };
}
