using FirebaseAdmin.Auth;
using Google.Cloud.Firestore;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public class UserService : IUserService
{
    private readonly FirebaseAuth _auth;
    private readonly FirestoreDb _db;
    private readonly ILogger<UserService> _logger;

    public UserService(FirestoreDb db, ILogger<UserService> logger)
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

            // Đọc FCM tokens từ Firestore
            var doc = await _db.Collection("users").Document(uid).GetSnapshotAsync();
            if (doc.Exists && doc.TryGetValue<List<string>>("fcmTokens", out var tokens))
                user.FcmTokens = tokens ?? [];

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

        // Tạo doc Firestore cho user mới
        await _db.Collection("users").Document(record.Uid).SetAsync(new Dictionary<string, object>
        {
            ["uid"] = record.Uid,
            ["email"] = request.Email,
            ["displayName"] = request.DisplayName ?? "",
            ["createdAt"] = Timestamp.GetCurrentTimestamp(),
            ["fcmTokens"] = new List<string>(),
            ["isAdmin"] = request.IsAdmin,
        });

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

        // Cập nhật Firestore
        var updates = new Dictionary<string, object>
        {
            ["updatedAt"] = Timestamp.GetCurrentTimestamp(),
        };
        if (request.DisplayName != null) updates["displayName"] = request.DisplayName;
        if (request.Email != null) updates["email"] = request.Email;
        if (request.IsAdmin.HasValue) updates["isAdmin"] = request.IsAdmin.Value;

        try
        {
            await _db.Collection("users").Document(uid).UpdateAsync(updates);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Firestore update skipped for {Uid}", uid);
        }

        return MapUser(record);
    }

    public async Task DeleteUserAsync(string uid)
    {
        await _auth.DeleteUserAsync(uid);
        try { await _db.Collection("users").Document(uid).DeleteAsync(); }
        catch (Exception ex) { _logger.LogWarning(ex, "Firestore delete skipped for {Uid}", uid); }
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
