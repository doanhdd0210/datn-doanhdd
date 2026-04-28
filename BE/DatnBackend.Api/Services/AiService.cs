using System.Text;
using System.Text.Json;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class AiService
{
    private readonly HttpClient _http;
    private readonly ILogger<AiService> _logger;
    private readonly string _apiKey;

    private const string GroqUrl = "https://api.groq.com/openai/v1/chat/completions";
    private const string Model = "llama-3.1-8b-instant";

    public AiService(HttpClient http, ILogger<AiService> logger, IConfiguration config)
    {
        _http = http;
        _logger = logger;
        _apiKey = Environment.GetEnvironmentVariable("GROQ_API_KEY")
                  ?? config["Groq:ApiKey"]
                  ?? "";
    }

    private async Task<string> CallGroqAsync(string prompt)
    {
        if (string.IsNullOrEmpty(_apiKey))
            return "Chưa cấu hình GROQ_API_KEY trên server.";

        var body = new
        {
            model = Model,
            messages = new[] { new { role = "user", content = prompt } },
            max_tokens = 512,
            temperature = 0.4
        };

        var request = new HttpRequestMessage(HttpMethod.Post, GroqUrl);
        request.Headers.Add("Authorization", $"Bearer {_apiKey}");
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
                _logger.LogWarning("Groq error {Status}: {Body}", response.StatusCode, json);
                return $"AI lỗi {(int)response.StatusCode}. Thử lại sau.";
            }

            using var doc = JsonDocument.Parse(json);
            return doc.RootElement
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString() ?? "Không có phản hồi từ AI.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Groq call failed");
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

        return await CallGroqAsync(prompt);
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

        return await CallGroqAsync(prompt);
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

        return await CallGroqAsync(prompt);
    }
}
