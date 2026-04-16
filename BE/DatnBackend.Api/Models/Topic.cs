namespace DatnBackend.Api.Models;

public class Topic
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = ""; // emoji or icon name
    public string Color { get; set; } = ""; // hex color
    public int Order { get; set; }
    public int TotalLessons { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
}
