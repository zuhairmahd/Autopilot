<#
.SYNOPSIS
    Pester tests for main.ps1 menu creation and structure.

.DESCRIPTION
    Integration tests for menu initialization in main.ps1, including:
    - Menu object creation (NewMenu)
    - Menu item registration (AddMenuItem)
    - Menu structure validation against menu.psd1
    - Menu workflow integration

.NOTES
    Test Categories:
    - Menu creation (NewMenu function calls)
    - Menu item registration (AddMenuItem function calls)
    - Menu configuration validation
    - Menu structure completeness

    PowerShell Compatibility: 5.1+
    Dependencies: AutopilotTestHelpers
    
    This test suite validates menu creation without executing action blocks.
    Action block execution is tested separately in functional integration tests.
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Main: Menu Creation and Structure" -Tags 'Integration', 'Main' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load required menu functions and dependencies
        . "$script:RepoRoot/functions/menuFunctions/NewMenu.ps1"
        . "$script:RepoRoot/functions/menuFunctions/AddMenuItem.ps1"
        . "$script:RepoRoot/functions/menuFunctions/FilterMenuItemsByAppMode.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Test-MenuItemIncluded.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Get-CachedMenuConfiguration.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Get-MenuConfiguration.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Get-EffectiveAppModes.ps1"
        . "$script:RepoRoot/functions/menuFunctions/Get-AppModeHierarchy.ps1"
        . "$script:RepoRoot/functions/setupFunctions/Get-ApplicationDefaults.ps1"
        . "$script:RepoRoot/functions/setupFunctions/Get-ConfigurationData.ps1"
        . "$script:RepoRoot/functions/setupFunctions/Export-PowerShellDataFile.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Initialize log file (required for Write-Log)
        $script:logFile = Join-Path $TestDrive "test.log"
        $global:LogFile = $script:logFile
        
        # Initialize global Settings for menu functions (required by FilterMenuItemsByAppMode)
        $global:Settings = @{
            appMode = "full"
        }
        
        # Initialize global menus array for Test-MenuItemIncluded
        $global:menus = @()
        
        # Load menu configuration for validation tests
        $menuConfigPath = Join-Path $script:RepoRoot "menu.psd1"
        $script:menuConfig = $null
        if (Test-Path $menuConfigPath)
        {
            try
            {
                $script:menuConfig = Import-PowerShellDataFile -Path $menuConfigPath
            }
            catch
            {
                Write-Warning "Failed to load menu configuration: $($_.Exception.Message)"
            }
        }
    }

    # NOTE: Configuration-based menu creation tests validate that NewMenu can successfully
    # create menus from menu.psd1 configuration, including proper filtering and item loading.
    Context "Menu Object Creation (NewMenu)" {
        It "Should create mainMenu object from configuration" {
            $configPath = Join-Path $script:RepoRoot "menu"
            Write-Host "DEBUG: Using config path: $configPath" -ForegroundColor Cyan
            Write-Host "DEBUG: Config file exists: $(Test-Path "$configPath.psd1")" -ForegroundColor Cyan
            
            # Test Get-CachedMenuConfiguration directly first
            $directConfig = Get-CachedMenuConfiguration -MenuName "mainMenu" -MenuConfigFile $configPath
            Write-Host "DEBUG: Direct config result: $($directConfig | ConvertTo-Json -Depth 2)" -ForegroundColor Yellow
            Write-Host "DEBUG: Direct config is null: $($null -eq $directConfig)" -ForegroundColor Yellow
            Write-Host "DEBUG: Direct config type: $($directConfig.GetType().FullName)" -ForegroundColor Yellow
            
            $mainMenu = NewMenu -MenuName "mainMenu" -MenuConfigFile $configPath -Verbose
            
            $mainMenu | Should -Not -BeNullOrEmpty
            $mainMenu.Title | Should -Not -BeNullOrEmpty
            $mainMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create checkMenu object from configuration" {
            $checkMenu = NewMenu -MenuName "checkMenu" -MenuConfigFile (Join-Path $script:RepoRoot "menu")
            
            $checkMenu | Should -Not -BeNullOrEmpty
            $checkMenu.Title | Should -Not -BeNullOrEmpty
            $checkMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create serialNumberMenu object from configuration" {
            $serialNumberMenu = NewMenu -MenuName "serialNumberMenu" -MenuConfigFile (Join-Path $script:RepoRoot "menu")
            
            $serialNumberMenu | Should -Not -BeNullOrEmpty
            $serialNumberMenu.Title | Should -Not -BeNullOrEmpty
            $serialNumberMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create exportMenu object from configuration" {
            $exportMenu = NewMenu -MenuName "exportMenu" -MenuConfigFile (Join-Path $script:RepoRoot "menu")
            
            $exportMenu | Should -Not -BeNullOrEmpty
            $exportMenu.Title | Should -Not -BeNullOrEmpty
            $exportMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create settingsMenu object from configuration" {
            $settingsMenu = NewMenu -MenuName "settingsMenu" -MenuConfigFile (Join-Path $script:RepoRoot "menu")
            
            $settingsMenu | Should -Not -BeNullOrEmpty
            $settingsMenu.Title | Should -Not -BeNullOrEmpty
            $settingsMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create autopilotMenu object from configuration" {
            $autopilotMenu = NewMenu -MenuName "autopilotMenu" -MenuConfigFile (Join-Path $script:RepoRoot "menu")
            
            $autopilotMenu | Should -Not -BeNullOrEmpty
            $autopilotMenu.Title | Should -Not -BeNullOrEmpty
            $autopilotMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create environmentMenu object from configuration" {
            $environmentMenu = NewMenu -MenuName "environmentMenu" -MenuConfigFile (Join-Path $script:RepoRoot "menu")
            
            $environmentMenu | Should -Not -BeNullOrEmpty
            $environmentMenu.Title | Should -Not -BeNullOrEmpty
            $environmentMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create inclusionExclusionMenu object from configuration" {
            $inclusionExclusionMenu = NewMenu -MenuName "inclusionExclusionMenu" -MenuConfigFile (Join-Path $script:RepoRoot "menu")
            
            $inclusionExclusionMenu | Should -Not -BeNullOrEmpty
            $inclusionExclusionMenu.Title | Should -Not -BeNullOrEmpty
            $inclusionExclusionMenu.Items | Should -Not -BeNullOrEmpty
        }

        It "Should create all 8 required menus from configuration" {
            $menuNames = @("mainMenu", "checkMenu", "serialNumberMenu", "exportMenu", 
                "settingsMenu", "autopilotMenu", "environmentMenu", "inclusionExclusionMenu")
            
            $createdMenus = @()
            foreach ($menuName in $menuNames)
            {
                $menu = NewMenu -MenuName $menuName -MenuConfigFile (Join-Path $script:RepoRoot "menu")
                $createdMenus += $menu
            }
            
            $createdMenus.Count | Should -Be 8
            $createdMenus | ForEach-Object { $_ | Should -Not -BeNullOrEmpty }
        }
    }

    Context "Menu Item Registration (AddMenuItem)" {
        BeforeEach {
            $script:testMenu = @{
                Title       = "Test Menu"
                Description = "Test Description"
                Items       = @()
            }
        }

        It "Should add single menu item to manual menu" {
            $testMenu = @{
                Title       = "Test Menu"
                Description = "Test"
                Items       = @()
            }
            
            $testMenu = AddMenuItem -menu $testMenu -Name "Test Item" -Action {
                Write-Host "Test action"
            }
            
            $testMenu.Items.Count | Should -BeGreaterOrEqual 1
            $testMenu.Items | Where-Object { $_.Name -eq "Test Item" } | Should -Not -BeNullOrEmpty
        }

        It "Should add multiple menu items to manual menu" {
            $testMenu = @{
                Title       = "Test Menu"
                Description = "Test"
                Items       = @()
            }
            
            $testMenu = AddMenuItem -menu $testMenu -Name "Item1" -Action { Write-Host "Action1" }
            $testMenu = AddMenuItem -menu $testMenu -Name "Item2" -Action { Write-Host "Action2" }
            $testMenu = AddMenuItem -menu $testMenu -Name "Item3" -Action { Write-Host "Action3" }
            
            $testMenu.Items.Count | Should -BeGreaterOrEqual 3
        }

        It "Should preserve action blocks when adding menu items" {
            $testAction = { Write-Output "Test Action Executed" }
            
            $menu = AddMenuItem -menu $script:testMenu -Name "Test Item" -Action $testAction
            
            $addedItem = $menu.Items | Where-Object { $_.Name -eq "Test Item" } | Select-Object -First 1
            $addedItem.Action | Should -Not -BeNullOrEmpty
            $addedItem.Action.GetType().Name | Should -Be "ScriptBlock"
        }

        It "Should support chaining AddMenuItem calls on manual menu" {
            $menu = AddMenuItem -menu $script:testMenu -Name "Item1" -Action { Write-Host "Action1" }
            $menu = AddMenuItem -menu $menu -Name "Item2" -Action { Write-Host "Action2" }
            
            $menu.Items.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context "Menu Structure Validation Against Configuration" {
        It "Should have menu configuration loaded from menu.psd1" {
            $script:menuConfig | Should -Not -BeNullOrEmpty
        }

        It "Should have mainMenu configuration in menu.psd1" {
            $script:menuConfig.mainMenu | Should -Not -BeNullOrEmpty
        }

        It "Should have exportMenu configuration in menu.psd1" {
            $script:menuConfig.exportMenu | Should -Not -BeNullOrEmpty
        }

        It "Should have checkMenu configuration in menu.psd1" {
            $script:menuConfig.checkMenu | Should -Not -BeNullOrEmpty
        }

        It "Should have serialNumberMenu configuration in menu.psd1" {
            $script:menuConfig.serialNumberMenu | Should -Not -BeNullOrEmpty
        }

        It "Should have autopilotMenu configuration in menu.psd1" {
            $script:menuConfig.autopilotMenu | Should -Not -BeNullOrEmpty
        }

        It "Should have settingsMenu configuration in menu.psd1" {
            $script:menuConfig.settingsMenu | Should -Not -BeNullOrEmpty
        }

        It "Should have environmentMenu configuration in menu.psd1" {
            $script:menuConfig.environmentMenu | Should -Not -BeNullOrEmpty
        }

        It "Should have all 8 menu configurations defined" {
            $expectedMenus = @("mainMenu", "checkMenu", "serialNumberMenu", "exportMenu", 
                "settingsMenu", "autopilotMenu", "environmentMenu", "inclusionExclusionMenu")
            
            foreach ($menuName in $expectedMenus)
            {
                $script:menuConfig.ContainsKey($menuName) | Should -BeTrue -Because "menu.psd1 should define $menuName"
            }
        }
    }

    Context "Menu Configuration Items Validation" {
        It "Should have items defined in mainMenu configuration" {
            $script:menuConfig.mainMenu.items | Should -Not -BeNullOrEmpty
            $script:menuConfig.mainMenu.items.Count | Should -BeGreaterThan 0
        }

        It "Should have items defined in exportMenu configuration" {
            $script:menuConfig.exportMenu.items | Should -Not -BeNullOrEmpty
            $script:menuConfig.exportMenu.items.Count | Should -BeGreaterThan 0
        }

        It "Should have items defined in checkMenu configuration" {
            $script:menuConfig.checkMenu.items | Should -Not -BeNullOrEmpty
            $script:menuConfig.checkMenu.items.Count | Should -BeGreaterThan 0
        }

        It "Should have items defined in serialNumberMenu configuration" {
            $script:menuConfig.serialNumberMenu.items | Should -Not -BeNullOrEmpty
            $script:menuConfig.serialNumberMenu.items.Count | Should -BeGreaterThan 0
        }

        It "Should have items defined in autopilotMenu configuration" {
            $script:menuConfig.autopilotMenu.items | Should -Not -BeNullOrEmpty
            $script:menuConfig.autopilotMenu.items.Count | Should -BeGreaterThan 0
        }

        It "Should have expected menu item names in exportMenu" {
            $expectedItems = @(
                "Export Autopilot Devices",
                "Export Imported Autopilot Devices",
                "Export Managed Windows Devices",
                "Export Unmanaged Windows Devices"
            )
            
            $configuredItems = $script:menuConfig.exportMenu.items | ForEach-Object { $_.name }
            
            foreach ($expectedItem in $expectedItems)
            {
                $configuredItems | Should -Contain $expectedItem
            }
        }

        It "Should have expected menu item names in serialNumberMenu" {
            $expectedItems = @(
                "Enter a serial number",
                "Use this device's serial number"
            )
            
            $configuredItems = $script:menuConfig.serialNumberMenu.items | ForEach-Object { $_.name }
            
            foreach ($expectedItem in $expectedItems)
            {
                $configuredItems | Should -Contain $expectedItem
            }
        }
    }

    Context "Menu Workflow Integration" {
        It "Should support chaining AddMenuItem calls" {
            $menu = @{
                Title       = "Test Menu"
                Description = "Test"
                Items       = @()
            }
            
            $menu = AddMenuItem -menu $menu -Name "Item1" -Action { Write-Host "Action1" }
            $menu = AddMenuItem -menu $menu -Name "Item2" -Action { Write-Host "Action2" }
            $menu = AddMenuItem -menu $menu -Name "Item3" -Action { Write-Host "Action3" }
            
            $menu.Items.Count | Should -BeGreaterOrEqual 3
            $menu.Items[0].Name | Should -Be "Item1"
            $menu.Items[1].Name | Should -Be "Item2"
            $menu.Items[2].Name | Should -Be "Item3"
        }

        It "Should maintain menu title across AddMenuItem calls" {
            $originalMenu = @{
                Title       = "Test Menu"
                Description = "Test"
                Items       = @()
            }
            $originalTitle = $originalMenu.Title
            
            $updatedMenu = AddMenuItem -menu $originalMenu -Name "TestItem" -Action { Write-Host "Test" }
            
            $updatedMenu.Title | Should -Be $originalTitle
        }

        It "Should create independent menu objects" {
            $menu1 = @{
                Title       = "Menu1"
                Description = "Test1"
                Items       = @()
            }
            $menu2 = @{
                Title       = "Menu2"
                Description = "Test2"
                Items       = @()
            }
            
            $menu1 = AddMenuItem -menu $menu1 -Name "Item1" -Action { Write-Host "Action1" }
            $menu2 = AddMenuItem -menu $menu2 -Name "Item2" -Action { Write-Host "Action2" }
            
            # Menus should be independent
            $menu1.Title | Should -Not -Be $menu2.Title
            $menu1.Items[0].Name | Should -Not -Be $menu2.Items[0].Name
        }
    }

    Context "Menu Completeness Validation" {
        It "Should create complete menu with all expected items using manual creation" {
            $exportMenu = @{
                Title       = "Export Menu"
                Description = "Export operations"
                Items       = @()
            }
            
            # Add all export menu items as in main.ps1
            $exportMenu = AddMenuItem -menu $exportMenu -Name "Export Autopilot Devices" -Action { Write-Host "Action" }
            $exportMenu = AddMenuItem -menu $exportMenu -Name "Export Imported Autopilot Devices" -Action { Write-Host "Action" }
            $exportMenu = AddMenuItem -menu $exportMenu -Name "Export Managed Windows Devices" -Action { Write-Host "Action" }
            $exportMenu = AddMenuItem -menu $exportMenu -Name "Export Unmanaged Windows Devices" -Action { Write-Host "Action" }
            $exportMenu = AddMenuItem -menu $exportMenu -Name "Export device storage report" -Action { Write-Host "Action" }
            $exportMenu = AddMenuItem -menu $exportMenu -Name "Export Application Assignments" -Action { Write-Host "Action" }
            
            $exportMenu.Items.Count | Should -BeGreaterOrEqual 6
            
            # Verify all expected items exist
            $itemNames = $exportMenu.Items | ForEach-Object { $_.Name }
            $itemNames | Should -Contain "Export Autopilot Devices"
            $itemNames | Should -Contain "Export Imported Autopilot Devices"
            $itemNames | Should -Contain "Export Managed Windows Devices"
            $itemNames | Should -Contain "Export Unmanaged Windows Devices"
            $itemNames | Should -Contain "Export device storage report"
            $itemNames | Should -Contain "Export Application Assignments"
        }

        It "Should support building menu incrementally with proper item count" {
            $serialNumberMenu = @{
                Title       = "Serial Number Menu"
                Description = "Serial number operations"
                Items       = @()
            }
            
            # Add items incrementally
            $serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number" -Action { Write-Host "Action" }
            $count1 = $serialNumberMenu.Items.Count
            
            $serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number" -Action { Write-Host "Action" }
            $count2 = $serialNumberMenu.Items.Count
            
            $count2 | Should -BeGreaterThan $count1
            $serialNumberMenu.Items.Count | Should -BeGreaterOrEqual 2
        }

        It "Should support multiple action items with distinct names" {
            $autopilotMenu = @{
                Title       = "Autopilot Menu"
                Description = "Autopilot operations"
                Items       = @()
            }
            
            # Add multiple distinct items
            $autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Quick Import device into Autopilot (requires admin rights)" -Action { Write-Host "Action" }
            $autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Custom import device into Autopilot (requires admin rights)" -Action { Write-Host "Action" }
            $autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Import Corporate Device Identifier for Device Preparation (requires admin rights)" -Action { Write-Host "Action" }
            
            $autopilotMenu.Items.Count | Should -BeGreaterOrEqual 3
            
            # Verify key items exist and are distinct
            $itemNames = $autopilotMenu.Items | ForEach-Object { $_.Name }
            $itemNames | Should -Contain "Quick Import device into Autopilot (requires admin rights)"
            $itemNames | Should -Contain "Custom import device into Autopilot (requires admin rights)"
            $itemNames | Should -Contain "Import Corporate Device Identifier for Device Preparation (requires admin rights)"
            
            # Verify all names are unique
            $uniqueNames = $itemNames | Select-Object -Unique
            $uniqueNames.Count | Should -Be $itemNames.Count
        }
    }
}
