namespace DatnBackend.Api.Models;

public class UpdateLessonRequest
{
    public string? TopicId { get; set; }
    public string? Title { get; set; }
    public string? Content { get; set; }
    public string? Summary { get; set; }
    public int? Order { get; set; }
    public int? XpReward { get; set; }
    public int? EstimatedMinutes { get; set; }
    public bool? IsActive { get; set; }
}
