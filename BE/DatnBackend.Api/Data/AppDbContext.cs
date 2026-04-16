using Microsoft.EntityFrameworkCore;
using DatnBackend.Api.Models;
using System.Text.Json;

namespace DatnBackend.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<UserProfile> UserProfiles => Set<UserProfile>();
    public DbSet<Topic> Topics => Set<Topic>();
    public DbSet<Lesson> Lessons => Set<Lesson>();
    public DbSet<Question> Questions => Set<Question>();
    public DbSet<CodeSnippet> CodeSnippets => Set<CodeSnippet>();
    public DbSet<UserProgress> UserProgresses => Set<UserProgress>();
    public DbSet<QuizResult> QuizResults => Set<QuizResult>();
    public DbSet<PracticeResult> PracticeResults => Set<PracticeResult>();
    public DbSet<DailyProgress> DailyProgresses => Set<DailyProgress>();
    public DbSet<QaPost> QaPosts => Set<QaPost>();
    public DbSet<QaAnswer> QaAnswers => Set<QaAnswer>();
    public DbSet<UserFollow> UserFollows => Set<UserFollow>();
    public DbSet<NotificationRecord> NotificationHistory => Set<NotificationRecord>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var jsonOpts = new JsonSerializerOptions();

        // Map all DateTime properties to timestamptz (UTC)
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        foreach (var prop in entityType.GetProperties()
            .Where(p => p.ClrType == typeof(DateTime) || p.ClrType == typeof(DateTime?)))
        {
            prop.SetColumnType("timestamp with time zone");
        }

        // UserProfile — PK = Firebase UID (string)
        modelBuilder.Entity<UserProfile>(e =>
        {
            e.HasKey(p => p.Uid);
            e.Property(p => p.FcmTokens)
                .HasConversion(
                    v => JsonSerializer.Serialize(v, jsonOpts),
                    v => JsonSerializer.Deserialize<List<string>>(v, jsonOpts) ?? new())
                .HasColumnType("jsonb");
        });

        modelBuilder.Entity<Topic>(e => e.HasKey(t => t.Id));

        modelBuilder.Entity<Lesson>(e => e.HasKey(l => l.Id));

        modelBuilder.Entity<Question>(e =>
        {
            e.HasKey(q => q.Id);
            e.Property(q => q.Options)
                .HasConversion(
                    v => JsonSerializer.Serialize(v, jsonOpts),
                    v => JsonSerializer.Deserialize<List<string>>(v, jsonOpts) ?? new())
                .HasColumnType("jsonb");
            e.HasIndex(q => q.LessonId);
        });

        modelBuilder.Entity<CodeSnippet>(e => e.HasKey(c => c.Id));

        modelBuilder.Entity<UserProgress>(e =>
        {
            e.HasKey(p => p.Id);
            e.HasIndex(p => new { p.UserId, p.LessonId });
            e.HasIndex(p => new { p.UserId, p.TopicId });
        });

        modelBuilder.Entity<QuizResult>(e =>
        {
            e.HasKey(r => r.Id);
            e.HasIndex(r => new { r.UserId, r.LessonId });
            e.Property(r => r.Answers)
                .HasConversion(
                    v => JsonSerializer.Serialize(v, jsonOpts),
                    v => JsonSerializer.Deserialize<List<UserAnswer>>(v, jsonOpts) ?? new())
                .HasColumnType("jsonb");
        });

        modelBuilder.Entity<PracticeResult>(e =>
        {
            e.HasKey(r => r.Id);
            e.HasIndex(r => new { r.UserId, r.CodeSnippetId });
        });

        modelBuilder.Entity<DailyProgress>(e =>
        {
            e.HasKey(d => d.Id);
            e.HasIndex(d => new { d.UserId, d.Date }).IsUnique();
        });

        modelBuilder.Entity<QaPost>(e =>
        {
            e.HasKey(p => p.Id);
            e.Property(p => p.Tags)
                .HasConversion(
                    v => JsonSerializer.Serialize(v, jsonOpts),
                    v => JsonSerializer.Deserialize<List<string>>(v, jsonOpts) ?? new())
                .HasColumnType("jsonb");
        });

        modelBuilder.Entity<QaAnswer>(e =>
        {
            e.HasKey(a => a.Id);
            e.HasIndex(a => a.PostId);
        });

        modelBuilder.Entity<UserFollow>(e =>
        {
            e.HasKey(f => f.Id);
            e.HasIndex(f => new { f.FollowerId, f.FollowingId }).IsUnique();
        });

        modelBuilder.Entity<NotificationRecord>(e => e.HasKey(n => n.Id));
    }
}
