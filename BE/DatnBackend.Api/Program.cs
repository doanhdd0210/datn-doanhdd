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
    await db.Database.EnsureCreatedAsync();

    // Tạo bảng mới nếu chưa tồn tại (EnsureCreated không thêm table mới vào DB cũ)
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""UserNotifications"" (
            ""Id"" text NOT NULL PRIMARY KEY,
            ""UserId"" text NOT NULL,
            ""Type"" text NOT NULL,
            ""Title"" text NOT NULL,
            ""Body"" text NOT NULL,
            ""ActorId"" text,
            ""ActorName"" text,
            ""ActorAvatar"" text,
            ""RefId"" text,
            ""IsRead"" boolean NOT NULL DEFAULT false,
            ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT now()
        );
        ALTER TABLE ""UserNotifications"" ADD COLUMN IF NOT EXISTS ""RefId"" text;
        CREATE INDEX IF NOT EXISTS ""IX_UserNotifications_UserId_CreatedAt""
            ON ""UserNotifications"" (""UserId"", ""CreatedAt"" DESC);
    ");

    // Tạo bảng Achievements nếu chưa có
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""Achievements"" (
            ""Id"" text NOT NULL PRIMARY KEY,
            ""Title"" text NOT NULL DEFAULT '',
            ""Description"" text NOT NULL DEFAULT '',
            ""Icon"" text NOT NULL DEFAULT '🏅',
            ""ConditionType"" text NOT NULL DEFAULT '',
            ""ConditionValue"" integer NOT NULL DEFAULT 0,
            ""XpReward"" integer NOT NULL DEFAULT 0,
            ""IsActive"" boolean NOT NULL DEFAULT true,
            ""CreatedAt"" timestamp with time zone NOT NULL DEFAULT now()
        );
    ");

    // Tạo bảng UserAchievements nếu chưa có
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""UserAchievements"" (
            ""Id"" text NOT NULL PRIMARY KEY,
            ""UserId"" text NOT NULL,
            ""AchievementId"" text NOT NULL,
            ""UnlockedAt"" timestamp with time zone NOT NULL DEFAULT now(),
            ""IsNotified"" boolean NOT NULL DEFAULT false,
            CONSTRAINT ""UQ_UserAchievements_UserId_AchievementId"" UNIQUE (""UserId"", ""AchievementId"")
        );
        CREATE INDEX IF NOT EXISTS ""IX_UserAchievements_UserId""
            ON ""UserAchievements"" (""UserId"");
    ");

    // Add Level column to UserProfiles if not exists
    await db.Database.ExecuteSqlRawAsync(@"
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""Level"" text NOT NULL DEFAULT 'beginner';
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""IsAdmin"" boolean NOT NULL DEFAULT false;
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""LastSeenQaAt"" timestamp with time zone;
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""DailyGoalTarget"" integer NOT NULL DEFAULT 20;
        ALTER TABLE ""UserProfiles"" ADD COLUMN IF NOT EXISTS ""LastActiveAt"" timestamp with time zone;
    ");

    // Tạo bảng DailyGoalBonusClaims nếu chưa có
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""DailyGoalBonusClaims"" (
            ""Id"" text NOT NULL PRIMARY KEY,
            ""UserId"" text NOT NULL,
            ""Date"" text NOT NULL,
            ""GoalTarget"" integer NOT NULL DEFAULT 0,
            ""BonusXp"" integer NOT NULL DEFAULT 0,
            ""ClaimedAt"" timestamp with time zone NOT NULL DEFAULT now(),
            CONSTRAINT ""UQ_DailyGoalBonusClaims_UserId_Date"" UNIQUE (""UserId"", ""Date"")
        );
        CREATE INDEX IF NOT EXISTS ""IX_DailyGoalBonusClaims_UserId_Date""
            ON ""DailyGoalBonusClaims"" (""UserId"", ""Date"");
    ");

    // Tạo bảng AppSettings nếu chưa có
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""AppSettings"" (
            ""Key"" text NOT NULL PRIMARY KEY,
            ""Value"" text NOT NULL DEFAULT ''
        );
    ");

    // Seed giá trị mặc định daily goal bonuses nếu chưa có
    await db.Database.ExecuteSqlRawAsync(@"
        INSERT INTO ""AppSettings"" (""Key"", ""Value"") VALUES
            ('dailyGoalBonus:20',  '5'),
            ('dailyGoalBonus:50',  '15'),
            ('dailyGoalBonus:100', '35')
        ON CONFLICT (""Key"") DO NOTHING;
    ");

    // Tạo bảng UserSubscriptions
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""UserSubscriptions"" (
            ""UserId""        text NOT NULL PRIMARY KEY,
            ""PlanType""      text NOT NULL DEFAULT '',
            ""ProductId""     text NOT NULL DEFAULT '',
            ""PurchaseToken"" text NOT NULL DEFAULT '',
            ""OrderId""       text NOT NULL DEFAULT '',
            ""Platform""      text NOT NULL DEFAULT 'google_play',
            ""IsActive""      boolean NOT NULL DEFAULT true,
            ""IsTrial""       boolean NOT NULL DEFAULT false,
            ""PurchasedAt""   timestamp with time zone NOT NULL DEFAULT now(),
            ""ExpiresAt""     timestamp with time zone,
            ""UpdatedAt""     timestamp with time zone NOT NULL DEFAULT now()
        );
        ALTER TABLE ""UserSubscriptions"" ADD COLUMN IF NOT EXISTS ""IsTrial"" boolean NOT NULL DEFAULT false;
        ALTER TABLE ""UserSubscriptions"" ADD COLUMN IF NOT EXISTS ""WillRenew"" boolean NOT NULL DEFAULT true;

        INSERT INTO ""AppSettings"" (""Key"", ""Value"") VALUES
            ('subscription:package_name',        'doanhdd.javaup.mobile'),
            ('subscription:standard_product_id', 'vip_standard'),
            ('subscription:max_product_id',      'vip_max'),
            ('subscription:standard_price',      '29.000đ / tháng'),
            ('subscription:max_price',           '59.000đ / tháng'),
            ('subscription:trial_days',          '7')
        ON CONFLICT (""Key"") DO UPDATE
            SET ""Value"" = EXCLUDED.""Value""
            WHERE ""AppSettings"".""Value"" = '';
    ");

    // Tạo bảng AI usage tracking
    await db.Database.ExecuteSqlRawAsync(@"
        CREATE TABLE IF NOT EXISTS ""UserAiUsages"" (
            ""UserId"" text NOT NULL,
            ""Date"" date NOT NULL,
            ""Count"" integer NOT NULL DEFAULT 0,
            PRIMARY KEY (""UserId"", ""Date"")
        );

        CREATE TABLE IF NOT EXISTS ""UserAiLimits"" (
            ""UserId"" text NOT NULL PRIMARY KEY,
            ""DailyLimit"" integer NOT NULL DEFAULT 10
        );

        INSERT INTO ""AppSettings"" (""Key"", ""Value"") VALUES
            ('ai:default_daily_limit', '10')
        ON CONFLICT (""Key"") DO NOTHING;
    ");

    // Add CreatedAt to Questions if not exists, default existing rows to yesterday
    await db.Database.ExecuteSqlRawAsync(@"
        ALTER TABLE ""Questions"" ADD COLUMN IF NOT EXISTS ""CreatedAt"" timestamp with time zone;
        UPDATE ""Questions"" SET ""CreatedAt"" = now() - interval '1 day' WHERE ""CreatedAt"" IS NULL;
        ALTER TABLE ""Questions"" ALTER COLUMN ""CreatedAt"" SET NOT NULL;
        ALTER TABLE ""Questions"" ALTER COLUMN ""CreatedAt"" SET DEFAULT now();
    ");

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
