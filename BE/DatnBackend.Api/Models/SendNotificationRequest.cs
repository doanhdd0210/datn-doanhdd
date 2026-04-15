using System.ComponentModel.DataAnnotations;

namespace DatnBackend.Api.Models;

public class SendNotificationRequest
{
    [Required]
    public required string Title { get; set; }

    [Required]
    public required string Body { get; set; }

    public string? ImageUrl { get; set; }
    public Dictionary<string, string>? Data { get; set; }

    // Target — chỉ chọn 1 trong 4:
    public string? Token { get; set; }    // FCM device token cụ thể
    public string? Topic { get; set; }    // Firebase topic
    public string? Uid { get; set; }      // UID người dùng (đọc token từ Firestore)
    public bool BroadcastAll { get; set; } // Gửi tới topic "all"
}
