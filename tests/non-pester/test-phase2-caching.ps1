# Test Phase 2 Caching Implementation
# Tests Initialize-ApplicationConfiguration.ps1 with ConfigCore and CacheCore caching

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Phase 2 Caching Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Initialize DLLs
. 'c:\Users\zuhai\code\Autopilot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1'
$dllStatus = Initialize-AutopilotDlls -DLLPath 'c:\Users\zuhai\code\Autopilot\bin\Release'

Write-Host "`nDLL Status:" -ForegroundColor Cyan
Write-Host "  ConfigCore: $($dllStatus.ConfigCoreLoaded)" -ForegroundColor $(if ($dllStatus.ConfigCoreLoaded) { 'Green' } else { 'Red' })
Write-Host "  CacheCore: $($dllStatus.CacheCoreLoaded)" -ForegroundColor $(if ($dllStatus.CacheCoreLoaded) { 'Green' } else { 'Red' })

if (-not $dllStatus.ConfigCoreLoaded -or -not $dllStatus.CacheCoreLoaded)
{
    Write-Host "`nERROR: ConfigCore and CacheCore must be loaded for Phase 2 testing" -ForegroundColor Red
    exit 1
}

# Load required functions
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-ApplicationConfiguration.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-ConfigurationFiles.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-AuthConfiguration.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-GlobalSettings.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-LocalSettings.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-RequiredScopes.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-StringsConfiguration.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Initialize-MenuConfiguration.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Export-PowerShellDataFile.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\Save-DomainConfiguration.ps1'

# Mock Write-Log for testing
function Write-Log
{
    param([string]$logFile, [string]$Module, [string]$Message, [string]$LogLevel = "Information")
    # No-op for testing
}

# Set up test configuration files
$testRoot = "$env:TEMP\AutopilotPhase2Test_$(Get-Random)"
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$initFile = Join-Path $testRoot "settings.psd1"
$stringsFile = Join-Path $testRoot "strings.psd1"
$menuFile = Join-Path $testRoot "menu.psd1"

Write-Host "`nTest Environment:" -ForegroundColor Cyan
Write-Host "  Test Root: $testRoot" -ForegroundColor Gray

# Create minimal test configuration files
@"
@{
    auth = @{
        delegated = `$true
        authType = "PublicAuthFlow"
        scope = @("Device.ReadWrite.All")
    }
    globalSettings = @{
        maxRetries = 3
        timeout = 30
    }
}
"@ | Out-File -FilePath $initFile -Encoding UTF8

@"
@{
    appTitle = "Autopilot Test"
    welcomeMessage = "Welcome"
}
"@ | Out-File -FilePath $stringsFile -Encoding UTF8

@"
@{
    mainMenu = @{
        title = "Main Menu"
        items = @()
    }
}
"@ | Out-File -FilePath $menuFile -Encoding UTF8

Write-Host "`nTest 1: Initial Load (Cache Miss)" -ForegroundColor Cyan
# Clear cache and file watcher metadata
[Autopilot.ConfigCore.ConfigFileWatcher]::ClearAll()
$global:ConfigCache.Clear()

$sw1 = [System.Diagnostics.Stopwatch]::StartNew()
$result1 = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
    -menuFile $menuFile -Domain "test.com" -Verbose
$sw1.Stop()

Write-Host "  Success: $($result1.Success)" -ForegroundColor $(if ($result1.Success) { 'Green' } else { 'Red' })
Write-Host "  Time: $($sw1.ElapsedMilliseconds)ms" -ForegroundColor Gray
Write-Host "  Auth Keys: $($result1.Auth.Keys.Count)" -ForegroundColor $(if ($result1.Auth.Keys.Count -gt 0) { 'Green' } else { 'Red' })
Write-Host "  GlobalSettings Keys: $($result1.GlobalSettings.Keys.Count)" -ForegroundColor $(if ($result1.GlobalSettings.Keys.Count -gt 0) { 'Green' } else { 'Red' })

Write-Host "`nTest 2: Cached Load (Cache Hit)" -ForegroundColor Cyan
$sw2 = [System.Diagnostics.Stopwatch]::StartNew()
$result2 = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
    -menuFile $menuFile -Domain "test.com" -Verbose
$sw2.Stop()

Write-Host "  Success: $($result2.Success)" -ForegroundColor $(if ($result2.Success) { 'Green' } else { 'Red' })
Write-Host "  Time: $($sw2.ElapsedMilliseconds)ms" -ForegroundColor Gray
Write-Host "  Auth Keys: $($result2.Auth.Keys.Count)" -ForegroundColor $(if ($result2.Auth.Keys.Count -gt 0) { 'Green' } else { 'Red' })
Write-Host "  Speedup: $([math]::Round($sw1.ElapsedMilliseconds / $sw2.ElapsedMilliseconds, 1))x faster" -ForegroundColor $(if ($sw2.ElapsedMilliseconds -lt $sw1.ElapsedMilliseconds) { 'Green' } else { 'Yellow' })

Write-Host "`nTest 3: Cache Invalidation (File Modification)" -ForegroundColor Cyan
# Modify the settings file
Start-Sleep -Milliseconds 100  # Ensure file timestamp changes
@"
@{
    auth = @{
        delegated = `$true
        authType = "PublicAuthFlow"
        scope = @("Device.ReadWrite.All")
    }
    globalSettings = @{
        maxRetries = 5
        timeout = 60
    }
}
"@ | Out-File -FilePath $initFile -Encoding UTF8 -Force

$sw3 = [System.Diagnostics.Stopwatch]::StartNew()
$result3 = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
    -menuFile $menuFile -Domain "test.com" -Verbose
$sw3.Stop()

Write-Host "  Success: $($result3.Success)" -ForegroundColor $(if ($result3.Success) { 'Green' } else { 'Red' })
Write-Host "  Time: $($sw3.ElapsedMilliseconds)ms" -ForegroundColor Gray
Write-Host "  MaxRetries changed: $($result3.GlobalSettings.maxRetries -eq 5)" -ForegroundColor $(if ($result3.GlobalSettings.maxRetries -eq 5) { 'Green' } else { 'Red' })
Write-Host "  Detected file change: $(($sw3.ElapsedMilliseconds -ge $sw2.ElapsedMilliseconds))" -ForegroundColor $(if ($sw3.ElapsedMilliseconds -ge $sw2.ElapsedMilliseconds) { 'Green' } else { 'Yellow' })

Write-Host "`nTest 4: Cache Hit After Update" -ForegroundColor Cyan
$sw4 = [System.Diagnostics.Stopwatch]::StartNew()
$result4 = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
    -menuFile $menuFile -Domain "test.com" -Verbose
$sw4.Stop()

Write-Host "  Success: $($result4.Success)" -ForegroundColor $(if ($result4.Success) { 'Green' } else { 'Red' })
Write-Host "  Time: $($sw4.ElapsedMilliseconds)ms" -ForegroundColor Gray
Write-Host "  Using updated value: $($result4.GlobalSettings.maxRetries -eq 5)" -ForegroundColor $(if ($result4.GlobalSettings.maxRetries -eq 5) { 'Green' } else { 'Red' })
Write-Host "  Cached: $($sw4.ElapsedMilliseconds -lt $sw1.ElapsedMilliseconds)" -ForegroundColor $(if ($sw4.ElapsedMilliseconds -lt $sw1.ElapsedMilliseconds) { 'Green' } else { 'Yellow' })

Write-Host "`nTest 5: Multiple Rapid Calls (Cache Effectiveness)" -ForegroundColor Cyan
$totalTime = 0
$iterations = 10
for ($i = 1; $i -le $iterations; $i++)
{
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Initialize-ApplicationConfiguration -InitFile $initFile -StringsFile $stringsFile `
        -menuFile $menuFile -Domain "test.com"
    $sw.Stop()
    $totalTime += $sw.ElapsedMilliseconds
}
$avgTime = [math]::Round($totalTime / $iterations, 2)

Write-Host "  Total iterations: $iterations" -ForegroundColor Gray
Write-Host "  Average time: ${avgTime}ms" -ForegroundColor Green
Write-Host "  Expected cache hit: $($avgTime -lt 10)" -ForegroundColor $(if ($avgTime -lt 10) { 'Green' } else { 'Yellow' })

# Cleanup
Write-Host "`nCleanup:" -ForegroundColor Cyan
Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  Test directory removed" -ForegroundColor Gray

# Final summary
$allTestsPassed = ($result1.Success -and $result2.Success -and $result3.Success -and $result4.Success -and 
    $sw2.ElapsedMilliseconds -lt $sw1.ElapsedMilliseconds -and 
    $result3.GlobalSettings.maxRetries -eq 5 -and
    $avgTime -lt 10)

if ($allTestsPassed)
{
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  Phase 2 Caching: All Tests Passed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nPerformance Summary:" -ForegroundColor Cyan
    Write-Host "  Initial Load: $($sw1.ElapsedMilliseconds)ms" -ForegroundColor Gray
    Write-Host "  Cached Load: $($sw2.ElapsedMilliseconds)ms" -ForegroundColor Gray
    Write-Host "  Speedup: $([math]::Round($sw1.ElapsedMilliseconds / $sw2.ElapsedMilliseconds, 1))x faster" -ForegroundColor Green
    Write-Host "  Average (10 calls): ${avgTime}ms" -ForegroundColor Green
}
else
{
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  Phase 2 Caching: Some Issues Detected" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
}
