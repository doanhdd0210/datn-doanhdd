using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class QuestionService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<QuestionService> _logger;

    public QuestionService(AppDbContext db, ICacheService cache, ILogger<QuestionService> logger)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
    }

    public async Task<List<Question>> ListQuestionsAsync(string lessonId)
    {
        var cacheKey = $"questions:lesson:{lessonId}";
        var cached = await _cache.GetAsync<List<Question>>(cacheKey);
        if (cached != null) return cached;

        var questions = await _db.Questions
            .Where(q => q.LessonId == lessonId)
            .OrderBy(q => q.Order)
            .ToListAsync();

        await _cache.SetAsync(cacheKey, questions, TimeSpan.FromMinutes(10));
        return questions;
    }

    public async Task<Question?> GetQuestionAsync(string id)
    {
        return await _db.Questions.FirstOrDefaultAsync(q => q.Id == id);
    }

    public async Task<Question> CreateQuestionAsync(CreateQuestionRequest request)
    {
        var question = new Question
        {
            Id = Guid.NewGuid().ToString(),
            LessonId = request.LessonId,
            QuestionText = request.QuestionText,
            Options = request.Options,
            CorrectAnswerIndex = request.CorrectAnswerIndex,
            Explanation = request.Explanation,
            Order = request.Order,
            Points = request.Points,
        };

        _db.Questions.Add(question);
        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"questions:lesson:{request.LessonId}");

        return question;
    }

    public async Task<Question> UpdateQuestionAsync(string id, UpdateQuestionRequest request)
    {
        var question = await _db.Questions.FirstOrDefaultAsync(q => q.Id == id)
            ?? throw new KeyNotFoundException($"Question '{id}' not found");

        if (request.LessonId != null) question.LessonId = request.LessonId;
        if (request.QuestionText != null) question.QuestionText = request.QuestionText;
        if (request.Options != null) question.Options = request.Options;
        if (request.CorrectAnswerIndex.HasValue) question.CorrectAnswerIndex = request.CorrectAnswerIndex.Value;
        if (request.Explanation != null) question.Explanation = request.Explanation;
        if (request.Order.HasValue) question.Order = request.Order.Value;
        if (request.Points.HasValue) question.Points = request.Points.Value;

        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"questions:lesson:{question.LessonId}");

        return question;
    }

    public async Task DeleteQuestionAsync(string id)
    {
        var question = await _db.Questions.FirstOrDefaultAsync(q => q.Id == id)
            ?? throw new KeyNotFoundException($"Question '{id}' not found");

        var lessonId = question.LessonId;
        _db.Questions.Remove(question);
        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"questions:lesson:{lessonId}");
    }
}
