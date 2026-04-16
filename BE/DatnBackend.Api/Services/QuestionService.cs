using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class QuestionService
{
    private readonly FirestoreDb _db;
    private readonly ILogger<QuestionService> _logger;
    private const string Collection = "questions";

    public QuestionService(FirestoreDb db, ILogger<QuestionService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<Question>> ListQuestionsAsync(string lessonId)
    {
        var snapshot = await _db.Collection(Collection)
            .WhereEqualTo("lessonId", lessonId)
            .OrderBy("order")
            .GetSnapshotAsync();

        return snapshot.Documents.Select(MapQuestion).ToList();
    }

    public async Task<Question?> GetQuestionAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        return doc.Exists ? MapQuestion(doc) : null;
    }

    public async Task<Question> CreateQuestionAsync(CreateQuestionRequest request)
    {
        var docRef = _db.Collection(Collection).Document();

        var data = new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["lessonId"] = request.LessonId,
            ["questionText"] = request.QuestionText,
            ["options"] = request.Options,
            ["correctAnswerIndex"] = request.CorrectAnswerIndex,
            ["explanation"] = request.Explanation,
            ["order"] = request.Order,
            ["points"] = request.Points,
        };

        await docRef.SetAsync(data);

        return new Question
        {
            Id = docRef.Id,
            LessonId = request.LessonId,
            QuestionText = request.QuestionText,
            Options = request.Options,
            CorrectAnswerIndex = request.CorrectAnswerIndex,
            Explanation = request.Explanation,
            Order = request.Order,
            Points = request.Points,
        };
    }

    public async Task<Question> UpdateQuestionAsync(string id, UpdateQuestionRequest request)
    {
        var docRef = _db.Collection(Collection).Document(id);
        var snapshot = await docRef.GetSnapshotAsync();
        if (!snapshot.Exists)
            throw new KeyNotFoundException($"Question '{id}' not found");

        var updates = new Dictionary<string, object>();
        if (request.LessonId != null) updates["lessonId"] = request.LessonId;
        if (request.QuestionText != null) updates["questionText"] = request.QuestionText;
        if (request.Options != null) updates["options"] = request.Options;
        if (request.CorrectAnswerIndex.HasValue) updates["correctAnswerIndex"] = request.CorrectAnswerIndex.Value;
        if (request.Explanation != null) updates["explanation"] = request.Explanation;
        if (request.Order.HasValue) updates["order"] = request.Order.Value;
        if (request.Points.HasValue) updates["points"] = request.Points.Value;

        if (updates.Count > 0)
            await docRef.UpdateAsync(updates);

        var updated = await docRef.GetSnapshotAsync();
        return MapQuestion(updated);
    }

    public async Task DeleteQuestionAsync(string id)
    {
        var doc = await _db.Collection(Collection).Document(id).GetSnapshotAsync();
        if (!doc.Exists)
            throw new KeyNotFoundException($"Question '{id}' not found");

        await _db.Collection(Collection).Document(id).DeleteAsync();
    }

    private static Question MapQuestion(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        LessonId = doc.ContainsField("lessonId") ? doc.GetValue<string>("lessonId") : "",
        QuestionText = doc.ContainsField("questionText") ? doc.GetValue<string>("questionText") : "",
        Options = doc.ContainsField("options") ? doc.GetValue<List<string>>("options") : new(),
        CorrectAnswerIndex = doc.ContainsField("correctAnswerIndex") ? doc.GetValue<int>("correctAnswerIndex") : 0,
        Explanation = doc.ContainsField("explanation") ? doc.GetValue<string>("explanation") : "",
        Order = doc.ContainsField("order") ? doc.GetValue<int>("order") : 0,
        Points = doc.ContainsField("points") ? doc.GetValue<int>("points") : 10,
    };
}
