namespace DatnBackend.Api.Models;

public class SubmitPracticeRequest
{
    public string CodeSnippetId { get; set; } = "";
    public string SubmittedCode { get; set; } = "";
    public string ActualOutput { get; set; } = "";
    public bool IsPassed { get; set; }
}
