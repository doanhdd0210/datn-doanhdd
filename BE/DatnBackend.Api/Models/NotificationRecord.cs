namespace DatnBackend.Api.Models;

public class NotificationRecord
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string Target { get; set; } = "";   // token | topic | uid | all
    public string? TargetValue { get; set; }
    public string SentByUid { get; set; } = "";
    public DateTime SentAt { get; set; }
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
}
