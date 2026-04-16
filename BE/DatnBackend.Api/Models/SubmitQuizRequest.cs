namespace DatnBackend.Api.Models;

public class SubmitQuizRequest
{
    public string LessonId { get; set; } = "";
    public List<UserAnswer> Answers { get; set; } = new();
    public int TimeSpentSeconds { get; set; }
}
