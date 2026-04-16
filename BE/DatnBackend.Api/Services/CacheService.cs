using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json;

namespace DatnBackend.Api.Services;

public class CacheService : ICacheService
{
    private readonly IDistributedCache _cache;
    private readonly ILogger<CacheService> _logger;
    private static readonly TimeSpan DefaultExpiry = TimeSpan.FromMinutes(5);

    public CacheService(IDistributedCache cache, ILogger<CacheService> logger)
    {
        _cache = cache;
        _logger = logger;
    }

    public async Task<T?> GetAsync<T>(string key) where T : class
    {
        try
        {
            var raw = await _cache.GetStringAsync(key);
            return raw is null ? null : JsonSerializer.Deserialize<T>(raw);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cache get failed: {Key}", key);
            return null;
        }
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expiry = null) where T : class
    {
        try
        {
            var options = new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = expiry ?? DefaultExpiry,
            };
            await _cache.SetStringAsync(key, JsonSerializer.Serialize(value), options);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Cache set failed: {Key}", key);
        }
    }

    public async Task RemoveAsync(params string[] keys)
    {
        foreach (var key in keys)
        {
            try { await _cache.RemoveAsync(key); }
            catch (Exception ex) { _logger.LogWarning(ex, "Cache remove failed: {Key}", key); }
        }
    }
}
