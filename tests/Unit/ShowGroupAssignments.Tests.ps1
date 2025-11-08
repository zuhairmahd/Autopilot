# ShowGroupAssignments.Tests.ps1
# Unit tests for ShowGroupAssignments function

#Requires -Version 5.1

BeforeAll {
    # Import helper modules
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotMenuMocks.psm1" -Force
    
    # Initialize test environment
    $script:TestEnv = Initialize-AutopilotTestEnvironment
    
    # Load required functions
    . "$script:RepoRoot/functions/UserAndGroupFunctions/ShowGroupAssignments.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupDirectAssignments.ps1"
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
    
    # Mock System.Console globally for tests that display results
    # Create a mock type that can be used in place of [System.Console]
    if (-not ('MockConsole' -as [type]))
    {
        Add-Type -TypeDefinition @"
            public class MockConsole {
                public static System.ConsoleKeyInfo ReadKey(bool intercept) {
                    return new System.ConsoleKeyInfo(' ', System.ConsoleKey.Spacebar, false, false, false);
                }
            }
"@
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

Describe "Function: ShowGroupAssignments" -Tags 'Unit' {
    
    Context "Parameter Validation" {
        It "Should require accessToken parameter" {
            Mock GetGroupDirectAssignments { }
            Mock Write-Error { }
            
            ShowGroupAssignments -Group $TestGroup
            
            Assert-MockCalled Write-Error -ParameterFilter { $Message -match "Access token" }
        }
        
        It "Should accept group as object" {
            Mock GetGroupDirectAssignments { return @{ AllAssignments = @() } }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            
            { ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken } | Should -Not -Throw
        }
        
        It "Should accept group as string" {
            Mock GetGroupDirectAssignments { return @{ AllAssignments = @() } }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            
            { ShowGroupAssignments -Group $TestGroupName -accessToken $TestAccessToken } | Should -Not -Throw
        }
    }
    
    Context "Assignment Retrieval" {
        It "Should call GetGroupDirectAssignments with IncludeBeta" {
            Mock GetGroupDirectAssignments { 
                return @{
                    AllAssignments           = @()
                    AppAssignments           = @()
                    ConfigurationAssignments = @()
                }
            }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            Assert-MockCalled GetGroupDirectAssignments -ParameterFilter { 
                $includeBeta -eq $true 
            }
        }
        
        It "Should return when no group found" {
            Mock GetGroupDirectAssignments { return 'noGroup' }
            
            $result = ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            $result | Should -Be "noGroup"
        }
        
        It "Should return when no assignments found" {
            Mock GetGroupDirectAssignments { 
                return @{ AllAssignments = @() }
            }
            
            $result = ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
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
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            # Verify all assignment types are added as menu items
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Application" }
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Device Configurations" }
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Windows Information Protection" }
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Policy Sets" }
        }
    }
    
    Context "Assignment Display" {
        It "Should display assignment name" {
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
            # First call returns assignment type, second call returns Back to exit loop
            $script:showMenuCallCount = 0
            Mock ShowMenu { 
                $script:showMenuCallCount++
                if ($script:showMenuCallCount -eq 1)
                {
                    return "Application"
                }
                else
                {
                    return "Back"
                }
            }
            Mock Write-Host { }
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            Assert-MockCalled Write-Host -ParameterFilter { $Object -match "Test App" }
        }
        
        It "Should display assignment description when available" {
            $mockAssignments = @{
                AllAssignments                          = @(
                    @{Type = "Application"; Name = "Test App"; Description = "Important app for testing"; Id = "app-1"}
                )
                AppAssignments                          = @(
                    @{Type = "Application"; Name = "Test App"; Description = "Important app for testing"; Id = "app-1"}
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
            $script:showMenuCallCount = 0
            Mock ShowMenu { 
                $script:showMenuCallCount++
                if ($script:showMenuCallCount -eq 1)
                {
                    return "Application"
                }
                else
                {
                    return "Back"
                }
            }
            Mock Write-Host { }
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            Assert-MockCalled Write-Host -ParameterFilter { $Object -match "Important app for testing" }
        }
        
        It "Should not display description when empty" {
            $mockAssignments = @{
                AllAssignments                          = @(
                    @{Type = "Application"; Name = "Test App"; Description = ""; Id = "app-1"}
                )
                AppAssignments                          = @(
                    @{Type = "Application"; Name = "Test App"; Description = ""; Id = "app-1"}
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
            $script:showMenuCallCount = 0
            Mock ShowMenu { 
                $script:showMenuCallCount++
                if ($script:showMenuCallCount -eq 1)
                {
                    return "Application"
                }
                else
                {
                    return "Back"
                }
            }
            Mock Write-Host { }
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            # Should not call Write-Host with "Description: " prefix
            Assert-MockCalled Write-Host -ParameterFilter { $Object -notmatch "Description: $" }
        }
    }
    
    Context "Assignment Export" {
        It "Should export all assignments to CSV" {
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
            $script:showMenuCallCount = 0
            Mock ShowMenu { 
                $script:showMenuCallCount++
                if ($script:showMenuCallCount -eq 1)
                {
                    return "All"
                }
                else
                {
                    return "Back"
                }
            }
            Mock Write-Host { }
            Mock Export-Csv { }
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            # Verify CSV export was called with description field
            Assert-MockCalled Export-Csv -ParameterFilter { 
                $InputObject[0].Description -ne $null 
            }
        }
    }
    
    Context "Assignment Type Filtering" {
        It "Should filter Windows Information Protection assignments" {
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
            $script:showMenuCallCount = 0
            Mock ShowMenu { 
                $script:showMenuCallCount++
                if ($script:showMenuCallCount -eq 1)
                {
                    return "WindowsInformationProtection"
                }
                else
                {
                    return "Back"
                }
            }
            Mock Write-Host { }
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            Assert-MockCalled Write-Host -ParameterFilter { $Object -match "WIP Policy" }
        }
        
        It "Should filter Policy Set assignments" {
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
            $script:showMenuCallCount = 0
            Mock ShowMenu { 
                $script:showMenuCallCount++
                if ($script:showMenuCallCount -eq 1)
                {
                    return "PolicySet"
                }
                else
                {
                    return "Back"
                }
            }
            Mock Write-Host { }
            
            ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            Assert-MockCalled Write-Host -ParameterFilter { $Object -match "Test Policy Set" }
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
            
            Mock GetGroupDirectAssignments { return $mockAssignments }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            Mock AddMenuItem { 
                param($menu)
                return $menu
            }
            
            $result = ShowGroupAssignments -Group $TestGroup -accessToken $TestAccessToken
            
            $result | Should -Be "Back"
        }
    }
}

AfterAll {
    if ($script:TestEnv)
    {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}
