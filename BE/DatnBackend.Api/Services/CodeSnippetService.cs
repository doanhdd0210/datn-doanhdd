using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class CodeSnippetService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<CodeSnippetService> _logger;
    private readonly AchievementsService _achievements;

    public CodeSnippetService(AppDbContext db, ICacheService cache, ILogger<CodeSnippetService> logger, AchievementsService achievements)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
        _achievements = achievements;
    }

    public async Task<List<CodeSnippetDto>> ListSnippetsAsync(string? userId = null, string? topicId = null, bool activeOnly = true)
    {
        var query = _db.CodeSnippets.AsQueryable();
        if (topicId != null) query = query.Where(s => s.TopicId == topicId);
        if (activeOnly) query = query.Where(s => s.IsActive);
        var snippets = await query.OrderBy(s => s.Order).ToListAsync();

        HashSet<string> passedIds = [];
        if (userId != null)
        {
            var passed = await _db.PracticeResults
                .Where(r => r.UserId == userId && r.IsPassed)
                .Select(r => r.CodeSnippetId)
                .Distinct()
                .ToListAsync();
            passedIds = [.. passed];
        }

        return snippets.Select(s => new CodeSnippetDto(s, passedIds.Contains(s.Id))).ToList();
    }

    public async Task<CodeSnippet?> GetSnippetAsync(string id)
    {
        return await _db.CodeSnippets.FirstOrDefaultAsync(s => s.Id == id);
    }

    public async Task<CodeSnippet> CreateSnippetAsync(CreateCodeSnippetRequest request)
    {
        var snippet = new CodeSnippet
        {
            Id = Guid.NewGuid().ToString(),
            TopicId = request.TopicId,
            Title = request.Title,
            Description = request.Description,
            Code = request.Code,
            Language = request.Language,
            ExpectedOutput = request.ExpectedOutput,
            Order = request.Order,
            XpReward = request.XpReward,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
        };

        _db.CodeSnippets.Add(snippet);
        await _db.SaveChangesAsync();
        await InvalidateSnippetCacheAsync(snippet.TopicId);

        return snippet;
    }

    public async Task<CodeSnippet> UpdateSnippetAsync(string id, UpdateCodeSnippetRequest request)
    {
        var snippet = await _db.CodeSnippets.FirstOrDefaultAsync(s => s.Id == id)
            ?? throw new KeyNotFoundException($"CodeSnippet '{id}' not found");

        if (request.TopicId != null) snippet.TopicId = request.TopicId;
        if (request.Title != null) snippet.Title = request.Title;
        if (request.Description != null) snippet.Description = request.Description;
        if (request.Code != null) snippet.Code = request.Code;
        if (request.Language != null) snippet.Language = request.Language;
        if (request.ExpectedOutput != null) snippet.ExpectedOutput = request.ExpectedOutput;
        if (request.Order.HasValue) snippet.Order = request.Order.Value;
        if (request.XpReward.HasValue) snippet.XpReward = request.XpReward.Value;
        if (request.IsActive.HasValue) snippet.IsActive = request.IsActive.Value;

        await _db.SaveChangesAsync();
        await InvalidateSnippetCacheAsync(snippet.TopicId);

        return snippet;
    }

    public async Task DeleteSnippetAsync(string id)
    {
        var snippet = await _db.CodeSnippets.FirstOrDefaultAsync(s => s.Id == id)
            ?? throw new KeyNotFoundException($"CodeSnippet '{id}' not found");

        var topicId = snippet.TopicId;
        _db.CodeSnippets.Remove(snippet);
        await _db.SaveChangesAsync();
        await InvalidateSnippetCacheAsync(topicId);
    }

    public async Task<List<string>> GetPassedSnippetIdsAsync(string userId)
    {
        return await _db.PracticeResults
            .Where(r => r.UserId == userId && r.IsPassed)
            .Select(r => r.CodeSnippetId)
            .Distinct()
            .ToListAsync();
    }

    public async Task<PracticeResult> SubmitPracticeAsync(string userId, SubmitPracticeRequest request)
    {
        var snippet = await GetSnippetAsync(request.CodeSnippetId)
            ?? throw new KeyNotFoundException($"CodeSnippet '{request.CodeSnippetId}' not found");

        // Chỉ award XP lần đầu pass (tránh farm khi làm lại)
        bool hasPassedBefore = await _db.PracticeResults
            .AnyAsync(r => r.UserId == userId && r.CodeSnippetId == request.CodeSnippetId && r.IsPassed);
        int xpEarned = (request.IsPassed && !hasPassedBefore) ? snippet.XpReward : 0;

        var result = new PracticeResult
        {
            Id = Guid.NewGuid().ToString(),
            UserId = userId,
            CodeSnippetId = request.CodeSnippetId,
            SubmittedCode = request.SubmittedCode,
            ActualOutput = request.ActualOutput,
            IsPassed = request.IsPassed,
            Score = request.IsPassed ? 100 : 0,
            XpEarned = xpEarned,
            CompletedAt = DateTime.UtcNow,
        };

        _db.PracticeResults.Add(result);

        if (xpEarned > 0)
        {
            await _db.UserProfiles
                .Where(p => p.Uid == userId)
                .ExecuteUpdateAsync(s => s.SetProperty(p => p.TotalXp, p => p.TotalXp + xpEarned));
        }

        await _db.SaveChangesAsync();

        if (xpEarned > 0)
            await _achievements.CheckAndGrantAsync(userId);

        return result;
    }

    private Task InvalidateSnippetCacheAsync(string topicId) =>
        _cache.RemoveAsync(
            $"snippets:topic:{topicId}:True",
            $"snippets:topic:{topicId}:False",
            "snippets:topic:all:True",
            "snippets:topic:all:False");
}
