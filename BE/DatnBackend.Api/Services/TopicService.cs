using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class TopicService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<TopicService> _logger;

    public TopicService(AppDbContext db, ICacheService cache, ILogger<TopicService> logger)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
    }

    public async Task<List<Topic>> ListTopicsAsync(bool activeOnly = true)
    {
        var cacheKey = $"topics:all:{activeOnly}";
        var cached = await _cache.GetAsync<List<Topic>>(cacheKey);
        if (cached != null) return cached;

        var query = _db.Topics.AsQueryable();
        if (activeOnly) query = query.Where(t => t.IsActive);
        var topics = await query.OrderBy(t => t.Order).ToListAsync();

        await _cache.SetAsync(cacheKey, topics, TimeSpan.FromMinutes(10));
        return topics;
    }

    public async Task<Topic?> GetTopicAsync(string id)
    {
        var cacheKey = $"topics:{id}";
        var cached = await _cache.GetAsync<Topic>(cacheKey);
        if (cached != null) return cached;

        var topic = await _db.Topics.FirstOrDefaultAsync(t => t.Id == id);
        if (topic != null)
            await _cache.SetAsync(cacheKey, topic, TimeSpan.FromMinutes(10));

        return topic;
    }

    public async Task<Topic> CreateTopicAsync(CreateTopicRequest request)
    {
        var topic = new Topic
        {
            Id = Guid.NewGuid().ToString(),
            Title = request.Title,
            Description = request.Description,
            Icon = request.Icon,
            Color = request.Color,
            Order = request.Order,
            TotalLessons = 0,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
        };

        _db.Topics.Add(topic);
        await _db.SaveChangesAsync();
        await InvalidateTopicsListAsync();

        return topic;
    }

    public async Task<Topic> UpdateTopicAsync(string id, UpdateTopicRequest request)
    {
        var topic = await _db.Topics.FirstOrDefaultAsync(t => t.Id == id)
            ?? throw new KeyNotFoundException($"Topic '{id}' not found");

        if (request.Title != null) topic.Title = request.Title;
        if (request.Description != null) topic.Description = request.Description;
        if (request.Icon != null) topic.Icon = request.Icon;
        if (request.Color != null) topic.Color = request.Color;
        if (request.Order.HasValue) topic.Order = request.Order.Value;
        if (request.IsActive.HasValue) topic.IsActive = request.IsActive.Value;

        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"topics:{id}", "topics:all:True", "topics:all:False");

        return topic;
    }

    public async Task DeleteTopicAsync(string id)
    {
        var topic = await _db.Topics.FirstOrDefaultAsync(t => t.Id == id)
            ?? throw new KeyNotFoundException($"Topic '{id}' not found");

        _db.Topics.Remove(topic);
        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"topics:{id}", "topics:all:True", "topics:all:False");
    }

    public async Task IncrementLessonCountAsync(string topicId, int delta = 1)
    {
        try
        {
            await _db.Topics
                .Where(t => t.Id == topicId)
                .ExecuteUpdateAsync(s => s.SetProperty(t => t.TotalLessons, t => t.TotalLessons + delta));

            await _cache.RemoveAsync($"topics:{topicId}", "topics:all:True", "topics:all:False");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to update totalLessons for topic {TopicId}", topicId);
        }
    }

    private Task InvalidateTopicsListAsync() =>
        _cache.RemoveAsync("topics:all:True", "topics:all:False");
}
