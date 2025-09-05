#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for Phase 1 configuration storage optimization - Migration infrastructure
    
.DESCRIPTION
    Validates the new migration infrastructure functions:
    - Convert-JsonToPsd1
    - Convert-Psd1ToJson  
    - Test-ConfigurationFormat
    - Get-ConfigurationData (enhanced loader)
    
    Tests cover format detection, conversion accuracy, error handling, and fallback mechanisms.
#>

# Import required modules and set up test environment
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Get script directory and navigate to repository root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
Set-Location $repoRoot

Write-Host "=== Phase 1 Configuration Storage Optimization Tests ===" -ForegroundColor Green
Write-Host "Testing migration infrastructure and format conversion functions..." -ForegroundColor Yellow

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

# Create temporary test directory
$tempBase = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
$testDir = Join-Path $tempBase "autopilot_phase1_test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Write-Host "Created test directory: $testDir" -ForegroundColor Cyan

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
    
    # Test 1: Format Detection
    Write-Host "`n--- Test 1: Format Detection ---" -ForegroundColor Yellow
    
    # Create test JSON file
    $testJsonPath = Join-Path $testDir "test.json"
    $testJsonData = @{
        key1 = "value1"
        key2 = @("item1", "item2")
        nested = @{
            subkey = "subvalue"
        }
    } | ConvertTo-Json -Depth 3
    
    $testJsonData | Set-Content -Path $testJsonPath -Encoding UTF8
    
    $detectedFormat = Test-ConfigurationFormat -FilePath $testJsonPath
    Test-Assert ($detectedFormat -eq 'JSON') "Detected JSON format correctly"
    
    # Test detailed format detection
    $details = Test-ConfigurationFormat -FilePath $testJsonPath -ReturnDetails -CheckCompatibility
    Test-Assert ($details.Format -eq 'JSON') "Detailed detection returned JSON format"
    Test-Assert ($details.IsValid -eq $true) "JSON file validated as valid"
    Test-Assert ($details.CompatibilityInfo.CrossPlatformCompatible -eq $true) "JSON marked as cross-platform compatible"
    
    # Test 2: JSON to PSD1 Conversion
    Write-Host "`n--- Test 2: JSON to PSD1 Conversion ---" -ForegroundColor Yellow
    
    $testPsd1Path = Join-Path $testDir "test.psd1"
    
    $convertedPath = Convert-JsonToPsd1 -JsonFilePath $testJsonPath -Psd1FilePath $testPsd1Path -Validate
    Test-Assert (Test-Path $convertedPath) "PSD1 file created successfully"
    Test-Assert ($convertedPath -eq $testPsd1Path) "Conversion returned correct path"
    
    # Verify PSD1 content can be loaded
    try {
        $loadedPsd1 = Import-PowerShellDataFile -Path $testPsd1Path
        Test-Assert ($loadedPsd1.key1 -eq "value1") "PSD1 key1 value preserved correctly"
        Test-Assert ($loadedPsd1.key2.Count -eq 2) "PSD1 array preserved correctly"
        Test-Assert ($loadedPsd1.nested.subkey -eq "subvalue") "PSD1 nested structure preserved"
    }
    catch {
        Test-Assert $false "PSD1 file loading failed" $_.Exception.Message
    }
    
    # Test 3: PSD1 to JSON Conversion
    Write-Host "`n--- Test 3: PSD1 to JSON Conversion ---" -ForegroundColor Yellow
    
    $testJsonPath2 = Join-Path $testDir "test2.json"
    
    $convertedJsonPath = Convert-Psd1ToJson -Psd1FilePath $testPsd1Path -JsonFilePath $testJsonPath2 -Validate
    Test-Assert (Test-Path $convertedJsonPath) "JSON file created from PSD1"
    
    # Verify round-trip conversion preserves data
    try {
        $loadedJson = Get-Content -Path $testJsonPath2 -Raw | ConvertFrom-Json
        Test-Assert ($loadedJson.key1 -eq "value1") "Round-trip conversion preserved key1"
        Test-Assert ($loadedJson.key2.Count -eq 2) "Round-trip conversion preserved array"
        Test-Assert ($loadedJson.nested.subkey -eq "subvalue") "Round-trip conversion preserved nested structure"
    }
    catch {
        Test-Assert $false "Round-trip JSON loading failed" $_.Exception.Message
    }
    
    # Test 4: Enhanced Configuration Loader
    Write-Host "`n--- Test 4: Enhanced Configuration Loader ---" -ForegroundColor Yellow
    
    $defaultValues = @{
        key1 = "default1"
        key2 = @("default_item")
        key3 = "default3"
    }
    
    # Test loading PSD1 with preference
    $basePath = Join-Path $testDir "test"
    $loadedConfig = Get-ConfigurationData -ConfigurationPath $basePath -DefaultValues $defaultValues -PreferredFormat 'PSD1'
    Test-Assert ($loadedConfig.key1 -eq "value1") "Enhanced loader loaded PSD1 correctly"
    Test-Assert ($loadedConfig.key2.Count -eq 2) "Enhanced loader preserved PSD1 array"
    
    # Test loading JSON with preference
    Remove-Item -Path $testPsd1Path -Force -ErrorAction SilentlyContinue
    $loadedConfig2 = Get-ConfigurationData -ConfigurationPath $basePath -DefaultValues $defaultValues -PreferredFormat 'PSD1'
    Test-Assert ($loadedConfig2.key1 -eq "value1") "Enhanced loader fell back to JSON correctly"
    
    # Test default values when no file exists
    Remove-Item -Path $testJsonPath -Force -ErrorAction SilentlyContinue
    $loadedConfig3 = Get-ConfigurationData -ConfigurationPath $basePath -DefaultValues $defaultValues
    Test-Assert ($loadedConfig3.key1 -eq "default1") "Enhanced loader used defaults when no file found"
    Test-Assert ($loadedConfig3.key3 -eq "default3") "Enhanced loader included all default values"
    
    # Test 5: Error Handling
    Write-Host "`n--- Test 5: Error Handling ---" -ForegroundColor Yellow
    
    # Create invalid JSON file
    $invalidJsonPath = Join-Path $testDir "invalid.json"
    "{ invalid json content" | Set-Content -Path $invalidJsonPath
    
    $invalidFormat = Test-ConfigurationFormat -FilePath $invalidJsonPath
    Test-Assert ($invalidFormat -eq 'JSON') "Invalid JSON still detected as JSON format"
    
    $invalidDetails = Test-ConfigurationFormat -FilePath $invalidJsonPath -ReturnDetails
    Test-Assert ($invalidDetails.IsValid -eq $false) "Invalid JSON marked as not valid"
    Test-Assert ($invalidDetails.ErrorMessage -like "*Invalid JSON syntax*") "Proper error message for invalid JSON"
    
    # Test loading with invalid file
    $invalidConfig = Get-ConfigurationData -ConfigurationPath $invalidJsonPath -DefaultValues $defaultValues
    Test-Assert ($invalidConfig.key1 -eq "default1") "Enhanced loader used defaults for invalid file"
    
    # Test 6: Backup and Safety Features
    Write-Host "`n--- Test 6: Backup and Safety Features ---" -ForegroundColor Yellow
    
    # Recreate valid test file
    $testJsonData | Set-Content -Path $testJsonPath -Encoding UTF8
    
    # Test backup creation
    $psd1WithBackup = Convert-JsonToPsd1 -JsonFilePath $testJsonPath -CreateBackup
    $backupPath = $testJsonPath + ".backup"
    Test-Assert (Test-Path $backupPath) "Backup file created during conversion"
    
    # Verify backup content
    $originalContent = Get-Content -Path $testJsonPath -Raw
    $backupContent = Get-Content -Path $backupPath -Raw
    Test-Assert ($originalContent -eq $backupContent) "Backup content matches original"
    
    # Test 7: Integration with Existing Settings
    Write-Host "`n--- Test 7: Integration with Existing Settings ---" -ForegroundColor Yellow
    
    # Test with actual settings.json if it exists
    if (Test-Path "./settings.json") {
        Write-Host "Testing with actual settings.json..." -ForegroundColor Cyan
        
        $actualSettingsDefaults = @{
            version = "1.0.0"
            auth = @{}
        }
        
        # Test format detection on real file
        $settingsFormat = Test-ConfigurationFormat -FilePath "./settings.json"
        Test-Assert ($settingsFormat -eq 'JSON') "Actual settings.json detected correctly"
        
        # Test loading real settings
        try {
            $realSettings = Get-ConfigurationData -ConfigurationPath "./settings" -DefaultValues $actualSettingsDefaults
            Test-Assert ($null -ne $realSettings.version) "Real settings version loaded"
            Write-Host "Settings version: $($realSettings.version)" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Could not load real settings: $($_.Exception.Message)"
        }
        
        # Test conversion of real settings (but don't save)
        try {
            $tempRealPsd1 = Join-Path $testDir "real_settings.psd1"
            Convert-JsonToPsd1 -JsonFilePath "./settings.json" -Psd1FilePath $tempRealPsd1 -Validate
            Test-Assert (Test-Path $tempRealPsd1) "Real settings converted to PSD1 successfully"
            
            # Verify converted content
            $convertedSettings = Import-PowerShellDataFile -Path $tempRealPsd1
            Test-Assert ($convertedSettings.version -eq $realSettings.version) "Real settings conversion preserved version"
        }
        catch {
            Write-Warning "Real settings conversion test failed: $($_.Exception.Message)"
        }
    }
    
    # Final Summary
    Write-Host "`n=== Test Summary ===" -ForegroundColor Green
    Write-Host "Total Tests: $script:TestsTotal" -ForegroundColor White
    Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
    Write-Host "Failed: $script:TestsFailed" -ForegroundColor Red
    
    $successRate = [math]::Round(($script:TestsPassed / $script:TestsTotal) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { 'Green' } elseif ($successRate -ge 75) { 'Yellow' } else { 'Red' })
    
    if ($script:TestsFailed -eq 0) {
        Write-Host "`n✓ All Phase 1 tests passed! Migration infrastructure is ready." -ForegroundColor Green
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
finally {
    # Cleanup
    if (Test-Path $testDir) {
        try {
            Remove-Item -Path $testDir -Recurse -Force
            Write-Host "`nCleaned up test directory: $testDir" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Could not clean up test directory: $($_.Exception.Message)"
        }
    }
}

Write-Host "`nPhase 1 testing completed." -ForegroundColor Green
exit $exitCode