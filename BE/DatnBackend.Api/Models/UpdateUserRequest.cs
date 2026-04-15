namespace DatnBackend.Api.Models;

public class UpdateUserRequest
{
    public string? Email { get; set; }
    public string? DisplayName { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Password { get; set; }
    public bool? Disabled { get; set; }
    public bool? IsAdmin { get; set; }
}
