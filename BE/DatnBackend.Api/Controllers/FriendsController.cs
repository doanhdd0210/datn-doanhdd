using Microsoft.AspNetCore.Mvc;
using DatnBackend.Api.Models;
using DatnBackend.Api.Services;

namespace DatnBackend.Api.Controllers;

[ApiController]
[Route("api/friends")]
[Produces("application/json")]
public class FriendsController : ControllerBase
{
    private readonly FriendsService _friendsService;

    public FriendsController(FriendsService friendsService)
    {
        _friendsService = friendsService;
    }

    private string? UserId => HttpContext.Items["FirebaseUid"]?.ToString();

    /// <summary>List users I follow</summary>
    [HttpGet("following")]
    public async Task<ActionResult<ApiResponse<List<UserFollow>>>> GetFollowing()
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<List<UserFollow>>.Fail("Unauthorized"));

        var following = await _friendsService.GetFollowingAsync(uid);
        return Ok(ApiResponse<List<UserFollow>>.Ok(following, $"{following.Count} following"));
    }

    /// <summary>List users who follow me</summary>
    [HttpGet("followers")]
    public async Task<ActionResult<ApiResponse<List<UserFollow>>>> GetFollowers()
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<List<UserFollow>>.Fail("Unauthorized"));

        var followers = await _friendsService.GetFollowersAsync(uid);
        return Ok(ApiResponse<List<UserFollow>>.Ok(followers, $"{followers.Count} followers"));
    }

    /// <summary>Follow a user</summary>
    [HttpPost("follow")]
    public async Task<ActionResult<ApiResponse<UserFollow>>> Follow([FromBody] FollowRequest request)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<UserFollow>.Fail("Unauthorized"));

        try
        {
            var follow = await _friendsService.FollowUserAsync(uid, request);
            return Ok(ApiResponse<UserFollow>.Ok(follow, "Followed successfully"));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<UserFollow>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<UserFollow>.Fail(ex.Message));
        }
    }

    /// <summary>Unfollow a user</summary>
    [HttpDelete("follow/{userId}")]
    public async Task<ActionResult<ApiResponse<object>>> Unfollow(string userId)
    {
        var uid = UserId;
        if (uid == null) return Unauthorized(ApiResponse<object>.Fail("Unauthorized"));

        try
        {
            await _friendsService.UnfollowUserAsync(uid, userId);
            return Ok(ApiResponse<object>.Ok(null, "Unfollowed successfully"));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(ApiResponse<object>.Fail(ex.Message));
        }
        catch (Exception ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    /// <summary>Get leaderboard - top users by XP</summary>
    [HttpGet("leaderboard")]
    public async Task<ActionResult<ApiResponse<List<LeaderboardEntry>>>> GetLeaderboard([FromQuery] int limit = 20)
    {
        var entries = await _friendsService.GetLeaderboardAsync(limit);
        return Ok(ApiResponse<List<LeaderboardEntry>>.Ok(entries));
    }
}
