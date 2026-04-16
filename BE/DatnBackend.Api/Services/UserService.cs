using FirebaseAdmin.Auth;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class UserService : IUserService
{
    private readonly FirebaseAuth _auth;
    private readonly AppDbContext _db;
    private readonly ILogger<UserService> _logger;

    public UserService(AppDbContext db, ILogger<UserService> logger)
    {
        _auth = FirebaseAuth.DefaultInstance;
        _db = db;
        _logger = logger;
    }

    public async Task<List<AppUser>> ListUsersAsync(int maxResults = 1000)
    {
        var users = new List<AppUser>();
        await foreach (var record in _auth.ListUsersAsync(null))
        {
            users.Add(MapUser(record));
            if (users.Count >= maxResults) break;
        }
        return users;
    }

    public async Task<AppUser?> GetUserAsync(string uid)
    {
        try
        {
            var record = await _auth.GetUserAsync(uid);
            var user = MapUser(record);

            var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == uid);
            if (profile != null)
                user.FcmTokens = profile.FcmTokens;

            return user;
        }
        catch (FirebaseAuthException ex)
        {
            _logger.LogWarning(ex, "User {Uid} not found", uid);
            return null;
        }
    }

    public async Task<AppUser> CreateUserAsync(CreateUserRequest request)
    {
        var args = new UserRecordArgs
        {
            Email = request.Email,
            Password = request.Password,
            DisplayName = request.DisplayName,
            PhoneNumber = string.IsNullOrEmpty(request.PhoneNumber) ? null : request.PhoneNumber,
            EmailVerified = false,
        };

        var record = await _auth.CreateUserAsync(args);

        if (request.IsAdmin)
            await SetAdminClaimAsync(record.Uid, true);

        var profile = new UserProfile
        {
            Uid = record.Uid,
            DisplayName = request.DisplayName ?? "",
            TotalXp = 0,
            CurrentStreak = 0,
            LongestStreak = 0,
            LessonsCompleted = 0,
            Rank = "Beginner",
            FcmTokens = new List<string>(),
        };
        _db.UserProfiles.Add(profile);
        await _db.SaveChangesAsync();

        return MapUser(record);
    }

    public async Task<AppUser> UpdateUserAsync(string uid, UpdateUserRequest request)
    {
        var args = new UserRecordArgs { Uid = uid };

        if (request.Email != null) args.Email = request.Email;
        if (request.DisplayName != null) args.DisplayName = request.DisplayName;
        if (request.PhoneNumber != null) args.PhoneNumber = request.PhoneNumber;
        if (request.Password != null) args.Password = request.Password;
        if (request.Disabled.HasValue) args.Disabled = request.Disabled.Value;

        var record = await _auth.UpdateUserAsync(args);

        if (request.IsAdmin.HasValue)
            await SetAdminClaimAsync(uid, request.IsAdmin.Value);

        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == uid);
        if (profile != null)
        {
            if (request.DisplayName != null) profile.DisplayName = request.DisplayName;
            await _db.SaveChangesAsync();
        }

        return MapUser(record);
    }

    public async Task DeleteUserAsync(string uid)
    {
        await _auth.DeleteUserAsync(uid);

        var profile = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == uid);
        if (profile != null)
        {
            _db.UserProfiles.Remove(profile);
            await _db.SaveChangesAsync();
        }
    }

    public async Task<AppUser> SetDisabledAsync(string uid, bool disabled)
    {
        var args = new UserRecordArgs { Uid = uid, Disabled = disabled };
        var record = await _auth.UpdateUserAsync(args);
        return MapUser(record);
    }

    public async Task SetAdminClaimAsync(string uid, bool isAdmin)
    {
        var claims = isAdmin
            ? new Dictionary<string, object> { ["admin"] = true }
            : new Dictionary<string, object>();
        await _auth.SetCustomUserClaimsAsync(uid, claims);
    }

    public async Task<List<AppUser>> ListAdminsAsync()
    {
        var all = await ListUsersAsync();
        return all.Where(u => u.IsAdmin).ToList();
    }

    public async Task<UserProfile?> GetUserProfileAsync(string uid)
    {
        return await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == uid);
    }

    public async Task<UserProfile> UpsertUserProfileAsync(string uid, UserProfile profile)
    {
        var existing = await _db.UserProfiles.FirstOrDefaultAsync(p => p.Uid == uid);
        if (existing == null)
        {
            profile.Uid = uid;
            _db.UserProfiles.Add(profile);
        }
        else
        {
            existing.DisplayName = profile.DisplayName;
            if (profile.PhotoUrl != null) existing.PhotoUrl = profile.PhotoUrl;
            existing.TotalXp = profile.TotalXp;
            existing.CurrentStreak = profile.CurrentStreak;
            existing.LongestStreak = profile.LongestStreak;
            existing.LessonsCompleted = profile.LessonsCompleted;
            existing.Rank = profile.Rank;
        }
        await _db.SaveChangesAsync();
        profile.Uid = uid;
        return profile;
    }

    private static AppUser MapUser(UserRecord record)
    {
        var isAdmin = record.CustomClaims?.TryGetValue("admin", out var v) == true
                      && (v is bool b && b || v?.ToString() == "true");

        return new AppUser
        {
            Uid = record.Uid,
            Email = record.Email,
            DisplayName = record.DisplayName,
            PhotoUrl = record.PhotoUrl,
            PhoneNumber = record.PhoneNumber,
            Disabled = record.Disabled,
            EmailVerified = record.EmailVerified,
            IsAdmin = isAdmin,
            CreatedAt = record.UserMetaData?.CreationTimestamp is DateTime createdAt
                ? createdAt
                : DateTime.UtcNow,
            LastSignInAt = record.UserMetaData?.LastSignInTimestamp is DateTime lastSignIn
                ? lastSignIn
                : null,
            Provider = record.ProviderData?.FirstOrDefault()?.ProviderId,
        };
    }
}
