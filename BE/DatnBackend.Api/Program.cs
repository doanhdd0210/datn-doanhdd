using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;
using DatnBackend.Api.Middleware;
using DatnBackend.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Render (và các cloud platform) set PORT env var — ASP.NET Core cần listen đúng port đó
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.UseUrls($"http://+:{port}");

// ─── Firebase Admin SDK ───────────────────────────────────────────────────────
var projectId = builder.Configuration["Firebase:ProjectId"]
    ?? throw new InvalidOperationException("Firebase:ProjectId is not configured.");

// Hỗ trợ 2 cách cấu hình credentials:
// 1. FIREBASE_SERVICE_ACCOUNT_JSON (env var) — dùng khi deploy Railway/Cloud Run
// 2. Firebase:ServiceAccountPath (appsettings) — dùng khi chạy local
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

// ─── Firestore ────────────────────────────────────────────────────────────────
var firestoreDb = await new FirestoreDbBuilder
{
    ProjectId = projectId,
    Credential = credential,
}.BuildAsync();

builder.Services.AddSingleton(firestoreDb);

// ─── Application Services ─────────────────────────────────────────────────────
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<INotificationService, NotificationService>();

// ─── CORS ─────────────────────────────────────────────────────────────────────
var allowedOrigins = builder.Configuration.GetSection("AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:5173", "http://localhost:3000", "http://localhost:4173"];

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.SetIsOriginAllowed(origin =>
            {
                // Cho phép tất cả *.vercel.app (bao gồm preview URLs)
                if (origin.EndsWith(".vercel.app", StringComparison.OrdinalIgnoreCase)) return true;
                // Cho phép các origin đã cấu hình
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
app.MapPost("/bootstrap/admin/{uid}", async (string uid, string? secret, FirebaseAdmin.Auth.FirebaseAuth firebaseAuth) =>
{
    var bootstrapSecret = Environment.GetEnvironmentVariable("BOOTSTRAP_SECRET");
    if (string.IsNullOrEmpty(bootstrapSecret) || secret != bootstrapSecret)
        return Results.Json(new { success = false, error = "Invalid secret" }, statusCode: 403);

    await FirebaseAdmin.Auth.FirebaseAuth.DefaultInstance.SetCustomUserClaimsAsync(uid, new Dictionary<string, object> { ["admin"] = true });
    return Results.Ok(new { success = true, message = $"Admin granted to {uid}" });
});

app.UseMiddleware<FirebaseAuthMiddleware>();

app.MapControllers();

app.Run();
