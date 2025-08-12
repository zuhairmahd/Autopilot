#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Manual demonstration of the Groups Editor functionality.

.DESCRIPTION
    This script demonstrates the Groups Editor in action by showing:
    1. Current group settings for a domain
    2. How the editor would be called
    3. Verification of the functionality
#>

param(
    [string]$Domain = "arabictutor.com"  # Default to first domain in settings
)

# Setup
$scriptRoot = Split-Path -Parent $PSCommandPath
$settingsFile = Join-Path $scriptRoot "../settings.json"
$functionsPath = Join-Path $scriptRoot "../functions"

# Load required functions
Write-Host "=== Loading Functions ===" -ForegroundColor Cyan
$functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -Recurse
foreach ($file in $functionFiles) {
    try {
        . $file.FullName
    }
    catch {
        Write-Warning "Failed to load $($file.Name): $($_.Exception.Message)"
    }
}

# Set global variables
$global:maxJSONDepth = 10
$global:logFile = "demo.log"

Write-Host "`n=== Groups Editor Demonstration ===" -ForegroundColor Yellow
Write-Host "Domain: $Domain" -ForegroundColor White

# Show current settings
Write-Host "`n=== Current Group Settings ===" -ForegroundColor Cyan
if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
    
    if ($settings.domains.$Domain) {
        $domain = $settings.domains.$Domain
        
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
        Write-Host "Domain '$Domain' not found in settings" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Settings file not found: $settingsFile" -ForegroundColor Red
    exit 1
}

# Test the editor functions (non-interactive)
Write-Host "`n=== Testing Helper Functions ===" -ForegroundColor Cyan

# Test array comparison
Write-Host "Testing array comparison..." -ForegroundColor Yellow
$testArray1 = @("group1", "group2")
$testArray2 = @("group1", "group3")
$testArray3 = @("group1", "group2")

$result1 = Compare-ArrayContents -Array1 $testArray1 -Array2 $testArray2
$result2 = Compare-ArrayContents -Array1 $testArray1 -Array2 $testArray3

Write-Host "  Different arrays change detected: $result1 (should be True)" -ForegroundColor White
Write-Host "  Same arrays change detected: $result2 (should be False)" -ForegroundColor White

if ($result1 -and -not $result2) {
    Write-Host "✓ Array comparison working correctly" -ForegroundColor Green
} else {
    Write-Host "✗ Array comparison not working correctly" -ForegroundColor Red
}

# Test availability of the main function
Write-Host "`nTesting main function availability..." -ForegroundColor Yellow
try {
    $editorFunction = Get-Command Show-GroupsEditor -ErrorAction Stop
    Write-Host "✓ Show-GroupsEditor function is available" -ForegroundColor Green
    Write-Host "  Function file: $($editorFunction.Source)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Show-GroupsEditor function not available: $($_.Exception.Message)" -ForegroundColor Red
}

# Show how the editor would be called from the menu
Write-Host "`n=== Menu Integration ===" -ForegroundColor Cyan
Write-Host "The editor would be called from the menu like this:" -ForegroundColor Yellow
Write-Host '  Show-GroupsEditor -SettingsFile $SettingsFile' -ForegroundColor White
Write-Host "`nThis is integrated into the main application menu under:" -ForegroundColor Yellow
Write-Host "  Change application settings > Change environment settings > Edit group inclusion/exclusion settings" -ForegroundColor White

# Demonstrate the expected workflow
Write-Host "`n=== Expected Workflow ===" -ForegroundColor Cyan
Write-Host "1. User selects 'Edit group inclusion/exclusion settings' from menu" -ForegroundColor White
Write-Host "2. If multiple domains exist, user selects domain" -ForegroundColor White
Write-Host "3. Current groups are displayed" -ForegroundColor White
Write-Host "4. User can edit groups to include (one per line)" -ForegroundColor White
Write-Host "5. User can edit groups to exclude (one per line)" -ForegroundColor White
Write-Host "6. Changes are saved to settings.json" -ForegroundColor White
Write-Host "7. Backup is created automatically" -ForegroundColor White

Write-Host "`n=== Demo Complete ===" -ForegroundColor Green
Write-Host "The Groups Editor is ready for use!" -ForegroundColor White
Write-Host "`nTo test interactively, run the main application:" -ForegroundColor Gray
Write-Host "  pwsh -File './main.ps1' -appMode 'full'" -ForegroundColor Gray
Write-Host "Then navigate to: Change application settings > Change environment settings > Edit group inclusion/exclusion settings" -ForegroundColor Gray