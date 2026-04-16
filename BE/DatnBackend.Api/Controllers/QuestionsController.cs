using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/questions")]
[Produces("application/json")]
public class QuestionsController : ControllerBase
{
    private readonly QuestionService _questionService;

    public QuestionsController(QuestionService questionService)
    {
        _questionService = questionService;
    }

    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;

    /// <summary>List questions for a lesson</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<Question>>>> List([FromQuery] string lessonId)
    {
        if (string.IsNullOrEmpty(lessonId))
            return BadRequest(ApiResponse<List<Question>>.Fail("lessonId query parameter is required"));

        var questions = await _questionService.ListQuestionsAsync(lessonId);
        return Ok(ApiResponse<List<Question>>.Ok(questions, $"{questions.Count} questions"));
    }

    /// <summary>Create question (admin only)</summary>
    [HttpPost]
    public async Task<ActionResult<ApiResponse<Question>>> Create([FromBody] CreateQuestionRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<Question>.Fail("Forbidden: Admin access required"));

        try
        {
            var question = await _questionService.CreateQuestionAsync(request);
            return CreatedAtAction(null, ApiResponse<Question>.Ok(question, "Question created successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<Question>.Fail(ex.Message));
        }
    }

    /// <summary>Update question (admin only)</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<Question>>> Update(string id, [FromBody] UpdateQuestionRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<Question>.Fail("Forbidden: Admin access required"));

        try
        {
            var question = await _questionService.UpdateQuestionAsync(id, request);
            return Ok(ApiResponse<Question>.Ok(question, "Question updated successfully"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<Question>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<Question>.Fail(ex.Message));
        }
    }

    /// <summary>Delete question (admin only)</summary>
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(string id)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));

        try
        {
            await _questionService.DeleteQuestionAsync(id);
            return Ok(ApiResponse<object>.Ok(null, "Question deleted successfully"));
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
}
