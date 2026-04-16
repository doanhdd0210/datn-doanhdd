namespace DatnBackend.Api.Models;

public class CreateTopicRequest
{
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "";
    public string Color { get; set; } = "";
    public int Order { get; set; }
}
