namespace DatnBackend.Api.Models;

public class PracticeResult
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string CodeSnippetId { get; set; } = "";
    public string SubmittedCode { get; set; } = "";
    public string ActualOutput { get; set; } = "";
    public bool IsPassed { get; set; }
    public int Score { get; set; }
    public int XpEarned { get; set; }
    public DateTime CompletedAt { get; set; }
}
