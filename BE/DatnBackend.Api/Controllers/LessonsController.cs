using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/lessons")]
[Produces("application/json")]
public class LessonsController : ControllerBase
{
    private readonly LessonService _lessonService;
    private readonly QuestionService _questionService;
    private readonly TopicService _topicService;

    public LessonsController(LessonService lessonService, QuestionService questionService, TopicService topicService)
    {
        _lessonService = lessonService;
        _questionService = questionService;
        _topicService = topicService;
    }

    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;

    /// <summary>List all lessons (optional topicId filter)</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<Lesson>>>> List([FromQuery] string? topicId = null)
    {
        var lessons = await _lessonService.ListLessonsAsync(topicId: topicId, activeOnly: true);
        return Ok(ApiResponse<List<Lesson>>.Ok(lessons, $"{lessons.Count} lessons"));
    }

    /// <summary>Get lesson by ID</summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<Lesson>>> Get(string id)
    {
        var lesson = await _lessonService.GetLessonAsync(id);
        if (lesson == null)
            return NotFound(ApiResponse<Lesson>.Fail($"Lesson '{id}' not found"));
        return Ok(ApiResponse<Lesson>.Ok(lesson));
    }

    /// <summary>Create lesson (admin only)</summary>
    [HttpPost]
    public async Task<ActionResult<ApiResponse<Lesson>>> Create([FromBody] CreateLessonRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<Lesson>.Fail("Forbidden: Admin access required"));

        try
        {
            var lesson = await _lessonService.CreateLessonAsync(request);
            // Update topic lesson count
            if (!string.IsNullOrEmpty(request.TopicId))
                await _topicService.IncrementLessonCountAsync(request.TopicId, 1);

            return CreatedAtAction(nameof(Get), new { id = lesson.Id },
                ApiResponse<Lesson>.Ok(lesson, "Lesson created successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<Lesson>.Fail(ex.Message));
        }
    }

    /// <summary>Update lesson (admin only)</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<Lesson>>> Update(string id, [FromBody] UpdateLessonRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<Lesson>.Fail("Forbidden: Admin access required"));

        try
        {
            var lesson = await _lessonService.UpdateLessonAsync(id, request);
            return Ok(ApiResponse<Lesson>.Ok(lesson, "Lesson updated successfully"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<Lesson>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<Lesson>.Fail(ex.Message));
        }
    }

    /// <summary>Delete lesson (admin only)</summary>
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(string id)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));

        try
        {
            var lesson = await _lessonService.GetLessonAsync(id);
            if (lesson == null)
                return NotFound(ApiResponse<object>.Fail($"Lesson '{id}' not found"));

            await _lessonService.DeleteLessonAsync(id);

            if (!string.IsNullOrEmpty(lesson.TopicId))
                await _topicService.IncrementLessonCountAsync(lesson.TopicId, -1);

            return Ok(ApiResponse<object>.Ok(null, "Lesson deleted successfully"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<object>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    /// <summary>List questions for lesson</summary>
    [HttpGet("{id}/questions")]
    public async Task<ActionResult<ApiResponse<List<Question>>>> GetQuestions(string id)
    {
        var lesson = await _lessonService.GetLessonAsync(id);
        if (lesson == null)
            return NotFound(ApiResponse<List<Question>>.Fail($"Lesson '{id}' not found"));

        var questions = await _questionService.ListQuestionsAsync(lessonId: id);
        return Ok(ApiResponse<List<Question>>.Ok(questions, $"{questions.Count} questions"));
    }
}
