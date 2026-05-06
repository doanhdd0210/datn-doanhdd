using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class SettingsService
{
    private readonly AppDbContext _db;

    // Default bonus XP per daily goal level
    public static readonly Dictionary<int, int> DefaultBonuses = new()
    {
        { 20,  5  },
        { 50,  15 },
        { 100, 35 },
    };

    public SettingsService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<Dictionary<int, int>> GetDailyGoalBonusesAsync()
    {
        var settings = await _db.AppSettings
            .Where(s => s.Key.StartsWith("dailyGoalBonus:"))
            .ToListAsync();

        var result = new Dictionary<int, int>(DefaultBonuses);
        foreach (var s in settings)
        {
            var parts = s.Key.Split(':');
            if (parts.Length == 2
                && int.TryParse(parts[1], out var goal)
                && int.TryParse(s.Value, out var bonus))
            {
                result[goal] = bonus;
            }
        }
        return result;
    }

    public async Task<int> GetBonusForGoalAsync(int goalTarget)
    {
        var key = $"dailyGoalBonus:{goalTarget}";
        var setting = await _db.AppSettings.FindAsync(key);
        if (setting != null && int.TryParse(setting.Value, out var val))
            return val;
        return DefaultBonuses.GetValueOrDefault(goalTarget, 0);
    }

    public async Task SetDailyGoalBonusAsync(int goal, int bonus)
    {
        var key = $"dailyGoalBonus:{goal}";
        var existing = await _db.AppSettings.FindAsync(key);
        if (existing != null)
            existing.Value = bonus.ToString();
        else
            _db.AppSettings.Add(new AppSetting { Key = key, Value = bonus.ToString() });

        await _db.SaveChangesAsync();
    }

    public async Task ReplaceDailyGoalBonusesAsync(List<(int GoalXp, int BonusXp)> configs)
    {
        var existing = await _db.AppSettings
            .Where(s => s.Key.StartsWith("dailyGoalBonus:"))
            .ToListAsync();
        _db.AppSettings.RemoveRange(existing);

        foreach (var (goal, bonus) in configs)
            _db.AppSettings.Add(new AppSetting { Key = $"dailyGoalBonus:{goal}", Value = bonus.ToString() });

        await _db.SaveChangesAsync();
    }
}
