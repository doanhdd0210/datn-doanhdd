using System.Collections.Concurrent;
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

    // ── Giới hạn toàn server: tối đa 5 process đồng thời ────────────────────
    private static readonly SemaphoreSlim _execSemaphore = new(5, 5);

    // ── Rate limit: tối đa 15 lần /run mỗi phút mỗi user ────────────────────
    private static readonly ConcurrentDictionary<string, Queue<long>> _userRateMap = new();
    private const int RateLimitPerMinute = 15;

    // ── Giới hạn kích thước ──────────────────────────────────────────────────
    private const int MaxOutputBytes = 32_000;   // 32KB stdout+stderr

    // ── Từ khóa Java nguy hiểm bị cấm ───────────────────────────────────────
    private static readonly string[] JavaBlacklist =
    [
        "Runtime.getRuntime", "ProcessBuilder", "System.exit",
        "Runtime.exec",       "Process.exec",
        "FileWriter",         "FileOutputStream", "FileInputStream",
        "new File(",          "Files.write",      "Files.delete",  "Files.copy",
        "Socket(",            "ServerSocket(",     "DatagramSocket(",
        "URL(",               "URLConnection",     "HttpURLConnection",
        "Class.forName",      "ClassLoader",       "getClassLoader",
        "SecurityManager",    "System.setSecurityManager",
        "Thread.getAllStackTraces",
        "sun.misc.Unsafe",    "java.lang.reflect",
    ];

    public CodeSnippetsController(CodeSnippetService codeSnippetService)
    {
        _codeSnippetService = codeSnippetService;
    }

    private bool IsAdmin => HttpContext.Items.TryGetValue("FirebaseIsAdmin", out var v) && v is true;
    private string? UserId => HttpContext.Items["FirebaseUid"]?.ToString();

    /// <summary>List code snippets — admin sees all, users see active only</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<CodeSnippetDto>>>> List([FromQuery] string? topicId = null)
    {
        var snippets = await _codeSnippetService.ListSnippetsAsync(userId: UserId, topicId: topicId, activeOnly: !IsAdmin);
        return Ok(ApiResponse<List<CodeSnippetDto>>.Ok(snippets, $"{snippets.Count} snippets"));
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

        // ── 1. Rate limit per user ────────────────────────────────────────────
        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var queue = _userRateMap.GetOrAdd(UserId, _ => new Queue<long>());
        lock (queue)
        {
            while (queue.Count > 0 && now - queue.Peek() >= 60) queue.Dequeue();
            if (queue.Count >= RateLimitPerMinute)
                return StatusCode(429, ApiResponse<RunCodeResult>.Fail(
                    $"Quá giới hạn: tối đa {RateLimitPerMinute} lần chạy code mỗi phút."));
            queue.Enqueue(now);
        }

        // ── 2. Validate kích thước code ───────────────────────────────────────
        if (string.IsNullOrWhiteSpace(request.Code))
            return BadRequest(ApiResponse<RunCodeResult>.Fail("Code không được để trống."));

        // ── 3. Validate từ khóa nguy hiểm (chỉ áp dụng Java) ─────────────────
        if (request.Language == "java")
        {
            foreach (var keyword in JavaBlacklist)
            {
                if (request.Code.Contains(keyword, StringComparison.OrdinalIgnoreCase))
                    return BadRequest(ApiResponse<RunCodeResult>.Fail(
                        $"Code chứa từ khóa không được phép: '{keyword}'."));
            }
        }

        // ── 4. Giới hạn concurrent process toàn server ────────────────────────
        var acquired = await _execSemaphore.WaitAsync(TimeSpan.FromSeconds(8));
        if (!acquired)
            return StatusCode(503, ApiResponse<RunCodeResult>.Fail(
                "Server đang xử lý quá nhiều yêu cầu. Vui lòng thử lại sau vài giây."));

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
            _execSemaphore.Release();
            try { Directory.Delete(tmpDir, true); } catch { }
        }
    }

    private static async Task<RunCodeResult> RunJavaAsync(string tmpDir, string code, string stdin)
    {
        var srcFile = Path.Combine(tmpDir, "Main.java");
        await System.IO.File.WriteAllTextAsync(srcFile, code);

        // Compile (timeout 15s – javac chậm lần đầu)
        var compile = await ExecAsync("javac", $"-encoding UTF-8 \"{srcFile}\"", tmpDir, "", TimeSpan.FromSeconds(15));
        if (compile.exitCode != 0)
            return new RunCodeResult { Stderr = Truncate(compile.stderr), ExitCode = compile.exitCode, IsSuccess = false };

        // Run – giới hạn JVM 64MB heap, 10s timeout
        var run = await ExecAsync("java",
            "-Dfile.encoding=UTF-8 -Xmx64m -Xss512k -cp . Main",
            tmpDir, stdin, TimeSpan.FromSeconds(10));

        return new RunCodeResult
        {
            Stdout    = Truncate(run.stdout),
            Stderr    = Truncate(run.stderr),
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
            Stdout    = Truncate(run.stdout),
            Stderr    = Truncate(run.stderr),
            ExitCode  = run.exitCode,
            IsSuccess = run.exitCode == 0,
        };
    }

    // Cắt bớt output nếu quá MaxOutputBytes để tránh OOM
    private static string Truncate(string s)
    {
        if (string.IsNullOrEmpty(s) || s.Length <= MaxOutputBytes) return s;
        return s[..MaxOutputBytes] + $"\n[... output bị cắt bớt – vượt quá {MaxOutputBytes / 1000}KB ...]";
    }

    private static async Task<(string stdout, string stderr, int exitCode)> ExecAsync(
        string cmd, string args, string workDir, string stdin, TimeSpan timeout)
    {
        using var cts = new CancellationTokenSource(timeout);
        using var proc = new System.Diagnostics.Process();
        proc.StartInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName                = cmd,
            Arguments               = args,
            WorkingDirectory        = workDir,
            RedirectStandardInput   = true,
            RedirectStandardOutput  = true,
            RedirectStandardError   = true,
            UseShellExecute         = false,
            CreateNoWindow          = true,
            StandardOutputEncoding  = Encoding.UTF8,
            StandardErrorEncoding   = Encoding.UTF8,
        };
        proc.Start();

        if (!string.IsNullOrEmpty(stdin))
            await proc.StandardInput.WriteAsync(stdin);
        proc.StandardInput.Close();

        // Đọc stdout/stderr song song với timeout riêng (tránh hang sau khi kill)
        using var readCts = new CancellationTokenSource(timeout + TimeSpan.FromSeconds(3));
        var stdoutTask = proc.StandardOutput.ReadToEndAsync(readCts.Token).AsTask();
        var stderrTask = proc.StandardError.ReadToEndAsync(readCts.Token).AsTask();

        try
        {
            await proc.WaitForExitAsync(cts.Token);
        }
        catch (OperationCanceledException)
        {
            try { proc.Kill(entireProcessTree: true); } catch { }
            readCts.Cancel();
            return ("", "⏱ Timeout: chương trình chạy quá 10 giây và đã bị dừng.", -1);
        }

        string stdout = "", stderr = "";
        try { stdout = await stdoutTask; } catch { }
        try { stderr = await stderrTask; } catch { }

        return (stdout, stderr, proc.ExitCode);
    }

    /// <summary>Get list of snippet IDs the user has already passed</summary>
    [HttpGet("my-passed")]
    public async Task<ActionResult<ApiResponse<List<string>>>> GetMyPassed()
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<List<string>>.Fail("Unauthorized"));
        var ids = await _codeSnippetService.GetPassedSnippetIdsAsync(uid);
        return Ok(ApiResponse<List<string>>.Ok(ids));
    }

    /// <summary>Submit practice result and award XP based on best score improvement</summary>
    [HttpPost("practice-submit")]
    public async Task<ActionResult<ApiResponse<PracticeSubmitResponse>>> SubmitPractice([FromBody] SubmitPracticeRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<PracticeSubmitResponse>.Fail("Unauthorized"));

        try
        {
            var result = await _codeSnippetService.SubmitPracticeAsync(uid, request);
            var msg = result.XpEarned > 0 ? $"+{result.XpEarned} XP (best score: {result.BestScore})" : $"Best score: {result.BestScore}";
            return Ok(ApiResponse<PracticeSubmitResponse>.Ok(result, msg));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<PracticeSubmitResponse>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<PracticeSubmitResponse>.Fail(ex.Message));
        }
    }
}
