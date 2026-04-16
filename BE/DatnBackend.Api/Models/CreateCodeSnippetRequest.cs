namespace DatnBackend.Api.Models;

public class CreateCodeSnippetRequest
{
    public string TopicId { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Code { get; set; } = "";
    public string Language { get; set; } = "java";
    public string ExpectedOutput { get; set; } = "";
    public int Order { get; set; }
    public int XpReward { get; set; } = 5;
}
