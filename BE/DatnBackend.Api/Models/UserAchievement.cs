namespace DatnBackend.Api.Models;

public class UserAchievement
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string UserId { get; set; } = "";
    public string AchievementId { get; set; } = "";
    public DateTime UnlockedAt { get; set; } = DateTime.UtcNow;
    public bool IsNotified { get; set; } = false; // đã gửi in-app notification chưa
}
