using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class TopicService
{
    private readonly FirestoreDb _db;
    private readonly ILogger<TopicService> _logger;
    private const string Collection = "topics";

    public TopicService(FirestoreDb db, ILogger<TopicService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<Topic>> ListTopicsAsync(bool activeOnly = true)
    {
        Query query = _db.Collection(Collection);
        if (activeOnly)
            query = query.WhereEqualTo("isActive", true);
        query = query.OrderBy("order");

        var snapshot = await query.GetSnapshotAsync();
        return snapshot.Documents.Select(MapTopic).ToList();
    }

    public async Task<Topic?> GetTopicAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        return doc.Exists ? MapTopic(doc) : null;
    }

    public async Task<Topic> CreateTopicAsync(CreateTopicRequest request)
    {
        var docRef = _db.Collection(Collection).Document();
        var now = DateTime.UtcNow;

        var data = new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["title"] = request.Title,
            ["description"] = request.Description,
            ["icon"] = request.Icon,
            ["color"] = request.Color,
            ["order"] = request.Order,
            ["totalLessons"] = 0,
            ["isActive"] = true,
            ["createdAt"] = Timestamp.FromDateTime(now),
        };

        await docRef.SetAsync(data);

        return new Topic
        {
            Id = docRef.Id,
            Title = request.Title,
            Description = request.Description,
            Icon = request.Icon,
            Color = request.Color,
            Order = request.Order,
            TotalLessons = 0,
            IsActive = true,
            CreatedAt = now,
        };
    }

    public async Task<Topic> UpdateTopicAsync(string id, UpdateTopicRequest request)
    {
        var docRef = _db.Collection(Collection).Document(id);
        var snapshot = await docRef.GetSnapshotAsync();
        if (!snapshot.Exists)
            throw new KeyNotFoundException($"Topic '{id}' not found");

        var updates = new Dictionary<string, object>();
        if (request.Title != null) updates["title"] = request.Title;
        if (request.Description != null) updates["description"] = request.Description;
        if (request.Icon != null) updates["icon"] = request.Icon;
        if (request.Color != null) updates["color"] = request.Color;
        if (request.Order.HasValue) updates["order"] = request.Order.Value;
        if (request.IsActive.HasValue) updates["isActive"] = request.IsActive.Value;

        if (updates.Count > 0)
            await docRef.UpdateAsync(updates);

        var updated = await docRef.GetSnapshotAsync();
        return MapTopic(updated);
    }

    public async Task DeleteTopicAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        if (!doc.Exists)
            throw new KeyNotFoundException($"Topic '{id}' not found");

        await _db.Collection(Collection).Document(id).DeleteAsync();
    }

    public async Task IncrementLessonCountAsync(string topicId, int delta = 1)
    {
        try
        {
            var docRef = _db.Collection(Collection).Document(topicId);
            await docRef.UpdateAsync(new Dictionary<string, object>
            {
                ["totalLessons"] = FieldValue.Increment(delta),
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to update totalLessons for topic {TopicId}", topicId);
        }
    }

    private static Topic MapTopic(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        Title = doc.ContainsField("title") ? doc.GetValue<string>("title") : "",
        Description = doc.ContainsField("description") ? doc.GetValue<string>("description") : "",
        Icon = doc.ContainsField("icon") ? doc.GetValue<string>("icon") : "",
        Color = doc.ContainsField("color") ? doc.GetValue<string>("color") : "",
        Order = doc.ContainsField("order") ? doc.GetValue<int>("order") : 0,
        TotalLessons = doc.ContainsField("totalLessons") ? doc.GetValue<int>("totalLessons") : 0,
        IsActive = doc.ContainsField("isActive") && doc.GetValue<bool>("isActive"),
        CreatedAt = doc.ContainsField("createdAt")
            ? doc.GetValue<Timestamp>("createdAt").ToDateTime()
            : DateTime.UtcNow,
    };
}
