namespace DatnBackend.Api.Models;

public class AppUser
{
    public string Uid { get; set; } = "";
    public string? Email { get; set; }
    public string? DisplayName { get; set; }
    public string? PhotoUrl { get; set; }
    public string? PhoneNumber { get; set; }
    public bool Disabled { get; set; }
    public bool EmailVerified { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? LastSignInAt { get; set; }
    public bool IsAdmin { get; set; }
    public List<string> FcmTokens { get; set; } = [];
    public string? Provider { get; set; }
}
