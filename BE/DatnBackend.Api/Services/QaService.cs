using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class QaService
{
    private readonly AppDbContext _db;
    private readonly ILogger<QaService> _logger;

    public QaService(AppDbContext db, ILogger<QaService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<QaPost>> ListPostsAsync(string? lessonId = null, int page = 1, int pageSize = 20)
    {
        var query = _db.QaPosts.AsQueryable();
        if (lessonId != null) query = query.Where(p => p.LessonId == lessonId);

        return await query
            .OrderByDescending(p => p.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();
    }

    public async Task<QaPost?> GetPostAsync(string id)
    {
        return await _db.QaPosts.FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task<QaPost> CreatePostAsync(string userId, string userName, string userAvatar, CreateQaPostRequest request)
    {
        var post = new QaPost
        {
            Id = Guid.NewGuid().ToString(),
            UserId = userId,
            UserName = userName,
            UserAvatar = userAvatar,
            Title = request.Title,
            Content = request.Content,
            LessonId = request.LessonId,
            Tags = request.Tags,
            AnswerCount = 0,
            UpvoteCount = 0,
            IsSolved = false,
            CreatedAt = DateTime.UtcNow,
        };

        _db.QaPosts.Add(post);
        await _db.SaveChangesAsync();
        return post;
    }

    public async Task<List<QaAnswer>> GetAnswersAsync(string postId)
    {
        return await _db.QaAnswers
            .Where(a => a.PostId == postId)
            .OrderByDescending(a => a.IsAccepted)
            .ThenBy(a => a.CreatedAt)
            .ToListAsync();
    }

    public async Task<QaAnswer> CreateAnswerAsync(string userId, string userName, string userAvatar, CreateQaAnswerRequest request)
    {
        var answer = new QaAnswer
        {
            Id = Guid.NewGuid().ToString(),
            PostId = request.PostId,
            UserId = userId,
            UserName = userName,
            UserAvatar = userAvatar,
            Content = request.Content,
            IsAccepted = false,
            UpvoteCount = 0,
            CreatedAt = DateTime.UtcNow,
        };

        _db.QaAnswers.Add(answer);

        // Increment answer count
        await _db.QaPosts
            .Where(p => p.Id == request.PostId)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.AnswerCount, p => p.AnswerCount + 1));

        await _db.SaveChangesAsync();
        return answer;
    }

    public async Task AcceptAnswerAsync(string answerId, string requestingUserId)
    {
        var answer = await _db.QaAnswers.FirstOrDefaultAsync(a => a.Id == answerId)
            ?? throw new KeyNotFoundException($"Answer '{answerId}' not found");

        var post = await _db.QaPosts.FirstOrDefaultAsync(p => p.Id == answer.PostId)
            ?? throw new KeyNotFoundException($"Post '{answer.PostId}' not found");

        if (post.UserId != requestingUserId)
            throw new UnauthorizedAccessException("Only the post author can accept an answer");

        // Unaccept all answers for this post, then accept the requested one
        await _db.QaAnswers
            .Where(a => a.PostId == post.Id && a.IsAccepted)
            .ExecuteUpdateAsync(s => s.SetProperty(a => a.IsAccepted, false));

        answer.IsAccepted = true;
        post.IsSolved = true;
        await _db.SaveChangesAsync();
    }

    public async Task UpvotePostAsync(string postId)
    {
        var rows = await _db.QaPosts
            .Where(p => p.Id == postId)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.UpvoteCount, p => p.UpvoteCount + 1));

        if (rows == 0)
            throw new KeyNotFoundException($"Post '{postId}' not found");
    }

    public async Task UpvoteAnswerAsync(string answerId)
    {
        var rows = await _db.QaAnswers
            .Where(a => a.Id == answerId)
            .ExecuteUpdateAsync(s => s.SetProperty(a => a.UpvoteCount, a => a.UpvoteCount + 1));

        if (rows == 0)
            throw new KeyNotFoundException($"Answer '{answerId}' not found");
    }
}
