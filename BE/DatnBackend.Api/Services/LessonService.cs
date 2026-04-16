using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class LessonService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<LessonService> _logger;

    public LessonService(AppDbContext db, ICacheService cache, ILogger<LessonService> logger)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
    }

    public async Task<List<Lesson>> ListLessonsAsync(string? topicId = null, bool activeOnly = true)
    {
        var cacheKey = $"lessons:topic:{topicId ?? "all"}:{activeOnly}";
        var cached = await _cache.GetAsync<List<Lesson>>(cacheKey);
        if (cached != null) return cached;

        var query = _db.Lessons.AsQueryable();
        if (topicId != null) query = query.Where(l => l.TopicId == topicId);
        if (activeOnly) query = query.Where(l => l.IsActive);
        var lessons = await query.OrderBy(l => l.Order).ToListAsync();

        await _cache.SetAsync(cacheKey, lessons, TimeSpan.FromMinutes(10));
        return lessons;
    }

    public async Task<Lesson?> GetLessonAsync(string id)
    {
        var cacheKey = $"lessons:{id}";
        var cached = await _cache.GetAsync<Lesson>(cacheKey);
        if (cached != null) return cached;

        var lesson = await _db.Lessons.FirstOrDefaultAsync(l => l.Id == id);
        if (lesson != null)
            await _cache.SetAsync(cacheKey, lesson, TimeSpan.FromMinutes(10));

        return lesson;
    }

    public async Task<Lesson> CreateLessonAsync(CreateLessonRequest request)
    {
        var lesson = new Lesson
        {
            Id = Guid.NewGuid().ToString(),
            TopicId = request.TopicId,
            Title = request.Title,
            Content = request.Content,
            Summary = request.Summary,
            Order = request.Order,
            XpReward = request.XpReward,
            EstimatedMinutes = request.EstimatedMinutes,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
        };

        _db.Lessons.Add(lesson);
        await _db.SaveChangesAsync();
        await InvalidateLessonCacheAsync(lesson.TopicId);

        return lesson;
    }

    public async Task<Lesson> UpdateLessonAsync(string id, UpdateLessonRequest request)
    {
        var lesson = await _db.Lessons.FirstOrDefaultAsync(l => l.Id == id)
            ?? throw new KeyNotFoundException($"Lesson '{id}' not found");

        if (request.TopicId != null) lesson.TopicId = request.TopicId;
        if (request.Title != null) lesson.Title = request.Title;
        if (request.Content != null) lesson.Content = request.Content;
        if (request.Summary != null) lesson.Summary = request.Summary;
        if (request.Order.HasValue) lesson.Order = request.Order.Value;
        if (request.XpReward.HasValue) lesson.XpReward = request.XpReward.Value;
        if (request.EstimatedMinutes.HasValue) lesson.EstimatedMinutes = request.EstimatedMinutes.Value;
        if (request.IsActive.HasValue) lesson.IsActive = request.IsActive.Value;

        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"lessons:{id}");
        await InvalidateLessonCacheAsync(lesson.TopicId);

        return lesson;
    }

    public async Task DeleteLessonAsync(string id)
    {
        var lesson = await _db.Lessons.FirstOrDefaultAsync(l => l.Id == id)
            ?? throw new KeyNotFoundException($"Lesson '{id}' not found");

        var topicId = lesson.TopicId;
        _db.Lessons.Remove(lesson);
        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"lessons:{id}");
        await InvalidateLessonCacheAsync(topicId);
    }

    private Task InvalidateLessonCacheAsync(string topicId) =>
        _cache.RemoveAsync(
            $"lessons:topic:{topicId}:True",
            $"lessons:topic:{topicId}:False",
            "lessons:topic:all:True",
            "lessons:topic:all:False");
}
