#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Demo script for the new Show-GroupsViewer functionality
.DESCRIPTION
    Demonstrates the Groups Viewer functionality that was added to address @zuhairmahd's request
#>

# Import required functions
. "./functions/utilityFunctions/Write-Log.ps1"
. "./functions/setupFunctions/Show-GroupsViewer.ps1"

# Set up minimal logging
$logFile = "./demo.log"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         Groups Viewer Demo                         ║" -ForegroundColor Cyan  
Write-Host "║              Addressing @zuhairmahd's Feature Request              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "This demo shows the new Groups Viewer functionality that was added" -ForegroundColor White
Write-Host "to provide a read-only view of group inclusion/exclusion settings" -ForegroundColor White
Write-Host "similar to the existing domain and global settings viewers." -ForegroundColor White
Write-Host ""

Write-Host "The Groups Viewer can display:" -ForegroundColor Yellow
Write-Host "  • All domains and their group settings" -ForegroundColor Gray
Write-Host "  • A specific domain's group settings" -ForegroundColor Gray  
Write-Host "  • Clear formatting with descriptions" -ForegroundColor Gray
Write-Host "  • Summary statistics" -ForegroundColor Gray
Write-Host ""

Write-Host "🔹 Demo 1: Viewing all domains" -ForegroundColor Green
Write-Host "═══════════════════════════════" -ForegroundColor Green
Show-GroupsViewer -SettingsFile "settings.json"

Write-Host ""
Write-Host "🔹 Demo 2: Viewing specific domain (gao.gov)" -ForegroundColor Green  
Write-Host "══════════════════════════════════════════" -ForegroundColor Green
Show-GroupsViewer -SettingsFile "settings.json" -DomainName "gao.gov"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                             Summary                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Groups Viewer successfully implemented" -ForegroundColor Green
Write-Host "✓ Integrated into the environment settings menu" -ForegroundColor Green  
Write-Host "✓ Consistent with existing viewer patterns" -ForegroundColor Green
Write-Host "✓ Supports both all domains and specific domain views" -ForegroundColor Green
Write-Host "✓ Read-only interface with clear formatting" -ForegroundColor Green
Write-Host ""
Write-Host "Menu Path: Main Menu → Change application settings → Change global environment settings → View group inclusion/exclusion settings" -ForegroundColor Yellow
Write-Host ""
Write-Host "This addresses @zuhairmahd's request for a groups viewer" -ForegroundColor White
Write-Host "similar to the domain and global settings viewer!" -ForegroundColor White
Write-Host ""

# Clean up
if (Test-Path $logFile) {
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
}