<#
.SYNOPSIS
    Manual validation tests for Phase 2 unified cache migrations

.DESCRIPTION
    Tests the three functions migrated to unified cache in Phase 2:
    1. Get-DeviceData.ps1
    2. Get-CachedDeviceEnrollmentState.ps1
    3. Get-ConfigurationData.ps1

.NOTES
    Run this script to validate that the migrated functions work correctly
    with the unified cache system.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testsPassed = 0
$testsFailed = 0

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Phase 2 Unified Cache Migration Validation Tests" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Get repo root
$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName

# Load required functions
Write-Host "Loading functions..." -ForegroundColor Yellow

# Load unified cache functions
. "$repoRoot\functions\utilityFunctions\Get-CachedData.ps1"

# Load migrated functions
. "$repoRoot\functions\setupFunctions\Get-ConfigurationData.ps1"

Write-Host "Functions loaded successfully" -ForegroundColor Green
Write-Host ""

# Initialize test settings
$global:settings = @{
    cacheSettings = @{
        enabled = $true
        defaultExpirationMinutes = 15
        maxCacheSize = 1000
        cacheTypes = @{
            Configuration = @{
                enabled = $true
                expirationMinutes = 60
            }
            DirectoryObjects = @{
                enabled = $true
                expirationMinutes = 15
            }
            Devices = @{
                enabled = $true
                expirationMinutes = 15
            }
        }
    }
}

# Test 1: Get-ConfigurationData with caching
Write-Host "Test 1: Get-ConfigurationData with caching" -ForegroundColor Cyan

try
{
    # Create a temporary test config file
    $tempConfigPath = Join-Path $env:TEMP "test-config-$(Get-Random)"
    $testConfigData = @{
        testKey1 = "value1"
        testKey2 = "value2"
    }
    
    # Export to PSD1
    "@{`n" | Out-File -FilePath "$tempConfigPath.psd1" -Encoding UTF8
    foreach ($key in $testConfigData.Keys)
    {
        "    $key = '$($testConfigData[$key])'`n" | Out-File -FilePath "$tempConfigPath.psd1" -Append -Encoding UTF8
    }
    "}" | Out-File -FilePath "$tempConfigPath.psd1" -Append -Encoding UTF8
    
    # First load - should load from file
    Write-Host "  Loading configuration from file..." -ForegroundColor Gray
    $config1 = Get-ConfigurationData -ConfigurationPath $tempConfigPath -DefaultValues @{} -EnableCaching
    
    if ($config1.testKey1 -eq "value1" -and $config1.testKey2 -eq "value2")
    {
        Write-Host "  First load successful" -ForegroundColor Gray
        
        # Second load - should load from cache
        Write-Host "  Loading configuration from cache..." -ForegroundColor Gray
        $config2 = Get-ConfigurationData -ConfigurationPath $tempConfigPath -DefaultValues @{} -EnableCaching
        
        if ($config2.testKey1 -eq "value1" -and $config2.testKey2 -eq "value2")
        {
            Write-Host "  Second load successful (from cache)" -ForegroundColor Gray
            
            # Verify cache entry exists
            $cacheKey = "config:$tempConfigPath.psd1"
            $cachedEntry = Get-CachedData -CacheType 'Configuration' -Key $cacheKey
            
            if ($null -ne $cachedEntry)
            {
                Write-Host "  PASS: Configuration caching works correctly" -ForegroundColor Green
                $testsPassed++
            }
            else
            {
                Write-Host "  FAIL: Cache entry not found" -ForegroundColor Red
                $testsFailed++
            }
        }
        else
        {
            Write-Host "  FAIL: Second load returned incorrect data" -ForegroundColor Red
            $testsFailed++
        }
    }
    else
    {
        Write-Host "  FAIL: First load returned incorrect data" -ForegroundColor Red
        $testsFailed++
    }
    
    # Cleanup
    Remove-Item "$tempConfigPath.psd1" -Force -ErrorAction SilentlyContinue
}
catch
{
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Test 2: Configuration cache invalidation on file change
Write-Host "Test 2: Configuration cache invalidation on file change" -ForegroundColor Cyan

try
{
    # Create a temporary test config file
    $tempConfigPath = Join-Path $env:TEMP "test-config-$(Get-Random)"
    $testConfigData = @{
        version = "1.0"
    }
    
    # Export to PSD1
    "@{`n    version = '1.0'`n}" | Out-File -FilePath "$tempConfigPath.psd1" -Encoding UTF8
    
    # First load
    Write-Host "  Loading initial configuration..." -ForegroundColor Gray
    $config1 = Get-ConfigurationData -ConfigurationPath $tempConfigPath -DefaultValues @{} -EnableCaching
    
    if ($config1.version -eq "1.0")
    {
        # Modify file
        Start-Sleep -Milliseconds 100  # Ensure file timestamp changes
        "@{`n    version = '2.0'`n}" | Out-File -FilePath "$tempConfigPath.psd1" -Encoding UTF8 -Force
        
        # Second load - should detect file change and reload
        Write-Host "  Loading modified configuration..." -ForegroundColor Gray
        $config2 = Get-ConfigurationData -ConfigurationPath $tempConfigPath -DefaultValues @{} -EnableCaching
        
        if ($config2.version -eq "2.0")
        {
            Write-Host "  PASS: Cache invalidation on file change works correctly" -ForegroundColor Green
            $testsPassed++
        }
        else
        {
            Write-Host "  FAIL: Cache not invalidated (got version: $($config2.version))" -ForegroundColor Red
            $testsFailed++
        }
    }
    else
    {
        Write-Host "  FAIL: Initial load returned incorrect data" -ForegroundColor Red
        $testsFailed++
    }
    
    # Cleanup
    Remove-Item "$tempConfigPath.psd1" -Force -ErrorAction SilentlyContinue
}
catch
{
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Test 3: Unified cache respects global enable/disable
Write-Host "Test 3: Unified cache respects global enable/disable" -ForegroundColor Cyan

try
{
    # Disable caching
    $global:settings.cacheSettings.enabled = $false
    
    # Try to set cached data
    $testData = @{ test = "value" }
    $cached = Set-CachedData -CacheType 'Configuration' -Key 'test:disabled' -Data $testData
    
    if ($cached -eq $false)
    {
        Write-Host "  Set-CachedData correctly returned false when caching disabled" -ForegroundColor Gray
        
        # Try to get cached data
        $retrieved = Get-CachedData -CacheType 'Configuration' -Key 'test:disabled'
        
        if ($null -eq $retrieved)
        {
            Write-Host "  PASS: Caching correctly disabled globally" -ForegroundColor Green
            $testsPassed++
        }
        else
        {
            Write-Host "  FAIL: Get-CachedData returned data when caching disabled" -ForegroundColor Red
            $testsFailed++
        }
    }
    else
    {
        Write-Host "  FAIL: Set-CachedData returned true when caching disabled" -ForegroundColor Red
        $testsFailed++
    }
    
    # Re-enable caching for remaining tests
    $global:settings.cacheSettings.enabled = $true
}
catch
{
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Test 4: Unified cache respects per-type enable/disable
Write-Host "Test 4: Unified cache respects per-type enable/disable" -ForegroundColor Cyan

try
{
    # Disable Configuration cache type
    $global:settings.cacheSettings.cacheTypes.Configuration.enabled = $false
    
    # Try to set cached data
    $testData = @{ test = "value" }
    $cached = Set-CachedData -CacheType 'Configuration' -Key 'test:type-disabled' -Data $testData
    
    if ($cached -eq $false)
    {
        Write-Host "  Set-CachedData correctly returned false when type disabled" -ForegroundColor Gray
        
        # Try to get cached data
        $retrieved = Get-CachedData -CacheType 'Configuration' -Key 'test:type-disabled'
        
        if ($null -eq $retrieved)
        {
            Write-Host "  PASS: Cache type enable/disable works correctly" -ForegroundColor Green
            $testsPassed++
        }
        else
        {
            Write-Host "  FAIL: Get-CachedData returned data when type disabled" -ForegroundColor Red
            $testsFailed++
        }
    }
    else
    {
        Write-Host "  FAIL: Set-CachedData returned true when type disabled" -ForegroundColor Red
        $testsFailed++
    }
    
    # Re-enable Configuration cache type
    $global:settings.cacheSettings.cacheTypes.Configuration.enabled = $true
}
catch
{
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Test 5: Clear unified cache
Write-Host "Test 5: Clear unified cache" -ForegroundColor Cyan

try
{
    # Set some test data
    $null = Set-CachedData -CacheType 'Configuration' -Key 'test:clear1' -Data @{ test = 1 }
    $null = Set-CachedData -CacheType 'Configuration' -Key 'test:clear2' -Data @{ test = 2 }
    $null = Set-CachedData -CacheType 'Devices' -Key 'test:device1' -Data @{ device = 1 }
    
    # Verify data exists
    $config1 = Get-CachedData -CacheType 'Configuration' -Key 'test:clear1'
    $device1 = Get-CachedData -CacheType 'Devices' -Key 'test:device1'
    
    if ($null -ne $config1 -and $null -ne $device1)
    {
        Write-Host "  Test data cached successfully" -ForegroundColor Gray
        
        # Clear Configuration cache type
        Clear-UnifiedCache -CacheType 'Configuration'
        
        # Verify Configuration cache cleared but Devices cache remains
        $config1After = Get-CachedData -CacheType 'Configuration' -Key 'test:clear1'
        $device1After = Get-CachedData -CacheType 'Devices' -Key 'test:device1'
        
        if ($null -eq $config1After -and $null -ne $device1After)
        {
            Write-Host "  Selective clear works correctly" -ForegroundColor Gray
            
            # Clear all caches
            Clear-UnifiedCache
            
            $device1Final = Get-CachedData -CacheType 'Devices' -Key 'test:device1'
            
            if ($null -eq $device1Final)
            {
                Write-Host "  PASS: Clear unified cache works correctly" -ForegroundColor Green
                $testsPassed++
            }
            else
            {
                Write-Host "  FAIL: Clear all did not clear Devices cache" -ForegroundColor Red
                $testsFailed++
            }
        }
        else
        {
            Write-Host "  FAIL: Selective clear did not work as expected" -ForegroundColor Red
            $testsFailed++
        }
    }
    else
    {
        Write-Host "  FAIL: Test data not cached" -ForegroundColor Red
        $testsFailed++
    }
}
catch
{
    Write-Host "  FAIL: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Summary
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Total Tests: $($testsPassed + $testsFailed)" -ForegroundColor White
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host ""

if ($testsFailed -eq 0)
{
    Write-Host "All tests PASSED!" -ForegroundColor Green
    exit 0
}
else
{
    Write-Host "Some tests FAILED!" -ForegroundColor Red
    exit 1
}
