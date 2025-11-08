<#
.SYNOPSIS
    Integration tests for Group Assignments workflows

.DESCRIPTION
    Tests end-to-end workflows for retrieving and displaying group assignments.
    Validates the integration between:
    - GetGroupDirectAssignments (direct assignments to groups)
    - GetGroupIndirectAssignments (All Users/All Devices assignments)
    - ShowGroupAssignments (interactive display and menu workflows)
    
    These tests cover scenarios that cannot be tested in unit tests due to:
    - Interactive loops with [System.Console]::ReadKey()
    - Complex batch API interactions
    - Full workflow integration across multiple functions

.NOTES
    Test Category: Integration
    Dependencies: UserAndGroupFunctions, AutopilotGraphMocks, AutopilotMenuMocks
    
    These integration tests complement the unit tests in:
    - tests/Unit/ShowGroupAssignments.Tests.ps1
    - tests/Unit/GetGroupDirectAssignments.Tests.ps1 (to be created)
    - tests/Unit/GetGroupIndirectAssignments.Tests.ps1 (to be created)
#>

#Requires -Version 5.1

BeforeAll {
    # Get repository root
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    
    # Import helper modules
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotGraphMocks.psm1" -Force
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotMenuMocks.psm1" -Force
    
    # Initialize test environment
    $script:TestEnv = Initialize-AutopilotTestEnvironment
    
    # Load required functions via direct dot-sourcing
    . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupDirectAssignments.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupIndirectAssignments.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/ShowGroupAssignments.ps1"
    . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
    . "$script:RepoRoot/functions/menuFunctions/NewMenu.ps1"
    . "$script:RepoRoot/functions/menuFunctions/AddMenuItem.ps1"
    . "$script:RepoRoot/functions/menuFunctions/ShowMenu.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    
    # Set up global variables
    $global:logFile = Join-Path $script:TestEnv.TestFolder "test.log"
    $global:maxJSONDepth = 10
    
    # Mock global returnValues
    $global:returnValues = @{
        noGroupFoundMessage            = "noGroup"
        noGroupAssignmentsFoundMessage = "noAssignments"
        backoutText                    = "Back"
    }
    
    # Test data
    $script:TestAccessToken = "test-token-integration-12345"
    $script:TestGroup = @{
        displayName = "Integration Test Group"
        id          = "group-integration-guid-12345"
    }
}

AfterAll {
    if ($script:TestEnv) {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}

Describe "GetGroupDirectAssignments Integration" -Tags 'Integration', 'GroupAssignments' {
    
    Context "Batch API Processing" {
        It "Should retrieve assignments across multiple resource types using batch API" {
            # Mock CallGraphAPI to simulate batch responses
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method, $Body)
                
                if ($ResourcePath -eq "`$batch") {
                    # Return batch response with multiple resource types
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(
                                @{ id = "app-1"; displayName = "Test App 1"; description = "App description" }
                                @{ id = "app-2"; displayName = "Test App 2"; description = "" }
                            )}}
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @(
                                @{ id = "config-1"; displayName = "Test Config 1"; description = "Config description" }
                            )}}
                            @{ id = "compliancePolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceScripts"; status = 200; body = @{ value = @() }}
                            @{ id = "appProtectionPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "intents"; status = 200; body = @{ value = @() }}
                            @{ id = "resourceAccessProfiles"; status = 200; body = @{ value = @() }}
                            @{ id = "policySets"; status = 200; body = @{ value = @() }}
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    # Return batch response for assignments
                    $responses = @()
                    foreach ($path in $ResourcePath) {
                        if ($path -match "app-1") {
                            $responses += @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroup.id }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                        else {
                            $responses += @{ value = @() }
                        }
                    }
                    return @{ value = $responses }
                }
                
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $script:TestAccessToken `
                -GroupName $script:TestGroup -IncludeBeta
            
            $result | Should -Not -BeNullOrEmpty
            $result.GroupName | Should -Be $script:TestGroup.displayName
            $result.AppAssignments.Count | Should -BeGreaterThan 0
            $result.AllAssignments.Count | Should -BeGreaterThan 0
        }
        
        It "Should include description field in assignments" {
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method, $Body)
                
                if ($ResourcePath -eq "`$batch") {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(
                                @{ id = "app-desc"; displayName = "App With Description"; description = "This is a test description" }
                            )}}
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @() }}
                            @{ id = "compliancePolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceScripts"; status = 200; body = @{ value = @() }}
                            @{ id = "appProtectionPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "intents"; status = 200; body = @{ value = @() }}
                            @{ id = "resourceAccessProfiles"; status = 200; body = @{ value = @() }}
                            @{ id = "policySets"; status = 200; body = @{ value = @() }}
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    return @{
                        value = @(
                            @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroup.id }
                                        intent = "required"
                                    }
                                )
                            }
                        )
                    }
                }
                
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $script:TestAccessToken `
                -GroupName $script:TestGroup
            
            $result.AllAssignments[0].Description | Should -Be "This is a test description"
        }
    }
    
    Context "Indirect Assignments Integration" {
        It "Should retrieve and merge indirect assignments when IncludeIndirectAssignments is specified" {
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method, $Body)
                
                if ($ResourcePath -eq "`$batch") {
                    # Simulate resources for both direct and indirect checks
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(
                                @{ id = "app-direct"; displayName = "Direct App"; description = "" }
                                @{ id = "app-indirect"; displayName = "Indirect App"; description = "" }
                            )}}
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @() }}
                            @{ id = "compliancePolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceScripts"; status = 200; body = @{ value = @() }}
                            @{ id = "appProtectionPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "intents"; status = 200; body = @{ value = @() }}
                            @{ id = "resourceAccessProfiles"; status = 200; body = @{ value = @() }}
                            @{ id = "policySets"; status = 200; body = @{ value = @() }}
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    $responses = @()
                    foreach ($path in $ResourcePath) {
                        if ($path -match "app-direct") {
                            # Direct assignment to group
                            $responses += @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroup.id }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                        elseif ($path -match "app-indirect") {
                            # Indirect assignment via All Users
                            $responses += @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                        else {
                            $responses += @{ value = @() }
                        }
                    }
                    return @{ value = $responses }
                }
                
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $script:TestAccessToken `
                -GroupName $script:TestGroup -IncludeIndirectAssignments
            
            # Should have both direct and indirect assignments
            $result.AllAssignments.Count | Should -Be 2
            
            # Verify assignment scopes
            $directAssignment = $result.AllAssignments | Where-Object { $_.Name -eq "Direct App" }
            $indirectAssignment = $result.AllAssignments | Where-Object { $_.Name -eq "Indirect App" }
            
            $directAssignment | Should -Not -BeNullOrEmpty
            $indirectAssignment | Should -Not -BeNullOrEmpty
            $indirectAssignment.AssignmentScope | Should -Be "All Users"
        }
    }
}

Describe "GetGroupIndirectAssignments Integration" -Tags 'Integration', 'GroupAssignments' {
    
    Context "Virtual Group Assignment Detection" {
        It "Should identify All Users assignments correctly" {
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method, $Body)
                
                if ($ResourcePath -eq "`$batch") {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(
                                @{ id = "app-allusers"; displayName = "All Users App"; description = "" }
                            )}}
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @() }}
                            @{ id = "compliancePolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceScripts"; status = 200; body = @{ value = @() }}
                            @{ id = "appProtectionPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "intents"; status = 200; body = @{ value = @() }}
                            @{ id = "resourceAccessProfiles"; status = 200; body = @{ value = @() }}
                            @{ id = "policySets"; status = 200; body = @{ value = @() }}
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    return @{
                        value = @(
                            @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
                                        intent = "required"
                                    }
                                )
                            }
                        )
                    }
                }
                
                return @{ value = @() }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $script:TestAccessToken -IncludeBeta
            
            $result.AllAssignments.Count | Should -Be 1
            $result.AllAssignments[0].AssignmentScope | Should -Be "All Users"
        }
        
        It "Should identify All Devices assignments correctly" {
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method, $Body)
                
                if ($ResourcePath -eq "`$batch") {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @(
                                @{ id = "config-alldevices"; displayName = "All Devices Config"; description = "" }
                            )}}
                            @{ id = "compliancePolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceScripts"; status = 200; body = @{ value = @() }}
                            @{ id = "appProtectionPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "intents"; status = 200; body = @{ value = @() }}
                            @{ id = "resourceAccessProfiles"; status = 200; body = @{ value = @() }}
                            @{ id = "policySets"; status = 200; body = @{ value = @() }}
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    return @{
                        value = @(
                            @{ value = @() }
                            @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' }
                                    }
                                )
                            }
                        )
                    }
                }
                
                return @{ value = @() }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $script:TestAccessToken -IncludeBeta
            
            $result.AllAssignments.Count | Should -Be 1
            $result.AllAssignments[0].AssignmentScope | Should -Be "All Devices"
        }
    }
    
    Context "Beta API Resource Types" {
        It "Should retrieve beta resource types when IncludeBeta is specified" {
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method, $Body)
                
                if ($ResourcePath -eq "`$batch") {
                    # Include beta-only resource types
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @() }}
                            @{ id = "compliancePolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "deviceScripts"; status = 200; body = @{ value = @() }}
                            @{ id = "appProtectionPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "intents"; status = 200; body = @{ value = @() }}
                            @{ id = "resourceAccessProfiles"; status = 200; body = @{ value = @() }}
                            @{ id = "policySets"; status = 200; body = @{ value = @() }}
                            @{ id = "autopilotProfiles"; status = 200; body = @{ value = @(
                                @{ id = "autopilot-1"; displayName = "Autopilot Profile"; description = "" }
                            )}}
                            @{ id = "healthScripts"; status = 200; body = @{ value = @() }}
                            @{ id = "configurationPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "groupPolicyConfigs"; status = 200; body = @{ value = @() }}
                            @{ id = "wipPolicies"; status = 200; body = @{ value = @() }}
                            @{ id = "mdmWipPolicies"; status = 200; body = @{ value = @() }}
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    $responses = @()
                    foreach ($path in $ResourcePath) {
                        if ($path -match "autopilot") {
                            $responses += @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' }
                                    }
                                )
                            }
                        }
                        else {
                            $responses += @{ value = @() }
                        }
                    }
                    return @{ value = $responses }
                }
                
                return @{ value = @() }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $script:TestAccessToken -IncludeBeta
            
            # Verify beta resource was processed
            $result.AutopilotAssignments.Count | Should -Be 1
            $result.AllAssignments[0].Type | Should -Be "AutopilotProfile"
        }
    }
}

Describe "ShowGroupAssignments Integration" -Tags 'Integration', 'GroupAssignments', 'Interactive' {
    
    Context "Interactive Menu Workflow (Simulated)" {
        It "Should display assignments and return to menu without hanging" {
            # Mock GetGroupDirectAssignments
            Mock GetGroupDirectAssignments {
                return @{
                    GroupName                               = $script:TestGroup.displayName
                    GroupId                                 = $script:TestGroup.id
                    AppAssignments                          = @(
                        @{ Type = "Application"; Name = "Test App"; Description = ""; Id = "app-1" }
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
                    AllAssignments                          = @(
                        @{ Type = "Application"; Name = "Test App"; Description = ""; Id = "app-1" }
                    )
                }
            }
            
            # Mock menu functions
            Mock NewMenu {
                return @{
                    Title       = "Test Menu"
                    Description = "Test"
                    MenuItems   = @()
                }
            }
            
            Mock AddMenuItem {
                param($menu)
                return $menu
            }
            
            # Mock ShowMenu to return Back immediately (simulates user pressing Back)
            Mock ShowMenu {
                return "Back"
            }
            
            Mock Write-Host { }
            
            # This should NOT hang - it should return immediately when ShowMenu returns "Back"
            $result = ShowGroupAssignments -Group $script:TestGroup -accessToken $script:TestAccessToken
            
            $result | Should -Be "Back"
            Assert-MockCalled GetGroupDirectAssignments -Times 1 -Exactly
            Assert-MockCalled ShowMenu -Times 1 -Exactly
        }
        
        It "Should handle CSV export workflow" {
            Mock GetGroupDirectAssignments {
                return @{
                    GroupName                               = $script:TestGroup.displayName
                    GroupId                                 = $script:TestGroup.id
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
                    AllAssignments                          = @(
                        @{ Type = "Application"; Name = "Export Test App"; Description = "Test"; Id = "app-export" }
                    )
                }
            }
            
            Mock NewMenu { return @{ Title = "Test"; Description = "Test"; MenuItems = @() } }
            Mock AddMenuItem { param($menu); return $menu }
            Mock Write-Host { }
            Mock Export-Csv { }
            
            # Simulate: ShowMenu returns "Back" immediately (don't enter interactive loop)
            Mock ShowMenu { return "Back" }
            
            # NOTE: Full CSV export with "All" selection and interactive loop is covered by manual testing
            # This test verifies the menu structure supports the export option
            
            $result = ShowGroupAssignments -Group $script:TestGroup -accessToken $script:TestAccessToken
            
            # Verify menu was created with export option
            Assert-MockCalled AddMenuItem -ParameterFilter { $name -match "Export All Assignments" }
            $result | Should -Be "Back"
        }
    }
    
    Context "Assignment Scope Display with Indirect Assignments" {
        It "Should display assignment scope when ShowIndirectAssignments is specified" {
            Mock GetGroupDirectAssignments {
                return @{
                    GroupName                               = $script:TestGroup.displayName
                    GroupId                                 = $script:TestGroup.id
                    AppAssignments                          = @(
                        @{ Type = "Application"; Name = "Indirect App"; Description = ""; Id = "app-indirect"; AssignmentScope = "All Users" }
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
                    AllAssignments                          = @(
                        @{ Type = "Application"; Name = "Indirect App"; Description = ""; Id = "app-indirect"; AssignmentScope = "All Users" }
                    )
                }
            }
            
            Mock NewMenu { return @{ Title = "Test"; Description = "Test"; MenuItems = @() } }
            Mock AddMenuItem { param($menu); return $menu }
            Mock ShowMenu { return "Back" }
            Mock Write-Host { }
            
            ShowGroupAssignments -Group $script:TestGroup -accessToken $script:TestAccessToken -ShowIndirectAssignments
            
            # Verify the message about indirect assignments was displayed
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -match "Including indirect assignments.*All Users and All Devices"
            }
            
            # Verify GetGroupDirectAssignments was called with the switch
            Assert-MockCalled GetGroupDirectAssignments -ParameterFilter {
                $IncludeIndirectAssignments -eq $true
            }
        }
    }
    
    Context "Error Handling" {
        It "Should handle no group found gracefully" {
            Mock GetGroupDirectAssignments { return 'noGroup' }
            
            $result = ShowGroupAssignments -Group $script:TestGroup -accessToken $script:TestAccessToken
            
            $result | Should -Be "noGroup"
        }
        
        It "Should handle no assignments found gracefully" {
            Mock GetGroupDirectAssignments {
                return @{
                    GroupName                               = $script:TestGroup.displayName
                    GroupId                                 = $script:TestGroup.id
                    AllAssignments                          = @()
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
            }
            
            $result = ShowGroupAssignments -Group $script:TestGroup -accessToken $script:TestAccessToken
            
            $result | Should -Be "noAssignments"
        }
    }
}
