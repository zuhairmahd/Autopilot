# Cache Improvement Plan for Autopilot

Summary
- Purpose: Provide a prioritized, actionable plan to improve the repository's caching system (security, correctness, performance, observability, and maintainability).
- Target branch: groupAssignments-enhancements
- Destination: docs/CACHE_IMPROVEMENT_PLAN.md

1. Goals and Constraints
- Goals:
  - Ensure token and sensitive data are stored securely and atomically when using on-disk caching.
  - Improve cache hit rates and eviction quality using an LRU policy.
  - Prevent cache stampedes (coalescing / singleflight behavior).
  - Add stale-while-revalidate support for low-latency reads.
  - Make caches pluggable (memory, file, Redis/SQLite) and configurable per cache type.
  - Improve observability (hit/miss, latency, evictions) and add machine-readable export.
- Constraints:
  - Maintain PowerShell 5.1 compatibility.
  - Keep changes non-breaking by providing defaults matching current behavior.

2. Prioritized Roadmap
- Phase 0 (Immediate, 1-3 days): Token file encryption + atomic writes, Add stronger logging and try/catch around cache operations.
- Phase 1 (Short, 1-2 weeks): Add in-flight singleflight request coalescing and basic LRU eviction for unified cache.
- Phase 2 (Medium, 2-4 weeks): Implement stale-while-revalidate for selected cache types and background refresh jobs.
- Phase 3 (Medium, 3-6 weeks): Pluggable backend abstraction (memory/file/redis/sqlite) and per-type persistence flags.
- Phase 4 (Ongoing): Improved observability, CI tests for concurrency, documentation and runtime UI controls.

3. Design Decisions (rationale)
- Use in-process hashtables for speed by default; offer optional external backends for multi-process scenarios.
- Prefer LRU eviction because it keeps frequently-used items.
- Use explicit global cacheSettings + per-type settings (already present) and add new flags: maxEntries, backend, staleWhileRevalidate (boolean), evictionPolicy.

4. Detailed Tasks and Implementation Examples

Task A — Secure atomic token file writes (high priority)
- What: When CacheType=file is used for tokens, always encrypt persisted tokens and write atomically.
- Why: Prevents partial writes and protects sensitive tokens.
- Implementation notes:
  - Use SecureString + ConvertFrom-SecureString for DPAPI encryption (per-user):

    $secure = ConvertTo-SecureString -String $plainText -AsPlainText -Force
    $encrypted = $secure | ConvertFrom-SecureString
    Set-Content -Path $tempFile -Value $encrypted -Force -Encoding UTF8
    Move-Item -Path $tempFile -Destination $finalFile -Force

  - Alternatively use Protect-CmsMessage for certificate-based protection if available.
  - Always write to a temp file (New-Guid or Get-TempFileName) then Move-Item -Force to replace atomically.
  - Honor NoSaveRefreshToken: do not persist refresh tokens when that flag is set.
- Files: functions/graphFunctions/GetGraphAccessToken.ps1, functions/utilityFunctions/Set-CachedData.ps1 (if persisting tokens through unified cache).

Task B — LRU eviction per cache type
- What: Replace FIFO 10% trimming with an LRU algorithm.
- Why: Retains hot items and improves hit rate.
- Implementation notes:
  - Maintain per-type hashtable for Data and a LinkedList/Array to track access order (most recent at head).
  - On Get: move key to head. On Set: add to head.
  - When limit exceeded, remove from tail until under maxEntries (or trimPercent).
- Example (conceptual PowerShell snippet):

    # Initialize
    if (-not $global:UnifiedCache) { Initialize-UnifiedCache }
    $cache = $global:UnifiedCache.Devices  # hashtable of entries
    $meta = $global:UnifiedCacheMeta.Devices  # contains List = [System.Collections.ArrayList]

    function Touch-Key($key) {
        $list = $meta.List
        if ($list.Contains($key)) { $list.Remove($key) }
        $list.Insert(0,$key)
    }

    function Evict-IfNeeded($maxEntries) {
        $list = $meta.List
        while ($list.Count -gt $maxEntries) {
            $tail = $list[$list.Count - 1]
            $cache.Remove($tail)
            $list.RemoveAt($list.Count - 1)
        }
    }

Task C — Singleflight / in-flight request coalescing
- What: Prevent multiple simultaneous requests for the same key from invoking duplicate expensive operations.
- Why: Avoids API throttling and redundant work.
- Implementation notes:
  - Maintain $global:UnifiedCache.InFlight hashtable mapping Key → PSCustomObject with Status and Result.
  - On Get-CachedData miss, before jumping to remote fetch, check InFlight:
    - If InFlight contains key and Status='Running', wait/poll until complete or timeout and return result.
    - If not present, create an InFlight entry with Status='Running' and perform fetch; store result into cache and set Status='Done'.
- Example (simplified):

    if ($global:UnifiedCache.InFlight[$key]) {
        # wait loop
        while ($global:UnifiedCache.InFlight[$key].Status -eq 'Running') { Start-Sleep -Milliseconds 100 }
        return $global:UnifiedCache.InFlight[$key].Result
    }
    else {
        $global:UnifiedCache.InFlight[$key] = @{ Status='Running'; Result=$null }
        try {
            $result = Fetch-From-Graph -Key $key
            Set-CachedData -CacheType 'DirectoryObjects' -Key $key -Data $result
            $global:UnifiedCache.InFlight[$key].Result = $result
        }
        finally { $global:UnifiedCache.InFlight[$key].Status = 'Done' }
        return $result
    }

Task D — Stale-while-revalidate (optional per-type)
- What: Serve stale cache entries while refreshing them in background.
- Implementation notes:
  - Store entries with fields: Data, FetchedAt, TTL, IsRefreshing
  - On Get: if expired but staleWithin tolerance, return stale data and trigger a background Start-Job or scheduled refresh to fetch and update cache.
  - Keep IsRefreshing to avoid multiple concurrent refresh jobs (use InFlight guard).
- Example:

    if ($cacheEntry.Expired -and $cacheEntry.StaleOk) {
        if (-not $cacheEntry.IsRefreshing) { Start-Job -ScriptBlock { Refresh-CacheForKey $key } }
        return $cacheEntry.Data  # stale
    }

Task E — File integrity & proactive invalidation
- What: Use LastWriteTimeUtc and optionally file hashes to validate file-backed caches. Use FileSystemWatcher for proactive invalidation.
- Implementation notes:
  - Compare LastWriteTimeUtc on access. For added safety compute Get-FileHash on save and compare.
  - Example: in Get-ConfigurationData, after reading cached entry, check (Get-Item $path).LastWriteTimeUtc -eq $cachedEntry.FileTimestampUtc.
  - For high-change dirs, use Register-ObjectEvent with FileSystemWatcher to Clear-UnifiedCache on change.

Task F — Pluggable backends and configuration
- What: Abstract storage backend behind functions Get-BackendData/Set-BackendData and implement memory (default), file, and Redis (optional) providers.
- Implementation notes:
  - Add $global:cacheSettings.cacheTypes.<Type>.backend = 'memory'|'file'|'redis'
  - Backend interface (PowerShell functions): Backend-Init, Backend-Get, Backend-Set, Backend-Remove, Backend-List, Backend-Clear
- Example config snippet (settings.psd1):

    cacheSettings = @{
        enabled = $true
        defaultExpirationMinutes = 15
        maxCacheSize = 1000
        cacheTypes = @{
            Configuration = @{ enabled = $true; expirationMinutes = 60; backend='memory' }
            DirectoryObjects = @{ enabled = $true; expirationMinutes = 15; backend='memory' }
            Devices = @{ enabled = $true; expirationMinutes = 15; backend='memory' }
        }
    }

Task G — Observability and metrics
- What: Extend $global:CacheStats to record evictions, avg latency per operation and top-N hot keys. Add an option to export stats as JSON for scraping.
- Implementation notes:
  - Add per-operation timing (Measure-Command or Get-Date timestamp differences) and aggregate to compute avg latency and P95.
  - Provide Invoke-CacheManagement -Action GetStatistics -Format JSON to output machine readable metrics.

Task H — Tests and CI
- What: Add unit and integration tests for LRU eviction, in-flight coalescing, stale-while-revalidate, and file-based encryption/read.
- Implementation notes:
  - Expand tests/Unit/Get-CachedData.Tests.ps1 to simulate concurrent callers using Start-Job and validate only one remote fetch occurs.
  - Add tests for atomic write/read of token files (write to temp then move), and encryption/decryption round trip.

5. Rollout & Migration Plan
- Keep changes behind feature flags in cacheSettings (e.g., evictionPolicy='fifo' or 'lru') to avoid breakage.
- Roll out in stages:
  1. Merge token encryption + atomic write.
  2. Merge in-flight coalescing with logs enabled.
  3. Enable LRU eviction for DirectoryObjects only by default and monitor stats.
  4. Add optional redis backend and test in staging.

6. Backout and Safety
- If unexpected regressions occur, switch cacheSettings.enabled = $false or set evictionPolicy back to 'fifo' and disable new features per-type.
- Keep metrics enabled to detect regressions quickly (hit rate drop, increased latency).

7. Estimated effort and owners (example)
- Token encryption & atomic writes: 1–2 days — Owner: @zuhairmahd
- In-flight singleflight: 2–3 days — Owner: Team member
- LRU eviction: 3–5 days — Owner: Team member
- Stale-while-revalidate: 3–7 days — Owner: Team member
- Backends (Redis/SQLite): 1–2 weeks — Owner: Team member
- Tests and CI: ongoing — Owner: Team member

8. Documentation & Examples to add
- Update docs/features/unified-cache-implementation.md with new settings, backend examples and code snippets.
- Add a new section in docs/CACHE_IMPROVEMENT_PLAN.md (this file) referencing concrete examples, and add a short README snippet showing how to enable/disable features at runtime using Invoke-CacheManagement.

Appendix: Useful code snippets & examples
- Atomic encrypted token write (PowerShell):

    $tempFile = Join-Path $env:TEMP (New-Guid).Guid + '.tmp'
    $secure = ConvertTo-SecureString -String $token -AsPlainText -Force
    $encrypted = $secure | ConvertFrom-SecureString
    Set-Content -Path $tempFile -Value $encrypted -Encoding UTF8 -Force
    Move-Item -Path $tempFile -Destination $tokenFile -Force

- Simple in-flight guard pattern (conceptual):

    if (-not $global:UnifiedCache.InFlight) { $global:UnifiedCache.InFlight = @{} }
    if ($global:UnifiedCache.InFlight[$key]) {
        while ($global:UnifiedCache.InFlight[$key].Status -eq 'Running') { Start-Sleep -Milliseconds 100 }
        return $global:UnifiedCache.InFlight[$key].Result
    }
    $global:UnifiedCache.InFlight[$key] = @{ Status='Running'; Result=$null }
    try { $result = Fetch(); Set-CachedData -CacheType $t -Key $k -Data $result; $global:UnifiedCache.InFlight[$key].Result = $result }
    finally { $global:UnifiedCache.InFlight[$key].Status='Done' }

- LRU Touch/Evict functions (conceptual) shown in Task B.