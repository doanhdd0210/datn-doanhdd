using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/topics")]
[Produces("application/json")]
public class TopicsController : ControllerBase
{
    private readonly TopicService _topicService;
    private readonly LessonService _lessonService;

    public TopicsController(TopicService topicService, LessonService lessonService)
    {
        _topicService = topicService;
        _lessonService = lessonService;
    }

    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;
    private string? UserId => HttpContext.Items["FirebaseUid"]?.ToString();

    /// <summary>List all active topics</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<Topic>>>> List()
    {
        var topics = await _topicService.ListTopicsAsync(activeOnly: true);
        return Ok(ApiResponse<List<Topic>>.Ok(topics, $"{topics.Count} topics"));
    }

    /// <summary>Get topic by ID</summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<Topic>>> Get(string id)
    {
        var topic = await _topicService.GetTopicAsync(id);
        if (topic == null)
            return NotFound(ApiResponse<Topic>.Fail($"Topic '{id}' not found"));
        return Ok(ApiResponse<Topic>.Ok(topic));
    }

    /// <summary>Create topic (admin only)</summary>
    [HttpPost]
    public async Task<ActionResult<ApiResponse<Topic>>> Create([FromBody] CreateTopicRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<Topic>.Fail("Forbidden: Admin access required"));

        try
        {
            var topic = await _topicService.CreateTopicAsync(request);
            return CreatedAtAction(nameof(Get), new { id = topic.Id },
                ApiResponse<Topic>.Ok(topic, "Topic created successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<Topic>.Fail(ex.Message));
        }
    }

    /// <summary>Update topic (admin only)</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<Topic>>> Update(string id, [FromBody] UpdateTopicRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<Topic>.Fail("Forbidden: Admin access required"));

        try
        {
            var topic = await _topicService.UpdateTopicAsync(id, request);
            return Ok(ApiResponse<Topic>.Ok(topic, "Topic updated successfully"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<Topic>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<Topic>.Fail(ex.Message));
        }
    }

    /// <summary>Delete topic (admin only)</summary>
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(string id)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));

        try
        {
            await _topicService.DeleteTopicAsync(id);
            return Ok(ApiResponse<object>.Ok(null, "Topic deleted successfully"));
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

    /// <summary>List lessons for topic</summary>
    [HttpGet("{id}/lessons")]
    public async Task<ActionResult<ApiResponse<List<Lesson>>>> GetLessons(string id)
    {
        var topic = await _topicService.GetTopicAsync(id);
        if (topic == null)
            return NotFound(ApiResponse<List<Lesson>>.Fail($"Topic '{id}' not found"));

        var lessons = await _lessonService.ListLessonsAsync(topicId: id, activeOnly: true);
        return Ok(ApiResponse<List<Lesson>>.Ok(lessons, $"{lessons.Count} lessons"));
    }
}
