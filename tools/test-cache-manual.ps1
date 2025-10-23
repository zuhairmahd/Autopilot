# Simple test of cache functions
. .\functions\utilityFunctions\Get-CachedData.ps1

# Setup settings
$global:settings = @{
    cacheSettings = @{
        enabled                  = $true
        defaultExpirationMinutes = 15
        maxCacheSize             = 1000
        cacheTypes               = @{
            Configuration    = @{ enabled = $true; expirationMinutes = 60 }
            DirectoryObjects = @{ enabled = $true; expirationMinutes = 15 }
            Devices          = @{ enabled = $true; expirationMinutes = 15 }
        }
    }
}

Write-Host "Testing unified cache functions..." -ForegroundColor Cyan

# Test 1: Initialize
Write-Host "`nTest 1: Initialize cache" -ForegroundColor Yellow
Initialize-UnifiedCache
if ($global:UnifiedCache)
{
    Write-Host "  PASS: Cache initialized" -ForegroundColor Green
    Write-Host "  Cache types: $($global:UnifiedCache.Keys -join ', ')" -ForegroundColor Gray
}
else
{
    Write-Host "  FAIL: Cache not initialized" -ForegroundColor Red
}

# Test 2: Set data
Write-Host "`nTest 2: Set cached data" -ForegroundColor Yellow
$setResult = Set-CachedData -CacheType 'Configuration' -Key 'menu:main' -Data @{ Name = 'Main Menu' }
if ($setResult)
{
    Write-Host "  PASS: Data cached successfully" -ForegroundColor Green
}
else
{
    Write-Host "  FAIL: Data not cached" -ForegroundColor Red
}

# Test 3: Get data
Write-Host "`nTest 3: Get cached data" -ForegroundColor Yellow
$getData = Get-CachedData -CacheType 'Configuration' -Key 'menu:main'
if ($getData -and $getData.Name -eq 'Main Menu')
{
    Write-Host "  PASS: Retrieved correct data" -ForegroundColor Green
    Write-Host "  Data: $($getData.Name)" -ForegroundColor Gray
}
else
{
    Write-Host "  FAIL: Data not retrieved correctly" -ForegroundColor Red
}

# Test 4: Cache miss
Write-Host "`nTest 4: Cache miss" -ForegroundColor Yellow
$missData = Get-CachedData -CacheType 'Configuration' -Key 'nonexistent:key'
if ($null -eq $missData)
{
    Write-Host "  PASS: Returns null for missing key" -ForegroundColor Green
}
else
{
    Write-Host "  FAIL: Should return null for missing key" -ForegroundColor Red
}

# Test 5: Disabled caching
Write-Host "`nTest 5: Disabled caching" -ForegroundColor Yellow
$global:settings.cacheSettings.enabled = $false
$disabledSet = Set-CachedData -CacheType 'Configuration' -Key 'test:disabled' -Data 'Value'
if (-not $disabledSet)
{
    Write-Host "  PASS: Caching correctly disabled" -ForegroundColor Green
}
else
{
    Write-Host "  FAIL: Should not cache when disabled" -ForegroundColor Red
}
$global:settings.cacheSettings.enabled = $true

# Test 6: Clear cache
Write-Host "`nTest 6: Clear cache" -ForegroundColor Yellow
$beforeCount = $global:UnifiedCache.Configuration.Count
Clear-UnifiedCache -CacheType 'Configuration'
$afterCount = $global:UnifiedCache.Configuration.Count
if ($afterCount -eq 0 -and $beforeCount -gt 0)
{
    Write-Host "  PASS: Cache cleared successfully (was $beforeCount, now $afterCount)" -ForegroundColor Green
}
else
{
    Write-Host "  FAIL: Cache not cleared properly" -ForegroundColor Red
}

Write-Host "`nAll tests completed!" -ForegroundColor Cyan
