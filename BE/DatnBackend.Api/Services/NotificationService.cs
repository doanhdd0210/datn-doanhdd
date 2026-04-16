using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class NotificationService : INotificationService
{
    private readonly FirebaseMessaging _messaging;
    private readonly AppDbContext _db;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(AppDbContext db, ILogger<NotificationService> logger)
    {
        _messaging = FirebaseMessaging.DefaultInstance;
        _db = db;
        _logger = logger;
    }

    public async Task<string> SendToTokenAsync(SendNotificationRequest request)
    {
        var msg = BuildMessage(request);
        msg.Token = request.Token;
        var id = await _messaging.SendAsync(msg);
        await SaveHistoryAsync(request, "token", request.Token, true);
        return id;
    }

    public async Task<string> SendToTopicAsync(SendNotificationRequest request)
    {
        var msg = BuildMessage(request);
        msg.Topic = request.Topic;
        var id = await _messaging.SendAsync(msg);
        await SaveHistoryAsync(request, "topic", request.Topic, true);
        return id;
    }

    public async Task<string> SendToTokensAsync(SendNotificationRequest request, List<string> tokens)
    {
        var multicast = new MulticastMessage
        {
            Tokens = tokens,
            Notification = new Notification
            {
                Title = request.Title,
                Body = request.Body,
                ImageUrl = request.ImageUrl,
            },
            Data = request.Data,
            Android = new AndroidConfig
            {
                Priority = Priority.High,
                Notification = new AndroidNotification { Sound = "default", ChannelId = "default" },
            },
            Apns = new ApnsConfig { Aps = new Aps { Sound = "default", Badge = 1 } },
        };

        var response = await _messaging.SendEachForMulticastAsync(multicast);
        var result = $"{response.SuccessCount}/{tokens.Count} tokens";
        await SaveHistoryAsync(request, "uid", request.Uid, response.SuccessCount > 0);
        return result;
    }

    public async Task<string> BroadcastAsync(SendNotificationRequest request)
    {
        var msg = BuildMessage(request);
        msg.Topic = "all";
        var id = await _messaging.SendAsync(msg);
        await SaveHistoryAsync(request, "all", null, true);
        return id;
    }

    public async Task SubscribeToTopicAsync(List<string> tokens, string topic)
    {
        var response = await _messaging.SubscribeToTopicAsync(tokens, topic);
        _logger.LogInformation("Subscribed {Success}/{Total} to topic '{Topic}'",
            response.SuccessCount, tokens.Count, topic);
    }

    public async Task UnsubscribeFromTopicAsync(List<string> tokens, string topic)
    {
        var response = await _messaging.UnsubscribeFromTopicAsync(tokens, topic);
        _logger.LogInformation("Unsubscribed {Success}/{Total} from topic '{Topic}'",
            response.SuccessCount, tokens.Count, topic);
    }

    public async Task<List<NotificationRecord>> GetHistoryAsync(int limit = 50)
    {
        return await _db.NotificationHistory
            .OrderByDescending(n => n.SentAt)
            .Take(limit)
            .ToListAsync();
    }

    private async Task SaveHistoryAsync(SendNotificationRequest req, string target, string? targetValue, bool success)
    {
        try
        {
            _db.NotificationHistory.Add(new NotificationRecord
            {
                Id = Guid.NewGuid().ToString(),
                Title = req.Title,
                Body = req.Body,
                Target = target,
                TargetValue = targetValue,
                SentByUid = "",
                SentAt = DateTime.UtcNow,
                Success = success,
            });
            await _db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to save notification history");
        }
    }

    private static Message BuildMessage(SendNotificationRequest request) => new()
    {
        Notification = new Notification
        {
            Title = request.Title,
            Body = request.Body,
            ImageUrl = request.ImageUrl,
        },
        Data = request.Data,
        Android = new AndroidConfig
        {
            Priority = Priority.High,
            Notification = new AndroidNotification { Sound = "default", ChannelId = "default" },
        },
        Apns = new ApnsConfig { Aps = new Aps { Sound = "default", Badge = 1 } },
    };
}
