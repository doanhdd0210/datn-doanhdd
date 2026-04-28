using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class AiService
{
    private readonly HttpClient _http;
    private readonly ILogger<AiService> _logger;
    private readonly string _apiKey;

    private const string GeminiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent";

    public AiService(HttpClient http, ILogger<AiService> logger, IConfiguration config)
    {
        _http = http;
        _logger = logger;
        _apiKey = Environment.GetEnvironmentVariable("GEMINI_API_KEY")
                  ?? config["Gemini:ApiKey"]
                  ?? "";
    }

    private async Task<string> CallGeminiAsync(string prompt)
    {
        if (string.IsNullOrEmpty(_apiKey))
            return "Chưa cấu hình GEMINI_API_KEY trên server.";

        var body = new
        {
            contents = new[]
            {
                new { parts = new[] { new { text = prompt } } }
            },
            generationConfig = new { maxOutputTokens = 512, temperature = 0.4 }
        };

        var request = new HttpRequestMessage(HttpMethod.Post, $"{GeminiUrl}?key={_apiKey}");
        request.Content = new StringContent(
            JsonSerializer.Serialize(body),
            Encoding.UTF8,
            "application/json");

        try
        {
            var response = await _http.SendAsync(request);
            var json = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("Gemini error {Status}: {Body}", response.StatusCode, json);
                return $"Gemini lỗi {(int)response.StatusCode}: {json[..Math.Min(json.Length, 200)]}";
            }

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (!root.TryGetProperty("candidates", out var candidates) || candidates.GetArrayLength() == 0)
                return "AI không trả về kết quả. Thử lại sau.";

            return candidates[0]
                .GetProperty("content")
                .GetProperty("parts")[0]
                .GetProperty("text")
                .GetString() ?? "Không có phản hồi từ AI.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Gemini call failed");
            return "Không thể kết nối AI lúc này. Thử lại sau.";
        }
    }

    public async Task<string> ExplainCodeErrorAsync(AiExplainRequest req)
    {
        var prompt = $"""
            Bạn là trợ lý học lập trình. Học sinh đang học {req.Language}.

            Code mẫu (đúng):
            ```{req.Language}
            {req.ReferenceCode}
            ```

            Code của học sinh:
            ```{req.Language}
            {req.UserCode}
            ```

            Output mong đợi: "{req.ExpectedOutput}"
            Output thực tế: "{req.ActualOutput}"

            Hãy:
            1. Chỉ ra điểm sai cụ thể trong code của học sinh (ngắn gọn)
            2. Giải thích lý do tại sao sai
            3. Gợi ý cách sửa (đừng đưa code hoàn chỉnh, chỉ gợi ý)

            Trả lời bằng tiếng Việt, ngắn gọn dưới 150 từ.
            """;

        return await CallGeminiAsync(prompt);
    }

    public async Task<string> GenerateQuizHintAsync(AiHintRequest req)
    {
        var optionsList = req.Options
            .Select((opt, i) => $"{(char)('A' + i)}. {opt}")
            .Aggregate((a, b) => $"{a}\n{b}");

        var prompt = $"""
            Câu hỏi lập trình: "{req.Question}"

            Các đáp án:
            {optionsList}

            Đáp án đúng là: {(char)('A' + req.CorrectIndex)}

            Hãy đưa ra 1 gợi ý (hint) giúp học sinh suy nghĩ đúng hướng mà KHÔNG tiết lộ đáp án trực tiếp.
            Trả lời bằng tiếng Việt, tối đa 2 câu.
            """;

        return await CallGeminiAsync(prompt);
    }

    public async Task<string> SuggestQaAnswerAsync(AiQaRequest req)
    {
        var prompt = $"""
            Bạn là trợ lý học lập trình Java cho sinh viên.

            Câu hỏi: "{req.Title}"
            Nội dung: "{(string.IsNullOrWhiteSpace(req.Body) ? "Không có thêm thông tin" : req.Body)}"

            Hãy đưa ra câu trả lời hữu ích và chính xác về lập trình Java.
            Trả lời bằng tiếng Việt, rõ ràng, dưới 200 từ. Nếu cần ví dụ code, đưa ra đoạn code ngắn gọn.
            """;

        return await CallGeminiAsync(prompt);
    }
}
