namespace DatnBackend.Api.Models;

public class QaPost
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string UserName { get; set; } = "";
    public string UserAvatar { get; set; } = "";
    public string Title { get; set; } = "";
    public string Content { get; set; } = "";
    public string? LessonId { get; set; } // optional, null if general
    public List<string> Tags { get; set; } = new();
    public int AnswerCount { get; set; }
    public int UpvoteCount { get; set; }
    public bool IsSolved { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class QaPostDto
{
    public string Id { get; init; } = "";
    public string UserId { get; init; } = "";
    public string UserName { get; init; } = "";
    public string UserAvatar { get; init; } = "";
    public string Title { get; init; } = "";
    public string Content { get; init; } = "";
    public string? LessonId { get; init; }
    public List<string> Tags { get; init; } = new();
    public int AnswerCount { get; init; }
    public int UpvoteCount { get; init; }
    public bool IsSolved { get; init; }
    public DateTime CreatedAt { get; init; }
    /// <summary>True nếu bài này chưa được user xem (tạo sau LastSeenQaAt và không phải của user)</summary>
    public bool IsNew { get; init; }

    public QaPostDto(QaPost post, string? viewerUserId, DateTime? lastSeenAt)
    {
        Id = post.Id; UserId = post.UserId; UserName = post.UserName;
        UserAvatar = post.UserAvatar; Title = post.Title; Content = post.Content;
        LessonId = post.LessonId; Tags = post.Tags; AnswerCount = post.AnswerCount;
        UpvoteCount = post.UpvoteCount; IsSolved = post.IsSolved; CreatedAt = post.CreatedAt;
        IsNew = viewerUserId != null
            && post.UserId != viewerUserId
            && (lastSeenAt == null || post.CreatedAt > lastSeenAt);
    }
}
