namespace DatnBackend.Api.Models;

public class AiExplainRequest
{
    public string ReferenceCode { get; set; } = "";
    public string UserCode { get; set; } = "";
    public string ActualOutput { get; set; } = "";
    public string ExpectedOutput { get; set; } = "";
    public string Language { get; set; } = "java";
}

public class AiHintRequest
{
    public string Question { get; set; } = "";
    public List<string> Options { get; set; } = [];
    public int CorrectIndex { get; set; }
}

public class AiQaRequest
{
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
}
