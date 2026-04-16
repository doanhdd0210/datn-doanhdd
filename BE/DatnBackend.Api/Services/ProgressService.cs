using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class ProgressService
{
    private readonly FirestoreDb _db;
    private readonly ILogger<ProgressService> _logger;

    public ProgressService(FirestoreDb db, ILogger<ProgressService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<UserProgress>> GetTopicProgressAsync(string userId)
    {
        var snapshot = await _db.Collection("userProgress")
            .WhereEqualTo("userId", userId)
            .WhereEqualTo("isCompleted", true)
            .GetSnapshotAsync();

        return snapshot.Documents.Select(MapProgress).ToList();
    }

    public async Task<List<UserProgress>> GetLessonProgressAsync(string userId, string topicId)
    {
        var snapshot = await _db.Collection("userProgress")
            .WhereEqualTo("userId", userId)
            .WhereEqualTo("topicId", topicId)
            .GetSnapshotAsync();

        return snapshot.Documents.Select(MapProgress).ToList();
    }

    public async Task<UserProgress> CompleteLessonAsync(string userId, CompleteLessonRequest request, int xpReward)
    {
        // Check if already completed
        var existing = await _db.Collection("userProgress")
            .WhereEqualTo("userId", userId)
            .WhereEqualTo("lessonId", request.LessonId)
            .Limit(1)
            .GetSnapshotAsync();

        string progressId;
        if (existing.Documents.Count > 0 && existing.Documents[0].GetValue<bool>("isCompleted"))
        {
            // Already completed, return existing
            return MapProgress(existing.Documents[0]);
        }

        var now = DateTime.UtcNow;
        DocumentReference docRef;

        if (existing.Documents.Count > 0)
        {
            // Update existing incomplete record
            docRef = existing.Documents[0].Reference;
            progressId = docRef.Id;
            await docRef.UpdateAsync(new Dictionary<string, object>
            {
                ["isCompleted"] = true,
                ["xpEarned"] = xpReward,
                ["completedAt"] = Timestamp.FromDateTime(now),
                ["timeSpentSeconds"] = request.TimeSpentSeconds,
            });
        }
        else
        {
            // Create new record
            docRef = _db.Collection("userProgress").Document();
            progressId = docRef.Id;
            await docRef.SetAsync(new Dictionary<string, object>
            {
                ["id"] = progressId,
                ["userId"] = userId,
                ["lessonId"] = request.LessonId,
                ["topicId"] = request.TopicId,
                ["isCompleted"] = true,
                ["score"] = 0,
                ["xpEarned"] = xpReward,
                ["completedAt"] = Timestamp.FromDateTime(now),
                ["timeSpentSeconds"] = request.TimeSpentSeconds,
            });
        }

        // Update daily progress and user stats
        await UpdateDailyProgressAsync(userId, 1, xpReward, request.TimeSpentSeconds);
        await UpdateUserStatsAsync(userId, xpReward, 1);

        return new UserProgress
        {
            Id = progressId,
            UserId = userId,
            LessonId = request.LessonId,
            TopicId = request.TopicId,
            IsCompleted = true,
            XpEarned = xpReward,
            CompletedAt = now,
            TimeSpentSeconds = request.TimeSpentSeconds,
        };
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

        var docRef = _db.Collection("quizResults").Document();
        var answersData = userAnswers.Select(a => new Dictionary<string, object>
        {
            ["questionId"] = a.QuestionId,
            ["selectedAnswerIndex"] = a.SelectedAnswerIndex,
            ["isCorrect"] = a.IsCorrect,
        }).ToList<object>();

        await docRef.SetAsync(new Dictionary<string, object>
        {
            ["id"] = docRef.Id,
            ["userId"] = userId,
            ["lessonId"] = request.LessonId,
            ["totalQuestions"] = total,
            ["correctAnswers"] = correct,
            ["score"] = scorePercent,
            ["xpEarned"] = xpEarned,
            ["answers"] = answersData,
            ["completedAt"] = Timestamp.FromDateTime(now),
        });

        // Update user progress for lesson
        var progressSnapshot = await _db.Collection("userProgress")
            .WhereEqualTo("userId", userId)
            .WhereEqualTo("lessonId", request.LessonId)
            .Limit(1)
            .GetSnapshotAsync();

        if (progressSnapshot.Documents.Count > 0)
        {
            await progressSnapshot.Documents[0].Reference.UpdateAsync(new Dictionary<string, object>
            {
                ["score"] = scorePercent,
            });
        }

        if (xpEarned > 0)
            await UpdateUserStatsAsync(userId, xpEarned, 0);

        return new QuizResult
        {
            Id = docRef.Id,
            UserId = userId,
            LessonId = request.LessonId,
            TotalQuestions = total,
            CorrectAnswers = correct,
            Score = scorePercent,
            XpEarned = xpEarned,
            Answers = userAnswers,
            CompletedAt = now,
        };
    }

    public async Task<List<QuizResult>> GetQuizResultsAsync(string userId, string lessonId)
    {
        var snapshot = await _db.Collection("quizResults")
            .WhereEqualTo("userId", userId)
            .WhereEqualTo("lessonId", lessonId)
            .OrderByDescending("completedAt")
            .GetSnapshotAsync();

        return snapshot.Documents.Select(MapQuizResult).ToList();
    }

    public async Task<List<DailyProgress>> GetDailyProgressAsync(string userId, int days = 30)
    {
        var since = DateTime.UtcNow.AddDays(-days).ToString("yyyy-MM-dd");
        var snapshot = await _db.Collection("dailyProgress")
            .WhereEqualTo("userId", userId)
            .WhereGreaterThanOrEqualTo("date", since)
            .OrderBy("date")
            .GetSnapshotAsync();

        return snapshot.Documents.Select(MapDailyProgress).ToList();
    }

    public async Task<int> GetCurrentStreakAsync(string userId)
    {
        var doc = await _db.Collection("users").Document(userId).GetSnapshotAsync();
        if (doc.Exists && doc.ContainsField("currentStreak"))
            return doc.GetValue<int>("currentStreak");
        return 0;
    }

    public async Task<UserStatsResponse> GetUserStatsAsync(string userId)
    {
        var doc = await _db.Collection("users").Document(userId).GetSnapshotAsync();
        int totalXp = 0, lessonsCompleted = 0, currentStreak = 0, longestStreak = 0;

        if (doc.Exists)
        {
            if (doc.ContainsField("totalXp")) totalXp = doc.GetValue<int>("totalXp");
            if (doc.ContainsField("lessonsCompleted")) lessonsCompleted = doc.GetValue<int>("lessonsCompleted");
            if (doc.ContainsField("currentStreak")) currentStreak = doc.GetValue<int>("currentStreak");
            if (doc.ContainsField("longestStreak")) longestStreak = doc.GetValue<int>("longestStreak");
        }

        // Calculate rank based on XP
        string rank = CalculateRank(totalXp);

        return new UserStatsResponse
        {
            TotalXp = totalXp,
            LessonsCompleted = lessonsCompleted,
            CurrentStreak = currentStreak,
            LongestStreak = longestStreak,
            Rank = rank,
        };
    }

    private async Task UpdateDailyProgressAsync(string userId, int lessonsAdded, int xpAdded, int timeAdded)
    {
        try
        {
            var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
            var dailyId = $"{userId}_{today}";
            var docRef = _db.Collection("dailyProgress").Document(dailyId);
            var snapshot = await docRef.GetSnapshotAsync();

            if (snapshot.Exists)
            {
                await docRef.UpdateAsync(new Dictionary<string, object>
                {
                    ["lessonsCompleted"] = FieldValue.Increment(lessonsAdded),
                    ["xpEarned"] = FieldValue.Increment(xpAdded),
                    ["timeSpentSeconds"] = FieldValue.Increment(timeAdded),
                });
            }
            else
            {
                // Calculate streak
                var yesterday = DateTime.UtcNow.AddDays(-1).ToString("yyyy-MM-dd");
                var yesterdayId = $"{userId}_{yesterday}";
                var yesterdayDoc = await _db.Collection("dailyProgress").Document(yesterdayId).GetSnapshotAsync();
                int streak = yesterdayDoc.Exists ? yesterdayDoc.GetValue<int>("streak") + 1 : 1;

                await docRef.SetAsync(new Dictionary<string, object>
                {
                    ["id"] = dailyId,
                    ["userId"] = userId,
                    ["date"] = today,
                    ["lessonsCompleted"] = lessonsAdded,
                    ["xpEarned"] = xpAdded,
                    ["timeSpentSeconds"] = timeAdded,
                    ["streak"] = streak,
                });

                // Update user streak
                var userRef = _db.Collection("users").Document(userId);
                var userDoc = await userRef.GetSnapshotAsync();
                int longestStreak = userDoc.Exists && userDoc.ContainsField("longestStreak")
                    ? userDoc.GetValue<int>("longestStreak")
                    : 0;

                var streakUpdates = new Dictionary<string, object>
                {
                    ["currentStreak"] = streak,
                };
                if (streak > longestStreak)
                    streakUpdates["longestStreak"] = streak;

                try { await userRef.UpdateAsync(streakUpdates); }
                catch { await userRef.SetAsync(streakUpdates, SetOptions.MergeAll); }
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
            var userRef = _db.Collection("users").Document(userId);
            var updates = new Dictionary<string, object>
            {
                ["totalXp"] = FieldValue.Increment(xpDelta),
            };
            if (lessonsDelta > 0)
                updates["lessonsCompleted"] = FieldValue.Increment(lessonsDelta);

            try { await userRef.UpdateAsync(updates); }
            catch { await userRef.SetAsync(updates, SetOptions.MergeAll); }
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

    private static UserProgress MapProgress(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        UserId = doc.ContainsField("userId") ? doc.GetValue<string>("userId") : "",
        LessonId = doc.ContainsField("lessonId") ? doc.GetValue<string>("lessonId") : "",
        TopicId = doc.ContainsField("topicId") ? doc.GetValue<string>("topicId") : "",
        IsCompleted = doc.ContainsField("isCompleted") && doc.GetValue<bool>("isCompleted"),
        Score = doc.ContainsField("score") ? doc.GetValue<int>("score") : 0,
        XpEarned = doc.ContainsField("xpEarned") ? doc.GetValue<int>("xpEarned") : 0,
        CompletedAt = doc.ContainsField("completedAt")
            ? doc.GetValue<Timestamp>("completedAt").ToDateTime()
            : DateTime.UtcNow,
        TimeSpentSeconds = doc.ContainsField("timeSpentSeconds") ? doc.GetValue<int>("timeSpentSeconds") : 0,
    };

    private static QuizResult MapQuizResult(DocumentSnapshot doc)
    {
        var answers = new List<UserAnswer>();
        if (doc.ContainsField("answers"))
        {
            var rawAnswers = doc.GetValue<List<Dictionary<string, object>>>("answers");
            if (rawAnswers != null)
            {
                answers = rawAnswers.Select(a => new UserAnswer
                {
                    QuestionId = a.TryGetValue("questionId", out var qid) ? qid?.ToString() ?? "" : "",
                    SelectedAnswerIndex = a.TryGetValue("selectedAnswerIndex", out var idx)
                        ? Convert.ToInt32(idx) : 0,
                    IsCorrect = a.TryGetValue("isCorrect", out var ic) && ic is bool b && b,
                }).ToList();
            }
        }

        return new QuizResult
        {
            Id = doc.Id,
            UserId = doc.ContainsField("userId") ? doc.GetValue<string>("userId") : "",
            LessonId = doc.ContainsField("lessonId") ? doc.GetValue<string>("lessonId") : "",
            TotalQuestions = doc.ContainsField("totalQuestions") ? doc.GetValue<int>("totalQuestions") : 0,
            CorrectAnswers = doc.ContainsField("correctAnswers") ? doc.GetValue<int>("correctAnswers") : 0,
            Score = doc.ContainsField("score") ? doc.GetValue<int>("score") : 0,
            XpEarned = doc.ContainsField("xpEarned") ? doc.GetValue<int>("xpEarned") : 0,
            Answers = answers,
            CompletedAt = doc.ContainsField("completedAt")
                ? doc.GetValue<Timestamp>("completedAt").ToDateTime()
                : DateTime.UtcNow,
        };
    }

    private static DailyProgress MapDailyProgress(DocumentSnapshot doc) => new()
    {
        Id = doc.Id,
        UserId = doc.ContainsField("userId") ? doc.GetValue<string>("userId") : "",
        Date = doc.ContainsField("date") ? doc.GetValue<string>("date") : "",
        LessonsCompleted = doc.ContainsField("lessonsCompleted") ? doc.GetValue<int>("lessonsCompleted") : 0,
        XpEarned = doc.ContainsField("xpEarned") ? doc.GetValue<int>("xpEarned") : 0,
        TimeSpentSeconds = doc.ContainsField("timeSpentSeconds") ? doc.GetValue<int>("timeSpentSeconds") : 0,
        Streak = doc.ContainsField("streak") ? doc.GetValue<int>("streak") : 0,
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
