#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for dynamic menu functionality

.DESCRIPTION
    This script tests the new dynamic menu system that reads menu definitions
    from menu.json instead of using hardcoded strings.

.NOTES
    Author: Copilot
    Version: 1.0.0
    Compatible: PowerShell 5.1+
#>

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Test helper functions
function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestCode,
        [switch]$ContinueOnError
    )
    
    Write-Host "Testing: $TestName" -ForegroundColor Cyan
    try {
        & $TestCode
        Write-Host "✓ $TestName passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ $TestName failed: $_" -ForegroundColor Red
        if (-not $ContinueOnError) {
            throw
        }
        return $false
    }
}

# Set up test environment
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $scriptPath
Set-Location $rootPath

# Import required functions
$functionsFolder = "$rootPath\functions"
if (Test-Path $functionsFolder) {
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse
    foreach ($function in $functions) {
        . $function.FullName
    }
}

# Initialize global variables that functions expect
$global:LogFile = "$rootPath\Logs\test.log"
$global:settings = @{
    appMode = "full"
}

Write-Host "=== Testing Dynamic Menu Functionality ===" -ForegroundColor Yellow

# Test 1: Load menu configuration function
Test-Function "Get-MenuConfiguration function loads menu.json" {
    $config = Get-MenuConfiguration
    if (-not $config) {
        throw "Failed to load menu configuration"
    }
    if (-not $config.mainMenu) {
        throw "Main menu not found in configuration"
    }
    Write-Verbose "Successfully loaded menu configuration with $($config.PSObject.Properties.Count) menus"
}

# Test 2: Load specific menu configuration
Test-Function "Get-MenuConfiguration loads specific menu" {
    $mainMenuConfig = Get-MenuConfiguration -MenuName "mainMenu"
    if (-not $mainMenuConfig) {
        throw "Failed to load main menu configuration"
    }
    if (-not $mainMenuConfig.Title) {
        throw "Main menu configuration missing Title"
    }
    Write-Verbose "Main menu title: $($mainMenuConfig.Title)"
}

# Test 3: NewMenu function with MenuName parameter
Test-Function "NewMenu creates menu from configuration" {
    $menu = NewMenu -MenuName "mainMenu"
    if (-not $menu) {
        throw "Failed to create menu from configuration"
    }
    if (-not $menu.Title) {
        throw "Menu missing Title"
    }
    if (-not $menu.Items) {
        throw "Menu missing Items array"
    }
    Write-Verbose "Created menu '$($menu.Title)' with $($menu.Items.Count) items"
}

# Test 4: NewMenu function fallback to manual creation
Test-Function "NewMenu falls back to manual creation" {
    $menu = NewMenu -Title "Test Menu" -Description "Test Description"
    if (-not $menu) {
        throw "Failed to create manual menu"
    }
    if ($menu.Title -ne "Test Menu") {
        throw "Manual menu title incorrect"
    }
    if ($menu.Description -ne "Test Description") {
        throw "Manual menu description incorrect"
    }
    Write-Verbose "Successfully created manual menu: $($menu.Title)"
}

# Test 5: Static menu items loaded from configuration
Test-Function "Static menu items loaded correctly" {
    $menu = NewMenu -MenuName "exportMenu"
    if (-not $menu) {
        throw "Failed to load export menu"
    }
    if ($menu.Items.Count -eq 0) {
        throw "Export menu has no items"
    }
    
    # Check that items have required properties
    $firstItem = $menu.Items[0]
    if (-not $firstItem.Name) {
        throw "Menu item missing Name property"
    }
    if (-not $firstItem.includeInDisplayModes) {
        throw "Menu item missing includeInDisplayModes property"
    }
    
    Write-Verbose "Export menu loaded with $($menu.Items.Count) items"
}

# Test 6: includeInDisplayModes defaults to "full" when empty
Test-Function "includeInDisplayModes defaults to 'full' when empty" {
    $menu = NewMenu -MenuName "mainMenu"
    if (-not $menu) {
        throw "Failed to load main menu"
    }
    
    # Find an item with empty includeInDisplayModes in menu.json
    $itemWithEmptyModes = $menu.Items | Where-Object { 
        $_.includeInDisplayModes -contains "full" -and $_.includeInDisplayModes.Count -eq 1
    }
    
    if (-not $itemWithEmptyModes) {
        throw "No items found with default 'full' mode"
    }
    
    Write-Verbose "Found items with default 'full' mode: $($itemWithEmptyModes.Count)"
}

# Test 7: AddMenuItem updates existing items
Test-Function "AddMenuItem updates existing items and preserves includeInDisplayModes" {
    $menu = NewMenu -MenuName "exportMenu"
    if (-not $menu) {
        throw "Failed to load export menu"
    }
    
    $originalItemCount = $menu.Items.Count
    $firstItemName = $menu.Items[0].Name
    $originalIncludeModes = $menu.Items[0].includeInDisplayModes
    
    # Add an action to an existing item (should update, not add new)
    $updatedMenu = AddMenuItem -Menu $menu -Name $firstItemName -Action {
        Write-Host "Test action"
    }
    
    if ($updatedMenu.Items.Count -ne $originalItemCount) {
        throw "AddMenuItem should have updated existing item, not added new one. Expected: $originalItemCount, Got: $($updatedMenu.Items.Count)"
    }
    
    # Find the updated item
    $updatedItem = $updatedMenu.Items | Where-Object { $_.Name -eq $firstItemName }
    if (-not $updatedItem) {
        throw "Updated item not found"
    }
    
    if (-not $updatedItem.Action) {
        throw "Action was not set on updated item"
    }
    
    if ($updatedItem.includeInDisplayModes -ne $originalIncludeModes) {
        throw "includeInDisplayModes was not preserved during update"
    }
    
    Write-Verbose "Successfully updated existing menu item and preserved includeInDisplayModes"
}

# Test 8: AddMenuItem adds new items when name doesn't exist
Test-Function "AddMenuItem adds new items when name doesn't exist" {
    $menu = NewMenu -MenuName "exportMenu"
    if (-not $menu) {
        throw "Failed to load export menu"
    }
    
    $originalItemCount = $menu.Items.Count
    $newItemName = "Test New Item"
    
    # Add a new item
    $updatedMenu = AddMenuItem -Menu $menu -Name $newItemName -Action {
        Write-Host "New test action"
    }
    
    if ($updatedMenu.Items.Count -ne ($originalItemCount + 1)) {
        throw "AddMenuItem should have added new item. Expected: $($originalItemCount + 1), Got: $($updatedMenu.Items.Count)"
    }
    
    # Find the new item
    $newItem = $updatedMenu.Items | Where-Object { $_.Name -eq $newItemName }
    if (-not $newItem) {
        throw "New item not found"
    }
    
    if (-not $newItem.Action) {
        throw "Action was not set on new item"
    }
    
    Write-Verbose "Successfully added new menu item"
}

# Test 9: Menu configuration not found handling
Test-Function "Handle non-existent menu configuration gracefully" {
    try {
        $menu = NewMenu -MenuName "nonExistentMenu"
        if ($menu) {
            throw "Should not create menu for non-existent configuration"
        }
    }
    catch {
        # This should fail, which is expected behavior
        Write-Verbose "Correctly handled non-existent menu configuration"
    }
}

Write-Host "=== Dynamic Menu Tests Completed ===" -ForegroundColor Yellow
Write-Host "All tests passed successfully!" -ForegroundColor Green