namespace DatnBackend.Api.Models;

public class UserSubscription
{
    public string UserId { get; set; } = "";
    public string PlanType { get; set; } = ""; // "standard" | "max"
    public string ProductId { get; set; } = "";
    public string PurchaseToken { get; set; } = "";
    public string OrderId { get; set; } = "";
    public string Platform { get; set; } = "google_play";
    public bool IsActive { get; set; } = true;
    public bool IsTrial { get; set; } = false;
    public bool WillRenew { get; set; } = true;
    public DateTime PurchasedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ExpiresAt { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
