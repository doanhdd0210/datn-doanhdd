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

    /// <summary>Chạy code trực tiếp trên server (Java/Python/Node)</summary>
    [HttpPost("run")]
    public async Task<ActionResult<ApiResponse<RunCodeResult>>> Run([FromBody] RunCodeRequest request)
    {
        if (UserId == null) return Unauthorized(ApiResponse<RunCodeResult>.Fail("Unauthorized"));

        var tmpDir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmpDir);
        try
        {
            RunCodeResult result = request.Language switch
            {
                "java"       => await RunJavaAsync(tmpDir, request.Code, request.Stdin),
                "python"     => await RunProcessAsync("python3", $"\"{Path.Combine(tmpDir, "main.py")}\"", request.Code, "main.py", tmpDir, request.Stdin),
                "javascript" => await RunProcessAsync("node",    $"\"{Path.Combine(tmpDir, "main.js")}\"",  request.Code, "main.js",  tmpDir, request.Stdin),
                _            => new RunCodeResult { Stderr = "Unsupported language.", ExitCode = -1, IsSuccess = false },
            };
            return Ok(ApiResponse<RunCodeResult>.Ok(result));
        }
        finally
        {
            try { Directory.Delete(tmpDir, true); } catch { }
        }
    }

    private static async Task<RunCodeResult> RunJavaAsync(string tmpDir, string code, string stdin)
    {
        var srcFile = Path.Combine(tmpDir, "Main.java");
        await System.IO.File.WriteAllTextAsync(srcFile, code);

        // Compile
        var compile = await ExecAsync("javac", $"-encoding UTF-8 \"{srcFile}\"", tmpDir, "", TimeSpan.FromSeconds(15));
        if (compile.exitCode != 0)
            return new RunCodeResult { Stderr = compile.stderr, ExitCode = compile.exitCode, IsSuccess = false };

        // Run
        var run = await ExecAsync("java", "-cp \".\" Main", tmpDir, stdin, TimeSpan.FromSeconds(10));
        return new RunCodeResult
        {
            Stdout    = run.stdout,
            Stderr    = run.stderr,
            ExitCode  = run.exitCode,
            IsSuccess = run.exitCode == 0,
        };
    }

    private static async Task<RunCodeResult> RunProcessAsync(string cmd, string args, string code, string fileName, string tmpDir, string stdin)
    {
        await System.IO.File.WriteAllTextAsync(Path.Combine(tmpDir, fileName), code);
        var run = await ExecAsync(cmd, args, tmpDir, stdin, TimeSpan.FromSeconds(10));
        return new RunCodeResult
        {
            Stdout    = run.stdout,
            Stderr    = run.stderr,
            ExitCode  = run.exitCode,
            IsSuccess = run.exitCode == 0,
        };
    }

    private static async Task<(string stdout, string stderr, int exitCode)> ExecAsync(
        string cmd, string args, string workDir, string stdin, TimeSpan timeout)
    {
        using var cts = new CancellationTokenSource(timeout);
        using var proc = new System.Diagnostics.Process();
        proc.StartInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName               = cmd,
            Arguments              = args,
            WorkingDirectory       = workDir,
            RedirectStandardInput  = true,
            RedirectStandardOutput = true,
            RedirectStandardError  = true,
            UseShellExecute        = false,
            CreateNoWindow         = true,
        };
        proc.Start();
        if (!string.IsNullOrEmpty(stdin))
        {
            await proc.StandardInput.WriteAsync(stdin);
        }
        proc.StandardInput.Close();

        var stdoutTask = proc.StandardOutput.ReadToEndAsync();
        var stderrTask = proc.StandardError.ReadToEndAsync();

        try { await proc.WaitForExitAsync(cts.Token); }
        catch (OperationCanceledException)
        {
            try { proc.Kill(true); } catch { }
            return ("", "Timeout: chương trình chạy quá lâu.", -1);
        }

        return (await stdoutTask, await stderrTask, proc.ExitCode);
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
