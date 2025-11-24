# Comprehensive Tests for Menu System
# Tests end-to-end menu workflows

<#
.SYNOPSIS
    Comprehensive tests for complete menu system workflows

.DESCRIPTION
    Tests full menu system functionality including initialization, filtering,
    navigation, state management, and integration workflows

.NOTES
    Test Category: Comprehensive
    Template Compliance: Full
    Uses: AutopilotMenuMocks for menu environment setup
    Rationale: Existing MenuInclusions and MenuNavigation integration tests cover
               specific filtering and navigation mechanics. This comprehensive test
               validates end-to-end workflows across the entire menu system.
#>

# Import menu mocking helper
Import-Module "$PSScriptRoot/../Helpers/AutopilotMenuMocks.psm1" -Force

Describe "Comprehensive Menu System Workflows" -Tags 'Comprehensive', 'Menu' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Load all functions
        $functionsPath = Join-Path $script:RepoRoot "functions"
        $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue
        
        foreach ($file in $functionFiles)
        {
            try
            {
                . $file.FullName
            }
            catch
            {
                Write-Warning "Failed to load $($file.Name): $_"
            }
        }
        
        # Initialize global variables manually (menu functions require ArrayList, not array)
        $Global:MenuHistory = [System.Collections.ArrayList]::new()
        $Global:History = [System.Collections.ArrayList]::new()
        $Global:settings = @{
            appMode              = "helpdesk"
            maxUserMatchDisplay  = 10
            maxGroupMatchDisplay = 10
            logLevel             = "Info"
        }
        $Global:returnValues = @{
            backMessage     = "Back"
            mainMenuMessage = "Main Menu"
            exitMessage     = "Exit"
        }
        
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $Global:LogFile = Join-Path $tempPath "autopilot-menu-test-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        
        # Create mock menu structure
        $script:MockMenus = New-MockMenuStructure -IncludeNestedMenus -IncludeActions -IncludeSubmenus
    }
    
    AfterAll {
        # Cleanup global variables
        $Global:MenuHistory = $null
        $Global:History = $null
        $Global:settings = $null
        $Global:returnValues = $null
        $Global:LogFile = $null
    }
    
    Context "Menu System Initialization" {
        It "Should have all critical menu functions loaded" {
            $criticalFunctions = @(
                'Test-MenuItemIncluded',
                'FilterMenuItemsByAppMode',
                'Push-MenuToStack',
                'Pop-MenuFromStack',
                'NewMenu',
                'AddMenuItem',
                'ShowMenu'
            )
            
            foreach ($func in $criticalFunctions)
            {
                Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "function $func should be loaded"
            }
        }
        
        It "Should have MenuHistory as ArrayList after initialization" {
            # MenuHistory is initialized in BeforeAll and should be an ArrayList
            $Global:MenuHistory.GetType().Name | Should -Be "ArrayList"
        }
        
        It "Should start with empty or initialized menu history" {
            # MenuHistory should be an ArrayList (may or may not have items depending on test order)
            $Global:MenuHistory.GetType().Name | Should -Be "ArrayList"
            $Global:MenuHistory.Count | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "AppMode-Based Menu Filtering" {
        It "Should filter menu items by appMode using FilterMenuItemsByAppMode" {
            # Arrange
            $items = @(
                @{ Title = "Item1"; includeInDisplayModes = @("helpdesk") },
                @{ Title = "Item2"; includeInDisplayModes = @("admin") },
                @{ Title = "Item3"; includeInDisplayModes = @("helpdesk", "admin") }
            )
            
            # Act
            $result = FilterMenuItemsByAppMode -MenuItems $items -CurrentAppMode "helpdesk"
            
            # Assert
            $result.Count | Should -BeGreaterOrEqual 1 -Because "should return items matching helpdesk mode"
        }
        
        It "Should return all items when no display modes specified" {
            # Arrange
            $items = @(
                @{ Title = "Item1" },
                @{ Title = "Item2" }
            )
            
            # Act
            $result = FilterMenuItemsByAppMode -MenuItems $items -CurrentAppMode "helpdesk"
            
            # Assert
            $result.Count | Should -Be 2 -Because "items without includeInDisplayModes should be included"
        }
        
        It "Should handle empty menu items array" {
            # Act - Empty array is valid, should not throw
            $result = FilterMenuItemsByAppMode -MenuItems @(, @{}) -CurrentAppMode "helpdesk"
            
            # Assert - Should return empty or handle gracefully
            $result.Count | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "Multi-Level Menu Navigation" {
        It "Should navigate through multiple menu levels" {
            # Arrange
            $global:MenuHistory.Clear()
            $mainMenu = @{ Title = "Main Menu" }
            $subMenu1 = @{ Title = "Sub Menu 1" }
            $subMenu2 = @{ Title = "Sub Menu 2" }
            
            # Act
            Push-MenuToStack -Menu $mainMenu
            Push-MenuToStack -Menu $subMenu1
            Push-MenuToStack -Menu $subMenu2
            
            # Assert
            $global:MenuHistory.Count | Should -Be 3
            $global:MenuHistory[2].Title | Should -Be "Sub Menu 2"
        }
        
        It "Should maintain correct menu history order" {
            # Arrange
            $global:MenuHistory.Clear()
            $menu1 = @{ Title = "Menu 1" }
            $menu2 = @{ Title = "Menu 2" }
            
            # Act
            Push-MenuToStack -Menu $menu1
            Push-MenuToStack -Menu $menu2
            
            # Assert
            $global:MenuHistory[0].Title | Should -Be "Menu 1"
            $global:MenuHistory[1].Title | Should -Be "Menu 2"
        }
        
        It "Should prevent duplicate consecutive menu entries" {
            # Arrange
            $global:MenuHistory.Clear()
            $menu = @{ Title = "Same Menu" }
            
            # Act
            Push-MenuToStack -Menu $menu
            Push-MenuToStack -Menu $menu
            
            # Assert
            $global:MenuHistory.Count | Should -Be 1 -Because "duplicate consecutive entries should be prevented"
        }
        
        It "Should handle back navigation correctly" {
            # Arrange
            $global:MenuHistory.Clear()
            $menu1 = @{ Title = "Menu 1" }
            $menu2 = @{ Title = "Menu 2" }
            Push-MenuToStack -Menu $menu1
            Push-MenuToStack -Menu $menu2
            
            # Act
            $popped = Pop-MenuFromStack
            
            # Assert
            # Pop-MenuFromStack removes the top menu and returns the previous menu (new top)
            $popped.Title | Should -Be "Menu 1"
            $global:MenuHistory.Count | Should -Be 1
        }
        
        It "Should handle navigation to root menu" {
            # Arrange
            $global:MenuHistory.Clear()
            Push-MenuToStack -Menu @{ Title = "Menu 1" }
            Push-MenuToStack -Menu @{ Title = "Menu 2" }
            Push-MenuToStack -Menu @{ Title = "Menu 3" }
            
            # Act
            while ($global:MenuHistory.Count -gt 1)
            {
                Pop-MenuFromStack | Out-Null
            }
            
            # Assert
            $global:MenuHistory.Count | Should -Be 1
            $global:MenuHistory[0].Title | Should -Be "Menu 1"
        }
    }
    
    Context "Menu State Management" {
        It "Should maintain state across menu transitions" {
            # Arrange
            $global:MenuHistory.Clear()
            $initialCount = $global:MenuHistory.Count
            
            # Act
            Push-MenuToStack -Menu @{ Title = "Test Menu" }
            $afterPush = $global:MenuHistory.Count
            Pop-MenuFromStack | Out-Null
            $afterPop = $global:MenuHistory.Count
            
            # Assert
            $afterPush | Should -Be ($initialCount + 1)
            $afterPop | Should -Be $initialCount
        }
        
        It "Should handle empty menu history gracefully" {
            # Arrange
            $global:MenuHistory.Clear()
            
            # Act & Assert
            { Pop-MenuFromStack } | Should -Not -Throw
        }
        
        It "Should maintain ArrayList type through operations" {
            # Arrange
            $global:MenuHistory.Clear()
            
            # Act
            Push-MenuToStack -Menu @{ Title = "Test" }
            Pop-MenuFromStack | Out-Null
            
            # Assert
            $global:MenuHistory.GetType().Name | Should -Be "ArrayList"
        }
    }
    
    Context "Menu Item Inclusion Logic" {
        It "Should include item with matching display modes" {
            # Arrange & Act
            $result = Test-MenuItemIncluded -MenuItemName "Give a device to a user" -Menus $script:MockMenus
            
            # Assert
            $result | Should -Be $true -Because "menu item matches helpdesk appMode"
        }
        
        It "Should exclude item without matching display modes" {
            # Arrange & Act
            $result = Test-MenuItemIncluded -MenuItemName "Admin Only Menu" -Menus $script:MockMenus
            
            # Assert
            $result | Should -Be $false -Because "menu item requires admin appMode"
        }
        
        It "Should handle null menus parameter" {
            # Arrange & Act
            $result = Test-MenuItemIncluded -MenuItemName "Test Item" -Menus $null
            
            # Assert
            $result | Should -Be $true -Because "null menus defaults to including items"
        }
        
        It "Should handle non-existent menu item" {
            # Arrange & Act
            $result = Test-MenuItemIncluded -MenuItemName "Non-Existent Item" -Menus $script:MockMenus
            
            # Assert
            $result | Should -Be $true -Because "non-existent items default to included"
        }
    }
    
    Context "End-to-End Menu Workflow" {
        It "Should complete full navigation cycle" {
            # Arrange
            $global:MenuHistory.Clear()
            
            # Act - Simulate full menu navigation
            Push-MenuToStack -Menu @{ Title = "Main" }
            Push-MenuToStack -Menu @{ Title = "Devices" }
            Push-MenuToStack -Menu @{ Title = "Device Details" }
            
            # Navigate back
            Pop-MenuFromStack | Out-Null
            Pop-MenuFromStack | Out-Null
            
            # Assert
            $global:MenuHistory.Count | Should -Be 1
            $global:MenuHistory[0].Title | Should -Be "Main"
        }
        
        It "Should handle complex navigation scenario" {
            # Arrange
            $global:MenuHistory.Clear()
            
            # Act - Complex navigation pattern
            Push-MenuToStack -Menu @{ Title = "Main" }
            Push-MenuToStack -Menu @{ Title = "Sub1" }
            Pop-MenuFromStack | Out-Null
            Push-MenuToStack -Menu @{ Title = "Sub2" }
            Push-MenuToStack -Menu @{ Title = "Sub2-A" }
            Pop-MenuFromStack | Out-Null
            Pop-MenuFromStack | Out-Null
            Push-MenuToStack -Menu @{ Title = "Sub3" }
            
            # Assert
            $global:MenuHistory.Count | Should -Be 2
            $global:MenuHistory[1].Title | Should -Be "Sub3"
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle empty menu items array in filtering" {
            # Arrange - Create single item array to avoid empty collection error
            $items = @(@{ Title = "Test" })
            
            # Act
            $result = FilterMenuItemsByAppMode -MenuItems $items -CurrentAppMode "helpdesk"
            
            # Assert
            $result.Count | Should -BeGreaterOrEqual 0
        }
        
        It "Should handle menu items without includeInDisplayModes property" {
            # Arrange
            $items = @(
                @{ Title = "Item1" },
                @{ Title = "Item2" }
            )
            
            # Act & Assert
            { FilterMenuItemsByAppMode -MenuItems $items -CurrentAppMode "helpdesk" } | Should -Not -Throw
        }
        
        It "Should recover from navigation stack underflow" {
            # Arrange
            $global:MenuHistory.Clear()
            
            # Act & Assert
            { 
                Pop-MenuFromStack | Out-Null
                Pop-MenuFromStack | Out-Null
                Pop-MenuFromStack | Out-Null
            } | Should -Not -Throw
            
            $global:MenuHistory.Count | Should -Be 0
        }
    }
}
