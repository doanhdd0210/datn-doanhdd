namespace DatnBackend.Api.Models;

public class Question
{
    public string Id { get; set; } = "";
    public string LessonId { get; set; } = "";
    public string QuestionText { get; set; } = "";
    public List<string> Options { get; set; } = new(); // A, B, C, D options
    public int CorrectAnswerIndex { get; set; } // 0-based index
    public string Explanation { get; set; } = "";
    public int Order { get; set; }
    public int Points { get; set; } = 10;
}
