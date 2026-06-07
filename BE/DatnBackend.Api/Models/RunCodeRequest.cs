using System.ComponentModel.DataAnnotations;

namespace DatnBackend.Api.Models;

public class RunCodeRequest
{
    [Required]
    public string Language { get; set; } = "java";

    [Required]
    [MaxLength(20_000, ErrorMessage = "Code không được vượt quá 20.000 ký tự (~20KB).")]
    public string Code { get; set; } = "";

    [MaxLength(2_000, ErrorMessage = "Stdin không được vượt quá 2.000 ký tự.")]
    public string Stdin { get; set; } = "";
}

public class RunCodeResult
{
    public string Stdout { get; set; } = "";
    public string Stderr { get; set; } = "";
    public int ExitCode { get; set; }
    public bool IsSuccess { get; set; }
}
