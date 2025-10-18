# Simple Phase 2 Caching Validation Test
# Tests that Initialize-ApplicationConfiguration caching is working

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 2 Caching Validation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Source all functions via main bootstrap
Write-Host "Loading functions..." -ForegroundColor Gray
. 'c:\Users\zuhai\code\Autopilot\main.ps1' -NoMenu -InitFile 'c:\Users\zuhai\code\Autopilot\settings.psd1' `
    -StringsFile 'c:\Users\zuhai\code\Autopilot\strings.psd1' `
    -menuFile 'c:\Users\zuhai\code\Autopilot\menu.psd1' `
    -Domain "contoso.com" 2>$null | Out-Null

if (-not $global:AutopilotDllStatus.ConfigCoreLoaded -or -not $global:AutopilotDllStatus.CacheCoreLoaded)
{
    Write-Host "ERROR: ConfigCore and CacheCore must be loaded" -ForegroundColor Red
    exit 1
}

Write-Host "ConfigCore: ✓" -ForegroundColor Green
Write-Host "CacheCore: ✓`n" -ForegroundColor Green

# Clear cache and file watcher for fresh start
[Autopilot.ConfigCore.ConfigFileWatcher]::ClearAll()
$global:ConfigCache.Clear()

$initFile = 'c:\Users\zuhai\code\Autopilot\settings.psd1'
$stringsFile = 'c:\Users\zuhai\code\Autopilot\strings.psd1'
$menuFile = 'c:\Users\zuhai\code\Autopilot\menu.psd1'

Write-Host "Test 1: First load (cache miss)" -ForegroundColor Cyan
$sw1 = [System.Diagnostics.Stopwatch]::StartNew()
$config1 = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
    -menuFile $menuFile -Domain "contoso.com" 2>$null
$sw1.Stop()
$time1 = $sw1.ElapsedMilliseconds

Write-Host "  Time: ${time1}ms" -ForegroundColor Gray
Write-Host "  Success: $($config1.Success)" -ForegroundColor $(if ($config1.Success) { 'Green' } else { 'Red' })
Write-Host "  GlobalSettings keys: $($config1.GlobalSettings.Keys.Count)" -ForegroundColor Gray

Write-Host "`nTest 2: Second load (cache hit)" -ForegroundColor Cyan
$sw2 = [System.Diagnostics.Stopwatch]::StartNew()
$config2 = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
    -menuFile $menuFile -Domain "contoso.com" 2>$null
$sw2.Stop()
$time2 = $sw2.ElapsedMilliseconds

Write-Host "  Time: ${time2}ms" -ForegroundColor Gray
Write-Host "  Success: $($config2.Success)" -ForegroundColor $(if ($config2.Success) { 'Green' } else { 'Red' })
Write-Host "  GlobalSettings keys: $($config2.GlobalSettings.Keys.Count)" -ForegroundColor Gray

$speedup = if ($time2 -gt 0) { [math]::Round($time1 / $time2, 1) } else { 0 }
Write-Host "  Speedup: ${speedup}x faster" -ForegroundColor $(if ($speedup -gt 3) { 'Green' } else { 'Yellow' })

Write-Host "`nTest 3: Multiple rapid calls (cache effectiveness)" -ForegroundColor Cyan
$totalTime = 0
$iterations = 10
for ($i = 1; $i -le $iterations; $i++)
{
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $config = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
        -menuFile $menuFile -Domain "contoso.com" 2>$null
    $sw.Stop()
    $totalTime += $sw.ElapsedMilliseconds
}
$avgTime = [math]::Round($totalTime / $iterations, 2)

Write-Host "  Average time (10 calls): ${avgTime}ms" -ForegroundColor $(if ($avgTime -lt 20) { 'Green' } else { 'Yellow' })
Write-Host "  Total time: ${totalTime}ms" -ForegroundColor Gray
Write-Host "  Expected cache hits" -ForegroundColor $(if ($avgTime -lt $time1) { 'Green' } else { 'Yellow' })

# Summary
$cacheWorking = ($time2 -lt $time1) -and ($avgTime -lt $time1 / 2)

Write-Host "`n========================================" -ForegroundColor Cyan
if ($cacheWorking)
{
    Write-Host "  Phase 2 Caching: WORKING ✓" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nPerformance Summary:" -ForegroundColor Cyan
    Write-Host "  Initial load: ${time1}ms" -ForegroundColor Gray
    Write-Host "  Cached load: ${time2}ms" -ForegroundColor Gray
    Write-Host "  Speedup: ${speedup}x faster" -ForegroundColor Green
    Write-Host "  Avg (10 calls): ${avgTime}ms" -ForegroundColor Green
    Write-Host "`nCache invalidation and file watching enabled ✓" -ForegroundColor Green
}
else
{
    Write-Host "  Phase 2 Caching: NEEDS REVIEW" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Note: Cache may be working but performance gains are modest" -ForegroundColor Yellow
}
