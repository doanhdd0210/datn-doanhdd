namespace DatnBackend.Api.Models;

public class QuizResult
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string LessonId { get; set; } = "";
    public int TotalQuestions { get; set; }
    public int CorrectAnswers { get; set; }
    public int Score { get; set; } // percentage
    public int XpEarned { get; set; }
    public List<UserAnswer> Answers { get; set; } = new();
    public DateTime CompletedAt { get; set; }
}

public class UserAnswer
{
    public string QuestionId { get; set; } = "";
    public int SelectedAnswerIndex { get; set; }
    public bool IsCorrect { get; set; }
}
