using FirebaseAdmin.Auth;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Middleware;

public class FirebaseAuthMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<FirebaseAuthMiddleware> _logger;

    // Paths that do not require any authentication
    private static readonly HashSet<string> PublicPaths =
    [
        "/health",
        "/",
        "/favicon.ico",
    ];

    // API paths that require authentication but NOT admin
    // (everything under /api that is not explicitly admin-only)
    // Admin enforcement is done per-controller for write operations.
    private static readonly HashSet<string> AdminOnlyPrefixes =
    [
        "/api/users",
        "/api/admins",
        "/api/notifications",
    ];

    public FirebaseAuthMiddleware(RequestDelegate next, ILogger<FirebaseAuthMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value ?? "";

        // Skip Swagger UI, health check and bootstrap
        if (path.StartsWith("/swagger", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("/bootstrap", StringComparison.OrdinalIgnoreCase)
            || PublicPaths.Contains(path))
        {
            await _next(context);
            return;
        }

        var authHeader = context.Request.Headers.Authorization.ToString();
        if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(
                ApiResponse<object>.Fail("Unauthorized: Bearer token is required"));
            return;
        }

        var token = authHeader["Bearer ".Length..].Trim();

        try
        {
            var decoded = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(token);

            decoded.Claims.TryGetValue("admin", out var adminClaim);
            var isAdmin = adminClaim is bool b && b
                       || adminClaim?.ToString() == "true";

            context.Items["FirebaseUid"] = decoded.Uid;
            context.Items["FirebaseEmail"] = decoded.Claims.GetValueOrDefault("email")?.ToString();
            context.Items["FirebaseIsAdmin"] = isAdmin;

            // For legacy admin-only API paths, enforce admin at middleware level
            bool isAdminOnlyPath = AdminOnlyPrefixes.Any(prefix =>
                path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));

            if (isAdminOnlyPath && !isAdmin)
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                await context.Response.WriteAsJsonAsync(
                    ApiResponse<object>.Fail("Forbidden: Admin access required"));
                return;
            }
        }
        catch (FirebaseAuthException ex)
        {
            _logger.LogWarning("Firebase token verification failed: {Message}", ex.Message);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(
                ApiResponse<object>.Fail($"Unauthorized: {ex.Message}"));
            return;
        }

        await _next(context);
    }
}
