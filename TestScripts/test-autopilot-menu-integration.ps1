#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for menu integration of Autopilot profile validation functionality.

.DESCRIPTION
    Tests that the new "Change Autopilot profile settings" menu option is properly
    integrated into the environment menu and that all menu items are accessible.

.NOTES
    - Tests menu structure and accessibility
    - Validates menu item presence in menu.psd1
    - Tests integration with main.ps1 environment menu
#>

param(
    [switch]$Verbose
)

# Set up test environment
$ErrorActionPreference = "Stop"
if ($Verbose)
{
    $VerbosePreference = "Continue" 
}

Write-Host "=== Testing Autopilot Profile Menu Integration ===" -ForegroundColor Cyan

# Test 1: Check if menu.psd1 contains the new menu item
Write-Host "`nTest 1: Verify menu.psd1 contains Autopilot profile settings menu item" -ForegroundColor Yellow
try 
{
    $menuContent = Get-Content "./menu.psd1" -Raw
    if ($menuContent -match "Change Autopilot profile settings") 
    {
        Write-Host "✓ Menu.psd1 contains 'Change Autopilot profile settings' menu item" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ Menu.psd1 missing 'Change Autopilot profile settings' menu item" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error checking menu.psd1: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Check if main.ps1 contains the menu handling code
Write-Host "`nTest 2: Verify main.ps1 contains Autopilot profile menu handling" -ForegroundColor Yellow
try 
{
    $mainContent = Get-Content "./main.ps1" -Raw
    if ($mainContent -match "Show-AutopilotProfilesEditor") 
    {
        Write-Host "✓ Main.ps1 contains Show-AutopilotProfilesEditor menu handling" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ Main.ps1 missing Show-AutopilotProfilesEditor menu handling" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error checking main.ps1: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Verify settings.psd1 no longer contains DesiredAutopilotProfiles
Write-Host "`nTest 3: Verify DesiredAutopilotProfiles removed from local settings editor" -ForegroundColor Yellow
try 
{
    $settingsContent = Get-Content "./settings.psd1" -Raw
    if ($settingsContent -notmatch "DesiredAutopilotProfiles") 
    {
        Write-Host "✓ DesiredAutopilotProfiles successfully removed from settings.psd1" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ DesiredAutopilotProfiles still present in settings.psd1" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error checking settings.psd1: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 4: Check that menu structure is valid PowerShell
Write-Host "`nTest 4: Verify menu.psd1 is valid PowerShell syntax" -ForegroundColor Yellow
try 
{
    $null = Import-PowerShellDataFile "./menu.psd1" -ErrorAction Stop
    Write-Host "✓ Menu.psd1 has valid PowerShell syntax" -ForegroundColor Green
}
catch 
{
    Write-Host "✗ Menu.psd1 has invalid PowerShell syntax: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 5: Check that settings.psd1 is still valid PowerShell after removal
Write-Host "`nTest 5: Verify settings.psd1 is valid PowerShell syntax after removal" -ForegroundColor Yellow
try 
{
    $null = Import-PowerShellDataFile "./settings.psd1" -ErrorAction Stop
    Write-Host "✓ Settings.psd1 has valid PowerShell syntax" -ForegroundColor Green
}
catch 
{
    Write-Host "✗ Settings.psd1 has invalid PowerShell syntax: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 6: Verify both group and autopilot profile menu items exist together
Write-Host "`nTest 6: Verify both group and Autopilot profile menu items are present" -ForegroundColor Yellow
try 
{
    $menuContent = Get-Content "./menu.psd1" -Raw
    $hasGroupMenu = $menuContent -match "Change group inclusion/exclusion"
    $hasAutopilotMenu = $menuContent -match "Change Autopilot profile settings"
    
    if ($hasGroupMenu -and $hasAutopilotMenu) 
    {
        Write-Host "✓ Both group and Autopilot profile menu items are present" -ForegroundColor Green
    }
    else 
    {
        Write-Host "✗ Missing menu items - Group: $hasGroupMenu, Autopilot: $hasAutopilotMenu" -ForegroundColor Red
        exit 1
    }
}
catch 
{
    Write-Host "✗ Error checking menu items: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== All Menu Integration Tests Passed! ===" -ForegroundColor Green
Write-Host "✓ Autopilot profile settings menu item added to menu.psd1" -ForegroundColor Green
Write-Host "✓ Show-AutopilotProfilesEditor integration added to main.ps1" -ForegroundColor Green  
Write-Host "✓ DesiredAutopilotProfiles removed from local settings editor (settings.psd1)" -ForegroundColor Green
Write-Host "✓ All PowerShell configuration files have valid syntax" -ForegroundColor Green
Write-Host "✓ Menu structure maintains both group and Autopilot profile editing options" -ForegroundColor Green

exit 0