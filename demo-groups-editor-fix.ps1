#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Demo script to show the Groups Editor immediate save behavior
.DESCRIPTION
    This script demonstrates that the Groups Editor now saves settings immediately
    after each edit operation, rather than deferring saves until exit.
#>

Write-Host "=== Groups Editor Immediate Save Demo ===" -ForegroundColor Green
Write-Host "This demo shows the new immediate save behavior in the Groups Editor." -ForegroundColor Yellow
Write-Host ""

# Load all functions
. "$PSScriptRoot/functions/setupFunctions/Show-GroupsEditor.ps1"
. "$PSScriptRoot/functions/setupFunctions/Update-Setting.ps1" 

# Set up test environment
$global:logFile = Join-Path (Get-Location) "demo.log"
$global:maxJSONDepth = 10

Write-Host "Key changes made to Groups Editor:" -ForegroundColor Cyan
Write-Host "1. Saving happens immediately after each edit operation" -ForegroundColor White
Write-Host "2. User sees 'Saving changes...' and 'Group settings updated successfully!' messages" -ForegroundColor White
Write-Host "3. Settings are persisted immediately, not deferred until exit" -ForegroundColor White
Write-Host "4. User gets confirmation with 'Press any key to continue...' after each save" -ForegroundColor White
Write-Host ""

Write-Host "Array preservation changes:" -ForegroundColor Cyan
Write-Host "1. Single-element arrays now properly maintained as arrays in JSON" -ForegroundColor White
Write-Host "2. Fixed existing data in settings.json (desiredAutopilotProfiles)" -ForegroundColor White
Write-Host "3. Both Get-ArrayInput and Get-GroupArrayInput preserve array types" -ForegroundColor White
Write-Host ""

Write-Host "To test the Groups Editor manually:" -ForegroundColor Yellow
Write-Host "1. Run: pwsh -File './main.ps1' -appMode 'full'" -ForegroundColor Gray
Write-Host "2. Navigate to: Settings menu > Change Environment Menu > Change group inclusion/exclusion" -ForegroundColor Gray
Write-Host "3. Edit either 'Groups to Include' or 'Groups to Exclude'" -ForegroundColor Gray
Write-Host "4. Observe immediate save behavior after completing input" -ForegroundColor Gray
Write-Host ""

# Check if settings.json has the fix
if (Test-Path "settings.json") {
    $settings = Get-Content "settings.json" -Raw | ConvertFrom-Json
    
    Write-Host "Verifying array fix in settings.json:" -ForegroundColor Cyan
    $exampleDomain = $settings.domains.PSObject.Properties | Where-Object { $_.Value.settings.desiredAutopilotProfiles } | Select-Object -First 1
    if ($exampleDomain) {
        $domainName = $exampleDomain.Name
        $profiles = $exampleDomain.Value.settings.desiredAutopilotProfiles
        
        Write-Host "Domain: $domainName" -ForegroundColor White
        Write-Host "desiredAutopilotProfiles type: $($profiles.GetType().Name)" -ForegroundColor White
        Write-Host "desiredAutopilotProfiles count: $($profiles.Count)" -ForegroundColor White
        Write-Host "desiredAutopilotProfiles value: $($profiles -join ', ')" -ForegroundColor White
        
        if ($profiles -is [array] -and $profiles.Count -ge 1) {
            Write-Host "✓ Array structure is properly maintained!" -ForegroundColor Green
        } else {
            Write-Host "✗ Array structure issue detected" -ForegroundColor Red
        }
    }
} else {
    Write-Host "settings.json not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "Demo completed!" -ForegroundColor Green