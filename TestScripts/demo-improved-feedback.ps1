#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Demonstrates the improved user feedback in Get-EditorReplaceOrAddChoice and Get-GroupArrayInput.

.DESCRIPTION
    This demo shows what users will see with the enhanced feedback system.
#>

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  DEMO: Improved User Feedback for Groups Editor" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan

Write-Host "`n[i] Scenario: User has 2 existing groups and wants to edit them`n" -ForegroundColor White

Write-Host "[1] OPTION 1: REPLACE MODE" -ForegroundColor Yellow
Write-Host "-------------------------------" -ForegroundColor Gray
Write-Host "When user selects option 1, they will see:" -ForegroundColor Gray
Write-Host ""
Write-Host "[*] You chose: REPLACE all existing group" -ForegroundColor Yellow
Write-Host "  -> All current group will be removed" -ForegroundColor Red
Write-Host "  -> Only new group you enter will be saved" -ForegroundColor Green
Write-Host ""
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "  MODE: REPLACE - Old groups will be removed" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Current groups:" -ForegroundColor Cyan
Write-Host "  - Name: OldGroup1" -ForegroundColor White
Write-Host "    ID:   old-id-1" -ForegroundColor Gray
Write-Host "  - Name: OldGroup2" -ForegroundColor White
Write-Host "    ID:   old-id-2" -ForegroundColor Gray
Write-Host ""
Write-Host "[!] REPLACE MODE: Enter new groups (old groups will be removed)" -ForegroundColor Yellow
Write-Host "   * Enter group names one per line" -ForegroundColor Gray
Write-Host "   * Group names will be searched and resolved interactively" -ForegroundColor Gray
Write-Host "   * Press Enter on empty line to finish" -ForegroundColor Gray
Write-Host "   * Leave first line empty to cancel" -ForegroundColor Gray
Write-Host ""
Write-Host "[User enters: NewGroup1]" -ForegroundColor Cyan
Write-Host ""
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "  SUMMARY - REPLACE MODE" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "Old groups (2): REMOVED" -ForegroundColor Red
Write-Host "New groups (1): WILL BE SAVED" -ForegroundColor Green
Write-Host ""

Write-Host "`n-------------------------------------------------------------`n" -ForegroundColor Gray

Write-Host "[2] OPTION 2: ADD MODE" -ForegroundColor Green
Write-Host "-------------------------------" -ForegroundColor Gray
Write-Host "When user selects option 2, they will see:" -ForegroundColor Gray
Write-Host ""
Write-Host "[*] You chose: ADD new group to existing ones" -ForegroundColor Yellow
Write-Host "  -> All current group will be kept" -ForegroundColor Green
Write-Host "  -> New group you enter will be added to the list" -ForegroundColor Green
Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host "  MODE: ADD - New groups will be added" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Current groups:" -ForegroundColor Cyan
Write-Host "  - Name: OldGroup1" -ForegroundColor White
Write-Host "    ID:   old-id-1" -ForegroundColor Gray
Write-Host "  - Name: OldGroup2" -ForegroundColor White
Write-Host "    ID:   old-id-2" -ForegroundColor Gray
Write-Host ""
Write-Host "[+] ADD MODE: Enter new groups (old groups will be kept)" -ForegroundColor Green
Write-Host "   * Enter group names one per line" -ForegroundColor Gray
Write-Host "   * Group names will be searched and resolved interactively" -ForegroundColor Gray
Write-Host "   * Press Enter on empty line to finish" -ForegroundColor Gray
Write-Host "   * Leave first line empty to cancel" -ForegroundColor Gray
Write-Host ""
Write-Host "[User enters: NewGroup1]" -ForegroundColor Cyan
Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host "  SUMMARY - ADD MODE" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host "Old groups (2): KEPT" -ForegroundColor Green
Write-Host "New groups (1): ADDED" -ForegroundColor Green
Write-Host "Total groups: 3" -ForegroundColor Cyan
Write-Host ""

Write-Host "`n-------------------------------------------------------------`n" -ForegroundColor Gray

Write-Host "[3] OPTION 3: KEEP UNCHANGED" -ForegroundColor Cyan
Write-Host "-------------------------------" -ForegroundColor Gray
Write-Host "When user selects option 3, they will see:" -ForegroundColor Gray
Write-Host ""
Write-Host "[*] You chose: KEEP current group unchanged" -ForegroundColor Yellow
Write-Host "  -> No changes will be made" -ForegroundColor Cyan
Write-Host "  -> Returning to previous menu" -ForegroundColor Cyan
Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  NO CHANGES - Keeping 2 existing groups" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "`n===============================================================" -ForegroundColor Cyan
Write-Host "  KEY IMPROVEMENTS" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[+] Clear confirmation of user's choice" -ForegroundColor Green
Write-Host "[+] Explicit consequences shown immediately" -ForegroundColor Green
Write-Host "[+] Visual MODE banners throughout the process" -ForegroundColor Green
Write-Host "[+] Summary showing exactly what will be saved" -ForegroundColor Green
Write-Host "[+] Color-coded feedback (Yellow=Replace, Green=Add, Cyan=Keep)" -ForegroundColor Green
Write-Host "[+] No ambiguity about what will happen" -ForegroundColor Green
Write-Host ""
