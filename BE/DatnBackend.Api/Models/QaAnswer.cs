namespace DatnBackend.Api.Models;

public class QaAnswer
{
    public string Id { get; set; } = "";
    public string PostId { get; set; } = "";
    public string UserId { get; set; } = "";
    public string UserName { get; set; } = "";
    public string UserAvatar { get; set; } = "";
    public string Content { get; set; } = "";
    public bool IsAccepted { get; set; }
    public int UpvoteCount { get; set; }
    public DateTime CreatedAt { get; set; }
}
