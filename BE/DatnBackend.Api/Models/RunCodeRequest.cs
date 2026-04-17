namespace DatnBackend.Api.Models;

public class RunCodeRequest
{
    public string Language { get; set; } = "java";
    public string Code { get; set; } = "";
    public string Stdin { get; set; } = "";
}

public class RunCodeResult
{
    public string Stdout { get; set; } = "";
    public string Stderr { get; set; } = "";
    public int ExitCode { get; set; }
    public bool IsSuccess { get; set; }
}
