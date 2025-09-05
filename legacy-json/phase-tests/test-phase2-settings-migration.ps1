#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for Phase 2 configuration storage optimization - Core PSD1 Migration
    
.DESCRIPTION
    Validates the Phase 2 migration including:
    - Successful settings.json to settings.psd1 conversion
    - Enhanced configuration loader with both formats
    - Performance comparison between formats
    - Backward compatibility verification
    - Integration with existing application functions
#>

# Import required modules and set up test environment
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Get script directory and navigate to repository root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
Set-Location $repoRoot

Write-Host "=== Phase 2 Configuration Storage Optimization Tests ===" -ForegroundColor Green
Write-Host "Testing settings.json to settings.psd1 migration and compatibility..." -ForegroundColor Yellow

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsTotal = 0

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$Message,
        [string]$FailureMessage = "Assertion failed"
    )
    
    $script:TestsTotal++
    
    if ($Condition) {
        Write-Host "✓ $Message" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "✗ $Message - $FailureMessage" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Measure-LoadTime {
    param(
        [string]$Description,
        [scriptblock]$ScriptBlock
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $result = & $ScriptBlock
    $stopwatch.Stop()
    
    Write-Host "[$Description] Load time: $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Cyan
    return @{
        Result = $result
        ElapsedMs = $stopwatch.ElapsedMilliseconds
    }
}

try {
    # Load all functions first
    Write-Host "`n--- Loading Functions ---" -ForegroundColor Yellow
    
    # Load existing functions
    Get-ChildItem -Path "./functions" -Recurse -Filter "*.ps1" | ForEach-Object {
        try {
            . $_.FullName
            Write-Verbose "Loaded: $($_.Name)"
        }
        catch {
            Write-Warning "Failed to load $($_.Name): $($_.Exception.Message)"
        }
    }
    
    # Test 1: Verify Settings Migration
    Write-Host "`n--- Test 1: Settings Migration Verification ---" -ForegroundColor Yellow
    
    # Check that settings files exist
    Test-Assert (Test-Path "./settings.json") "Original settings.json exists"
    Test-Assert (Test-Path "./settings.psd1") "Converted settings.psd1 exists"
    Test-Assert (Test-Path "./settings.json.backup") "Backup settings.json.backup exists"
    
    # Verify file sizes are reasonable
    $jsonSize = (Get-Item "./settings.json").Length
    $psd1Size = (Get-Item "./settings.psd1").Length
    $sizeRatio = [math]::Round(($psd1Size / $jsonSize) * 100, 1)
    
    Write-Host "JSON size: $jsonSize bytes, PSD1 size: $psd1Size bytes (Ratio: $sizeRatio%)" -ForegroundColor Cyan
    Test-Assert ($psd1Size -gt 0) "PSD1 file has content"
    Test-Assert ($sizeRatio -lt 150) "PSD1 file size is reasonable (less than 150% of JSON)"
    
    # Test 2: Format Detection and Loading
    Write-Host "`n--- Test 2: Format Detection and Loading ---" -ForegroundColor Yellow
    
    $jsonFormat = Test-ConfigurationFormat -FilePath "./settings.json"
    $psd1Format = Test-ConfigurationFormat -FilePath "./settings.psd1"
    
    Test-Assert ($jsonFormat -eq 'JSON') "JSON format detected correctly"
    Test-Assert ($psd1Format -eq 'PSD1') "PSD1 format detected correctly"
    
    # Test loading with format details
    $jsonDetails = Test-ConfigurationFormat -FilePath "./settings.json" -ReturnDetails -CheckCompatibility
    $psd1Details = Test-ConfigurationFormat -FilePath "./settings.psd1" -ReturnDetails -CheckCompatibility
    
    Test-Assert ($jsonDetails.IsValid -eq $true) "JSON file validates successfully"
    Test-Assert ($psd1Details.IsValid -eq $true) "PSD1 file validates successfully"
    Test-Assert ($jsonDetails.CompatibilityInfo.CrossPlatformCompatible -eq $true) "JSON marked as cross-platform"
    Test-Assert ($psd1Details.CompatibilityInfo.CrossPlatformCompatible -eq $false) "PSD1 marked as PowerShell-specific"
    
    # Test 3: Performance Comparison
    Write-Host "`n--- Test 3: Performance Comparison ---" -ForegroundColor Yellow
    
    $defaultSettings = @{
        version = "1.0.0"
        globalSettings = @{}
    }
    
    # Test JSON loading performance
    $jsonPerf = Measure-LoadTime "JSON Loading" {
        Get-ConfigurationData -ConfigurationPath "./settings.json" -DefaultValues $defaultSettings -PreferredFormat 'JSON'
    }
    
    # Test PSD1 loading performance  
    $psd1Perf = Measure-LoadTime "PSD1 Loading" {
        Get-ConfigurationData -ConfigurationPath "./settings.psd1" -DefaultValues $defaultSettings -PreferredFormat 'PSD1'
    }
    
    $perfImprovement = [math]::Round((($jsonPerf.ElapsedMs - $psd1Perf.ElapsedMs) / $jsonPerf.ElapsedMs) * 100, 1)
    Write-Host "Performance improvement: $perfImprovement%" -ForegroundColor $(if ($perfImprovement -gt 0) { 'Green' } else { 'Yellow' })
    
    Test-Assert ($psd1Perf.ElapsedMs -lt ($jsonPerf.ElapsedMs * 2)) "PSD1 loading time is reasonable"
    Test-Assert ($jsonPerf.Result.version -eq $psd1Perf.Result.version) "Both formats loaded same version"
    
    # Test 4: Content Validation
    Write-Host "`n--- Test 4: Content Validation ---" -ForegroundColor Yellow
    
    $jsonSettings = $jsonPerf.Result
    $psd1Settings = $psd1Perf.Result
    
    # Compare key fields
    Test-Assert ($jsonSettings.version -eq $psd1Settings.version) "Version matches between formats"
    Test-Assert ($jsonSettings.description -eq $psd1Settings.description) "Description matches between formats"
    
    # Check global settings
    if ($jsonSettings.globalSettings -and $psd1Settings.globalSettings) {
        Test-Assert ($jsonSettings.globalSettings.appMode -eq $psd1Settings.globalSettings.appMode) "AppMode matches between formats"
        Test-Assert ($jsonSettings.globalSettings.maxWaitTime -eq $psd1Settings.globalSettings.maxWaitTime) "MaxWaitTime matches between formats"
    }
    
    # Check auth settings
    if ($jsonSettings.auth -and $psd1Settings.auth) {
        Test-Assert ($jsonSettings.auth.authType -eq $psd1Settings.auth.authType) "AuthType matches between formats"
        Test-Assert ($jsonSettings.auth.delegated -eq $psd1Settings.auth.delegated) "Delegated setting matches between formats"
    }
    
    # Test array preservation (scopes)
    if ($jsonSettings.auth -and $jsonSettings.auth.scope -and $psd1Settings.auth -and $psd1Settings.auth.scope) {
        Test-Assert ($jsonSettings.auth.scope.Count -eq $psd1Settings.auth.scope.Count) "Scope array length matches"
        Test-Assert ($jsonSettings.auth.scope[0] -eq $psd1Settings.auth.scope[0]) "First scope entry matches"
    }
    
    # Test 5: Enhanced Loader with Auto-Detection
    Write-Host "`n--- Test 5: Enhanced Loader Auto-Detection ---" -ForegroundColor Yellow
    
    # Test auto-detection with both files present
    $autoSettings = Get-ConfigurationData -ConfigurationPath "./settings" -DefaultValues $defaultSettings -PreferredFormat 'Auto'
    Test-Assert ($autoSettings.version -eq $jsonSettings.version) "Auto-detection loaded correct version"
    
    # Test preference for PSD1
    $preferPsd1 = Get-ConfigurationData -ConfigurationPath "./settings" -DefaultValues $defaultSettings -PreferredFormat 'PSD1'
    Test-Assert ($preferPsd1.version -eq $psd1Settings.version) "PSD1 preference honored"
    
    # Test fallback mechanism - temporarily rename PSD1
    if (Test-Path "./settings.psd1") {
        Move-Item "./settings.psd1" "./settings.psd1.temp"
        
        $fallbackToJson = Get-ConfigurationData -ConfigurationPath "./settings" -DefaultValues $defaultSettings -PreferredFormat 'PSD1'
        Test-Assert ($fallbackToJson.version -eq $jsonSettings.version) "Fallback to JSON works when PSD1 missing"
        
        # Restore PSD1
        Move-Item "./settings.psd1.temp" "./settings.psd1"
    }
    
    # Test 6: Integration with Existing Functions
    Write-Host "`n--- Test 6: Integration with Existing Functions ---" -ForegroundColor Yellow
    
    # Test that existing Get-JsonConfiguration still works with JSON
    if (Get-Command Get-JsonConfiguration -ErrorAction SilentlyContinue) {
        try {
            $legacyJsonLoad = Get-JsonConfiguration -JsonFile "./settings.json" -DefaultValues $defaultSettings
            Test-Assert ($legacyJsonLoad.version -eq $jsonSettings.version) "Legacy Get-JsonConfiguration still works"
        }
        catch {
            Write-Warning "Legacy Get-JsonConfiguration test failed: $($_.Exception.Message)"
        }
    }
    
    # Test direct PSD1 loading with Import-PowerShellDataFile
    try {
        $directPsd1Load = Import-PowerShellDataFile -Path "./settings.psd1"
        Test-Assert ($directPsd1Load.version -eq $psd1Settings.version) "Direct PSD1 loading works"
        Test-Assert ($directPsd1Load -is [hashtable]) "Direct PSD1 loading returns hashtable"
    }
    catch {
        Write-Warning "Direct PSD1 loading test failed: $($_.Exception.Message)"
    }
    
    # Test 7: Backward Compatibility
    Write-Host "`n--- Test 7: Backward Compatibility ---" -ForegroundColor Yellow
    
    # Test that applications expecting JSON format still work
    $compatibilitySettings = @{
        version = "test"
        auth = @{ authType = "test" }
    }
    
    # Test loading from JSON path specifically
    $jsonSpecific = Get-ConfigurationData -ConfigurationPath "./settings.json" -DefaultValues $compatibilitySettings
    Test-Assert ($jsonSpecific.version -ne "test") "JSON-specific loading overrides defaults"
    
    # Test loading from PSD1 path specifically
    $psd1Specific = Get-ConfigurationData -ConfigurationPath "./settings.psd1" -DefaultValues $compatibilitySettings
    Test-Assert ($psd1Specific.version -ne "test") "PSD1-specific loading overrides defaults"
    
    # Test 8: Error Handling and Edge Cases
    Write-Host "`n--- Test 8: Error Handling and Edge Cases ---" -ForegroundColor Yellow
    
    # Test loading non-existent configuration
    $nonExistent = Get-ConfigurationData -ConfigurationPath "./non-existent-settings" -DefaultValues $defaultSettings
    Test-Assert ($nonExistent.version -eq $defaultSettings.version) "Non-existent file returns defaults"
    
    # Test loading with empty defaults
    $emptyDefaults = @{}
    $withEmptyDefaults = Get-ConfigurationData -ConfigurationPath "./settings" -DefaultValues $emptyDefaults
    Test-Assert ($withEmptyDefaults.version -eq $psd1Settings.version) "Loading with empty defaults still works"
    
    # Final Summary
    Write-Host "`n=== Test Summary ===" -ForegroundColor Green
    Write-Host "Total Tests: $script:TestsTotal" -ForegroundColor White
    Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
    Write-Host "Failed: $script:TestsFailed" -ForegroundColor Red
    
    $successRate = [math]::Round(($script:TestsPassed / $script:TestsTotal) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { 'Green' } elseif ($successRate -ge 75) { 'Yellow' } else { 'Red' })
    
    # Performance Summary
    Write-Host "`n=== Performance Summary ===" -ForegroundColor Green
    Write-Host "JSON Load Time: $($jsonPerf.ElapsedMs)ms" -ForegroundColor White
    Write-Host "PSD1 Load Time: $($psd1Perf.ElapsedMs)ms" -ForegroundColor White
    if ($perfImprovement -gt 0) {
        Write-Host "Performance Improvement: $perfImprovement%" -ForegroundColor Green
    } else {
        Write-Host "Performance Change: $perfImprovement%" -ForegroundColor Yellow
    }
    
    if ($script:TestsFailed -eq 0) {
        Write-Host "`n✓ All Phase 2 tests passed! Settings migration is successful." -ForegroundColor Green
        $exitCode = 0
    } else {
        Write-Host "`n✗ Some tests failed. Please review the failures before proceeding." -ForegroundColor Red
        $exitCode = 1
    }
}
catch {
    Write-Error "Test execution failed: $($_.Exception.Message)"
    $exitCode = 1
}

Write-Host "`nPhase 2 testing completed." -ForegroundColor Green
exit $exitCode