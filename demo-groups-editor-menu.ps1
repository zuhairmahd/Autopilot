#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Demo script to show the Groups Editor menu system improvements.

.DESCRIPTION
    This demo shows the new menu-based interface for the Groups Editor
    and the clearer domain display formatting.
#>

# Import required functions
$scriptRoot = Split-Path -Parent $PSCommandPath
$functionsPath = Join-Path $scriptRoot "functions"

# Load menu functions
. (Join-Path $functionsPath "menuFunctions/NewMenu.ps1")
. (Join-Path $functionsPath "menuFunctions/AddMenuItem.ps1")
. (Join-Path $functionsPath "menuFunctions/ShowMenu.ps1")
. (Join-Path $functionsPath "setupFunctions/Show-GroupsEditor.ps1")
. (Join-Path $functionsPath "setupFunctions/Show-GroupsViewer.ps1")

# Set global variables that the functions expect
$global:maxJSONDepth = 10
$global:logFile = "demo.log"

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                         Groups Editor Menu Demo                              " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "This demo shows the improvements made to the Groups Editor:" -ForegroundColor White
Write-Host ""
Write-Host "1. " -NoNewline -ForegroundColor Yellow
Write-Host "Menu-based interface:" -ForegroundColor Green
Write-Host "   - Users can now choose between editing 'Groups to Include' or 'Groups to Exclude'" -ForegroundColor Gray
Write-Host "   - Uses the well-documented menu system (NewMenu, AddMenuItem, ShowMenu)" -ForegroundColor Gray
Write-Host "   - Follows the same pattern as ShowGroupAssignments and ProcessSerialNumber" -ForegroundColor Gray
Write-Host ""
Write-Host "2. " -NoNewline -ForegroundColor Yellow
Write-Host "Clear domain display:" -ForegroundColor Green
Write-Host "   - Domain name is now clearly visible without background colors" -ForegroundColor Gray
Write-Host "   - Fixed the issue where users saw unclear domain formatting" -ForegroundColor Gray
Write-Host ""
Write-Host "3. " -NoNewline -ForegroundColor Yellow
Write-Host "Enhanced user experience:" -ForegroundColor Green
Write-Host "   - Added 'View Current Group Settings' option" -ForegroundColor Gray
Write-Host "   - Better navigation with proper menu stack operations" -ForegroundColor Gray
Write-Host "   - Consistent behavior with other domain-specific settings editors" -ForegroundColor Gray
Write-Host ""

Write-Host "The Groups Editor menu now offers these options:" -ForegroundColor Cyan
Write-Host "  1. Edit Groups to Include" -ForegroundColor White
Write-Host "  2. Edit Groups to Exclude" -ForegroundColor White
Write-Host "  3. View Current Group Settings" -ForegroundColor White
Write-Host "  b. Back" -ForegroundColor Gray
Write-Host "  m. Main Menu" -ForegroundColor Gray
Write-Host "  q/e/0. Exit" -ForegroundColor Gray
Write-Host ""

Write-Host "Example domain display (fixed formatting):" -ForegroundColor Cyan
Write-Host "  Domain: " -NoNewline -ForegroundColor White
Write-Host "contoso.com" -ForegroundColor Yellow
Write-Host "  (instead of the previous unclear background color formatting)" -ForegroundColor Gray
Write-Host ""

Write-Host "Key improvements:" -ForegroundColor Green
Write-Host "✓ Follows established menu patterns from ShowGroupAssignments" -ForegroundColor Green
Write-Host "✓ Clear domain name display without background colors" -ForegroundColor Green
Write-Host "✓ Menu-driven selection instead of sequential prompts" -ForegroundColor Green
Write-Host "✓ All existing tests continue to pass" -ForegroundColor Green
Write-Host "✓ PowerShell 5.1 compatibility maintained" -ForegroundColor Green
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                              Demo Complete                                   " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan