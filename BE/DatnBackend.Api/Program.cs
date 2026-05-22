using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
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
    var pgUsername = pgUserInfo.Length > 0 ? Uri.UnescapeDataString(pgUserInfo[0]) : "";
    var pgPassword = pgUserInfo.Length > 1 ? Uri.UnescapeDataString(pgUserInfo[1]) : "";
    pgConn = $"Host={pgHost};Port={pgPort};Database={pgDatabase};Username={pgUsername};Password={pgPassword};SSL Mode=Require;Trust Server Certificate=true";
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(pgConn, o => o.EnableRetryOnFailure()));

// ─── In-memory Cache ───────────────────────────────────────────────────────────
builder.Services.AddDistributedMemoryCache();

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
builder.Services.AddScoped<AchievementsService>();
builder.Services.AddScoped<SettingsService>();
builder.Services.AddHttpClient<AiService>();
builder.Services.AddScoped<AiUsageService>();
builder.Services.AddScoped<SubscriptionService>();

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

// ─── HttpClient (dùng cho compiler proxy) ─────────────────────────────────────
builder.Services.AddHttpClient();

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
    var creator = db.Database.GetService<IRelationalDatabaseCreator>();

    // Check if core schema exists (UserProfiles is the central table)
    var conn = db.Database.GetDbConnection();
    if (conn.State != System.Data.ConnectionState.Open) await conn.OpenAsync();
    using var checkCmd = conn.CreateCommand();
    checkCmd.CommandText = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='UserProfiles'";
    var schemaExists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync()) > 0;

    if (!schemaExists)
    {
        // Fresh or broken DB: drop any partially-created tables so CreateTablesAsync starts clean
        await db.Database.ExecuteSqlRawAsync(@"
            DROP TABLE IF EXISTS ""Achievements"" CASCADE;
            DROP TABLE IF EXISTS ""UserAchievements"" CASCADE;
            DROP TABLE IF EXISTS ""UserNotifications"" CASCADE;
            DROP TABLE IF EXISTS ""DailyGoalBonusClaims"" CASCADE;
            DROP TABLE IF EXISTS ""AppSettings"" CASCADE;
            DROP TABLE IF EXISTS ""UserSubscriptions"" CASCADE;
            DROP TABLE IF EXISTS ""UserAiUsages"" CASCADE;
            DROP TABLE IF EXISTS ""UserAiLimits"" CASCADE;
        ");
        await creator.CreateTablesAsync();
    }

    // Schema patches — each wrapped individually so one failure doesn't block others
    try { await db.Database.ExecuteSqlRawAsync(@"
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""Level"" text NOT NULL DEFAULT 'beginner';
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""IsAdmin"" boolean NOT NULL DEFAULT false;
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""LastSeenQaAt"" timestamp with time zone;
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""DailyGoalTarget"" integer NOT NULL DEFAULT 20;
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""LastActiveAt"" timestamp with time zone;
    "); } catch { }

    try { await db.Database.ExecuteSqlRawAsync(@"
        ALTER TABLE ""UserNotifications"" ADD COLUMN IF NOT EXISTS ""RefId"" text;
        CREATE INDEX IF NOT EXISTS ""IX_UserNotifications_UserId_CreatedAt""
            ON ""UserNotifications"" (""UserId"", ""CreatedAt"" DESC);
    "); } catch { }

    try { await db.Database.ExecuteSqlRawAsync(@"
        ALTER TABLE ""UserSubscriptions"" ADD COLUMN IF NOT EXISTS ""IsTrial"" boolean NOT NULL DEFAULT false;
        ALTER TABLE ""UserSubscriptions"" ADD COLUMN IF NOT EXISTS ""WillRenew"" boolean NOT NULL DEFAULT true;
    "); } catch { }

    // Seed data — safe with ON CONFLICT DO NOTHING
    try { await db.Database.ExecuteSqlRawAsync(@"
        INSERT INTO ""AppSettings"" (""Key"", ""Value"") VALUES
            ('dailyGoalBonus:20',  '5'),
            ('dailyGoalBonus:50',  '15'),
            ('dailyGoalBonus:100', '35'),
            ('ai:default_daily_limit', '10'),
            ('subscription:package_name',        'doanhdd.javaup.mobile'),
            ('subscription:standard_product_id', 'vip_standard'),
            ('subscription:max_product_id',      'vip_max'),
            ('subscription:standard_price',      '29.000đ / tháng'),
            ('subscription:max_price',           '59.000đ / tháng'),
            ('subscription:trial_days',          '7')
        ON CONFLICT (""Key"") DO UPDATE
            SET ""Value"" = EXCLUDED.""Value""
            WHERE ""AppSettings"".""Value"" = '';
    "); } catch { }

    // Add CreatedAt to Questions if not exists, default existing rows to yesterday
    try { await db.Database.ExecuteSqlRawAsync(@"
        ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""CreatedAt"" timestamp with time zone;
        UPDATE ""Questions"" SET ""CreatedAt"" = now() - interval '1 day' WHERE ""CreatedAt"" IS NULL;
        ALTER TABLE ""Questions"" ALTER COLUMN ""CreatedAt"" SET NOT NULL;
        ALTER TABLE ""Questions"" ALTER COLUMN ""CreatedAt"" SET DEFAULT now();
    "); } catch { }

    // Sync IsAdmin flag from Firebase claims to UserProfiles
    try
    {
        var userService = scope.ServiceProvider.GetRequiredService<IUserService>();
        var admins = await userService.ListAdminsAsync();
        var adminUids = admins.Select(a => a.Uid).ToList();
        if (adminUids.Count > 0)
        {
            await db.UserProfiles
                .Where(p => adminUids.Contains(p.Uid))
                .ExecuteUpdateAsync(s => s.SetProperty(p => p.IsAdmin, true));
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning(ex, "Failed to sync admin flags to UserProfiles");
    }

    await DbSeeder.SeedAsync(db);
    await DbSeeder.SeedAchievementsAsync(db);
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
app.MapMethods("/health", ["GET", "HEAD"], () => Results.Ok(new
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
