using System.ComponentModel.DataAnnotations;

namespace DatnBackend.Api.Models;

public class TopicSubscriptionRequest
{
    [Required]
    public required List<string> Tokens { get; set; }

    [Required]
    public required string Topic { get; set; }
}
