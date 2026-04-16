using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class CodeSnippetService
{
    private readonly FirestoreDb _db;
    private readonly ILogger<CodeSnippetService> _logger;
    private const string Collection = "codeSnippets";

    public CodeSnippetService(FirestoreDb db, ILogger<CodeSnippetService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<CodeSnippet>> ListSnippetsAsync(string? topicId = null, bool activeOnly = true)
    {
        Query query = _db.Collection(Collection);
        if (topicId != null)
            query = query.WhereEqualTo("topicId", topicId);
        if (activeOnly)
            query = query.WhereEqualTo("isActive", true);

        query = query.OrderBy("order");
        var snapshot = await query.GetSnapshotAsync();
        return snapshot.Documents.Select(MapSnippet).ToList();
    }

    public async Task<CodeSnippet?> GetSnippetAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        return doc.Exists ? MapSnippet(doc) : null;
    }

    public async Task<CodeSnippet> CreateSnippetAsync(CreateCodeSnippetRequest request)
    {
        var docRef = _db.Collection(Collection).Document();
        var now = DateTime.UtcNow;

        var data = new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["topicId"] = request.TopicId,
            ["title"] = request.Title,
            ["description"] = request.Description,
            ["code"] = request.Code,
            ["language"] = request.Language,
            ["expectedOutput"] = request.ExpectedOutput,
            ["order"] = request.Order,
            ["xpReward"] = request.XpReward,
            ["isActive"] = true,
            ["createdAt"] = Timestamp.FromDateTime(now),
        };

        await docRef.SetAsync(data);

        return new CodeSnippet
        {
            Id = docRef.Id,
            TopicId = request.TopicId,
            Title = request.Title,
            Description = request.Description,
            Code = request.Code,
            Language = request.Language,
            ExpectedOutput = request.ExpectedOutput,
            Order = request.Order,
            XpReward = request.XpReward,
            IsActive = true,
            CreatedAt = now,
        };
    }

    public async Task<CodeSnippet> UpdateSnippetAsync(string id, UpdateCodeSnippetRequest request)
    {
        var docRef = _db.Collection(Collection).Document(id);
        var snapshot = await docRef.GetSnapshotAsync();
        if (!snapshot.Exists)
            throw new KeyNotFoundException($"CodeSnippet '{id}' not found");

        var updates = new Dictionary<string, object>();
        if (request.TopicId != null) updates["topicId"] = request.TopicId;
        if (request.Title != null) updates["title"] = request.Title;
        if (request.Description != null) updates["description"] = request.Description;
        if (request.Code != null) updates["code"] = request.Code;
        if (request.Language != null) updates["language"] = request.Language;
        if (request.ExpectedOutput != null) updates["expectedOutput"] = request.ExpectedOutput;
        if (request.Order.HasValue) updates["order"] = request.Order.Value;
        if (request.XpReward.HasValue) updates["xpReward"] = request.XpReward.Value;
        if (request.IsActive.HasValue) updates["isActive"] = request.IsActive.Value;

        if (updates.Count > 0)
            await docRef.UpdateAsync(updates);

        var updated = await docRef.GetSnapshotAsync();
        return MapSnippet(updated);
    }

    public async Task DeleteSnippetAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        if (!doc.Exists)
            throw new KeyNotFoundException($"CodeSnippet '{id}' not found");

        await _db.Collection(Collection).Document(id).DeleteAsync();
    }

    public async Task<PracticeResult> SubmitPracticeAsync(string userId, SubmitPracticeRequest request)
    {
        var snippet = await GetSnippetAsync(request.CodeSnippetId);
        if (snippet == null)
            throw new KeyNotFoundException($"CodeSnippet '{request.CodeSnippetId}' not found");

        int score = request.IsPassed ? 100 : 0;
        int xpEarned = request.IsPassed ? snippet.XpReward : 0;
        var now = DateTime.UtcNow;

        var docRef = _db.Collection("practiceResults").Document();

        await docRef.SetAsync(new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["userId"] = userId,
            ["codeSnippetId"] = request.CodeSnippetId,
            ["submittedCode"] = request.SubmittedCode,
            ["actualOutput"] = request.ActualOutput,
            ["isPassed"] = request.IsPassed,
            ["score"] = score,
            ["xpEarned"] = xpEarned,
            ["completedAt"] = Timestamp.FromDateTime(now),
        });

        if (xpEarned > 0)
        {
            try
            {
                var userRef = _db.Collection("users").Document(userId);
                var updates = new Dictionary<string, object>
                {
                    ["totalXp"] = FieldValue.Increment(xpEarned),
                };
                try { await userRef.UpdateAsync(updates); }
                catch { await userRef.SetAsync(updates, SetOptions.MergeAll); }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to update XP for user {UserId}", userId);
            }
        }

        return new PracticeResult
        {
            Id = docRef.Id,
            UserId = userId,
            CodeSnippetId = request.CodeSnippetId,
            SubmittedCode = request.SubmittedCode,
            ActualOutput = request.ActualOutput,
            IsPassed = request.IsPassed,
            Score = score,
            XpEarned = xpEarned,
            CompletedAt = now,
        };
    }

    private static CodeSnippet MapSnippet(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        TopicId = doc.ContainsField("topicId") ? doc.GetValue<string>("topicId") : "",
        Title = doc.ContainsField("title") ? doc.GetValue<string>("title") : "",
        Description = doc.ContainsField("description") ? doc.GetValue<string>("description") : "",
        Code = doc.ContainsField("code") ? doc.GetValue<string>("code") : "",
        Language = doc.ContainsField("language") ? doc.GetValue<string>("language") : "java",
        ExpectedOutput = doc.ContainsField("expectedOutput") ? doc.GetValue<string>("expectedOutput") : "",
        Order = doc.ContainsField("order") ? doc.GetValue<int>("order") : 0,
        XpReward = doc.ContainsField("xpReward") ? doc.GetValue<int>("xpReward") : 5,
        IsActive = doc.ContainsField("isActive") && doc.GetValue<bool>("isActive"),
        CreatedAt = doc.ContainsField("createdAt")
            ? doc.GetValue<Timestamp>("createdAt").ToDateTime()
            : DateTime.UtcNow,
    };
}
