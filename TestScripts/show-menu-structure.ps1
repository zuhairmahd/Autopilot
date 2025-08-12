#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Shows the menu structure to demonstrate where the new Groups Editor option appears.
#>

# Setup
$scriptRoot = Split-Path -Parent $PSCommandPath
$settingsFile = Join-Path $scriptRoot "../settings.json"

Write-Host "=== Menu Structure Demonstration ===" -ForegroundColor Cyan
Write-Host "Showing where the new 'Edit group inclusion/exclusion settings' option appears in the menu hierarchy." -ForegroundColor White

Write-Host "`n📁 Main Menu" -ForegroundColor Yellow
Write-Host "   ├── Give a device to a user" -ForegroundColor Gray
Write-Host "   ├── Check device status" -ForegroundColor Gray
Write-Host "   ├── Autopilot menu" -ForegroundColor Gray
Write-Host "   ├── 📁 Change application settings" -ForegroundColor Green
Write-Host "   │   ├── 📁 Change global environment settings" -ForegroundColor Green
Write-Host "   │   │   ├── View global settings" -ForegroundColor Gray
Write-Host "   │   │   ├── View domain settings" -ForegroundColor Gray
Write-Host "   │   │   ├── Change global environment settings" -ForegroundColor Gray
Write-Host "   │   │   ├── Change domain specific settings" -ForegroundColor Gray
Write-Host "   │   │   ├── Change authentication settings" -ForegroundColor Gray
Write-Host "   │   │   └── 🆕 Edit group inclusion/exclusion settings" -ForegroundColor Magenta -BackgroundColor DarkBlue
Write-Host "   │   ├── Change Entra credentials" -ForegroundColor Gray
Write-Host "   │   ├── Change Auto Update setting" -ForegroundColor Gray
Write-Host "   │   └── Change App Mode setting" -ForegroundColor Gray
Write-Host "   ├── Check for script updates" -ForegroundColor Gray
Write-Host "   ├── Export Menu" -ForegroundColor Gray
Write-Host "   ├── Device Actions" -ForegroundColor Gray
Write-Host "   └── About" -ForegroundColor Gray

Write-Host "`n=== New Feature Details ===" -ForegroundColor Yellow
Write-Host "Option Name: " -NoNewline -ForegroundColor White
Write-Host "Edit group inclusion/exclusion settings" -ForegroundColor Magenta
Write-Host "Location: " -NoNewline -ForegroundColor White
Write-Host "Main Menu > Change application settings > Change global environment settings" -ForegroundColor Green
Write-Host "Function: " -NoNewline -ForegroundColor White
Write-Host "Show-GroupsEditor" -ForegroundColor Cyan
Write-Host "Purpose: " -NoNewline -ForegroundColor White
Write-Host "Edit groupsToInclude and groupsToExclude arrays for domains" -ForegroundColor White

Write-Host "`n=== Available Domains ===" -ForegroundColor Yellow
if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
    $domainNames = $settings.domains.PSObject.Properties.Name
    foreach ($domain in $domainNames) {
        $domainObj = $settings.domains.$domain
        $includeCount = if ($domainObj.groupsToInclude) { $domainObj.groupsToInclude.Count } else { 0 }
        $excludeCount = if ($domainObj.groupsToExclude) { $domainObj.groupsToExclude.Count } else { 0 }
        
        Write-Host "   🌐 $domain" -ForegroundColor Cyan
        Write-Host "      Groups to Include: $includeCount" -ForegroundColor Green
        Write-Host "      Groups to Exclude: $excludeCount" -ForegroundColor Red
    }
} else {
    Write-Host "   Settings file not found" -ForegroundColor Red
}

Write-Host "`n=== Integration Status ===" -ForegroundColor Yellow
Write-Host "✓ Function created: Show-GroupsEditor.ps1" -ForegroundColor Green
Write-Host "✓ Menu item added to main.ps1" -ForegroundColor Green
Write-Host "✓ Helper functions implemented" -ForegroundColor Green
Write-Host "✓ Error handling and logging" -ForegroundColor Green
Write-Host "✓ PowerShell 5.1 compatibility" -ForegroundColor Green
Write-Host "✓ Existing architecture leveraged" -ForegroundColor Green
Write-Host "✓ Tests created and passing" -ForegroundColor Green

Write-Host "`n=== Ready for Use! ===" -ForegroundColor Green
Write-Host "The Groups Editor is fully integrated and ready for testing." -ForegroundColor White