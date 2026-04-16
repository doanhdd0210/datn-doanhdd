using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/qa")]
[Produces("application/json")]
public class QaController : ControllerBase
{
    private readonly QaService _qaService;
    private readonly IUserService _userService;

    public QaController(QaService qaService, IUserService userService)
    {
        _qaService = qaService;
        _userService = userService;
    }

    private string? UserId => HttpContext.Items["FirebaseUid"]?.ToString();

    /// <summary>List QA posts (optional lessonId and page filters)</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<QaPost>>>> List(
        [FromQuery] string? lessonId = null,
        [FromQuery] int page = 1)
    {
        var posts = await _qaService.ListPostsAsync(lessonId: lessonId, page: page);
        return Ok(ApiResponse<List<QaPost>>.Ok(posts, $"{posts.Count} posts"));
    }

    /// <summary>Get QA post detail with answers</summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<QaPostDetail>>> Get(string id)
    {
        var post = await _qaService.GetPostAsync(id);
        if (post == null)
            return NotFound(ApiResponse<QaPostDetail>.Fail($"Post '{id}' not found"));

        var answers = await _qaService.GetAnswersAsync(id);
        return Ok(ApiResponse<QaPostDetail>.Ok(new QaPostDetail { Post = post, Answers = answers }));
    }

    /// <summary>Create QA post (requires auth)</summary>
    [HttpPost]
    public async Task<ActionResult<ApiResponse<QaPost>>> Create([FromBody] CreateQaPostRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<QaPost>.Fail("Unauthorized"));

        try
        {
            var user = await _userService.GetUserAsync(uid);
            var userName = user?.DisplayName ?? "";
            var userAvatar = user?.PhotoUrl ?? "";

            var post = await _qaService.CreatePostAsync(uid, userName, userAvatar, request);
            return CreatedAtAction(nameof(Get), new { id = post.Id },
                ApiResponse<QaPost>.Ok(post, "Post created successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<QaPost>.Fail(ex.Message));
        }
    }

    /// <summary>List answers for a post</summary>
    [HttpGet("{id}/answers")]
    public async Task<ActionResult<ApiResponse<List<QaAnswer>>>> GetAnswers(string id)
    {
        var post = await _qaService.GetPostAsync(id);
        if (post == null)
            return NotFound(ApiResponse<List<QaAnswer>>.Fail($"Post '{id}' not found"));

        var answers = await _qaService.GetAnswersAsync(id);
        return Ok(ApiResponse<List<QaAnswer>>.Ok(answers, $"{answers.Count} answers"));
    }

    /// <summary>Create answer (requires auth)</summary>
    [HttpPost("answers")]
    public async Task<ActionResult<ApiResponse<QaAnswer>>> CreateAnswer([FromBody] CreateQaAnswerRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<QaAnswer>.Fail("Unauthorized"));

        try
        {
            var user = await _userService.GetUserAsync(uid);
            var userName = user?.DisplayName ?? "";
            var userAvatar = user?.PhotoUrl ?? "";

            var answer = await _qaService.CreateAnswerAsync(uid, userName, userAvatar, request);
            return CreatedAtAction(null, ApiResponse<QaAnswer>.Ok(answer, "Answer created successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<QaAnswer>.Fail(ex.Message));
        }
    }

    /// <summary>Accept answer as correct (post author only)</summary>
    [HttpPost("answers/{id}/accept")]
    public async Task<ActionResult<ApiResponse<object>>> AcceptAnswer(string id)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        try
        {
            await _qaService.AcceptAnswerAsync(id, uid);
            return Ok(ApiResponse<object>.Ok(null, "Answer accepted"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<object>.Fail(ex.Message));
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(403, ApiResponse<object>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    /// <summary>Upvote a post</summary>
    [HttpPost("{id}/upvote")]
    public async Task<ActionResult<ApiResponse<object>>> UpvotePost(string id)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        try
        {
            await _qaService.UpvotePostAsync(id);
            return Ok(ApiResponse<object>.Ok(null, "Upvoted"));
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

    /// <summary>Upvote an answer</summary>
    [HttpPost("answers/{id}/upvote")]
    public async Task<ActionResult<ApiResponse<object>>> UpvoteAnswer(string id)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        try
        {
            await _qaService.UpvoteAnswerAsync(id);
            return Ok(ApiResponse<object>.Ok(null, "Upvoted"));
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

public class QaPostDetail
{
    public QaPost Post { get; set; } = new();
    public List<QaAnswer> Answers { get; set; } = new();
}
