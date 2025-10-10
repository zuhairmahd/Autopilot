# Integration Tests for Menu Inclusions Functionality
# Migrated from: TestScripts/test-menu-inclusions.ps1

BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Load all functions
    $functionsPath = Join-Path $script:RepoRoot "functions"
    $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue
    
    foreach ($file in $functionFiles) {
        try {
            . $file.FullName
        }
        catch {
            Write-Warning "Failed to load $($file.Name): $_"
        }
    }
    
    # Initialize global variables needed by menu functions
    $Global:MenuHistory = @()
    $Global:History = @()
    $Global:settings = @{ appMode = "helpdesk" }
    $Global:LogFile = Join-Path $TestDrive "test.log"
    
    # Create mock menu structure for testing
    $script:MockMenus = @(
        [PSCustomObject]@{
            name                  = "Give a device to a user"
            description           = "Start the user and device readiness check"
            type                  = "action"
            includeInDisplayModes = @("helpdesk")
        },
        [PSCustomObject]@{
            name                  = "Check device status"
            description           = "Troubleshoot a device"
            type                  = "submenu"
            includeInDisplayModes = @("helpdesk", "admin")
            items                 = @(
                [PSCustomObject]@{
                    name                  = "Lookup device by Serial Number"
                    description           = "Lookup a device by its serial number"
                    type                  = "submenu"
                    includeInDisplayModes = @("helpdesk")
                    items                 = @(
                        [PSCustomObject]@{
                            name                  = "Enter a serial number"
                            description           = "Lookup a device by its serial number"
                            type                  = "action"
                            includeInDisplayModes = @("helpdesk")
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            name                  = "Admin Only Menu"
            description           = "Admin only functionality"
            type                  = "action"
            includeInDisplayModes = @("admin")
        }
    )
}

AfterAll {
    # Cleanup global variables
    Remove-Variable -Name MenuHistory -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name History -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name LogFile -Scope Global -ErrorAction SilentlyContinue
}

Describe "Menu Inclusions Functionality" -Tags 'Integration', 'Menu' {
    
    Context "Test-MenuItemIncluded with null menus parameter" {
        
        BeforeEach {
            $Global:settings = @{ appMode = "helpdesk" }
        }
        
        It "Should return true when menus parameter is null" {
            # Act
            $result = Test-MenuItemIncluded -MenuItemName "Test Item" -Menus $null
            
            # Assert
            $result | Should -Be $true -Because "null menus parameter should default to true (include all items)"
        }
    }
    
    Context "Menu structure search and inclusion logic" {
        
        BeforeEach {
            $Global:settings = @{ appMode = "helpdesk" }
        }
        
        It "Should return true for menu item with matching includeInDisplayModes" {
            # Act
            $result = Test-MenuItemIncluded -MenuItemName "Give a device to a user" -Menus $script:MockMenus
            
            # Assert
            $result | Should -Be $true -Because "item has 'helpdesk' in includeInDisplayModes and global settings.appMode is 'helpdesk'"
        }
        
        It "Should return false for menu item without matching includeInDisplayModes" {
            # Act
            $result = Test-MenuItemIncluded -MenuItemName "Admin Only Menu" -Menus $script:MockMenus
            
            # Assert
            $result | Should -Be $false -Because "item only has 'admin' in includeInDisplayModes but global settings.appMode is 'helpdesk'"
        }
        
        It "Should return true for deeply nested menu item (2 levels deep)" {
            # Act
            $result = Test-MenuItemIncluded -MenuItemName "Enter a serial number" -Menus $script:MockMenus
            
            # Assert
            $result | Should -Be $true -Because "nested item has 'helpdesk' in includeInDisplayModes"
        }
        
        It "Should return true by default for non-existent menu item" {
            # Act
            $result = Test-MenuItemIncluded -MenuItemName "Non-existent Menu Item" -Menus $script:MockMenus
            
            # Assert
            $result | Should -Be $true -Because "non-existent items should default to true (include by default)"
        }
    }
    
    Context "Menu filtering integration" {
        
        BeforeEach {
            $Global:settings = @{ appMode = "helpdesk" }
            $Global:MenuHistory = @()
            $Global:History = @()
        }
        
        It "Should filter out items that don't match includeInDisplayModes" {
            # Arrange
            $testMenu = @{
                Title       = "Test Menu"
                Description = "Test menu for inclusion testing"
                Items       = @(
                    @{ Name = "Give a device to a user"; Action = { Write-Host "Action 1" } },
                    @{ Name = "Admin Only Menu"; Action = { Write-Host "Should be excluded in helpdesk mode" } },
                    @{ Name = "Check device status"; Action = { Write-Host "Action 2" } },
                    @{ Name = "Lookup device by Serial Number"; Action = { Write-Host "Action 3" } },
                    @{ Name = "Enter a serial number"; Action = { Write-Host "Action 4" } }
                )
            }
            
            # Act - Apply filtering logic
            $choices = @()
            $menuItems = @()
            
            foreach ($item in $testMenu.Items) {
                if (Test-MenuItemIncluded -MenuItemName $item.Name -Menus $script:MockMenus) {
                    $choices += $item.Name
                    $menuItems += $item
                }
            }
            
            # Assert
            $choices.Count | Should -Be 4 -Because "only 4 items should pass the filter (Admin Only Menu excluded)"
        }
        
        It "Should exclude admin-only items when in helpdesk mode" {
            # Arrange
            $testMenu = @{
                Items = @(
                    @{ Name = "Give a device to a user"; Action = { } },
                    @{ Name = "Admin Only Menu"; Action = { } },
                    @{ Name = "Check device status"; Action = { } }
                )
            }
            
            # Act
            $choices = @()
            foreach ($item in $testMenu.Items) {
                if (Test-MenuItemIncluded -MenuItemName $item.Name -Menus $script:MockMenus) {
                    $choices += $item.Name
                }
            }
            
            # Assert
            $choices | Should -Not -Contain "Admin Only Menu" -Because "admin-only item should be filtered out in helpdesk mode"
        }
        
        It "Should include all non-excluded items in filtered list" {
            # Arrange
            $testMenu = @{
                Items = @(
                    @{ Name = "Give a device to a user"; Action = { } },
                    @{ Name = "Check device status"; Action = { } },
                    @{ Name = "Lookup device by Serial Number"; Action = { } },
                    @{ Name = "Enter a serial number"; Action = { } }
                )
            }
            
            # Act
            $choices = @()
            foreach ($item in $testMenu.Items) {
                if (Test-MenuItemIncluded -MenuItemName $item.Name -Menus $script:MockMenus) {
                    $choices += $item.Name
                }
            }
            
            # Assert
            $choices.Count | Should -Be 4 -Because "all items in this menu should be included in helpdesk mode"
            $choices | Should -Contain "Give a device to a user"
            $choices | Should -Contain "Check device status"
            $choices | Should -Contain "Lookup device by Serial Number"
            $choices | Should -Contain "Enter a serial number"
        }
    }
}
