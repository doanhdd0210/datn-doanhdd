namespace DatnBackend.Api.Models;

public record PracticeSubmitResponse(int XpEarned, int BestScore);

public class SubmitPracticeRequest
{
    public string CodeSnippetId { get; set; } = "";
    public string SubmittedCode { get; set; } = "";
    public string ActualOutput { get; set; } = "";
    public bool IsPassed { get; set; }
    /// <summary>0.0 – 1.0, tỉ lệ code khớp với bài mẫu (tính phía mobile)</summary>
    public double MatchPercent { get; set; } = 0.0;
}
