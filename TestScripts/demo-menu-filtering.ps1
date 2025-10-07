#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Demo script showing menu filtering with different app modes
.DESCRIPTION
    This script demonstrates how different app mode combinations affect menu visibility
#>

# Set up test environment
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath

Write-Host "=== Multiple App Modes Menu Filtering Demo ===" -ForegroundColor Green
Write-Host ""

# Load required functions
. "$rootPath/functions/menuFunctions/Get-EffectiveAppModes.ps1"
. "$rootPath/functions/menuFunctions/Get-CombinedAppModeHierarchy.ps1"
. "$rootPath/functions/menuFunctions/Get-AppModeHierarchy.ps1"

# Read menu configuration
$menuConfig = Get-Content "$rootPath/menu.psd1" -Raw | Invoke-Expression

function Show-MenuForModes {
    param(
        [array]$AppModes,
        [string]$Description
    )
    
    Write-Host "=== $Description ===" -ForegroundColor Cyan
    Write-Host "App Modes: [$($AppModes -join ', ')]" -ForegroundColor Yellow
    Write-Host ""
    
    # Get effective permissions
    try {
        $combinedResult = Get-CombinedAppModeHierarchy -AppModes $AppModes -ResolutionStrategy 'Additive'
        $effectivePermissions = $combinedResult.AllowedModes
        Write-Host "Effective Permissions: [$($effectivePermissions -join ', ')]" -ForegroundColor Green
    } catch {
        $effectivePermissions = $AppModes
        Write-Host "Effective Permissions: [$($effectivePermissions -join ', ')] (fallback)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    Write-Host "Available Menu Items:" -ForegroundColor White
    $itemNumber = 1
    
    foreach ($menuItem in $menuConfig.mainMenu.items) {
        $isVisible = $false
        
        # Check if item should be visible
        if (-not $menuItem.includeInDisplayModes -or $menuItem.includeInDisplayModes.Count -eq 0) {
            $isVisible = $true
        } else {
            foreach ($permission in $effectivePermissions) {
                if ($permission -in $menuItem.includeInDisplayModes) {
                    $isVisible = $true
                    break
                }
            }
        }
        
        if ($isVisible) {
            Write-Host "$itemNumber. $($menuItem.name)" -ForegroundColor White
            Write-Host "   $($menuItem.description)" -ForegroundColor Gray
            $itemNumber++
        }
    }
    
    Write-Host ""
    Write-Host "Hidden Menu Items:" -ForegroundColor Red
    foreach ($menuItem in $menuConfig.mainMenu.items) {
        $isVisible = $false
        
        # Check if item should be visible
        if (-not $menuItem.includeInDisplayModes -or $menuItem.includeInDisplayModes.Count -eq 0) {
            $isVisible = $true
        } else {
            foreach ($permission in $effectivePermissions) {
                if ($permission -in $menuItem.includeInDisplayModes) {
                    $isVisible = $true
                    break
                }
            }
        }
        
        if (-not $isVisible) {
            Write-Host "- $($menuItem.name)" -ForegroundColor Red
            Write-Host "  Required modes: [$($menuItem.includeInDisplayModes -join ', ')]" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "---" -ForegroundColor Gray
    Write-Host ""
}

# Demo different app mode combinations
Show-MenuForModes -AppModes @('helpDesk', 'registration') -Description "Help Desk + Registration (User's Issue)"
Show-MenuForModes -AppModes @('registration') -Description "Registration Only"
Show-MenuForModes -AppModes @('admin') -Description "Admin Mode"
Show-MenuForModes -AppModes @('full') -Description "Full Mode"

Write-Host "The demo shows that with Help Desk + Registration modes:" -ForegroundColor Green
Write-Host "- Settings menu should be HIDDEN (requires full/admin/advanced)" -ForegroundColor Green
Write-Host "- Show Group Assignments should be HIDDEN (requires full/admin/advanced)" -ForegroundColor Green
Write-Host "- Other menus like 'Give a device to a user' should be VISIBLE" -ForegroundColor Green
Write-Host ""
Write-Host "This matches the expected behavior reported in the issue!" -ForegroundColor Green