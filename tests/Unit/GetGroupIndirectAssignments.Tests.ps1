# GetGroupIndirectAssignments.Tests.ps1
# Unit tests for GetGroupIndirectAssignments function

#Requires -Version 5.1

BeforeAll {
    # Import helper modules
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force
    
    # Initialize test environment
    $script:TestEnv = Initialize-AutopilotTestEnvironment
    
    # Load required functions
    . "$script:RepoRoot/functions/UserAndGroupFunctions/GetGroupIndirectAssignments.ps1"
    . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    
    # Set up global variables required by functions
    $global:logFile = Join-Path $script:TestEnv.TestFolder "test.log"
    $global:maxJSONDepth = 10
    
    # Set up test variables
    $script:TestAccessToken = "test-token-12345"
}

Describe "Function: GetGroupIndirectAssignments" -Tags 'Unit' {
    
    Context "Parameter Validation" {
        It "Should require accessToken parameter" {
            { GetGroupIndirectAssignments -AccessToken $null } | Should -Throw
        }
        
        It "Should accept valid accessToken" {
            Mock CallGraphAPI { 
                return @{ 
                    responses = @() 
                } 
            }
            
            { GetGroupIndirectAssignments -AccessToken $TestAccessToken } | Should -Not -Throw
        }
        
        It "Should default to v1.0 API version when IncludeBeta not specified" {
            Mock CallGraphAPI { 
                param($APIVersion)
                return @{ 
                    responses = @() 
                }
            }
            
            GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            Assert-MockCalled CallGraphAPI -ParameterFilter { 
                $APIVersion -eq 'v1.0' 
            }
        }
        
        It "Should use beta API version when IncludeBeta specified" {
            Mock CallGraphAPI { 
                param($APIVersion)
                return @{ 
                    responses = @() 
                }
            }
            
            GetGroupIndirectAssignments -AccessToken $TestAccessToken -IncludeBeta
            
            Assert-MockCalled CallGraphAPI -ParameterFilter { 
                $APIVersion -eq 'beta' 
            }
        }
        
        It "Should accept custom BatchSize parameter" {
            Mock CallGraphAPI { 
                return @{ 
                    responses = @() 
                } 
            }
            
            { GetGroupIndirectAssignments -AccessToken $TestAccessToken -BatchSize 50 } | Should -Not -Throw
        }
    }
    
    Context "Result Structure" {
        It "Should return object with all assignment category properties" {
            Mock CallGraphAPI { 
                return @{ 
                    responses = @() 
                } 
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.PSObject.Properties.Name | Should -Contain "AppAssignments"
            $result.PSObject.Properties.Name | Should -Contain "ConfigurationAssignments"
            $result.PSObject.Properties.Name | Should -Contain "ComplianceAssignments"
            $result.PSObject.Properties.Name | Should -Contain "AutopilotAssignments"
            $result.PSObject.Properties.Name | Should -Contain "ScriptAssignments"
            $result.PSObject.Properties.Name | Should -Contain "HealthScriptAssignments"
            $result.PSObject.Properties.Name | Should -Contain "AppProtectionAssignments"
            $result.PSObject.Properties.Name | Should -Contain "IntentAssignments"
            $result.PSObject.Properties.Name | Should -Contain "ResourceAccessAssignments"
            $result.PSObject.Properties.Name | Should -Contain "ConfigurationPolicyAssignments"
            $result.PSObject.Properties.Name | Should -Contain "GroupPolicyAssignments"
            $result.PSObject.Properties.Name | Should -Contain "WindowsInformationProtectionAssignments"
            $result.PSObject.Properties.Name | Should -Contain "PolicySetAssignments"
            $result.PSObject.Properties.Name | Should -Contain "AllAssignments"
        }
        
        It "Should initialize all assignment arrays as empty" {
            Mock CallGraphAPI { 
                return @{ 
                    responses = @() 
                } 
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AppAssignments.Count | Should -Be 0
            $result.AllAssignments.Count | Should -Be 0
        }
    }
    
    Context "Batch API Request Construction" {
        It "Should create batch request for v1.0 resource endpoints" {
            Mock CallGraphAPI { 
                param($Body, $ResourcePath)
                if ($ResourcePath -eq '$batch' -and $Body)
                {
                    # Store body for verification
                    $script:capturedBody = $Body
                }
                return @{ 
                    responses = @() 
                }
            }
            
            GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $script:capturedBody | Should -Not -BeNullOrEmpty
            $bodyObject = $script:capturedBody | ConvertFrom-Json
            $bodyObject.requests.Count | Should -BeGreaterThan 0
            $bodyObject.requests.id | Should -Contain "mobileApps"
            $bodyObject.requests.id | Should -Contain "deviceConfigs"
            $bodyObject.requests.id | Should -Contain "compliancePolicies"
        }
        
        It "Should include beta endpoints when IncludeBeta specified" {
            Mock CallGraphAPI { 
                param($Body, $ResourcePath)
                if ($ResourcePath -eq '$batch' -and $Body)
                {
                    $script:capturedBody = $Body
                }
                return @{ 
                    responses = @() 
                }
            }
            
            GetGroupIndirectAssignments -AccessToken $TestAccessToken -IncludeBeta
            
            $script:capturedBody | Should -Not -BeNullOrEmpty
            $bodyObject = $script:capturedBody | ConvertFrom-Json
            $bodyObject.requests.id | Should -Contain "autopilotProfiles"
            $bodyObject.requests.id | Should -Contain "healthScripts"
            $bodyObject.requests.id | Should -Contain "configurationPolicies"
            $bodyObject.requests.id | Should -Contain "groupPolicyConfigs"
        }
        
        It "Should request proper resource fields (id, displayName, description)" {
            Mock CallGraphAPI { 
                param($Body, $ResourcePath)
                if ($ResourcePath -eq '$batch' -and $Body)
                {
                    $script:capturedBody = $Body
                }
                return @{ 
                    responses = @(
                        @{ id = "mobileApps"; status = 200; body = @{ value = @() } }
                    )
                }
            }
            
            GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $script:capturedBody | Should -Not -BeNullOrEmpty
            $bodyObject = $script:capturedBody | ConvertFrom-Json
            $mobileAppsRequest = $bodyObject.requests | Where-Object { $_.id -eq "mobileApps" }
            $mobileAppsRequest.url | Should -Match "select=id,displayName,description"
        }
    }
    
    Context "All Users Assignment Filtering" {
        It "Should filter assignments with allLicensedUsersAssignmentTarget" {
            # Mock batch response with resources
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 200
                        body   = @{
                            value = @(
                                @{
                                    id          = "app-1"
                                    displayName = "Test App"
                                    description = "Test Description"
                                }
                            )
                        }
                    }
                )
            }
            
            # Mock assignments response with All Users target
            $assignmentsResponse = @{
                value = @(
                    @{
                        value = @(
                            @{
                                id       = "assignment-1"
                                intent   = "required"
                                target   = @{
                                    '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget'
                                }
                                settings = @{}
                            }
                        )
                    }
                )
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return $batchResponse
                }
                else
                {
                    return $assignmentsResponse
                }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AllAssignments.Count | Should -Be 1
            $result.AllAssignments[0].AssignmentScope | Should -Be 'All Users'
        }
    }
    
    Context "All Devices Assignment Filtering" {
        It "Should filter assignments with allDevicesAssignmentTarget" {
            # Mock batch response with resources
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "deviceConfigs"
                        status = 200
                        body   = @{
                            value = @(
                                @{
                                    id          = "config-1"
                                    displayName = "Test Config"
                                    description = "Config Description"
                                }
                            )
                        }
                    }
                )
            }
            
            # Mock assignments response with All Devices target
            $assignmentsResponse = @{
                value = @(
                    @{
                        value = @(
                            @{
                                id       = "assignment-1"
                                intent   = "required"
                                target   = @{
                                    '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget'
                                }
                                settings = @{}
                            }
                        )
                    }
                )
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return $batchResponse
                }
                else
                {
                    return $assignmentsResponse
                }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AllAssignments.Count | Should -Be 1
            $result.AllAssignments[0].AssignmentScope | Should -Be 'All Devices'
        }
    }
    
    Context "Assignment Object Structure" {
        It "Should create assignment objects with required properties" {
            # Mock batch response with resources
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 200
                        body   = @{
                            value = @(
                                @{
                                    id          = "app-1"
                                    displayName = "Test App"
                                    description = "App Description"
                                }
                            )
                        }
                    }
                )
            }
            
            # Mock assignments response
            $assignmentsResponse = @{
                value = @(
                    @{
                        value = @(
                            @{
                                id       = "assignment-1"
                                intent   = "required"
                                target   = @{
                                    '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget'
                                }
                                settings = @{ setting1 = "value1" }
                            }
                        )
                    }
                )
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return $batchResponse
                }
                else
                {
                    return $assignmentsResponse
                }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $assignment = $result.AllAssignments[0]
            $assignment.Type | Should -Be "Application"
            $assignment.Name | Should -Be "Test App"
            $assignment.Description | Should -Be "App Description"
            $assignment.Id | Should -Be "app-1"
            $assignment.Intent | Should -Be "required"
            $assignment.AssignmentScope | Should -Be "All Users"
            $assignment.Target | Should -Not -BeNullOrEmpty
            $assignment.Settings | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle missing description field gracefully" {
            # Mock batch response without description
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 200
                        body   = @{
                            value = @(
                                @{
                                    id          = "app-1"
                                    displayName = "Test App"
                                }
                            )
                        }
                    }
                )
            }
            
            # Mock assignments response
            $assignmentsResponse = @{
                value = @(
                    @{
                        value = @(
                            @{
                                id       = "assignment-1"
                                intent   = "required"
                                target   = @{
                                    '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget'
                                }
                                settings = @{}
                            }
                        )
                    }
                )
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                {
                    return $batchResponse
                }
                else
                {
                    return $assignmentsResponse
                }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AllAssignments[0].Description | Should -Be ""
        }
    }
    
    Context "Assignment Categorization" {
        It "Should categorize Application assignments correctly" {
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 200
                        body   = @{
                            value = @(@{
                                    id          = "app-1"
                                    displayName = "Test App"
                                })
                        }
                    }
                )
            }
            
            $assignmentsResponse = @{
                value = @(@{
                        value = @(@{
                                target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
                            })
                    })
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') { return $batchResponse }
                else { return $assignmentsResponse }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AppAssignments.Count | Should -Be 1
            $result.AllAssignments[0].Type | Should -Be "Application"
        }
        
        It "Should categorize Configuration assignments correctly" {
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "deviceConfigs"
                        status = 200
                        body   = @{
                            value = @(@{
                                    id          = "config-1"
                                    displayName = "Test Config"
                                })
                        }
                    }
                )
            }
            
            $assignmentsResponse = @{
                value = @(@{
                        value = @(@{
                                target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' }
                            })
                    })
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') { return $batchResponse }
                else { return $assignmentsResponse }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.ConfigurationAssignments.Count | Should -Be 1
            $result.AllAssignments[0].Type | Should -Be "Configuration"
        }
    }
    
    Context "Configuration Policies Special Handling" {
        It "Should add displayName property to configuration policies using name field" {
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "configurationPolicies"
                        status = 200
                        body   = @{
                            value = @(
                                @{
                                    id          = "policy-1"
                                    name        = "Test Policy"
                                    description = "Policy Description"
                                }
                            )
                        }
                    }
                )
            }
            
            $assignmentsResponse = @{
                value = @(@{
                        value = @(@{
                                target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
                            })
                    })
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') { return $batchResponse }
                else { return $assignmentsResponse }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken -IncludeBeta
            
            $result.ConfigurationPolicyAssignments[0].Name | Should -Be "Test Policy"
        }
    }
    
    Context "Direct Group Assignment Filtering" {
        It "Should NOT include direct group assignments (only All Users/All Devices)" {
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 200
                        body   = @{
                            value = @(@{
                                    id          = "app-1"
                                    displayName = "Test App"
                                })
                        }
                    }
                )
            }
            
            # Mix of assignment types
            $assignmentsResponse = @{
                value = @(
                    @{
                        value = @(
                            @{
                                id     = "assignment-1"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget'
                                }
                            }
                            @{
                                id     = "assignment-2"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                    groupId       = "group-123"
                                }
                            }
                            @{
                                id     = "assignment-3"
                                target = @{
                                    '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget'
                                }
                            }
                        )
                    }
                )
            }
            
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch') { return $batchResponse }
                else { return $assignmentsResponse }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            # Should only have 2 assignments (All Users and All Devices), not the direct group assignment
            $result.AllAssignments.Count | Should -Be 2
            $result.AllAssignments | ForEach-Object {
                $_.AssignmentScope | Should -BeIn @('All Users', 'All Devices')
            }
        }
    }
    
    Context "Error Handling" {
        It "Should handle batch API errors gracefully" {
            Mock CallGraphAPI { 
                throw "API Error" 
            }
            
            { GetGroupIndirectAssignments -AccessToken $TestAccessToken } | Should -Not -Throw
        }
        
        It "Should return empty assignments on error" {
            Mock CallGraphAPI { 
                throw "API Error" 
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AllAssignments.Count | Should -Be 0
        }
        
        It "Should handle failed resource list retrieval" {
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 403
                        body   = @{
                            error = @{
                                message = "Forbidden"
                            }
                        }
                    }
                )
            }
            
            Mock CallGraphAPI {
                return $batchResponse
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AllAssignments.Count | Should -Be 0
        }
        
        It "Should handle empty resource lists" {
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 200
                        body   = @{
                            value = @()
                        }
                    }
                )
            }
            
            Mock CallGraphAPI {
                return $batchResponse
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AllAssignments.Count | Should -Be 0
        }
    }
    
    Context "Multiple Resource Types" {
        It "Should process multiple resource types with indirect assignments" {
            $batchResponse = @{
                responses = @(
                    @{
                        id     = "mobileApps"
                        status = 200
                        body   = @{
                            value = @(@{
                                    id          = "app-1"
                                    displayName = "Test App"
                                })
                        }
                    }
                    @{
                        id     = "deviceConfigs"
                        status = 200
                        body   = @{
                            value = @(@{
                                    id          = "config-1"
                                    displayName = "Test Config"
                                })
                        }
                    }
                    @{
                        id     = "compliancePolicies"
                        status = 200
                        body   = @{
                            value = @(@{
                                    id          = "compliance-1"
                                    displayName = "Test Compliance"
                                })
                        }
                    }
                )
            }
            
            $assignmentsResponse = @{
                value = @(
                    @{ value = @(@{ target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' } }) }
                    @{ value = @(@{ target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' } }) }
                    @{ value = @(@{ target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' } }) }
                )
            }
            
            $script:callCount = 0
            Mock CallGraphAPI {
                param($ResourcePath)
                if ($ResourcePath -eq '$batch')
                { 
                    return $batchResponse 
                }
                elseif ($ResourcePath -is [array])
                {
                    # Only return assignments once per resource type
                    $script:callCount++
                    if ($script:callCount -eq 1)
                    {
                        return @{ value = @(@{ value = @(@{ target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' } }) }) }
                    }
                    elseif ($script:callCount -eq 2)
                    {
                        return @{ value = @(@{ value = @(@{ target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' } }) }) }
                    }
                    elseif ($script:callCount -eq 3)
                    {
                        return @{ value = @(@{ value = @(@{ target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' } }) }) }
                    }
                }
                return @{ value = @() }
            }
            
            $result = GetGroupIndirectAssignments -AccessToken $TestAccessToken
            
            $result.AllAssignments.Count | Should -Be 3
            $result.AppAssignments.Count | Should -Be 1
            $result.ConfigurationAssignments.Count | Should -Be 1
            $result.ComplianceAssignments.Count | Should -Be 1
        }
    }
}

AfterAll {
    if ($script:TestEnv)
    {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}
