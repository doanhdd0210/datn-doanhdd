using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/ai")]
[Produces("application/json")]
public class AiController : ControllerBase
{
    private readonly AiService _ai;
    private readonly AiUsageService _usage;

    public AiController(AiService ai, AiUsageService usage)
    {
        _ai = ai;
        _usage = usage;
    }

    private string GetUid() => HttpContext.Items["FirebaseUid"]?.ToString() ?? "";

    /// <summary>Trả về số lượt AI đã dùng hôm nay của user</summary>
    [HttpGet("usage")]
    public async Task<ActionResult<ApiResponse<AiUsageInfo>>> GetUsage()
    {
        var info = await _usage.GetUsageInfoAsync(GetUid());
        return Ok(ApiResponse<AiUsageInfo>.Ok(info));
    }

    /// <summary>Giải thích lỗi code thực hành</summary>
    [HttpPost("explain")]
    public async Task<ActionResult<ApiResponse<string>>> ExplainCode([FromBody] AiExplainRequest req)
    {
        try
        {
            await _usage.CheckAndIncrementAsync(GetUid());
        }
        catch (AiLimitExceededException ex)
        {
            return StatusCode(429, ApiResponse<string>.Fail(ex.Message));
        }

        var result = await _ai.ExplainCodeErrorAsync(req);
        return Ok(ApiResponse<string>.Ok(result));
    }

    /// <summary>Gợi ý hint cho câu hỏi quiz</summary>
    [HttpPost("hint")]
    public async Task<ActionResult<ApiResponse<string>>> QuizHint([FromBody] AiHintRequest req)
    {
        try
        {
            await _usage.CheckAndIncrementAsync(GetUid());
        }
        catch (AiLimitExceededException ex)
        {
            return StatusCode(429, ApiResponse<string>.Fail(ex.Message));
        }

        var result = await _ai.GenerateQuizHintAsync(req);
        return Ok(ApiResponse<string>.Ok(result));
    }

    /// <summary>Gợi ý câu trả lời cho Q&A</summary>
    [HttpPost("qa")]
    public async Task<ActionResult<ApiResponse<string>>> QaSuggest([FromBody] AiQaRequest req)
    {
        try
        {
            await _usage.CheckAndIncrementAsync(GetUid());
        }
        catch (AiLimitExceededException ex)
        {
            return StatusCode(429, ApiResponse<string>.Fail(ex.Message));
        }

        var result = await _ai.SuggestQaAnswerAsync(req);
        return Ok(ApiResponse<string>.Ok(result));
    }
}
