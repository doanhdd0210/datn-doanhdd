using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class AchievementsService
{
    private readonly AppDbContext _db;

    public AchievementsService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<List<Achievement>> GetAllAsync()
    {
        return await _db.Achievements
            .OrderBy(a => a.ConditionType)
            .ThenBy(a => a.ConditionValue)
            .ToListAsync();
    }

    public async Task<Achievement> CreateAsync(CreateAchievementRequest req)
    {
        var achievement = new Achievement
        {
            Id = Guid.NewGuid().ToString(),
            Title = req.Title,
            Description = req.Description,
            Icon = req.Icon,
            ConditionType = req.ConditionType,
            ConditionValue = req.ConditionValue,
            XpReward = req.XpReward,
            IsActive = req.IsActive,
            CreatedAt = DateTime.UtcNow,
        };
        _db.Achievements.Add(achievement);
        await _db.SaveChangesAsync();
        return achievement;
    }

    public async Task<Achievement> UpdateAsync(string id, UpdateAchievementRequest req)
    {
        var achievement = await _db.Achievements.FindAsync(id)
            ?? throw new KeyNotFoundException($"Achievement {id} not found");

        if (req.Title != null) achievement.Title = req.Title;
        if (req.Description != null) achievement.Description = req.Description;
        if (req.Icon != null) achievement.Icon = req.Icon;
        if (req.ConditionType != null) achievement.ConditionType = req.ConditionType;
        if (req.ConditionValue.HasValue) achievement.ConditionValue = req.ConditionValue.Value;
        if (req.XpReward.HasValue) achievement.XpReward = req.XpReward.Value;
        if (req.IsActive.HasValue) achievement.IsActive = req.IsActive.Value;

        await _db.SaveChangesAsync();
        return achievement;
    }

    public async Task DeleteAsync(string id)
    {
        var achievement = await _db.Achievements.FindAsync(id)
            ?? throw new KeyNotFoundException($"Achievement {id} not found");
        _db.Achievements.Remove(achievement);
        await _db.SaveChangesAsync();
    }
}
