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

    public AiController(AiService ai)
    {
        _ai = ai;
    }

    /// <summary>Giải thích lỗi code thực hành</summary>
    [HttpPost("explain")]
    public async Task<ActionResult<ApiResponse<string>>> ExplainCode([FromBody] AiExplainRequest req)
    {
        var result = await _ai.ExplainCodeErrorAsync(req);
        return Ok(ApiResponse<string>.Ok(result));
    }

    /// <summary>Gợi ý hint cho câu hỏi quiz</summary>
    [HttpPost("hint")]
    public async Task<ActionResult<ApiResponse<string>>> QuizHint([FromBody] AiHintRequest req)
    {
        var result = await _ai.GenerateQuizHintAsync(req);
        return Ok(ApiResponse<string>.Ok(result));
    }

    /// <summary>Gợi ý câu trả lời cho Q&A</summary>
    [HttpPost("qa")]
    public async Task<ActionResult<ApiResponse<string>>> QaSuggest([FromBody] AiQaRequest req)
    {
        var result = await _ai.SuggestQaAnswerAsync(req);
        return Ok(ApiResponse<string>.Ok(result));
    }
}
