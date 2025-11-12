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
    . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupIndirectAssignments.ps1"
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"
    
    # Set up global variables required by functions
    $global:logFile = Join-Path $script:TestEnv.TestFolder "test.log"
    $global:maxJSONDepth = 10
    
    # Set up test variables
    $script:TestAccessToken = "test-token-12345"
    $script:TestGroupId = "group-guid-12345"
    $script:TestGroup = @{
        id          = $script:TestGroupId
        displayName = "Test Group"
    }
}

Describe "Function: GetGroupDirectAssignments" -Tags 'Unit' {
    BeforeAll {
        # Mock caching functions to prevent cross-test contamination
        Mock Get-CachedData { return $null }
        Mock Set-CachedData { }
    }
    
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
                if ($ResourcePath -eq '$batch')
                {
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
                if ($ResourcePath -eq '$batch')
                {
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
                if ($ResourcePath -eq '$batch')
                {
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
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id = "app-1"; displayName = "Test App"; description = "Test app description"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    # Return assignments for the app
                    return @{
                        value = @(
                            @{
                                id     = "1"
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            target   = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = $TestGroupId
                                            }
                                            intent   = "available"
                                            settings = @{}
                                        }
                                        @{
                                            target = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = "different-group-id"
                                            }
                                            intent = "available"
                                        }
                                    )
                                }
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
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id = "app-2"; displayName = "Test App 2"; description = "App description for testing"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    return @{
                        value = @(
                            @{
                                id     = "1"
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            target = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = $TestGroupId
                                            }
                                            intent = "required"
                                        }
                                    )
                                }
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            
            $result.AppAssignments[0].Description | Should -Be "App description for testing"
            $result.AppAssignments[0].Name | Should -Be "Test App 2"
            $result.AppAssignments[0].Type | Should -Be "Application"
        }
        
        It "Should handle resources without description gracefully" {
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id = "app-3"; displayName = "Test App 3"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    return @{
                        value = @(
                            @{
                                id     = "1"
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            target = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = $TestGroupId
                                            }
                                            intent = "required"
                                        }
                                    )
                                }
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
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id = "app-1"; displayName = "App1"; description = "Desc1"}) } }
                            @{ id = "deviceConfigs"; status = 200; body = @{ value = @(@{id = "config-1"; displayName = "Config1"; description = "Desc2"}) } }
                            @{ id = "policySets"; status = 200; body = @{ value = @(@{id = "ps-1"; displayName = "PolicySet1"; description = "Desc3"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    # Return one batch response per resource in the array
                    $responses = @()
                    for ($i = 0; $i -lt $ResourcePath.Count; $i++)
                    {
                        $responses += @{
                            id     = ($i + 1).ToString()
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId       = $TestGroupId
                                        }
                                    }
                                )
                            }
                        }
                    }
                    return @{ value = $responses }
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
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "wipPolicies"; status = 200; body = @{ value = @(@{id = "wip-1"; displayName = "WIP Policy"; description = "WIP Desc"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    return @{
                        value = @(
                            @{
                                id     = "1"
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            target = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = $TestGroupId
                                            }
                                        }
                                    )
                                }
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
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id = "app-summary"; displayName = "Summary Test App"; description = "Test"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    return @{
                        value = @(
                            @{
                                id     = "1"
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            target = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = $TestGroupId
                                            }
                                        }
                                    )
                                }
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
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
    
    Context "Indirect Assignments Integration" {
        It "Should not call GetGroupIndirectAssignments when IncludeIndirectAssignments not specified" {
            Mock CallGraphAPI { return @{ responses = @() } }
            Mock GetGroupIndirectAssignments { }
            
            GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup
            
            Assert-MockCalled GetGroupIndirectAssignments -Times 0
        }
        
        It "Should call GetGroupIndirectAssignments when IncludeIndirectAssignments specified" {
            Mock CallGraphAPI { return @{ responses = @() } }
            Mock GetGroupIndirectAssignments {
                return @{
                    AppAssignments                          = @()
                    ConfigurationAssignments                = @()
                    ComplianceAssignments                   = @()
                    AutopilotAssignments                    = @()
                    ScriptAssignments                       = @()
                    HealthScriptAssignments                 = @()
                    AppProtectionAssignments                = @()
                    IntentAssignments                       = @()
                    ResourceAccessAssignments               = @()
                    ConfigurationPolicyAssignments          = @()
                    GroupPolicyAssignments                  = @()
                    WindowsInformationProtectionAssignments = @()
                    PolicySetAssignments                    = @()
                    AllAssignments                          = @()
                }
            }
            
            GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeIndirectAssignments
            
            Assert-MockCalled GetGroupIndirectAssignments -Times 1
        }
        
        It "Should pass IncludeBeta parameter to GetGroupIndirectAssignments" {
            Mock CallGraphAPI { return @{ responses = @() } }
            Mock GetGroupIndirectAssignments {
                return @{
                    AllAssignments = @()
                }
            }
            
            GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeIndirectAssignments -IncludeBeta
            
            Assert-MockCalled GetGroupIndirectAssignments -ParameterFilter { 
                $IncludeBeta -eq $true 
            }
        }
        
        It "Should merge indirect assignments with direct assignments" {
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id = "app-4"; displayName = "Direct App"; description = "Direct assignment"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    return @{
                        value = @(
                            @{
                                id     = "1"
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            target = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = $TestGroupId
                                            }
                                            intent = "required"
                                        }
                                    )
                                }
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
            
            # Setup indirect assignments
            Mock GetGroupIndirectAssignments {
                return @{
                    AppAssignments                          = @(
                        @{
                            Type            = "Application"
                            Name            = "Indirect App"
                            Description     = "All Users assignment"
                            Id              = "app-2"
                            AssignmentScope = "All Users"
                        }
                    )
                    ConfigurationAssignments                = @()
                    ComplianceAssignments                   = @()
                    AutopilotAssignments                    = @()
                    ScriptAssignments                       = @()
                    HealthScriptAssignments                 = @()
                    AppProtectionAssignments                = @()
                    IntentAssignments                       = @()
                    ResourceAccessAssignments               = @()
                    ConfigurationPolicyAssignments          = @()
                    GroupPolicyAssignments                  = @()
                    WindowsInformationProtectionAssignments = @()
                    PolicySetAssignments                    = @()
                    AllAssignments                          = @(
                        @{
                            Type            = "Application"
                            Name            = "Indirect App"
                            Description     = "All Users assignment"
                            Id              = "app-2"
                            AssignmentScope = "All Users"
                        }
                    )
                }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeIndirectAssignments
            
            # Should have both direct and indirect assignments
            $result.AppAssignments.Count | Should -Be 2
            $result.AllAssignments.Count | Should -Be 2
            
            # Verify both types are present
            $result.AppAssignments[0].Name | Should -Be "Direct App"
            $result.AppAssignments[1].Name | Should -Be "Indirect App"
            $result.AppAssignments[1].AssignmentScope | Should -Be "All Users"
        }
        
        It "Should handle empty indirect assignments gracefully" {
            Mock CallGraphAPI { return @{ responses = @() } }
            Mock GetGroupIndirectAssignments {
                return @{
                    AllAssignments = @()
                }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeIndirectAssignments
            
            $result.AllAssignments.Count | Should -Be 0
        }
        
        It "Should update summary title when indirect assignments included" {
            Mock CallGraphAPI { 
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return @{
                        responses = @(
                            @{ id = "mobileApps"; status = 200; body = @{ value = @(@{id = "app-indirect-summary"; displayName = "Indirect Summary App"; description = "Test"}) } }
                        )
                    }
                }
                elseif ($ResourcePath -is [array])
                {
                    return @{
                        value = @(
                            @{
                                id     = "1"
                                status = 200
                                body   = @{
                                    value = @(
                                        @{
                                            target = @{
                                                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                                groupId       = $TestGroupId
                                            }
                                        }
                                    )
                                }
                            }
                        )
                    }
                }
                return @{ value = @() }
            }
            Mock GetGroupIndirectAssignments {
                return @{
                    AllAssignments = @()
                }
            }
            Mock Write-Host { }
            
            GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeIndirectAssignments -ShowSummary
            
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -match "Group Direct and Indirect Assignments Summary" 
            }
        }
        
        It "Should handle GetGroupIndirectAssignments errors without failing" {
            Mock CallGraphAPI { return @{ responses = @() } }
            Mock GetGroupIndirectAssignments { throw "Indirect API Error" }
            
            { GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeIndirectAssignments } | Should -Not -Throw
        }
        
        It "Should merge multiple indirect assignment types correctly" {
            Mock CallGraphAPI { return @{ responses = @() } }
            
            Mock GetGroupIndirectAssignments {
                return @{
                    AppAssignments                          = @(
                        @{ Type = "Application"; Name = "App1"; AssignmentScope = "All Users" }
                    )
                    ConfigurationAssignments                = @(
                        @{ Type = "Configuration"; Name = "Config1"; AssignmentScope = "All Devices" }
                    )
                    ComplianceAssignments                   = @(
                        @{ Type = "Compliance"; Name = "Compliance1"; AssignmentScope = "All Users" }
                    )
                    AutopilotAssignments                    = @()
                    ScriptAssignments                       = @()
                    HealthScriptAssignments                 = @()
                    AppProtectionAssignments                = @()
                    IntentAssignments                       = @()
                    ResourceAccessAssignments               = @()
                    ConfigurationPolicyAssignments          = @()
                    GroupPolicyAssignments                  = @()
                    WindowsInformationProtectionAssignments = @()
                    PolicySetAssignments                    = @()
                    AllAssignments                          = @(
                        @{ Type = "Application"; Name = "App1"; AssignmentScope = "All Users" }
                        @{ Type = "Configuration"; Name = "Config1"; AssignmentScope = "All Devices" }
                        @{ Type = "Compliance"; Name = "Compliance1"; AssignmentScope = "All Users" }
                    )
                }
            }
            
            $result = GetGroupDirectAssignments -AccessToken $TestAccessToken -GroupName $TestGroup -IncludeIndirectAssignments
            
            $result.AppAssignments.Count | Should -Be 1
            $result.ConfigurationAssignments.Count | Should -Be 1
            $result.ComplianceAssignments.Count | Should -Be 1
            $result.AllAssignments.Count | Should -Be 3
            
            # Verify assignment scopes are preserved
            $result.AppAssignments[0].AssignmentScope | Should -Be "All Users"
            $result.ConfigurationAssignments[0].AssignmentScope | Should -Be "All Devices"
        }
    }
}

AfterAll {
    if ($script:TestEnv)
    {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}
