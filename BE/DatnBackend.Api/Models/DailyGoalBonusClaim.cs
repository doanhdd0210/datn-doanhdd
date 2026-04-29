namespace DatnBackend.Api.Models;

/// <summary>Tracks daily goal bonus claims to prevent double-claiming</summary>
public class DailyGoalBonusClaim
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string Date { get; set; } = ""; // "yyyy-MM-dd"
    public int GoalTarget { get; set; }
    public int BonusXp { get; set; }
    public DateTime ClaimedAt { get; set; }
}
