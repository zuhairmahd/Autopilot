function Show-AppModeHierarchyInfo()
{
    <#
    .SYNOPSIS
        Displays app mode hierarchy and conflict resolution information.
    #>
    
    Write-Host ""
    Write-Host "=== App Mode Hierarchy Information ===" -ForegroundColor Cyan
    Write-Host "Understanding mode combinations and conflicts:" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Mode Precedence (highest to lowest):" -ForegroundColor Yellow
    Write-Host "1. Full Mode - Grants all permissions, supersedes all other modes" -ForegroundColor White
    Write-Host "2. Admin Mode - Administrative functions + Advanced + Help Desk + Registration" -ForegroundColor White  
    Write-Host "3. Advanced Mode - Advanced features + Help Desk + Registration" -ForegroundColor White
    Write-Host "4. Advanced Registration - Extended registration features" -ForegroundColor White
    Write-Host "5. Help Desk Mode - Troubleshooting and device management" -ForegroundColor White
    Write-Host "6. Registration Mode - Device enrollment and basic operations" -ForegroundColor White
    Write-Host "7. Custom Mode - User-defined permissions" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Conflict Resolution:" -ForegroundColor Yellow
    Write-Host "* ADDITIVE: Combines permissions from all selected modes (default)" -ForegroundColor White
    Write-Host "* Higher precedence modes include lower precedence permissions" -ForegroundColor White
    Write-Host "* Selecting both 'Admin' and 'Help Desk' is redundant (Admin includes Help Desk)" -ForegroundColor Cyan
    Write-Host "* 'Full' mode with any other mode is redundant (Full includes everything)" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Recommended Combinations:" -ForegroundColor Yellow
    Write-Host "* Help Desk + Registration: Comprehensive support operations" -ForegroundColor White
    Write-Host "* Advanced Registration: Specialized device enrollment" -ForegroundColor White
    Write-Host "* Custom: For unique organizational requirements" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    Read-Host | Out-Null
}
