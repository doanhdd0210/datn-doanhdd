namespace DatnBackend.Api.Models;

public class Lesson
{
    public string Id { get; set; } = "";
    public string TopicId { get; set; } = "";
    public string Title { get; set; } = "";
    public string Content { get; set; } = ""; // HTML or markdown content
    public string Summary { get; set; } = "";
    public int Order { get; set; }
    public int XpReward { get; set; } = 10;
    public int EstimatedMinutes { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
}
