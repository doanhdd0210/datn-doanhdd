namespace DatnBackend.Api.Models;

public class UserFollow
{
    public string Id { get; set; } = "";
    public string FollowerId { get; set; } = "";
    public string FollowingId { get; set; } = "";
    public string FollowingName { get; set; } = "";
    public string FollowingAvatar { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}
