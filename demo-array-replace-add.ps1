#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Demonstration script for the new array replace vs add functionality
.DESCRIPTION
    This script demonstrates the enhanced array handling behavior in both
    Get-ArrayInput and Get-GroupArrayInput functions. It shows how users
    can now choose to replace or add to existing array values.
#>

[CmdletBinding()]
param()

Write-Host "=== Array Replace vs Add Functionality Demo ===" -ForegroundColor Green
Write-Host "This demo shows the new array handling options in settings and groups editors." -ForegroundColor Cyan
Write-Host ""

# Load the required functions
try {
    . "./functions/setupFunctions/Show-SettingsEditor.ps1"
    . "./functions/setupFunctions/Show-GroupsEditor.ps1"
    . "./functions/utilityFunctions/Write-Log.ps1"
    
    Write-Host "✓ Functions loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set up minimal environment for logging
$tempDir = if ($IsWindows) { $env:TEMP } else { "/tmp" }
$global:logFile = Join-Path $tempDir "demo-array-replace-add.log"

Write-Host "`n--- Function Signature Demonstration ---" -ForegroundColor Yellow

# Show the Get-ArrayInput function signature
Write-Host "`nGet-ArrayInput function:" -ForegroundColor Cyan
$arrayInputCmd = Get-Command Get-ArrayInput -ErrorAction SilentlyContinue
if ($arrayInputCmd) {
    Write-Host "  Parameters: $($arrayInputCmd.Parameters.Keys -join ', ')" -ForegroundColor White
    Write-Host "  Purpose: Enhanced to support replace vs add for existing array values" -ForegroundColor Gray
} else {
    Write-Host "  Function not found" -ForegroundColor Red
}

# Show the Get-GroupArrayInput function signature  
Write-Host "`nGet-GroupArrayInput function:" -ForegroundColor Cyan
$groupArrayInputCmd = Get-Command Get-GroupArrayInput -ErrorAction SilentlyContinue
if ($groupArrayInputCmd) {
    Write-Host "  Parameters: $($groupArrayInputCmd.Parameters.Keys -join ', ')" -ForegroundColor White
    Write-Host "  Purpose: Enhanced to support replace vs add for existing group arrays" -ForegroundColor Gray
} else {
    Write-Host "  Function not found" -ForegroundColor Red
}

Write-Host "`n--- Behavior Description ---" -ForegroundColor Yellow

Write-Host "`nBoth functions now provide these options when arrays have existing values:" -ForegroundColor White
Write-Host "  1. Replace all existing values with new ones (original behavior)" -ForegroundColor White
Write-Host "  2. Add new values to the existing ones (NEW FEATURE)" -ForegroundColor Green
Write-Host "  3. Keep current values unchanged (cancel)" -ForegroundColor White

Write-Host "`n--- Usage Examples ---" -ForegroundColor Yellow

Write-Host "`nExample 1: Settings Editor Array Input" -ForegroundColor Cyan
Write-Host "When editing an array setting with existing values:" -ForegroundColor Gray
Write-Host "  Current array values:" -ForegroundColor Cyan
Write-Host "    - value1" -ForegroundColor White
Write-Host "    - value2" -ForegroundColor White
Write-Host ""
Write-Host "  You have existing values in this array." -ForegroundColor Yellow
Write-Host "  Do you want to:" -ForegroundColor White
Write-Host "    1. Replace all existing values with new ones" -ForegroundColor White
Write-Host "    2. Add new values to the existing ones" -ForegroundColor White
Write-Host "    3. Keep current values unchanged" -ForegroundColor White
Write-Host "  Enter your choice (1-3): [USER INPUT]" -ForegroundColor Gray

Write-Host "`nExample 2: Groups Editor Array Input" -ForegroundColor Cyan
Write-Host "When editing group arrays with existing groups:" -ForegroundColor Gray
Write-Host "  Current groups: group1, group2" -ForegroundColor White
Write-Host ""
Write-Host "  You have existing groups in this list." -ForegroundColor Yellow
Write-Host "  Do you want to:" -ForegroundColor White
Write-Host "    1. Replace all existing groups with new ones" -ForegroundColor White
Write-Host "    2. Add new groups to the existing ones" -ForegroundColor White
Write-Host "    3. Keep current groups unchanged" -ForegroundColor White
Write-Host "  Enter your choice (1-3): [USER INPUT]" -ForegroundColor Gray

Write-Host "`n--- Technical Details ---" -ForegroundColor Yellow

Write-Host "`nArray Type Preservation:" -ForegroundColor Cyan
Write-Host "  ✓ Single element arrays remain as arrays (not converted to strings)" -ForegroundColor Green
Write-Host "  ✓ Combined arrays maintain proper array structure" -ForegroundColor Green
Write-Host "  ✓ Empty arrays are handled correctly" -ForegroundColor Green

Write-Host "`nConsistent Behavior:" -ForegroundColor Cyan
Write-Host "  ✓ Both settings editor and groups editor use identical patterns" -ForegroundColor Green
Write-Host "  ✓ User experience is consistent across all array editing scenarios" -ForegroundColor Green
Write-Host "  ✓ Backward compatibility maintained for empty arrays" -ForegroundColor Green

Write-Host "`n--- Demo Complete ---" -ForegroundColor Green
Write-Host "The array replace vs add functionality is now available in both:" -ForegroundColor White
Write-Host "  • Settings Editor (Get-ArrayInput function)" -ForegroundColor Cyan
Write-Host "  • Groups Editor (Get-GroupArrayInput function)" -ForegroundColor Cyan
Write-Host ""
Write-Host "This enhancement provides users more control over array modifications" -ForegroundColor Gray
Write-Host "while maintaining full backward compatibility." -ForegroundColor Gray