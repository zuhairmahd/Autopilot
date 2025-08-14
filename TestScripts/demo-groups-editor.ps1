#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Manual demonstration of the Groups Editor functionality using mock data.

.DESCRIPTION
    This script demonstrates the Groups Editor in action by showing:
    1. Mock group settings for testing
    2. How the editor would be called
    3. Verification of the functionality
    Uses mock data instead of real settings.json to ensure test reliability
#>

param(
    [string]$Domain = "arabictutor.com",  # Default to test domain
    [string]$TestName = "Groups Editor Demo",
    [string]$TestFolder = "$PWD\demo-groups-editor-temp"
)

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Load all functions at script level (same as main.ps1)
    $functionsFolder = "$PWD\functions"
    if (Test-Path $functionsFolder) {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse
        foreach ($function in $functions) {
            try {
                . $function.FullName
            } catch {
                Write-Warning "Failed to load $($function.Name): $($_.Exception.Message)"
            }
        }
        Write-TestResult "Functions loaded successfully" $true
    } else {
        Write-TestResult "Functions folder not found" $false
        exit 1
    }
    
    # Initialize unified test environment  
    $testContext = Start-UnifiedTest -TestName $TestName -TestFolder $TestFolder
    
    # Set global variables needed by functions
    $tempDir = if ($IsWindows) { $env:TEMP } else { "/tmp" }
    $global:LogFile = Join-Path $tempDir "demo-groups-editor.log"
    $global:maxJSONDepth = 10
    
    Write-TestResult "Test environment initialized" $true
} catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

Write-TestSection "Groups Editor Demonstration"
Write-Host "Domain: $Domain" -ForegroundColor White

# Use mock settings data instead of real settings.json
$mockSettings = @{
    domains = @{
        "arabictutor.com" = @{
            groupsToInclude = @("Autopilot-Devices", "Test-Group-1", "Managed-Devices")
            groupsToExclude = @("Excluded-Group-1", "Legacy-Devices") 
            settings = @{
                operatingSystem = "Windows"
                maxNumberOfDevicesAllowed = 15
            }
        }
        "testdomain.com" = @{
            groupsToInclude = @("Test-Devices")
            groupsToExclude = @()
            settings = @{
                operatingSystem = "Windows"
                maxNumberOfDevicesAllowed = 10
            }
        }
    }
}

# Show current mock settings
Write-TestSection "Current Group Settings (Mock Data)"
if ($mockSettings.domains.$Domain) {
    $domain = $mockSettings.domains.$Domain
    
    Write-Host "Groups to Include:" -ForegroundColor Green
    if ($domain.groupsToInclude -and $domain.groupsToInclude.Count -gt 0) {
        foreach ($group in $domain.groupsToInclude) {
            Write-Host "  - $group" -ForegroundColor White
        }
    } else {
        Write-Host "  (no groups specified)" -ForegroundColor Gray
    }
    
    Write-Host "`nGroups to Exclude:" -ForegroundColor Red
    if ($domain.groupsToExclude -and $domain.groupsToExclude.Count -gt 0) {
        foreach ($group in $domain.groupsToExclude) {
            Write-Host "  - $group" -ForegroundColor White
        }
    } else {
        Write-Host "  (no groups specified)" -ForegroundColor Gray
    }
} else {
    Write-Host "Domain '$Domain' not found in mock settings" -ForegroundColor Red
    exit 1
}

# Test the editor functions (non-interactive)
Write-TestSection "Testing Helper Functions"

# Test array comparison
Write-Host "Testing array comparison..." -ForegroundColor Yellow
$testArray1 = @("group1", "group2")
$testArray2 = @("group1", "group3")
$testArray3 = @("group1", "group2")

try {
    $result1 = Compare-ArrayContents -Array1 $testArray1 -Array2 $testArray2
    $result2 = Compare-ArrayContents -Array1 $testArray1 -Array2 $testArray3
    
    Write-Host "  Different arrays change detected: $result1 (should be True)" -ForegroundColor White
    Write-Host "  Same arrays change detected: $result2 (should be False)" -ForegroundColor White
    
    if ($result1 -and -not $result2) {
        Write-TestResult "Array comparison working correctly" $true
    } else {
        Write-TestResult "Array comparison not working correctly" $false
    }
} catch {
    Write-TestResult "Array comparison test failed: $($_.Exception.Message)" $false
}

# Test availability of the main function
Write-Host "`nTesting main function availability..." -ForegroundColor Yellow
try {
    $editorFunction = Get-Command Show-GroupsEditor -ErrorAction Stop
    Write-TestResult "Show-GroupsEditor function is available" $true
    Write-Host "  Function file: $($editorFunction.Source)" -ForegroundColor Gray
} catch {
    Write-TestResult "Show-GroupsEditor function not available: $($_.Exception.Message)" $false
}

# Show how the editor would be called from the menu
Write-TestSection "Menu Integration"
Write-Host "The editor would be called from the menu like this:" -ForegroundColor Yellow
Write-Host '  Show-GroupsEditor -SettingsFile $SettingsFile' -ForegroundColor White
Write-Host "`nThis is integrated into the main application menu under:" -ForegroundColor Yellow
Write-Host "  Change application settings > Change environment settings > Edit group inclusion/exclusion settings" -ForegroundColor White

# Demonstrate the expected workflow
Write-TestSection "Expected Workflow"
Write-Host "1. User selects 'Edit group inclusion/exclusion settings' from menu" -ForegroundColor White
Write-Host "2. If multiple domains exist, user selects domain" -ForegroundColor White
Write-Host "3. Current groups are displayed" -ForegroundColor White
Write-Host "4. User can edit groups to include (one per line)" -ForegroundColor White
Write-Host "5. User can edit groups to exclude (one per line)" -ForegroundColor White
Write-Host "6. Changes are saved to settings.json" -ForegroundColor White
Write-Host "7. Backup is created automatically" -ForegroundColor White

Write-TestSection "Demo Complete"
Write-Host "The Groups Editor is ready for use!" -ForegroundColor White
Write-Host "`nTo test interactively, run the main application:" -ForegroundColor Gray
Write-Host "  pwsh -File './main.ps1' -appMode 'full'" -ForegroundColor Gray
Write-Host "Then navigate to: Change application settings > Change environment settings > Edit group inclusion/exclusion settings" -ForegroundColor Gray

# Complete the unified test
try {
    Push-Location $TestFolder
    Complete-UnifiedTest -TestContext $testContext
} catch {
    Write-TestResult "Test completion failed: $($_.Exception.Message)" $false
    exit 1
} finally {
    Pop-Location
}