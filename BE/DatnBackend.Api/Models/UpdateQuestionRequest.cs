namespace DatnBackend.Api.Models;

public class UpdateQuestionRequest
{
    public string? LessonId { get; set; }
    public string? QuestionText { get; set; }
    public List<string>? Options { get; set; }
    public int? CorrectAnswerIndex { get; set; }
    public string? Explanation { get; set; }
    public int? Order { get; set; }
    public int? Points { get; set; }
}
