using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class LessonService
{
    private readonly FirestoreDb _db;
    private readonly ILogger<LessonService> _logger;
    private const string Collection = "lessons";

    public LessonService(FirestoreDb db, ILogger<LessonService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<Lesson>> ListLessonsAsync(string? topicId = null, bool activeOnly = true)
    {
        Query query = _db.Collection(Collection);
        if (topicId != null)
            query = query.WhereEqualTo("topicId", topicId);
        if (activeOnly)
            query = query.WhereEqualTo("isActive", true);

        query = query.OrderBy("order");
        var snapshot = await query.GetSnapshotAsync();
        return snapshot.Documents.Select(MapLesson).ToList();
    }

    public async Task<Lesson?> GetLessonAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        return doc.Exists ? MapLesson(doc) : null;
    }

    public async Task<Lesson> CreateLessonAsync(CreateLessonRequest request)
    {
        var docRef = _db.Collection(Collection).Document();
        var now = DateTime.UtcNow;

        var data = new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["topicId"] = request.TopicId,
            ["title"] = request.Title,
            ["content"] = request.Content,
            ["summary"] = request.Summary,
            ["order"] = request.Order,
            ["xpReward"] = request.XpReward,
            ["estimatedMinutes"] = request.EstimatedMinutes,
            ["isActive"] = true,
            ["createdAt"] = Timestamp.FromDateTime(now),
        };

        await docRef.SetAsync(data);

        return new Lesson
        {
            Id = docRef.Id,
            TopicId = request.TopicId,
            Title = request.Title,
            Content = request.Content,
            Summary = request.Summary,
            Order = request.Order,
            XpReward = request.XpReward,
            EstimatedMinutes = request.EstimatedMinutes,
            IsActive = true,
            CreatedAt = now,
        };
    }

    public async Task<Lesson> UpdateLessonAsync(string id, UpdateLessonRequest request)
    {
        var docRef = _db.Collection(Collection).Document(id);
        var snapshot = await docRef.GetSnapshotAsync();
        if (!snapshot.Exists)
            throw new KeyNotFoundException($"Lesson '{id}' not found");

        var updates = new Dictionary<string, object>();
        if (request.TopicId != null) updates["topicId"] = request.TopicId;
        if (request.Title != null) updates["title"] = request.Title;
        if (request.Content != null) updates["content"] = request.Content;
        if (request.Summary != null) updates["summary"] = request.Summary;
        if (request.Order.HasValue) updates["order"] = request.Order.Value;
        if (request.XpReward.HasValue) updates["xpReward"] = request.XpReward.Value;
        if (request.EstimatedMinutes.HasValue) updates["estimatedMinutes"] = request.EstimatedMinutes.Value;
        if (request.IsActive.HasValue) updates["isActive"] = request.IsActive.Value;

        if (updates.Count > 0)
            await docRef.UpdateAsync(updates);

        var updated = await docRef.GetSnapshotAsync();
        return MapLesson(updated);
    }

    public async Task DeleteLessonAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        if (!doc.Exists)
            throw new KeyNotFoundException($"Lesson '{id}' not found");

        await _db.Collection(Collection).Document(id).DeleteAsync();
    }

    private static Lesson MapLesson(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        TopicId = doc.ContainsField("topicId") ? doc.GetValue<string>("topicId") : "",
        Title = doc.ContainsField("title") ? doc.GetValue<string>("title") : "",
        Content = doc.ContainsField("content") ? doc.GetValue<string>("content") : "",
        Summary = doc.ContainsField("summary") ? doc.GetValue<string>("summary") : "",
        Order = doc.ContainsField("order") ? doc.GetValue<int>("order") : 0,
        XpReward = doc.ContainsField("xpReward") ? doc.GetValue<int>("xpReward") : 10,
        EstimatedMinutes = doc.ContainsField("estimatedMinutes") ? doc.GetValue<int>("estimatedMinutes") : 0,
        IsActive = doc.ContainsField("isActive") && doc.GetValue<bool>("isActive"),
        CreatedAt = doc.ContainsField("createdAt")
            ? doc.GetValue<Timestamp>("createdAt").ToDateTime()
            : DateTime.UtcNow,
    };
}
