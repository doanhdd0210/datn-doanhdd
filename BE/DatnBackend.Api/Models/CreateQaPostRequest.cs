namespace DatnBackend.Api.Models;

public class CreateQaPostRequest
{
    public string Title { get; set; } = "";
    public string Content { get; set; } = "";
    public string? LessonId { get; set; }
    public List<string> Tags { get; set; } = new();
}
