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

    /// <summary>Chạy code qua Piston (proxy để tránh block từ mobile)</summary>
    [HttpPost("run")]
    public async Task<ActionResult<ApiResponse<RunCodeResult>>> Run(
        [FromBody] RunCodeRequest request,
        [FromServices] IHttpClientFactory httpFactory)
    {
        if (UserId == null) return Unauthorized(ApiResponse<RunCodeResult>.Fail("Unauthorized"));

        static string FileName(string lang) => lang switch
        {
            "java" => "Main.java",
            "python" => "main.py",
            "javascript" => "main.js",
            _ => $"main.{lang}",
        };

        var pistonBody = JsonSerializer.Serialize(new
        {
            language = request.Language,
            version = "*",
            files = new[] { new { name = FileName(request.Language), content = request.Code } },
            stdin = request.Stdin,
            compile_timeout = 10000,
            run_timeout = 5000,
        });

        try
        {
            var client = httpFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(30);
            var response = await client.PostAsync(
                "https://emkc.org/api/v2/piston/execute", // fallback: https://api.piston.rs/api/v2/execute
                new StringContent(pistonBody, Encoding.UTF8, "application/json"));

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                Console.WriteLine($"[Piston] HTTP {(int)response.StatusCode}: {errorBody}");
                return Ok(ApiResponse<RunCodeResult>.Ok(new RunCodeResult
                {
                    Stderr = "Compiler service unavailable. Try again.",
                    ExitCode = -1,
                    IsSuccess = false,
                }));
            }

            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            var root = doc.RootElement;

            // Compile error
            if (root.TryGetProperty("compile", out var compile) &&
                compile.TryGetProperty("code", out var cc) && cc.GetInt32() != 0)
            {
                var compileErr = compile.TryGetProperty("stderr", out var cs) ? cs.GetString() ?? ""
                               : compile.TryGetProperty("output", out var co) ? co.GetString() ?? "" : "";
                return Ok(ApiResponse<RunCodeResult>.Ok(new RunCodeResult
                {
                    Stderr = compileErr,
                    ExitCode = cc.GetInt32(),
                    IsSuccess = false,
                }));
            }

            var run = root.GetProperty("run");
            var exitCode = run.TryGetProperty("code", out var ec) ? ec.GetInt32() : 0;
            return Ok(ApiResponse<RunCodeResult>.Ok(new RunCodeResult
            {
                Stdout = run.TryGetProperty("stdout", out var so) ? so.GetString() ?? "" : "",
                Stderr = run.TryGetProperty("stderr", out var se) ? se.GetString() ?? "" : "",
                ExitCode = exitCode,
                IsSuccess = exitCode == 0,
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
