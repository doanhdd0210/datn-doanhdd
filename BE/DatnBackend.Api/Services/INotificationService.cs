using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public interface INotificationService
{
    Task<string> SendToTokenAsync(SendNotificationRequest request);
    Task<string> SendToTopicAsync(SendNotificationRequest request);
    Task<string> SendToTokensAsync(SendNotificationRequest request, List<string> tokens);
    Task<string> BroadcastAsync(SendNotificationRequest request);
    Task SubscribeToTopicAsync(List<string> tokens, string topic);
    Task UnsubscribeFromTopicAsync(List<string> tokens, string topic);
    Task<List<NotificationRecord>> GetHistoryAsync(int limit = 50);
}
