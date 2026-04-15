using FirebaseAdmin.Auth;
using DatnBackend.Api.Models;

namespace DatnBackend.Api.Middleware;

public class FirebaseAuthMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<FirebaseAuthMiddleware> _logger;

    // Các path không cần xác thực
    private static readonly HashSet<string> PublicPaths =
    [
        "/health",
        "/",
        "/favicon.ico",
    ];

    public FirebaseAuthMiddleware(RequestDelegate next, ILogger<FirebaseAuthMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value ?? "";

        // Bỏ qua Swagger UI, health check và bootstrap
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

            // Kiểm tra custom claim "admin"
            decoded.Claims.TryGetValue("admin", out var adminClaim);
            var isAdmin = adminClaim is bool b && b
                       || adminClaim?.ToString() == "true";

            if (!isAdmin)
            {
                context.Response.StatusCode = StatusCodes.Status403Forbidden;
                await context.Response.WriteAsJsonAsync(
                    ApiResponse<object>.Fail("Forbidden: Admin access required"));
                return;
            }

            context.Items["FirebaseUid"] = decoded.Uid;
            context.Items["FirebaseEmail"] = decoded.Claims.GetValueOrDefault("email")?.ToString();
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
