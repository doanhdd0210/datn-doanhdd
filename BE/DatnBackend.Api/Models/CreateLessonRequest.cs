namespace DatnBackend.Api.Models;

public class CreateLessonRequest
{
    public string TopicId { get; set; } = "";
    public string Title { get; set; } = "";
    public string Content { get; set; } = "";
    public string Summary { get; set; } = "";
    public int Order { get; set; }
    public int XpReward { get; set; } = 10;
    public int EstimatedMinutes { get; set; }
}
