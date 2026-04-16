using DatnBackend.Api.Models;

namespace DatnBackend.Api.Services;

public interface IUserService
{
    Task<List<AppUser>> ListUsersAsync(int maxResults = 1000);
    Task<AppUser?> GetUserAsync(string uid);
    Task<AppUser> CreateUserAsync(CreateUserRequest request);
    Task<AppUser> UpdateUserAsync(string uid, UpdateUserRequest request);
    Task DeleteUserAsync(string uid);
    Task<AppUser> SetDisabledAsync(string uid, bool disabled);
    Task SetAdminClaimAsync(string uid, bool isAdmin);
    Task<List<AppUser>> ListAdminsAsync();
    Task<UserProfile?> GetUserProfileAsync(string uid);
    Task<UserProfile> UpsertUserProfileAsync(string uid, UserProfile profile);
}
