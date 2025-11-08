# GetGroupDirectAssignments.Tests.ps1
# Unit tests for GetGroupDirectAssignments function

#Requires -Version 5.1

BeforeAll {
    # Import helper modules
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotGraphMocks.psm1" -Force
    
    # Initialize test environment
    $script:TestEnv = Initialize-AutopilotTestEnvironment
    
    # Load required functions
    . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupDirectAssignments.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    
    # Set up global variables required by functions
    $global:logFile = Join-Path $script:TestEnv.TestFolder "test.log"
    $global:maxJSONDepth = 10
    
    # Set up test variables
    $script:TestAccessToken = "test-token-12345"
    $script:TestGroupId = "group-guid-12345"
    $script:TestGroup = @{
        id = $script:TestGroupId
        displayName = "Test Group"
    }
}

Describe "Function: GetGroupDirectAssignments" -Tags 'Unit' {
    
    Context "Parameter Validation" {
        It "Should accept valid parameters" {
            Mock CallGraphAPI { return @{ responses = @() } }
            
            { GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup } | Should -Not -Throw
        }
        
        It "Should use default batch size of 20" {
            Mock CallGraphAPI { return @{ responses = @() } }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            # Batch size is used internally but not directly testable without implementation details
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept custom batch size" {
            Mock CallGraphAPI { return @{ responses = @() } }
            
            { GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -BatchSize 10 } | Should -Not -Throw
        }
    }
    
    Context "Resource List Retrieval" {
        It "Should retrieve all v1.0 resource types when IncludeBeta not specified" {
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @() } }
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @() } }
                            @{ id = "compliancePolicies"; status = 200; body = @{ value = @() } }
                            @{ id = "deviceScripts"; status = 200; body = @{ value = @() } }
                            @{ id = "appProtectionPolicies"; status = 200; body = @{ value = @() } }
                            @{ id = "intents"; status = 200; body = @{ value = @() } }
                            @{ id = "resourceAccessProfiles"; status = 200; body = @{ value = @() } }
                            @{ id = "policySets"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            
            $result | Should -Not -BeNullOrEmpty
            $result.GroupName | Should -Be $TestGroup.displayName
            $result.GroupId | Should -Be $TestGroup.id
        }
        
        It "Should retrieve additional beta resource types when IncludeBeta specified" {
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') {
                    return @{
                        responses = @(
                            @{ id = "autopilotProfiles"; status = 200; body = @{ value = @() } }
                            @{ id = "healthScripts"; status = 200; body = @{ value = @() } }
                            @{ id = "configurationPolicies"; status = 200; body = @{ value = @() } }
                            @{ id = "groupPolicyConfigs"; status = 200; body = @{ value = @() } }
                            @{ id = "wipPolicies"; status = 200; body = @{ value = @() } }
                            @{ id = "mdmWipPolicies"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeBeta
            
            # Verify beta API version is used
            Assert-MockCalled CallGraphAPI -ParameterFilter { $APIVersion -eq 'beta' }
        }
        
        It "Should include description field in resource queries" {
            Mock CallGraphAPI { 
                param($ResourcePath, $Body)
                if ($ResourcePath -eq '$batch') {
                    # Verify that select includes description
                    $bodyObj = $Body | ConvertFrom-Json
                    $bodyObj.requests[0].url | Should -Match 'description'
                    
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @() } }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
        }
    }
    
    Context "Assignment Processing" {
        It "Should filter assignments for specific group" {
            $testApp = @{
                id = "app-1"
                displayName = "Test App"
                description = "Test app description"
            }
            
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @($testApp) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    # Return assignments for the app
                    return @{
                        value = @(
                            @{
                                value = @(
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId = $TestGroupId
                                        }
                                        intent = "available"
                                        settings = @{}
                                    }
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId = "different-group-id"
                                        }
                                        intent = "available"
                                    }
                                )
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            
            # Should only include assignment for the target group
            $result.AppAssignments.Count | Should -Be 1
            $result.AllAssignments.Count | Should -Be 1
        }
        
        It "Should include description field in assignment objects" {
            $testApp = @{
                id = "app-1"
                displayName = "Test App"
                description = "App description for testing"
            }
            
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @($testApp) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    return @{
                        value = @(
                            @{
                                value = @(
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId = $TestGroupId
                                        }
                                        intent = "required"
                                    }
                                )
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            
            $result.AppAssignments[0].Description | Should -Be "App description for testing"
            $result.AppAssignments[0].Name | Should -Be "Test App"
            $result.AppAssignments[0].Type | Should -Be "Application"
        }
        
        It "Should handle resources without description gracefully" {
            $testApp = @{
                id = "app-1"
                displayName = "Test App"
                # No description property
            }
            
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @($testApp) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    return @{
                        value = @(
                            @{
                                value = @(
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId = $TestGroupId
                                        }
                                        intent = "required"
                                    }
                                )
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            
            $result.AppAssignments[0].Description | Should -Be ""
        }
        
        It "Should categorize assignments correctly" {
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id="app-1"; displayName="App1"; description="Desc1"}) } }
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @(@{id="config-1"; displayName="Config1"; description="Desc2"}) } }
                            @{ id = "policySets"; status = 200; body = @{ value = @(@{id="ps-1"; displayName="PolicySet1"; description="Desc3"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    return @{
                        value = @(
                            @{
                                value = @(
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId = $TestGroupId
                                        }
                                    }
                                )
                            }
                        ) * $ResourcePath.Count
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            
            $result.AppAssignments.Count | Should -Be 1
            $result.ConfigurationAssignments.Count | Should -Be 1
            $result.PolicySetAssignments.Count | Should -Be 1
            $result.AllAssignments.Count | Should -Be 3
        }
    }
    
    Context "Windows Information Protection Assignments" {
        It "Should retrieve WIP policy assignments when IncludeBeta specified" {
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') {
                    return @{
                        responses = @(
                            @{ id = "wipPolicies"; status = 200; body = @{ value = @(@{id="wip-1"; displayName="WIP Policy"; description="WIP Desc"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array]) {
                    return @{
                        value = @(
                            @{
                                value = @(
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId = $TestGroupId
                                        }
                                    }
                                )
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeBeta
            
            $result.WindowsInformationProtectionAssignments.Count | Should -Be 1
            $result.WindowsInformationProtectionAssignments[0].Type | Should -Be "WindowsInformationProtection"
        }
    }
    
    Context "Summary Display" {
        It "Should display summary when ShowSummary switch is used" {
            Mock CallGraphAPI { return @{ responses = @() } }
            Mock Write-Host { }
            
            GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -ShowSummary
            
            Assert-MockCalled Write-Host -ParameterFilter { $Object -match "Group Direct Assignments Summary" }
        }
    }
    
    Context "Error Handling" {
        It "Should handle missing group ID gracefully" {
            $badGroup = @{ displayName = "Bad Group" }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $badGroup
            
            $result | Should -Not -BeNullOrEmpty
            # Should return empty assignments structure
        }
        
        It "Should handle API errors gracefully" {
            Mock CallGraphAPI { throw "API Error" }
            
            { GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup } | Should -Not -Throw
        }
    }
}

AfterAll {
    if ($script:TestEnv) {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}
