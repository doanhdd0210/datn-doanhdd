namespace DatnBackend.Api.Models;

public class Achievement
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "🏅";
    public string ConditionType { get; set; } = ""; // lessonCount | xpRequired | streakDays
    public int ConditionValue { get; set; }
    public int XpReward { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class CreateAchievementRequest
{
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "🏅";
    public string ConditionType { get; set; } = "";
    public int ConditionValue { get; set; }
    public int XpReward { get; set; }
    public bool IsActive { get; set; } = true;
}

public class UpdateAchievementRequest
{
    public string? Title { get; set; }
    public string? Description { get; set; }
    public string? Icon { get; set; }
    public string? ConditionType { get; set; }
    public int? ConditionValue { get; set; }
    public int? XpReward { get; set; }
    public bool? IsActive { get; set; }
}
