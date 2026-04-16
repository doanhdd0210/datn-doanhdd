using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/progress")]
[Produces("application/json")]
public class ProgressController : ControllerBase
{
    private readonly ProgressService _progressService;
    private readonly LessonService _lessonService;
    private readonly QuestionService _questionService;

    public ProgressController(
        ProgressService progressService,
        LessonService lessonService,
        QuestionService questionService)
    {
        _progressService = progressService;
        _lessonService = lessonService;
        _questionService = questionService;
    }

    private string? UserId => HttpContext.Items["FirebaseUid"]?.ToString();

    /// <summary>Get user topic progress</summary>
    [HttpGet("topics")]
    public async Task<ActionResult<ApiResponse<List<UserProgress>>>> GetTopicProgress()
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<List<UserProgress>>.Fail("Unauthorized"));

        var progress = await _progressService.GetTopicProgressAsync(uid);
        return Ok(ApiResponse<List<UserProgress>>.Ok(progress));
    }

    /// <summary>Get user lesson progress for a topic</summary>
    [HttpGet("lessons")]
    public async Task<ActionResult<ApiResponse<List<UserProgress>>>> GetLessonProgress([FromQuery] string topicId)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<List<UserProgress>>.Fail("Unauthorized"));

        if (string.IsNullOrEmpty(topicId))
            return BadRequest(ApiResponse<List<UserProgress>>.Fail("topicId query parameter is required"));

        var progress = await _progressService.GetLessonProgressAsync(uid, topicId);
        return Ok(ApiResponse<List<UserProgress>>.Ok(progress));
    }

    /// <summary>Mark a lesson as complete and award XP</summary>
    [HttpPost("complete-lesson")]
    public async Task<ActionResult<ApiResponse<UserProgress>>> CompleteLesson([FromBody] CompleteLessonRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<UserProgress>.Fail("Unauthorized"));

        try
        {
            var lesson = await _lessonService.GetLessonAsync(request.LessonId);
            if (lesson == null)
                return NotFound(ApiResponse<UserProgress>.Fail($"Lesson '{request.LessonId}' not found"));

            var progress = await _progressService.CompleteLessonAsync(uid, request, lesson.XpReward);
            return Ok(ApiResponse<UserProgress>.Ok(progress, $"Lesson completed! +{lesson.XpReward} XP"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<UserProgress>.Fail(ex.Message));
        }
    }

    /// <summary>Submit quiz answers and save result</summary>
    [HttpPost("quiz-submit")]
    public async Task<ActionResult<ApiResponse<QuizResult>>> SubmitQuiz([FromBody] SubmitQuizRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<QuizResult>.Fail("Unauthorized"));

        try
        {
            var questions = await _questionService.ListQuestionsAsync(request.LessonId);
            if (questions.Count == 0)
                return BadRequest(ApiResponse<QuizResult>.Fail("No questions found for this lesson"));

            var result = await _progressService.SubmitQuizAsync(uid, request, questions);
            return Ok(ApiResponse<QuizResult>.Ok(result, $"Quiz completed! Score: {result.Score}%"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<QuizResult>.Fail(ex.Message));
        }
    }

    /// <summary>Get user quiz results for a lesson</summary>
    [HttpGet("quiz-results")]
    public async Task<ActionResult<ApiResponse<List<QuizResult>>>> GetQuizResults([FromQuery] string lessonId)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<List<QuizResult>>.Fail("Unauthorized"));

        if (string.IsNullOrEmpty(lessonId))
            return BadRequest(ApiResponse<List<QuizResult>>.Fail("lessonId query parameter is required"));

        var results = await _progressService.GetQuizResultsAsync(uid, lessonId);
        return Ok(ApiResponse<List<QuizResult>>.Ok(results));
    }

    /// <summary>Get daily progress for last 30 days</summary>
    [HttpGet("daily")]
    public async Task<ActionResult<ApiResponse<List<DailyProgress>>>> GetDailyProgress([FromQuery] int days = 30)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<List<DailyProgress>>.Fail("Unauthorized"));

        var progress = await _progressService.GetDailyProgressAsync(uid, days);
        return Ok(ApiResponse<List<DailyProgress>>.Ok(progress));
    }

    /// <summary>Get current streak</summary>
    [HttpGet("streak")]
    public async Task<ActionResult<ApiResponse<int>>> GetStreak()
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<int>.Fail("Unauthorized"));

        var streak = await _progressService.GetCurrentStreakAsync(uid);
        return Ok(ApiResponse<int>.Ok(streak));
    }

    /// <summary>Get overall user stats</summary>
    [HttpGet("stats")]
    public async Task<ActionResult<ApiResponse<UserStatsResponse>>> GetStats()
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<UserStatsResponse>.Fail("Unauthorized"));

        var stats = await _progressService.GetUserStatsAsync(uid);
        return Ok(ApiResponse<UserStatsResponse>.Ok(stats));
    }
}
