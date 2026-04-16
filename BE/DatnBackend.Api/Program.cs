using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Data;
using DatnBackend.Api.Middleware;
using DatnBackend.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Render (và các cloud platform) set PORT env var — ASP.NET Core cần listen đúng port đó
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://+:{port}");

// ─── Firebase Admin SDK (Auth + FCM) ─────────────────────────────────────────
var projectId = builder.Configuration["Firebase:ProjectId"]
    ?? throw new InvalidOperationException("Firebase:ProjectId is not configured.");

GoogleCredential credential;
var serviceAccountJson = Environment.GetEnvironmentVariable("FIREBASE_SERVICE_ACCOUNT_JSON");
if (!string.IsNullOrEmpty(serviceAccountJson))
{
    credential = GoogleCredential.FromJson(serviceAccountJson);
}
else
{
    var serviceAccountPath = builder.Configuration["Firebase:ServiceAccountPath"]
        ?? "firebase-service-account.json";
    if (!File.Exists(serviceAccountPath))
        throw new FileNotFoundException(
            $"Firebase service account không tìm thấy: '{serviceAccountPath}'. " +
            "Đặt file JSON hoặc set env var FIREBASE_SERVICE_ACCOUNT_JSON.");
    credential = GoogleCredential.FromFile(serviceAccountPath);
}

FirebaseApp.Create(new AppOptions
{
    Credential = credential,
    ProjectId = projectId,
});

// ─── PostgreSQL (EF Core) ─────────────────────────────────────────────────────
var pgConn = Environment.GetEnvironmentVariable("DATABASE_URL")
    ?? builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is not configured.");

// Render cung cấp DATABASE_URL dạng postgresql://user:pass@host:5432/db
// Npgsql cần convert sang key-value format và thêm SSL cho production
if (pgConn.StartsWith("postgresql://") || pgConn.StartsWith("postgres://"))
{
    var pgUri = new Uri(pgConn);
    var pgUserInfo = pgUri.UserInfo.Split(':', 2);
    var pgHost = pgUri.Host;
    var pgPort = pgUri.Port > 0 ? pgUri.Port : 5432;
    var pgDatabase = pgUri.AbsolutePath.TrimStart('/');
    var pgUsername = pgUserInfo.Length > 0 ? pgUserInfo[0] : "";
    var pgPassword = pgUserInfo.Length > 1 ? pgUserInfo[1] : "";
    pgConn = $"Host={pgHost};Port={pgPort};Database={pgDatabase};Username={pgUsername};Password={pgPassword};SSL Mode=Require;Trust Server Certificate=true";
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(pgConn, o => o.EnableRetryOnFailure()));

// ─── Redis Cache (optional — falls back to in-memory) ─────────────────────────
var redisConn = builder.Configuration.GetConnectionString("Redis")
    ?? Environment.GetEnvironmentVariable("REDIS_URL");

if (!string.IsNullOrEmpty(redisConn))
{
    builder.Services.AddStackExchangeRedisCache(options =>
    {
        options.Configuration = redisConn;
        options.InstanceName = "datn:";
    });
}
else
{
    builder.Services.AddDistributedMemoryCache();
}

builder.Services.AddScoped<ICacheService, CacheService>();

// ─── Application Services ─────────────────────────────────────────────────────
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<TopicService>();
builder.Services.AddScoped<LessonService>();
builder.Services.AddScoped<QuestionService>();
builder.Services.AddScoped<ProgressService>();
builder.Services.AddScoped<CodeSnippetService>();
builder.Services.AddScoped<QaService>();
builder.Services.AddScoped<FriendsService>();

// ─── CORS ─────────────────────────────────────────────────────────────────────
var allowedOrigins = builder.Configuration.GetSection("AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:5173", "http://localhost:3000", "http://localhost:4173"];

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.SetIsOriginAllowed(origin =>
            {
                if (origin.EndsWith(".vercel.app", StringComparison.OrdinalIgnoreCase)) return true;
                return allowedOrigins.Contains(origin, StringComparer.OrdinalIgnoreCase);
            })
              .AllowAnyHeader()
              .AllowAnyMethod());
});

// ─── Controllers + Swagger ────────────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new()
    {
        Title = "DATN Admin API",
        Version = "v1",
        Description = "Backend API cho hệ thống quản lý: Users, Admins, Push Notifications",
    });

    c.AddSecurityDefinition("Bearer", new()
    {
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Nhập Firebase ID Token: Bearer {token}",
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        BearerFormat = "JWT",
        Scheme = "bearer",
    });

    c.AddSecurityRequirement(new()
    {
        {
            new()
            {
                Reference = new()
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer",
                },
            },
            []
        }
    });
});

var app = builder.Build();

// ─── Auto-migrate database on startup ─────────────────────────────────────────
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();
}

// ─── Pipeline ─────────────────────────────────────────────────────────────────
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "DATN Admin API v1");
    c.RoutePrefix = "swagger";
});

app.UseCors();

// Health check (không cần auth)
app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    timestamp = DateTime.UtcNow,
    project = projectId,
}));

app.MapGet("/", () => Results.Redirect("/swagger"));

// Bootstrap: grant admin cho UID đầu tiên — chỉ dùng 1 lần, bảo vệ bằng BOOTSTRAP_SECRET
app.MapPost("/bootstrap/admin/{uid}", async (string uid, string? secret) =>
{
    var bootstrapSecret = Environment.GetEnvironmentVariable("BOOTSTRAP_SECRET");
    if (string.IsNullOrEmpty(bootstrapSecret) || secret != bootstrapSecret)
        return Results.Json(new { success = false, error = "Invalid secret" }, statusCode: 403);

    await FirebaseAdmin.Auth.FirebaseAuth.DefaultInstance
        .SetCustomUserClaimsAsync(uid, new Dictionary<string, object> { ["admin"] = true });
    return Results.Ok(new { success = true, message = $"Admin granted to {uid}" });
});

app.UseMiddleware<FirebaseAuthMiddleware>();

app.MapControllers();

app.Run();
