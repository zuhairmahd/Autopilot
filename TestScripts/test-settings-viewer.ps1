# Test script to verify the settings viewer functionality
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-settings-viewer-temp"
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "Settings Viewer Test"
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

# Load all functions using the helper
$rootPath = Split-Path -Parent $PSScriptRoot
$loadSuccess = Load-AllFunctions -RootPath $rootPath

if (-not $loadSuccess) {
    Write-TestResult "Failed to load functions" -Success $false
    exit 1
}

Write-TestResult "Functions loaded successfully" -Success $true

try {
    # Test 1: Check if Show-SettingsViewer function is loaded
    Write-Host "`n1. Testing Show-SettingsViewer function availability..." -ForegroundColor Cyan
    
    $functionExists = Get-Command Show-SettingsViewer -ErrorAction SilentlyContinue
    if ($functionExists) {
        Write-TestResult "Show-SettingsViewer function is loaded" -Success $true
    } else {
        Write-TestResult "Show-SettingsViewer function is not available" -Success $false
        throw "Show-SettingsViewer function not found"
    }
    
    # Test 2: Create test settings file
    Write-Host "`n2. Creating test settings file..." -ForegroundColor Cyan
    
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
    
    if (Test-Path $testSettingsFile) {
        Write-TestResult "Test settings file created successfully" -Success $true
    } else {
        Write-TestResult "Failed to create test settings file" -Success $false
        throw "Test settings file creation failed"
    }
    
    # Test 3: Test Global settings viewer
    Write-Host "`n3. Testing Global settings viewer..." -ForegroundColor Cyan
    
    try {
        $globalResult = Show-SettingsViewer -SettingsType "Global" -SettingsFile $testSettingsFile -Silent
        if ($globalResult) {
            Write-TestResult "Global settings viewer executed successfully" -Success $true
        } else {
            Write-TestResult "Global settings viewer returned false" -Success $false
        }
    } catch {
        Write-TestResult "Global settings viewer threw exception: $($_.Exception.Message)" -Success $false
    }
    
    # Test 4: Test Domain settings viewer
    Write-Host "`n4. Testing Domain settings viewer..." -ForegroundColor Cyan
    
    try {
        $domainResult = Show-SettingsViewer -SettingsType "Domain" -DomainName "test.com" -SettingsFile $testSettingsFile -Silent
        if ($domainResult) {
            Write-TestResult "Domain settings viewer executed successfully" -Success $true
        } else {
            Write-TestResult "Domain settings viewer returned false" -Success $false
        }
    } catch {
        Write-TestResult "Domain settings viewer threw exception: $($_.Exception.Message)" -Success $false
    }
    
    # Test 5: Test Auth settings viewer
    Write-Host "`n5. Testing Auth settings viewer..." -ForegroundColor Cyan
    
    try {
        $authResult = Show-SettingsViewer -SettingsType "Auth" -SettingsFile $testSettingsFile -Silent
        if ($authResult) {
            Write-TestResult "Auth settings viewer executed successfully" -Success $true
        } else {
            Write-TestResult "Auth settings viewer returned false" -Success $false
        }
    } catch {
        Write-TestResult "Auth settings viewer threw exception: $($_.Exception.Message)" -Success $false
    }
    
    # Test 6: Test parameter validation
    Write-Host "`n6. Testing parameter validation..." -ForegroundColor Cyan
    
    try {
        # This should fail because Domain type requires DomainName
        $invalidResult = Show-SettingsViewer -SettingsType "Domain" -SettingsFile $testSettingsFile -Silent
        if (-not $invalidResult) {
            Write-TestResult "Parameter validation correctly caught missing DomainName" -Success $true
        } else {
            Write-TestResult "Parameter validation failed - should have rejected missing DomainName" -Success $false
        }
    } catch {
        Write-TestResult "Parameter validation test threw exception (acceptable): $($_.Exception.Message)" -Success $true
    }
    
    # Test 7: Test non-silent output
    Write-Host "`n7. Testing non-silent output (visual verification)..." -ForegroundColor Cyan
    
    Write-Host "--- Global Settings Display ---" -ForegroundColor Yellow
    try {
        $visualResult = Show-SettingsViewer -SettingsType "Global" -SettingsFile $testSettingsFile
        if ($visualResult) {
            Write-TestResult "Non-silent global settings display completed" -Success $true
        } else {
            Write-TestResult "Non-silent global settings display failed" -Success $false
        }
    } catch {
        Write-TestResult "Non-silent display threw exception: $($_.Exception.Message)" -Success $false
    }
    
    Write-Host "`n--- Settings Viewer Tests Complete ---" -ForegroundColor Green

} catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" -Success $false
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    try {
        if (Test-Path $TestFolder) {
            Remove-Item -Path $TestFolder -Recurse -Force
            Write-TestResult "Test folder cleaned up" -Success $true
        }
    } catch {
        Write-Host "Warning: Failed to clean up test folder: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green