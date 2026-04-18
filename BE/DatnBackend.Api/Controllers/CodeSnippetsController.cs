using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/code-snippets")]
[Produces("application/json")]
public class CodeSnippetsController : ControllerBase
{
    private readonly CodeSnippetService _codeSnippetService;

    public CodeSnippetsController(CodeSnippetService codeSnippetService)
    {
        _codeSnippetService = codeSnippetService;
    }

    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;
    private string? UserId => HttpContext.Items["FirebaseUid"]?.ToString();

    /// <summary>List all active code snippets (optional topicId filter)</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<CodeSnippet>>>> List([FromQuery] string? topicId = null)
    {
        var snippets = await _codeSnippetService.ListSnippetsAsync(topicId: topicId, activeOnly: true);
        return Ok(ApiResponse<List<CodeSnippet>>.Ok(snippets, $"{snippets.Count} snippets"));
    }

    /// <summary>Get code snippet by ID</summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<CodeSnippet>>> Get(string id)
    {
        var snippet = await _codeSnippetService.GetSnippetAsync(id);
        if (snippet == null)
            return NotFound(ApiResponse<CodeSnippet>.Fail($"CodeSnippet '{id}' not found"));
        return Ok(ApiResponse<CodeSnippet>.Ok(snippet));
    }

    /// <summary>Create code snippet (admin only)</summary>
    [HttpPost]
    public async Task<ActionResult<ApiResponse<CodeSnippet>>> Create([FromBody] CreateCodeSnippetRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<CodeSnippet>.Fail("Forbidden: Admin access required"));

        try
        {
            var snippet = await _codeSnippetService.CreateSnippetAsync(request);
            return CreatedAtAction(nameof(Get), new { id = snippet.Id },
                ApiResponse<CodeSnippet>.Ok(snippet, "Code snippet created successfully"));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<CodeSnippet>.Fail(ex.Message));
        }
    }

    /// <summary>Update code snippet (admin only)</summary>
    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<CodeSnippet>>> Update(string id, [FromBody] UpdateCodeSnippetRequest request)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<CodeSnippet>.Fail("Forbidden: Admin access required"));

        try
        {
            var snippet = await _codeSnippetService.UpdateSnippetAsync(id, request);
            return Ok(ApiResponse<CodeSnippet>.Ok(snippet, "Code snippet updated successfully"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<CodeSnippet>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<CodeSnippet>.Fail(ex.Message));
        }
    }

    /// <summary>Delete code snippet (admin only)</summary>
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(string id)
    {
        if (!IsAdmin)
            return StatusCode(403, ApiResponse<object>.Fail("Forbidden: Admin access required"));

        try
        {
            await _codeSnippetService.DeleteSnippetAsync(id);
            return Ok(ApiResponse<object>.Ok(null, "Code snippet deleted successfully"));
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

    /// <summary>Chạy code qua JDoodle</summary>
    [HttpPost("run")]
    public async Task<ActionResult<ApiResponse<RunCodeResult>>> Run(
        [FromBody] RunCodeRequest request,
        [FromServices] IHttpClientFactory httpFactory,
        [FromServices] IConfiguration config)
    {
        if (UserId == null) return Unauthorized(ApiResponse<RunCodeResult>.Fail("Unauthorized"));

        static (string lang, string version) MapLanguage(string lang) => lang switch
        {
            "java"       => ("java", "4"),
            "python"     => ("python3", "4"),
            "javascript" => ("nodejs", "4"),
            _            => (lang, "0"),
        };

        var (jdLang, versionIndex) = MapLanguage(request.Language);
        var clientId     = config["JDoodle:ClientId"]     ?? Environment.GetEnvironmentVariable("JDOODLE_CLIENT_ID");
        var clientSecret = config["JDoodle:ClientSecret"] ?? Environment.GetEnvironmentVariable("JDOODLE_CLIENT_SECRET");

        var body = JsonSerializer.Serialize(new
        {
            clientId,
            clientSecret,
            script       = request.Code,
            language     = jdLang,
            versionIndex,
            stdin        = request.Stdin,
        });

        try
        {
            var client = httpFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(30);
            var response = await client.PostAsync(
                "https://api.jdoodle.com/v1/execute",
                new StringContent(body, Encoding.UTF8, "application/json"));

            var responseBody = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                Console.WriteLine($"[JDoodle] HTTP {(int)response.StatusCode}: {responseBody}");
                return Ok(ApiResponse<RunCodeResult>.Ok(new RunCodeResult
                {
                    Stderr = "Compiler service unavailable. Try again.",
                    ExitCode = -1,
                    IsSuccess = false,
                }));
            }

            using var doc = JsonDocument.Parse(responseBody);
            var root = doc.RootElement;

            var output   = root.TryGetProperty("output",   out var o) ? o.GetString() ?? "" : "";
            var exitCode = root.TryGetProperty("statusCode", out var sc) ? sc.GetInt32() : 0;

            return Ok(ApiResponse<RunCodeResult>.Ok(new RunCodeResult
            {
                Stdout    = exitCode == 200 ? output : "",
                Stderr    = exitCode != 200 ? output : "",
                ExitCode  = exitCode == 200 ? 0 : 1,
                IsSuccess = exitCode == 200,
            }));
        }
        catch (Exception ex)
        {
            return Ok(ApiResponse<RunCodeResult>.Ok(new RunCodeResult
            {
                Stderr = $"Lỗi kết nối compiler: {ex.Message}",
                ExitCode = -1,
                IsSuccess = false,
            }));
        }
    }

    /// <summary>Submit practice result and award XP</summary>
    [HttpPost("practice-submit")]
    public async Task<ActionResult<ApiResponse<PracticeResult>>> SubmitPractice([FromBody] SubmitPracticeRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<PracticeResult>.Fail("Unauthorized"));

        try
        {
            var result = await _codeSnippetService.SubmitPracticeAsync(uid, request);
            var msg = result.IsPassed ? $"Practice passed! +{result.XpEarned} XP" : "Practice failed. Try again!";
            return Ok(ApiResponse<PracticeResult>.Ok(result, msg));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<PracticeResult>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<PracticeResult>.Fail(ex.Message));
        }
    }
}
