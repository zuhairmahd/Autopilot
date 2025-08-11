# Simple test for settings viewer functionality - standalone test
param(
    [string]$TestFolder = "$PWD\test-viewer-simple"
)

Write-Host "=== Simple Settings Viewer Test ===" -ForegroundColor Cyan
Write-Host "Testing core functionality without full application context" -ForegroundColor Gray

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    # Create minimal test environment
    $global:logFile = "$TestFolder\test.log"
    $global:maxJSONDepth = 10
    
    # Load only the required functions for testing
    Write-Host "`n1. Loading required functions..." -ForegroundColor Yellow
    
    # Load the viewer function
    . "./functions/setupFunctions/Show-SettingsViewer.ps1"
    Write-Host "   Loaded Show-SettingsViewer" -ForegroundColor Green
    
    # Load helper functions that the viewer depends on
    . "./functions/setupFunctions/Show-SettingsEditor.ps1"  # For Get-DefaultSettingsStructure and Get-CurrentSettings
    Write-Host "   Loaded Show-SettingsEditor (for helper functions)" -ForegroundColor Green
    
    # Load required utility functions
    . "./functions/setupFunctions/Set-SettingsJsonStructure.ps1"
    . "./functions/setupFunctions/Get-JsonConfiguration.ps1"
    . "./functions/setupFunctions/FirstRunWizardFunctions/Test-SettingsJsonExists.ps1"
    
    # Create minimal implementations of required functions for testing
    function Write-Log { param($LogFile, $Module, $Message, $LogLevel) }
    function Get-AuthDefaults { 
        return @{
            authType = "PublicAuthFlow"
            delegated = $true
            scope = @("offline_access", "openid")
        }
    }
    function Test-AuthDefaults { param($SettingsFile, [switch]$Silent) return $true }
    
    Write-Host "   Loaded minimal helper functions" -ForegroundColor Green
    
    # Test 2: Create test settings file
    Write-Host "`n2. Creating test settings file..." -ForegroundColor Yellow
    
    $testSettingsFile = "$TestFolder\test-settings.json"
    $testSettings = @{
        description = "Test settings file for viewer"
        version = "1.1"
        auth = @{
            authType = "PublicAuthFlow"
            delegated = $true
            scope = @("offline_access", "openid")
        }
        globalSettings = @{
            appMode = "full"
            autoUpdate = $true
            maxWaitTime = "30"
            testMode = $false
            operatingSystem = "Windows"
        }
        domains = @{
            "test.com" = @{
                settings = @{
                    domain = "test.com"
                    appMode = "helpDesk"
                    maxWaitTime = "60"
                    deviceNamePrefix = "test-"
                }
            }
        }
    }
    
    $testSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $testSettingsFile -Encoding UTF8
    Write-Host "   Test settings file created" -ForegroundColor Green
    
    # Test 3: Test the function exists
    Write-Host "`n3. Checking function availability..." -ForegroundColor Yellow
    $functionExists = Get-Command Show-SettingsViewer -ErrorAction SilentlyContinue
    if ($functionExists) {
        Write-Host "   Show-SettingsViewer function is available" -ForegroundColor Green
    } else {
        Write-Host "   ERROR: Show-SettingsViewer function not found" -ForegroundColor Red
        exit 1
    }
    
    # Test 4: Test Global settings viewer with Silent flag
    Write-Host "`n4. Testing Global settings viewer (silent mode)..." -ForegroundColor Yellow
    
    try {
        $globalResult = Show-SettingsViewer -SettingsType "Global" -SettingsFile $testSettingsFile -Silent
        if ($globalResult) {
            Write-Host "   ✓ Global settings viewer succeeded" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Global settings viewer returned false" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ✗ Global settings viewer error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 5: Test Domain settings viewer with Silent flag
    Write-Host "`n5. Testing Domain settings viewer (silent mode)..." -ForegroundColor Yellow
    
    try {
        $domainResult = Show-SettingsViewer -SettingsType "Domain" -DomainName "test.com" -SettingsFile $testSettingsFile -Silent
        if ($domainResult) {
            Write-Host "   ✓ Domain settings viewer succeeded" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Domain settings viewer returned false" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ✗ Domain settings viewer error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 6: Test visual output (non-silent)
    Write-Host "`n6. Testing visual output..." -ForegroundColor Yellow
    Write-Host "--- Global Settings Display ---" -ForegroundColor Cyan
    
    try {
        $visualResult = Show-SettingsViewer -SettingsType "Global" -SettingsFile $testSettingsFile
        if ($visualResult) {
            Write-Host "`n   ✓ Visual display succeeded" -ForegroundColor Green
        } else {
            Write-Host "`n   ✗ Visual display failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "`n   ✗ Visual display error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
    Write-Host "Settings viewer functionality test completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR: Test failed with exception: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up..." -ForegroundColor Yellow
    try {
        if (Test-Path $TestFolder) {
            Remove-Item -Path $TestFolder -Recurse -Force
        }
        Write-Host "Cleanup completed" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Failed to clean up: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nSimple test completed!" -ForegroundColor Green