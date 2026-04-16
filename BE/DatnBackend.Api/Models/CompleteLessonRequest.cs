namespace DatnBackend.Api.Models;

public class CompleteLessonRequest
{
    public string LessonId { get; set; } = "";
    public string TopicId { get; set; } = "";
    public int TimeSpentSeconds { get; set; }
}
