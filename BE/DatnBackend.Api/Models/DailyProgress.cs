namespace DatnBackend.Api.Models;

public class DailyProgress
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string Date { get; set; } = ""; // "yyyy-MM-dd"
    public int LessonsCompleted { get; set; }
    public int XpEarned { get; set; }
    public int TimeSpentSeconds { get; set; }
    public int Streak { get; set; }
}
