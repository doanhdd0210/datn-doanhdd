namespace DatnBackend.Api.Models;

/// <summary>Key-value store for app configuration</summary>
public class AppSetting
{
    public string Key { get; set; } = "";
    public string Value { get; set; } = "";
}
