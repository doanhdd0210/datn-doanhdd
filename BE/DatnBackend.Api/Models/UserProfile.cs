namespace DatnBackend.Api.Models;

public class UserProfile
{
    public string Uid { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string? PhotoUrl { get; set; }
    public int TotalXp { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public int LessonsCompleted { get; set; }
    public string Rank { get; set; } = "Beginner";
    public string Level { get; set; } = "beginner";  // beginner | intermediate | advanced
    public List<string> FcmTokens { get; set; } = new();
}
