using FirebaseAdmin.Auth;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class ProgressService
{
    private readonly AppDbContext _db;
    private readonly ICacheService _cache;
    private readonly ILogger<ProgressService> _logger;
    private readonly SettingsService _settingsService;
    private readonly AchievementsService _achievements;
    private readonly INotificationService _notifService;

    public ProgressService(AppDbContext db, ICacheService cache, ILogger<ProgressService> logger, SettingsService settingsService, AchievementsService achievements, INotificationService notifService)
    {
        _db = db;
        _cache = cache;
        _logger = logger;
        _settingsService = settingsService;
        _achievements = achievements;
        _notifService = notifService;
    }

    /// <summary>Tạo UserProfile từ Firebase nếu chưa tồn tại trong DB.</summary>
    private async Task EnsureProfileAsync(string userId)
    {
        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
        try
        {
            var firebaseUser = await FirebaseAuth.DefaultInstance.GetUserAsync(userId);
            var name = firebaseUser.DisplayName ?? firebaseUser.Email?.Split('@')[0] ?? "User";

            if (profile == null)
            {
                profile = new UserProfile
                {
                    Uid = userId,
                    DisplayName = name,
                    PhotoUrl = firebaseUser.PhotoUrl,
                    TotalXp = 0,
                    CurrentStreak = 0,
                    LongestStreak = 0,
                    LessonsCompleted = 0,
                    Rank = "Beginner",
                    FcmTokens = [],
                    // Level intentionally left null — user must go through onboarding to set it
                };
                _db.UserProfiles.Add(profile);
                await _db.SaveChangesAsync();
            }
            else if (string.IsNullOrEmpty(profile.DisplayName))
            {
                profile.DisplayName = name;
                if (profile.PhotoUrl == null && firebaseUser.PhotoUrl != null)
                    profile.PhotoUrl = firebaseUser.PhotoUrl;
                await _db.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "EnsureProfile failed for {UserId}", userId);
        }
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

        // Skip XP award if quiz already gave XP for this lesson (prevent double-counting)
        bool xpAlreadyAwarded = await _db.QuizResults
            .AnyAsync(r => r.UserId == userId && r.LessonId == request.LessonId && r.Score == 100);
        int actualXp = xpAlreadyAwarded ? 0 : xpReward;

        await UpdateUserStatsAsync(userId, actualXp, 1);
        await UpdateDailyProgressAsync(userId, 1, actualXp, request.TimeSpentSeconds);

        await _achievements.CheckAndGrantAsync(userId);

        return existing;
    }

    public async Task<QuizResult> SubmitQuizAsync(string userId, SubmitQuizRequest request, List<Question> questions, int lessonXpReward = 10)
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
        int potentialXp = (int)Math.Round(scorePercent / 100.0 * lessonXpReward);

        // Chỉ award XP khi đúng 100% và chưa từng đạt 100% trước đó
        bool hasEarnedPerfectBefore = await _db.QuizResults
            .AnyAsync(r => r.UserId == userId && r.LessonId == request.LessonId && r.Score == 100);
        int xpEarned = (!hasEarnedPerfectBefore && scorePercent == 100) ? lessonXpReward : 0;

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

        // Update lesson progress score (luôn cập nhật điểm cao nhất)
        var progress = await _db.UserProgresses
            .FirstOrDefaultAsync(p => p.UserId == userId && p.LessonId == request.LessonId);
        if (progress != null && scorePercent > progress.Score)
        {
            progress.Score = scorePercent;
        }

        await _db.SaveChangesAsync();

        if (xpEarned > 0)
        {
            await UpdateUserStatsAsync(userId, xpEarned, 0);
            await UpdateDailyProgressAsync(userId, 0, xpEarned, request.TimeSpentSeconds);
        }

        await _achievements.CheckAndGrantAsync(userId);

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

        await EnsureProfileAsync(userId);
        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);

        var todayId = $"{userId}_{DateTime.UtcNow:yyyy-MM-dd}";
        var todayProgress = await _db.DailyProgresses.FirstOrDefaultAsync(d => d.Id == todayId);

        var todayStart = DateTime.UtcNow.Date;
        var todayAchievementXp = await _db.UserAchievements
            .Where(ua => ua.UserId == userId && ua.UnlockedAt >= todayStart)
            .Join(_db.Achievements, ua => ua.AchievementId, a => a.Id, (ua, a) => a.XpReward)
            .SumAsync();

        var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
        var bonusClaimedToday = await _db.DailyGoalBonusClaims
            .AnyAsync(c => c.UserId == userId && c.Date == today);

        var stats = new UserStatsResponse
        {
            TotalXp = profile?.TotalXp ?? 0,
            LessonsCompleted = profile?.LessonsCompleted ?? 0,
            CurrentStreak = profile?.CurrentStreak ?? 0,
            LongestStreak = profile?.LongestStreak ?? 0,
            Rank = profile?.Rank ?? "Beginner",
            Level = profile?.Level ?? "beginner",
            LevelSet = profile?.Level != null,
            TodayXp = (todayProgress?.XpEarned ?? 0) + todayAchievementXp,
            DailyGoalTarget = profile?.DailyGoalTarget ?? 20,
            DailyGoalBonusClaimedToday = bonusClaimedToday,
        };

        // Auto-claim bonus BEFORE caching so the response reflects the correct claimed state
        if (!bonusClaimedToday && stats.TodayXp >= stats.DailyGoalTarget)
        {
            await CheckAndAwardDailyGoalBonusAsync(userId);
            var bonusXp = await _settingsService.GetBonusForGoalAsync(stats.DailyGoalTarget);
            if (bonusXp > 0)
            {
                stats.DailyGoalBonusClaimedToday = true;
                stats.TotalXp += bonusXp;
            }
        }

        await _cache.SetAsync(cacheKey, stats, TimeSpan.FromMinutes(2));
        return stats;
    }

    public async Task UpdateDailyProgressAsync(string userId, int lessonsAdded, int xpAdded, int timeAdded, bool forceCreate = false)
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
                if (xpAdded <= 0 && lessonsAdded <= 0 && !forceCreate) return;

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
            return;
        }

        if (xpAdded > 0)
            await CheckAndAwardDailyGoalBonusAsync(userId);
    }

    public async Task SetDailyGoalAsync(string userId, int goalTarget)
    {
        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
        if (profile == null) return;
        profile.DailyGoalTarget = goalTarget;
        await _db.SaveChangesAsync();
        await _cache.RemoveAsync($"stats:{userId}");
    }

    private async Task CheckAndAwardDailyGoalBonusAsync(string userId)
    {
        try
        {
            var today = DateTime.UtcNow.ToString("yyyy-MM-dd");

            var alreadyClaimed = await _db.DailyGoalBonusClaims
                .AnyAsync(c => c.UserId == userId && c.Date == today);
            if (alreadyClaimed) return;

            var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
            if (profile == null) return;

            var dailyId = $"{userId}_{today}";
            var todayProgress = await _db.DailyProgresses.FirstOrDefaultAsync(d => d.Id == dailyId);

            var todayStart = DateTime.UtcNow.Date;
            var todayAchievementXp = await _db.UserAchievements
                .Where(ua => ua.UserId == userId && ua.UnlockedAt >= todayStart)
                .Join(_db.Achievements, ua => ua.AchievementId, a => a.Id, (ua, a) => a.XpReward)
                .SumAsync();

            var todayXp = (todayProgress?.XpEarned ?? 0) + todayAchievementXp;
            if (todayXp < profile.DailyGoalTarget) return;

            var bonusXp = await _settingsService.GetBonusForGoalAsync(profile.DailyGoalTarget);
            if (bonusXp <= 0) return;

            _db.DailyGoalBonusClaims.Add(new DailyGoalBonusClaim
            {
                Id = Guid.NewGuid().ToString(),
                UserId = userId,
                Date = today,
                GoalTarget = profile.DailyGoalTarget,
                BonusXp = bonusXp,
                ClaimedAt = DateTime.UtcNow,
            });

            profile.TotalXp += bonusXp;
            profile.Rank = CalculateRank(profile.TotalXp);

            try { await _db.SaveChangesAsync(); }
            catch (Exception ex) when (ex.InnerException?.Message.Contains("duplicate") == true
                                    || ex.InnerException?.Message.Contains("unique") == true)
            {
                return; // Race condition — another request already claimed
            }

            await _cache.RemoveAsync($"stats:{userId}", "leaderboard:20", "leaderboard:50", "leaderboard_weekly:20", "leaderboard_weekly:50");

            // In-app notification
            _db.UserNotifications.Add(new UserNotification
            {
                Id = Guid.NewGuid().ToString(),
                UserId = userId,
                Type = "daily_goal",
                Title = "Hoàn thành mục tiêu hôm nay! 🎯",
                Body = $"Bạn đã đạt mục tiêu {profile.DailyGoalTarget} XP và nhận thưởng +{bonusXp} XP",
                IsRead = false,
                CreatedAt = DateTime.UtcNow,
            });
            await _db.SaveChangesAsync();

            // Push notification
            if (profile.FcmTokens.Count > 0)
            {
                await _notifService.SendToTokensAsync(new SendNotificationRequest
                {
                    Title = "Hoàn thành mục tiêu hôm nay! 🎯",
                    Body = $"Xuất sắc! Bạn nhận được +{bonusXp} XP thưởng",
                    Data = new Dictionary<string, string>
                    {
                        ["type"] = "daily_goal",
                        ["bonusXp"] = bonusXp.ToString(),
                        ["screen"] = "home",
                    },
                }, profile.FcmTokens);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "CheckAndAwardDailyGoalBonus failed for {UserId}", userId);
        }
    }

    public async Task UpdateUserStatsAsync(string userId, int xpDelta, int lessonsDelta)
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
            await _cache.RemoveAsync($"stats:{userId}", "leaderboard:20", "leaderboard:50", "leaderboard_weekly:20", "leaderboard_weekly:50");
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

    public async Task<ClaimBonusResult> ClaimDailyGoalBonusAsync(string userId, int goalTarget)
    {
        var today = DateTime.UtcNow.ToString("yyyy-MM-dd");

        // Already claimed today?
        var alreadyClaimed = await _db.DailyGoalBonusClaims
            .AnyAsync(c => c.UserId == userId && c.Date == today);
        if (alreadyClaimed)
            return new ClaimBonusResult { Success = false, BonusXp = 0, Message = "Bạn đã nhận thưởng hôm nay rồi" };

        // Verify XP earned today >= goalTarget (include achievement XP same as GetUserStats)
        var todayProgress = await _db.DailyProgresses
            .FirstOrDefaultAsync(d => d.UserId == userId && d.Date == today);
        var todayStart = DateTime.UtcNow.Date;
        var todayAchievementXp = await _db.UserAchievements
            .Where(ua => ua.UserId == userId && ua.UnlockedAt >= todayStart)
            .Join(_db.Achievements, ua => ua.AchievementId, a => a.Id, (ua, a) => a.XpReward)
            .SumAsync();
        var todayXp = (todayProgress?.XpEarned ?? 0) + todayAchievementXp;
        if (todayXp < goalTarget)
            return new ClaimBonusResult { Success = false, BonusXp = 0, Message = "Chưa đạt mục tiêu hôm nay" };

        // Get configured bonus
        var bonusXp = await _settingsService.GetBonusForGoalAsync(goalTarget);
        if (bonusXp <= 0)
            return new ClaimBonusResult { Success = false, BonusXp = 0, Message = "Mục tiêu không hợp lệ" };

        // Mark claimed
        _db.DailyGoalBonusClaims.Add(new DailyGoalBonusClaim
        {
            Id = Guid.NewGuid().ToString(),
            UserId = userId,
            Date = today,
            GoalTarget = goalTarget,
            BonusXp = bonusXp,
            ClaimedAt = DateTime.UtcNow,
        });

        // Award bonus XP to profile only; DailyGoalBonusClaims is the authoritative store for bonus
        // (weekly leaderboard sums DailyProgress + DailyGoalBonusClaims separately to avoid double-count)
        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
        if (profile != null)
        {
            profile.TotalXp += bonusXp;
            profile.Rank = CalculateRank(profile.TotalXp);
        }

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (Exception ex) when (ex.InnerException?.Message.Contains("duplicate") == true
                                || ex.InnerException?.Message.Contains("unique") == true)
        {
            // Race condition: another request already claimed — return gracefully
            return new ClaimBonusResult { Success = false, BonusXp = 0, Message = "Bạn đã nhận thưởng hôm nay rồi" };
        }
        await _cache.RemoveAsync($"stats:{userId}", "leaderboard:20", "leaderboard:50", "leaderboard_weekly:20", "leaderboard_weekly:50");
        await _achievements.CheckAndGrantAsync(userId);

        // In-app notification
        _db.UserNotifications.Add(new UserNotification
        {
            Id = Guid.NewGuid().ToString(),
            UserId = userId,
            Type = "daily_goal",
            Title = "Hoàn thành mục tiêu hôm nay! 🎯",
            Body = $"Bạn đã đạt mục tiêu {goalTarget} XP và nhận thưởng +{bonusXp} XP",
            IsRead = false,
            CreatedAt = DateTime.UtcNow,
        });
        await _db.SaveChangesAsync();

        // Push notification
        try
        {
            var profile2 = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == userId);
            if (profile2?.FcmTokens.Count > 0)
            {
                await _notifService.SendToTokensAsync(new SendNotificationRequest
                {
                    Title = "Hoàn thành mục tiêu hôm nay! 🎯",
                    Body = $"Xuất sắc! Bạn nhận được +{bonusXp} XP thưởng",
                    Data = new Dictionary<string, string> { ["screen"] = "home" },
                }, profile2.FcmTokens);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to send push notification for daily goal bonus");
        }

        return new ClaimBonusResult { Success = true, BonusXp = bonusXp, Message = "Nhận thưởng thành công!" };
    }
}

public class UserStatsResponse
{
    public int TotalXp { get; set; }
    public int LessonsCompleted { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public string Rank { get; set; } = "";
    public string Level { get; set; } = "beginner";
    public bool LevelSet { get; set; }
    public int TodayXp { get; set; }
    public int DailyGoalTarget { get; set; } = 20;
    public bool DailyGoalBonusClaimedToday { get; set; }
}

public class ClaimBonusResult
{
    public bool Success { get; set; }
    public int BonusXp { get; set; }
    public string Message { get; set; } = "";
}
