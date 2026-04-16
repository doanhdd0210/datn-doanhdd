using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class ProgressService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<ProgressService> _logger;

    public ProgressService(AppDbContext db, ICacheService cache, ILogger<ProgressService> logger)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
    }

    public async Task<List<UserProgress>> GetTopicProgressAsync(string userId)
    {
        return await _db.UserProgresses
            .Where(p => p.UserId == userId && p.IsCompleted)
            .ToListAsync();
    }

    public async Task<List<UserProgress>> GetLessonProgressAsync(string userId, string topicId)
    {
        return await _db.UserProgresses
            .Where(p => p.UserId == userId && p.TopicId == topicId)
            .ToListAsync();
    }

    public async Task<UserProgress> CompleteLessonAsync(string userId, CompleteLessonRequest request, int xpReward)
    {
        var existing = await _db.UserProgresses
            .FirstOrDefaultAsync(p => p.UserId == userId && p.LessonId == request.LessonId);

        if (existing != null && existing.IsCompleted)
            return existing;

        var now = DateTime.UtcNow;

        if (existing != null)
        {
            existing.IsCompleted = true;
            existing.XpEarned = xpReward;
            existing.CompletedAt = now;
            existing.TimeSpentSeconds = request.TimeSpentSeconds;
        }
        else
        {
            existing = new UserProgress
            {
                Id = Guid.NewGuid().ToString(),
                UserId = userId,
                LessonId = request.LessonId,
                TopicId = request.TopicId,
                IsCompleted = true,
                Score = 0,
                XpEarned = xpReward,
                CompletedAt = now,
                TimeSpentSeconds = request.TimeSpentSeconds,
            };
            _db.UserProgresses.Add(existing);
        }

        await _db.SaveChangesAsync();
        await UpdateDailyProgressAsync(userId, 1, xpReward, request.TimeSpentSeconds);
        await UpdateUserStatsAsync(userId, xpReward, 1);

        return existing;
    }

    public async Task<QuizResult> SubmitQuizAsync(string userId, SubmitQuizRequest request, List<Question> questions)
    {
        var now = DateTime.UtcNow;
        int correct = 0;

        var userAnswers = new List<UserAnswer>();
        foreach (var answer in request.Answers)
        {
            var question = questions.FirstOrDefault(q => q.Id == answer.QuestionId);
            bool isCorrect = question != null && question.CorrectAnswerIndex == answer.SelectedAnswerIndex;
            if (isCorrect) correct++;
            userAnswers.Add(new UserAnswer
            {
                QuestionId = answer.QuestionId,
                SelectedAnswerIndex = answer.SelectedAnswerIndex,
                IsCorrect = isCorrect,
            });
        }

        int total = questions.Count;
        int scorePercent = total > 0 ? (int)Math.Round((double)correct / total * 100) : 0;
        int xpEarned = (int)(scorePercent / 100.0 * questions.Sum(q => q.Points));

        var result = new QuizResult
        {
            Id = Guid.NewGuid().ToString(),
            UserId = userId,
            LessonId = request.LessonId,
            TotalQuestions = total,
            CorrectAnswers = correct,
            Score = scorePercent,
            XpEarned = xpEarned,
            Answers = userAnswers,
            CompletedAt = now,
        };

        _db.QuizResults.Add(result);

        // Update lesson progress score
        var progress = await _db.UserProgresses
            .FirstOrDefaultAsync(p => p.UserId == userId && p.LessonId == request.LessonId);
        if (progress != null)
        {
            progress.Score = scorePercent;
        }

        await _db.SaveChangesAsync();

        if (xpEarned > 0)
            await UpdateUserStatsAsync(userId, xpEarned, 0);

        return result;
    }

    public async Task<List<QuizResult>> GetQuizResultsAsync(string userId, string lessonId)
    {
        return await _db.QuizResults
            .Where(r => r.UserId == userId && r.LessonId == lessonId)
            .OrderByDescending(r => r.CompletedAt)
            .ToListAsync();
    }

    public async Task<List<DailyProgress>> GetDailyProgressAsync(string userId, int days = 30)
    {
        var since = DateTime.UtcNow.AddDays(-days).ToString("yyyy-MM-dd");
        return await _db.DailyProgresses
            .Where(d => d.UserId == userId && string.Compare(d.Date, since) >= 0)
            .OrderBy(d => d.Date)
            .ToListAsync();
    }

    public async Task<int> GetCurrentStreakAsync(string userId)
    {
        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
        return profile?.CurrentStreak ?? 0;
    }

    public async Task<UserStatsResponse> GetUserStatsAsync(string userId)
    {
        var cacheKey = $"stats:{userId}";
        var cached = await _cache.GetAsync<UserStatsResponse>(cacheKey);
        if (cached != null) return cached;

        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
        var stats = new UserStatsResponse
        {
            TotalXp = profile?.TotalXp ?? 0,
            LessonsCompleted = profile?.LessonsCompleted ?? 0,
            CurrentStreak = profile?.CurrentStreak ?? 0,
            LongestStreak = profile?.LongestStreak ?? 0,
            Rank = profile?.Rank ?? "Beginner",
        };

        await _cache.SetAsync(cacheKey, stats, TimeSpan.FromMinutes(2));
        return stats;
    }

    private async Task UpdateDailyProgressAsync(string userId, int lessonsAdded, int xpAdded, int timeAdded)
    {
        try
        {
            var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
            var dailyId = $"{userId}_{today}";

            var existing = await _db.DailyProgresses.FirstOrDefaultAsync(d => d.Id == dailyId);
            if (existing != null)
            {
                existing.LessonsCompleted += lessonsAdded;
                existing.XpEarned += xpAdded;
                existing.TimeSpentSeconds += timeAdded;
                await _db.SaveChangesAsync();
            }
            else
            {
                var yesterday = DateTime.UtcNow.AddDays(-1).ToString("yyyy-MM-dd");
                var yesterdayId = $"{userId}_{yesterday}";
                var yesterdayDoc = await _db.DailyProgresses.FirstOrDefaultAsync(d => d.Id == yesterdayId);
                int streak = yesterdayDoc != null ? yesterdayDoc.Streak + 1 : 1;

                _db.DailyProgresses.Add(new DailyProgress
                {
                    Id = dailyId,
                    UserId = userId,
                    Date = today,
                    LessonsCompleted = lessonsAdded,
                    XpEarned = xpAdded,
                    TimeSpentSeconds = timeAdded,
                    Streak = streak,
                });
                await _db.SaveChangesAsync();

                // Update streak on user profile
                var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
                if (profile != null)
                {
                    profile.CurrentStreak = streak;
                    if (streak > profile.LongestStreak)
                        profile.LongestStreak = streak;
                    await _db.SaveChangesAsync();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to update daily progress for user {UserId}", userId);
        }
    }

    private async Task UpdateUserStatsAsync(string userId, int xpDelta, int lessonsDelta)
    {
        try
        {
            var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
            if (profile == null)
            {
                profile = new UserProfile { Uid = userId, TotalXp = xpDelta, LessonsCompleted = lessonsDelta };
                _db.UserProfiles.Add(profile);
            }
            else
            {
                profile.TotalXp += xpDelta;
                profile.LessonsCompleted += lessonsDelta;
            }
            profile.Rank = CalculateRank(profile.TotalXp);
            await _db.SaveChangesAsync();
            await _cache.RemoveAsync($"stats:{userId}", "leaderboard");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to update user stats for {UserId}", userId);
        }
    }

    private static string CalculateRank(int xp) => xp switch
    {
        < 100 => "Beginner",
        < 500 => "Learner",
        < 1500 => "Intermediate",
        < 3000 => "Advanced",
        < 6000 => "Expert",
        _ => "Master",
    };
}

public class UserStatsResponse
{
    public int TotalXp { get; set; }
    public int LessonsCompleted { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public string Rank { get; set; } = "";
}
