namespace DatnBackend.Api.Models;

public class SetLevelRequest
{
    public string Level { get; set; } = "beginner";
    public string? DisplayName { get; set; }
    public string? PhotoUrl { get; set; }
}
