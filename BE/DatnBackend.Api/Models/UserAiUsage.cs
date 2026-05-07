namespace DatnBackend.Api.Models;

public class UserAiUsage
{
    public string UserId { get; set; } = "";
    public DateOnly Date { get; set; }
    public int Count { get; set; }
}
