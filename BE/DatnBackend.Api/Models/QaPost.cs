namespace DatnBackend.Api.Models;

public class QaPost
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string UserName { get; set; } = "";
    public string UserAvatar { get; set; } = "";
    public string Title { get; set; } = "";
    public string Content { get; set; } = "";
    public string? LessonId { get; set; } // optional, null if general
    public List<string> Tags { get; set; } = new();
    public int AnswerCount { get; set; }
    public int UpvoteCount { get; set; }
    public bool IsSolved { get; set; }
    public DateTime CreatedAt { get; set; }
}
