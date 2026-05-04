namespace DatnBackend.Api.Models;

public class CodeSnippet
{
    public string Id { get; set; } = "";
    public string TopicId { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Code { get; set; } = "";
    public string Language { get; set; } = "java";
    public string ExpectedOutput { get; set; } = "";
    public int Order { get; set; }
    public int XpReward { get; set; } = 5;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
}

public class CodeSnippetDto(CodeSnippet s, bool isPassed, int bestScore = 0)
{
    public string Id { get; } = s.Id;
    public string TopicId { get; } = s.TopicId;
    public string Title { get; } = s.Title;
    public string Description { get; } = s.Description;
    public string Code { get; } = s.Code;
    public string Language { get; } = s.Language;
    public string ExpectedOutput { get; } = s.ExpectedOutput;
    public int Order { get; } = s.Order;
    public int XpReward { get; } = s.XpReward;
    public bool IsActive { get; } = s.IsActive;
    public bool IsPassed { get; } = isPassed;
    /// <summary>Điểm cao nhất user đạt được (0-100), 0 nếu chưa làm</summary>
    public int BestScore { get; } = bestScore;
}
