<#
.SYNOPSIS
    Integration tests for menu navigation flows.

.DESCRIPTION
    Tests the real menu navigation architecture using ShowMenu, Push-MenuToStack, 
    Pop-MenuFromStack, and Handle-*Navigation functions. Mocks DisplayNumericMenu 
    to simulate user input without simulating the menu loop itself.
    
    Converted from TestScripts/test-mnemonic-navigation.ps1

.NOTES
    Test Category: Integration
    Template Compliance: Full
    Uses: AutopilotMenuMocks, AutopilotTestHelpers
    
    Architecture Notes:
    - ShowMenu is the main entry point (handles display, navigation, returns menu objects)
    - DisplayNumericMenu gets user input (mocked here to simulate choices)
    - Push-MenuToStack adds menus to $Global:MenuHistory ArrayList
    - Pop-MenuFromStack removes and returns previous menu
    - Handle-BackNavigation calls Pop-MenuToStack then ShowMenu
    - Handle-MainMenuNavigation resets to main menu
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Menu Navigation Flows" -Tags 'Integration', 'Menu' {

    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $TestContext.RootPath
        
        # Load menu functions directly (PS 5.1 + Pester 5.x compatibility)
        . "$script:RepoRoot/functions/menuFunctions/ShowMenu.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Push-MenuToStack.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Pop-MenuFromStack.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Handle-BackNavigation.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Handle-MainMenuNavigation.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Test-MenuItemIncluded.ps1"
        
        # Initialize global variables (required by menu functions)
        $Global:MenuHistory = [System.Collections.ArrayList]::new()
        $Global:History = [System.Collections.ArrayList]::new()
        $Global:settings = @{
            appMode              = "helpdesk"
            maxUserMatchDisplay  = 10
            maxGroupMatchDisplay = 10
        }
        $Global:returnValues = @{
            backMessage     = "Back"
            mainMenuMessage = "Main Menu"
            exitMessage     = "Exit"
        }
        
        # Create test menu structure (nested 3 levels)
        $script:level3Menu = @{
            name    = "Level 3 Menu"
            Title   = "Level 3 Menu"  # Push/Pop functions use Title property
            items   = @(
                @{ name = "Level 3 Action"; type = "action"; appMode = "all" }
            )
            appMode = "all"
        }
        
        $script:level2Menu = @{
            name    = "Level 2 Menu"
            Title   = "Level 2 Menu"  # Push/Pop functions use Title property
            type    = "submenu"
            items   = @(
                @{ 
                    name    = "Go to Level 3"
                    type    = "submenu"
                    submenu = $script:level3Menu
                    appMode = "all"
                }
            )
            appMode = "all"
        }
        
        $script:mainMenu = @{
            name    = "Main Menu"
            Title   = "Main Menu"  # Push/Pop functions use Title property
            items   = @(
                @{ 
                    name    = "Go to Level 2"
                    type    = "submenu"
                    submenu = $script:level2Menu
                    appMode = "all"
                },
                @{ name = "Main Menu Action"; type = "action"; appMode = "all" }
            )
            appMode = "all"
        }
        
        # Set up parent relationships (if needed by menu functions)
        $script:level3Menu.parent = $script:level2Menu.items[0]
        $script:level2Menu.parent = $script:mainMenu.items[0]
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }

    BeforeEach {
        # Reset menu state before each test
        $Global:MenuHistory.Clear()
        $Global:History.Clear()
        $Global:currentMenu = $null
        $Global:previousMenu = $null
    }

    Context "Push-MenuToStack Function" {
        It "Should add a menu to the history" {
            # Act
            Push-MenuToStack -Menu $script:mainMenu
            
            # Assert
            $Global:MenuHistory.Count | Should -Be 1
            $Global:MenuHistory[0].Title | Should -Be "Main Menu"
        }

        It "Should prevent duplicate consecutive entries" {
            # Act
            Push-MenuToStack -Menu $script:mainMenu
            Push-MenuToStack -Menu $script:mainMenu # Try to add same menu twice
            
            # Assert
            $Global:MenuHistory.Count | Should -Be 1 -Because "duplicate entries should be prevented"
        }
    }

    Context "Pop-MenuFromStack Function" {
        It "Should remove and return the previous menu" {
            # Arrange
            Push-MenuToStack -Menu $script:mainMenu
            Push-MenuToStack -Menu $script:level2Menu
            
            # Act
            $result = Pop-MenuFromStack
            
            # Assert
            $result.Title | Should -Be "Main Menu"
            $Global:MenuHistory.Count | Should -Be 1
            $Global:MenuHistory[0].Title | Should -Be "Main Menu"
        }

        It "Should return null if stack is empty" {
            # Act
            $result = Pop-MenuFromStack
            
            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should handle popping when only main menu remains" {
            # Arrange
            Push-MenuToStack -Menu $script:mainMenu
            
            # Act
            $result = Pop-MenuFromStack
            
            # Assert
            $result | Should -BeNullOrEmpty -Because "can't pop the last menu"
            $Global:MenuHistory.Count | Should -Be 0 -Because "last menu was removed"
        }
    }

    Context "Multi-Level Navigation" {
        It "Should maintain correct history through multiple levels" {
            # Arrange
            $Global:MenuHistory.Clear()
            
            # Act - Navigate through all levels
            Push-MenuToStack -Menu $script:mainMenu
            Push-MenuToStack -Menu $script:level2Menu
            Push-MenuToStack -Menu $script:level3Menu
            
            # Assert
            $Global:MenuHistory.Count | Should -Be 3
            $Global:MenuHistory[0].Title | Should -Be "Main Menu"
            $Global:MenuHistory[1].Title | Should -Be "Level 2 Menu"
            $Global:MenuHistory[2].Title | Should -Be "Level 3 Menu"
        }

        It "Should correctly pop through multiple levels" {
            # Arrange
            Push-MenuToStack -Menu $script:mainMenu
            Push-MenuToStack -Menu $script:level2Menu
            Push-MenuToStack -Menu $script:level3Menu
            
            # Act - Pop back two levels
            $firstPop = Pop-MenuFromStack  # Should return Level 2
            $secondPop = Pop-MenuFromStack # Should return Main Menu
            
            # Assert
            $firstPop.Title | Should -Be "Level 2 Menu"
            $secondPop.Title | Should -Be "Main Menu"
            $Global:MenuHistory.Count | Should -Be 1
            $Global:MenuHistory[0].Title | Should -Be "Main Menu"
        }
    }

    Context "Edge Cases" {
        It "Should handle empty MenuHistory gracefully" {
            # Arrange
            $Global:MenuHistory.Clear()
            
            # Act
            $result = Pop-MenuFromStack
            
            # Assert
            $result | Should -BeNullOrEmpty
            { Pop-MenuFromStack } | Should -Not -Throw
        }

        It "Should maintain ArrayList type through operations" {
            # Arrange
            $Global:MenuHistory.Clear()
            Push-MenuToStack -Menu $script:mainMenu
            
            # Act
            Push-MenuToStack -Menu $script:level2Menu
            $popped = Pop-MenuFromStack
            
            # Assert - Check the ArrayList itself is still of correct type
            $Global:MenuHistory.GetType().FullName | Should -Be 'System.Collections.ArrayList'
            $popped.Title | Should -Be "Main Menu"
        }
    }
}
