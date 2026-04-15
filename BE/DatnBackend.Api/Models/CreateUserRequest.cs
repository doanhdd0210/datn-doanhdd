using System.ComponentModel.DataAnnotations;

namespace DatnBackend.Api.Models;

public class CreateUserRequest
{
    [Required, EmailAddress]
    public required string Email { get; set; }

    [Required, MinLength(6)]
    public required string Password { get; set; }

    public string? DisplayName { get; set; }
    public string? PhoneNumber { get; set; }
    public bool IsAdmin { get; set; }
}
