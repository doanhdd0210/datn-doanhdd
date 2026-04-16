namespace DatnBackend.Api.Models;

public class UserProgress
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string LessonId { get; set; } = "";
    public string TopicId { get; set; } = "";
    public bool IsCompleted { get; set; }
    public int Score { get; set; }
    public int XpEarned { get; set; }
    public DateTime CompletedAt { get; set; }
    public int TimeSpentSeconds { get; set; }
}
