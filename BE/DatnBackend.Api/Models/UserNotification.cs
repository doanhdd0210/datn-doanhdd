namespace DatnBackend.Api.Models;

public class UserNotification
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string UserId { get; set; } = "";          // người nhận
    public string Type { get; set; } = "";            // "follow" | "quiz_complete" | "system"
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string? ActorId { get; set; }              // người thực hiện hành động
    public string? ActorName { get; set; }
    public string? ActorAvatar { get; set; }
    public string? RefId { get; set; }              // postId / userId / achievementId
    public bool IsRead { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
