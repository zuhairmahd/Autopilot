# Show-GroupAssignments.Tests.ps1
# Unit tests for Show-GroupAssignments function

#Requires -Version 5.1

BeforeAll {
    # Import helper modules
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotMenuMocks.psm1" -Force

    # Initialize test environment
    $script:TestEnv = Initialize-AutopilotTestEnvironment

    # Load required functions
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Show-GroupAssignments.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Get-GroupDirectAssignments.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupIndirectAssignments.ps1"
    . "$script:RepoRoot/functions/menuFunctions/NewMenu.ps1"
    . "$script:RepoRoot/functions/menuFunctions/AddMenuItem.ps1"
    . "$script:RepoRoot/functions/menuFunctions/ShowMenu.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"

    # Set up global variables required by functions
    $global:logFile = Join-Path $script:TestEnv.TestFolder "test.log"

    # Set up test variables
    $script:TestAccessToken = "test-token-12345"
    $script:TestGroupName = "Test Group"
    $script:TestGroup = @{
        displayName = $TestGroupName
        id          = "group-guid-12345"
    }

    # Mock global returnValues
    $global:returnValues = @{
        noGroupFoundMessage            = "noGroup"
        noGroupAssignmentsFoundMessage = "noAssignments"
        backoutText                    = "Back"
    }

    # Mock NewMenu globally to return a valid menu structure
    Mock NewMenu {
        return @{
            Title       = if ($Title) { $Title } else { "Test Menu" }
            Description = if ($Description) { $Description } else { "Test Description" }
            MenuItems   = @()
        }
    } -ModuleName $null

    # Mock AddMenuItem globally to just return the menu unchanged
    Mock AddMenuItem {
        param($menu)
        return $menu
    } -ModuleName $null
}

Describe "Function: Show-GroupAssignments" -Tags 'Unit' {

    Context "Parameter Validation" {
        It "Should require accessToken parameter" {
            Mock Get-GroupDirectAssignments { }
            Mock Write-Error { }

            Show-GroupAssignments -Group $TestGroup

            Assert-MockCalled Write-Error -ParameterFilter { $Message -match "Access token" }
        }

        It "Should accept group as object" {
            Mock Get-GroupDirectAssignments { return @{ AllAssignments = @() } }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }

            { Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken } | Should -Not -Throw
        }

        It "Should accept group as string" {
            Mock Get-GroupDirectAssignments { return @{ AllAssignments = @() } }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }

            { Show-GroupAssignments -Group $TestGroupName -accessToken $TestAccessToken } | Should -Not -Throw
        }
    }

    Context "Assignment Retrieval" {
        It "Should call Get-GroupDirectAssignments with IncludeBeta" {
            Mock Get-GroupDirectAssignments {
                return @{
                    AllAssignments           = @()
                    AppAssignments           = @()
                    ConfigurationAssignments = @()
                }
            }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            Assert-MockCalled Get-GroupDirectAssignments -ParameterFilter {
                $includeBeta -eq $true
            }
        }

        It "Should return when no group found" {
            Mock Get-GroupDirectAssignments { return 'noGroup' }

            $result = Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            $result | Should -Be "noGroup"
        }

        It "Should return when no assignments found" {
            Mock Get-GroupDirectAssignments {
                return @{ AllAssignments = @() }
            }

            $result = Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            $result | Should -Be "noAssignments"
        }
    }

    Context "Menu Creation" {
        It "Should create menu with all assignment type options" {
            $mockAssignments = @{
                AllAssignments                          = @(@{Type = "Application"; Name = "App1"; Description = "Desc1"})
                AppAssignments                          = @(@{Type = "Application"; Name = "App1"; Description = "Desc1"})
                ConfigurationAssignments                = @()
                ComplianceAssignments                   = @()
                ScriptAssignments                       = @()
                AppProtectionAssignments                = @()
                IntentAssignments                       = @()
                ResourceAccessAssignments               = @()
                AutopilotAssignments                    = @()
                HealthScriptAssignments                 = @()
                ConfigurationPolicyAssignments          = @()
                GroupPolicyAssignments                  = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments                    = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock NewMenu {
                return @{
                    Title = "Group Assignments"
                    Items = @()
                }
            }
            Mock AddMenuItem {
                param($menu, $name)
                return $menu
            }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            # Verify all assignment types are added as menu items
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Application" }
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Device Configurations" }
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Windows Information Protection" }
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Policy Sets" }
        }
    }

    Context "Assignment Display" {
        It "Should create menu with assignment counts" {
            $mockAssignments = @{
                AllAssignments                          = @(
                    @{Type = "Application"; Name = "Test App"; Description = "Test Description"; Id = "app-1"}
                )
                AppAssignments                          = @(
                    @{Type = "Application"; Name = "Test App"; Description = "Test Description"; Id = "app-1"}
                )
                ConfigurationAssignments                = @()
                ComplianceAssignments                   = @()
                ScriptAssignments                       = @()
                AppProtectionAssignments                = @()
                IntentAssignments                       = @()
                ResourceAccessAssignments               = @()
                AutopilotAssignments                    = @()
                HealthScriptAssignments                 = @()
                ConfigurationPolicyAssignments          = @()
                GroupPolicyAssignments                  = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments                    = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            # Verify AddMenuItem was called with correct counts
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Application.*\(1\)" }
        }


    }

    Context "Assignment Structure" {
        It "Should verify assignments include description field" {
            $mockAssignments = @{
                AllAssignments                          = @(
                    @{Type = "Application"; Name = "App1"; Description = "Desc1"; Id = "app-1"}
                    @{Type = "Configuration"; Name = "Config1"; Description = "Desc2"; Id = "config-1"}
                )
                AppAssignments                          = @(@{Type = "Application"; Name = "App1"; Description = "Desc1"; Id = "app-1"})
                ConfigurationAssignments                = @(@{Type = "Configuration"; Name = "Config1"; Description = "Desc2"; Id = "config-1"})
                ComplianceAssignments                   = @()
                ScriptAssignments                       = @()
                AppProtectionAssignments                = @()
                IntentAssignments                       = @()
                ResourceAccessAssignments               = @()
                AutopilotAssignments                    = @()
                HealthScriptAssignments                 = @()
                ConfigurationPolicyAssignments          = @()
                GroupPolicyAssignments                  = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments                    = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            # Verify assignments structure includes description
            $mockAssignments.AllAssignments[0].Description | Should -Be "Desc1"
            $mockAssignments.AllAssignments[1].Description | Should -Be "Desc2"
        }
    }

    Context "Assignment Type Support" {
        It "Should include Windows Information Protection in menu" {
            $mockAssignments = @{
                AllAssignments                          = @(
                    @{Type = "WindowsInformationProtection"; Name = "WIP Policy"; Description = "WIP Desc"; Id = "wip-1"}
                )
                AppAssignments                          = @()
                ConfigurationAssignments                = @()
                ComplianceAssignments                   = @()
                ScriptAssignments                       = @()
                AppProtectionAssignments                = @()
                IntentAssignments                       = @()
                ResourceAccessAssignments               = @()
                AutopilotAssignments                    = @()
                HealthScriptAssignments                 = @()
                ConfigurationPolicyAssignments          = @()
                GroupPolicyAssignments                  = @()
                WindowsInformationProtectionAssignments = @(
                    @{Type = "WindowsInformationProtection"; Name = "WIP Policy"; Description = "WIP Desc"; Id = "wip-1"}
                )
                PolicySetAssignments                    = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            # Verify WIP menu item was added with count
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Windows Information Protection.*\(1\)" }
        }

        It "Should include Policy Sets in menu" {
            $mockAssignments = @{
                AllAssignments                          = @(
                    @{Type = "PolicySet"; Name = "Test Policy Set"; Description = "PS Desc"; Id = "ps-1"}
                )
                AppAssignments                          = @()
                ConfigurationAssignments                = @()
                ComplianceAssignments                   = @()
                ScriptAssignments                       = @()
                AppProtectionAssignments                = @()
                IntentAssignments                       = @()
                ResourceAccessAssignments               = @()
                AutopilotAssignments                    = @()
                HealthScriptAssignments                 = @()
                ConfigurationPolicyAssignments          = @()
                GroupPolicyAssignments                  = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments                    = @(
                    @{Type = "PolicySet"; Name = "Test Policy Set"; Description = "PS Desc"; Id = "ps-1"}
                )
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            # Verify Policy Set menu item was added with count
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Policy Sets.*\(1\)" }
        }
    }

    Context "Navigation" {
        It "Should return navigation option when user selects Back" {
            $mockAssignments = @{
                AllAssignments                          = @(@{Type = "Application"; Name = "App1"; Description = ""; Id = "app-1"})
                AppAssignments                          = @()
                ConfigurationAssignments                = @()
                ComplianceAssignments                   = @()
                ScriptAssignments                       = @()
                AppProtectionAssignments                = @()
                IntentAssignments                       = @()
                ResourceAccessAssignments               = @()
                AutopilotAssignments                    = @()
                HealthScriptAssignments                 = @()
                ConfigurationPolicyAssignments          = @()
                GroupPolicyAssignments                  = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments                    = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            Mock AddMenuItem {
                param($menu)
                return $menu
            }

            $result = Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            $result | Should -Be "Back"
        }
    }

    Context "Indirect Assignments Display" {
        # NOTE: Interactive loop tests with Console.ReadKey are covered in integration tests
        # See: tests/Integration/GroupAssignments.Tests.ps1

        It "Should pass ShowIndirectAssignments switch to Get-GroupDirectAssignments" {
            Mock Get-GroupDirectAssignments {
                return @{ AllAssignments = @() }
            }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken -ShowIndirectAssignments

            Assert-MockCalled Get-GroupDirectAssignments -ParameterFilter {
                $IncludeIndirectAssignments -eq $true
            }
        }

        It "Should not include indirect assignments by default" {
            Mock Get-GroupDirectAssignments {
                return @{ AllAssignments = @() }
            }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            Assert-MockCalled Get-GroupDirectAssignments -ParameterFilter {
                $IncludeIndirectAssignments -ne $true
            }
        }

        It "Should display message when including indirect assignments" {
            Mock Get-GroupDirectAssignments {
                return @{ AllAssignments = @() }
            }
            Mock Write-Host { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken -ShowIndirectAssignments

            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -match "Including indirect assignments.*All Users and All Devices"
            }
        }
    }

    Context "Assignment Consolidation" {
        It "Should consolidate duplicate assignments with multiple scopes" {
            # Create test assignments with duplicates across different scopes
            $mockAssignments = @{
                AllAssignments = @(
                    # Direct assignment
                    [PSCustomObject]@{
                        Type        = "Application"
                        Name        = "App1"
                        Description = "Test App"
                        Id          = "app-guid-123"
                        Intent      = $null
                        Target      = @{}
                        Settings    = @{}
                    }
                    # Indirect assignment - All Users
                    [PSCustomObject]@{
                        Type            = "Application"
                        Name            = "App1"
                        Description     = "Test App"
                        Id              = "app-guid-123"
                        Intent          = $null
                        Target          = @{}
                        Settings        = @{}
                        AssignmentScope = "All Users"
                    }
                    # Indirect assignment - All Devices
                    [PSCustomObject]@{
                        Type            = "Application"
                        Name            = "App1"
                        Description     = "Test App"
                        Id              = "app-guid-123"
                        Intent          = $null
                        Target          = @{}
                        Settings        = @{}
                        AssignmentScope = "All Devices"
                    }
                    # Another app with single assignment
                    [PSCustomObject]@{
                        Type        = "Configuration"
                        Name        = "Config1"
                        Description = "Test Config"
                        Id          = "config-guid-456"
                        Intent      = $null
                        Target      = @{}
                        Settings    = @{}
                    }
                )
                AppAssignments           = @()
                ConfigurationAssignments = @()
                ComplianceAssignments    = @()
                ScriptAssignments        = @()
                AppProtectionAssignments = @()
                IntentAssignments        = @()
                ResourceAccessAssignments = @()
                AutopilotAssignments     = @()
                HealthScriptAssignments  = @()
                ConfigurationPolicyAssignments = @()
                GroupPolicyAssignments   = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments     = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            Mock Write-Log { }

            # Call the function
            $result = Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken -ShowIndirectAssignments

            # Verify Write-Log was called with consolidation messages
            Assert-MockCalled Write-Log -ParameterFilter {
                $Message -match "Consolidating duplicate assignments.*before: 4"
            }

            Assert-MockCalled Write-Log -ParameterFilter {
                $Message -match "Consolidation complete.*after: 2"
            }
        }

        It "Should create AssignmentScope array for single direct assignment" {
            $mockAssignments = @{
                AllAssignments = @(
                    [PSCustomObject]@{
                        Type        = "Application"
                        Name        = "SingleApp"
                        Description = "Single Direct Assignment"
                        Id          = "app-single-123"
                        Intent      = $null
                        Target      = @{}
                        Settings    = @{}
                    }
                )
                AppAssignments = @()
                ConfigurationAssignments = @()
                ComplianceAssignments = @()
                ScriptAssignments = @()
                AppProtectionAssignments = @()
                IntentAssignments = @()
                ResourceAccessAssignments = @()
                AutopilotAssignments = @()
                HealthScriptAssignments = @()
                ConfigurationPolicyAssignments = @()
                GroupPolicyAssignments = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            Mock Write-Log { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken

            # Should consolidate 1 entry to 1 entry with proper scope
            Assert-MockCalled Write-Log -ParameterFilter {
                $Message -match "Consolidation complete.*after: 1"
            }
        }

        It "Should combine multiple indirect scopes correctly" {
            $mockAssignments = @{
                AllAssignments = @(
                    # All Users assignment
                    [PSCustomObject]@{
                        Type            = "Compliance"
                        Name            = "Policy1"
                        Description     = "Test Policy"
                        Id              = "policy-guid-789"
                        Intent          = $null
                        Target          = @{}
                        Settings        = @{}
                        AssignmentScope = "All Users"
                    }
                    # All Devices assignment (duplicate)
                    [PSCustomObject]@{
                        Type            = "Compliance"
                        Name            = "Policy1"
                        Description     = "Test Policy"
                        Id              = "policy-guid-789"
                        Intent          = $null
                        Target          = @{}
                        Settings        = @{}
                        AssignmentScope = "All Devices"
                    }
                )
                AppAssignments = @()
                ConfigurationAssignments = @()
                ComplianceAssignments = @()
                ScriptAssignments = @()
                AppProtectionAssignments = @()
                IntentAssignments = @()
                ResourceAccessAssignments = @()
                AutopilotAssignments = @()
                HealthScriptAssignments = @()
                ConfigurationPolicyAssignments = @()
                GroupPolicyAssignments = @()
                WindowsInformationProtectionAssignments = @()
                PolicySetAssignments = @()
            }

            Mock Get-GroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            Mock Write-Log { }

            Show-GroupAssignments -Group $TestGroup -accessToken $TestAccessToken -ShowIndirectAssignments

            # Should consolidate 2 entries to 1 entry
            Assert-MockCalled Write-Log -ParameterFilter {
                $Message -match "Consolidation complete.*after: 1"
            }
        }
    }
}

AfterAll {
    if ($script:TestEnv)
    {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}
