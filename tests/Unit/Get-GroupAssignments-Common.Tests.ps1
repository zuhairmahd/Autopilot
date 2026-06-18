<#
.SYNOPSIS
    Unit tests for Get-GroupAssignments-Common.ps1 shared functions

.DESCRIPTION
    Tests the common/shared functions used by Get-GroupDirectAssignments and GetGroupIndirectAssignments.
    Focuses on:
    - Get-IntuneResourceLists: Batch API resource fetching
    - Invoke-AssignmentBatchRequest: Batch assignment requests
    - Get-ResourceAssignments: Assignment processing with id/status/body structure

.NOTES
    Test Category: Unit
    Dependencies: UserAndGroupFunctions, AutopilotTestHelpers

    CRITICAL: These tests validate batch API response processing with the CallGraphAPI structure:
    - Batch responses: { value: [ { id, status, body: { value: [...] } } ] }
    - Single responses: { value: [...] }
#>

#Requires -Version 5.1

BeforeAll {
    # Get repository root
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName

    # Import helper modules
    Import-Module "$script:RepoRoot/tests/Helpers/AutopilotTestHelpers.psm1" -Force

    # Initialize test environment
    $script:TestEnv = Initialize-AutopilotTestEnvironment

    # Load required functions via direct dot-sourcing
    . "$script:RepoRoot/functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1"
    . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"

    # Set up global variables
    $global:logFile = Join-Path $script:TestEnv.TestFolder "test.log"
    $global:maxJSONDepth = 10

    # Test data
    $script:TestAccessToken = "test-token-common-12345"
    $script:TestGroupId = "group-common-guid-12345"
}

AfterAll {
    if ($script:TestEnv)
    {
        Remove-TestEnvironment -TestContext $script:TestEnv
    }
}

Describe "Function: Get-IntuneResourceLists" -Tags 'Unit', 'GroupAssignments', 'BatchAPI' {

    Context "Batch API Request Structure" {
        BeforeEach {
            # Clear cache before each test
            Clear-UnifiedCache -CacheType 'Configuration' -ErrorAction SilentlyContinue
        }

        It "Should make batch API request with correct structure" {
            # Mock CallGraphAPI to capture the batch request
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method, $Body)

                # Verify batch API call
                $ResourcePath | Should -Be '$batch'
                $Method | Should -Be 'POST'
                $APIVersion | Should -Be 'v1.0'

                # Return minimal batch response
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

            $result = Get-IntuneResourceLists -AccessToken $script:TestAccessToken -SkipCache

            Assert-MockCalled CallGraphAPI -Times 1 -Exactly
        }

        It "Should handle batch responses with id/status/body structure" {
            Mock CallGraphAPI {
                return @{
                    responses = @(
                        @{
                            id     = "mobileApps"
                            status = 200
                            body   = @{
                                value = @(
                                    @{ id = "app-1"; displayName = "Test App 1"; description = "App description" }
                                    @{ id = "app-2"; displayName = "Test App 2"; description = "" }
                                )
                            }
                        }
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

            $result = Get-IntuneResourceLists -AccessToken $script:TestAccessToken -SkipCache

            $result.mobileApps.Count | Should -Be 2
            $result.mobileApps[0].displayName | Should -Be "Test App 1"
        }

        It "Should handle failed batch responses (non-200 status)" {
            Mock CallGraphAPI {
                return @{
                    responses = @(
                        @{ id = "mobileApps"; status = 403; body = @{ error = @{ message = "Forbidden" } } }
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

            $result = Get-IntuneResourceLists -AccessToken $script:TestAccessToken -SkipCache

            # Should return hashtable with Keys property
            $result | Should -Not -BeNullOrEmpty
            $result.Keys | Should -Contain 'deviceConfigs'
        }
    }

    Context "Beta API Endpoints" {
        BeforeEach {
            Clear-UnifiedCache -CacheType 'Configuration' -ErrorAction SilentlyContinue
        }

        It "Should include beta-only resources when IncludeBeta is specified" {
            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion)

                # Verify beta API version
                $APIVersion | Should -Be 'beta'

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
                        @{ id = "autopilotProfiles"; status = 200; body = @{ value = @() } }
                        @{ id = "healthScripts"; status = 200; body = @{ value = @() } }
                        @{ id = "configurationPolicies"; status = 200; body = @{ value = @() } }
                        @{ id = "groupPolicyConfigs"; status = 200; body = @{ value = @() } }
                        @{ id = "wipPolicies"; status = 200; body = @{ value = @() } }
                        @{ id = "mdmWipPolicies"; status = 200; body = @{ value = @() } }
                        @{ id = "windowsFeatureUpdates"; status = 200; body = @{ value = @() } }
                        @{ id = "windowsQualityUpdates"; status = 200; body = @{ value = @() } }
                        @{ id = "windowsDriverUpdates"; status = 200; body = @{ value = @() } }
                    )
                }
            }

            $result = Get-IntuneResourceLists -AccessToken $script:TestAccessToken -IncludeBeta -SkipCache

            # Verify beta-only resources are present (result is hashtable)
            $result.Keys | Should -Contain 'autopilotProfiles'
            $result.Keys | Should -Contain 'healthScripts'
            $result.Keys | Should -Contain 'windowsFeatureUpdates'
        }
    }

    Context "Caching Behavior" {
        BeforeEach {
            # Clear cache and ensure caching infrastructure is initialized
            Clear-UnifiedCache -CacheType 'Configuration' -ErrorAction SilentlyContinue

            # Initialize $global:cacheSettings if not already set (required for caching to work)
            if (-not $global:cacheSettings)
            {
                $global:cacheSettings = @{
                    enabled    = $true
                    cacheTypes = @{
                        Configuration    = @{ enabled = $true; expirationMinutes = 60 }
                        DirectoryObjects = @{ enabled = $true; expirationMinutes = 30 }
                        Devices          = @{ enabled = $true; expirationMinutes = 15 }
                    }
                }
            }
        }

        It "Should cache resource lists after successful fetch" {
            $script:CallCount = 0
            $script:GetCacheDataCallCount = 0

            # Prepare test data that will be "cached"
            $testCachedData = @{
                mobileApps             = @(@{ id = "app-1"; displayName = "Cached App"; '@odata.type' = '#microsoft.graph.win32LobApp' })
                deviceConfigs          = @()
                compliancePolicies     = @()
                autopilotProfiles      = @()
                deviceScripts          = @()
                healthScripts          = @()
                appProtectionPolicies  = @()
                intents                = @()
                resourceAccessProfiles = @()
                configurationPolicies  = @()
                groupPolicyConfigs     = @()
                policySets             = @()
                wipPolicies            = @()
                mdmWipPolicies         = @()
                windowsFeatureUpdates  = @()
                windowsQualityUpdates  = @()
                windowsDriverUpdates   = @()
            }

            Mock CallGraphAPI {
                $script:CallCount++
                return @{
                    responses = @(
                        @{ id = "mobileApps"; status = 200; body = @{ value = $testCachedData.mobileApps } }
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

            # Mock Get-CachedData to return null on first call, cached data on second call
            Mock Get-CachedData {
                $script:GetCacheDataCallCount++
                if ($script:GetCacheDataCallCount -eq 1)
                {
                    # First call - no cache
                    return $null
                }
                else
                {
                    # Subsequent calls - return cached data
                    return $testCachedData
                }
            }

            # Mock Set-CachedData to just return true
            Mock Set-CachedData {
                return $true
            }

            # First call - should hit API (cache returns null)
            $result1 = Get-IntuneResourceLists -AccessToken $script:TestAccessToken

            # Second call - should use cache (cache returns data)
            $result2 = Get-IntuneResourceLists -AccessToken $script:TestAccessToken

            # Verify API was only called once (cache hit on second call)
            Assert-MockCalled CallGraphAPI -Times 1 -Exactly
            $result2.mobileApps[0].displayName | Should -Be "Cached App"
        }

        It "Should bypass cache when SkipCache is specified" {
            Mock CallGraphAPI {
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

            # First call with caching
            Get-IntuneResourceLists -AccessToken $script:TestAccessToken

            # Second call with SkipCache
            Get-IntuneResourceLists -AccessToken $script:TestAccessToken -SkipCache

            # Verify API was called twice (cache bypassed)
            Assert-MockCalled CallGraphAPI -Times 2 -Exactly
        }
    }
}

Describe "Function: Invoke-AssignmentBatchRequest" -Tags 'Unit', 'GroupAssignments', 'BatchAPI' {

    Context "Batch Request Execution" {
        It "Should execute batch request with array of assignment paths" {
            $assignmentPaths = @(
                "deviceAppManagement/mobileApps/app-1/assignments"
                "deviceAppManagement/mobileApps/app-2/assignments"
                "deviceManagement/deviceConfigurations/config-1/assignments"
            )

            Mock CallGraphAPI {
                param($accessToken, $ResourcePath, $APIVersion, $Method)

                # Verify batch request parameters
                $ResourcePath.Count | Should -Be 3
                $ResourcePath[0] | Should -Match "assignments"
                $APIVersion | Should -Be 'v1.0'
                $Method | Should -Be 'GET'

                return @{
                    value = @(
                        @{ id = "1"; status = 200; body = @{ value = @() } }
                        @{ id = "2"; status = 200; body = @{ value = @() } }
                        @{ id = "3"; status = 200; body = @{ value = @() } }
                    )
                }
            }

            $result = Invoke-AssignmentBatchRequest -AccessToken $script:TestAccessToken `
                -AssignmentPaths $assignmentPaths -ApiVersion 'v1.0' -ResourceType 'Mobile Apps'

            $result.Success | Should -Be $true
            $result.Result.value.Count | Should -Be 3
        }

        It "Should return error info when batch request fails" {
            Mock CallGraphAPI {
                throw "Network error"
            }

            $result = Invoke-AssignmentBatchRequest -AccessToken $script:TestAccessToken `
                -AssignmentPaths @("test/path") -ApiVersion 'v1.0' -ResourceType 'Test Resources'

            $result.Success | Should -Be $false
            $result.ErrorInfo | Should -Not -BeNullOrEmpty
            $result.ErrorInfo.Message | Should -Match "Failed to fetch assignments"
        }
    }

    Context "Error Categorization" {
        It "Should return error info with proper structure" {
            Mock CallGraphAPI {
                throw "Test error"
            }

            $result = Invoke-AssignmentBatchRequest -AccessToken $script:TestAccessToken `
                -AssignmentPaths @("test/path") -ApiVersion 'v1.0' -ResourceType 'Test Resources'

            $result.Success | Should -Be $false
            $result.ErrorInfo | Should -Not -BeNullOrEmpty
            $result.ErrorInfo.Message | Should -Not -BeNullOrEmpty
            $result.ErrorInfo.Category | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Function: Get-ResourceAssignments" -Tags 'Unit', 'GroupAssignments', 'BatchAPI' {

    BeforeEach {
        # Initialize result object for each test
        $script:TestResultObject = Initialize-AssignmentResultObject -GroupName "Test Group" -GroupId $script:TestGroupId
    }

    Context "Direct Assignment Mode" {
        It "Should process direct group assignments correctly" {
            $testResources = @(
                @{ id = "app-1"; displayName = "Test App"; description = "App desc"; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            # Mock batch API response with id/status/body structure
            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            $script:TestResultObject.AllAssignments.Count | Should -Be 1
            $script:TestResultObject.AllAssignments[0].AssignmentScope | Should -Be 'Direct'
            $script:TestResultObject.AllAssignments[0].Name | Should -Be 'Test App'
        }

        It "Should filter out non-matching group assignments" {
            $testResources = @(
                @{ id = "app-1"; displayName = "Test App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = 'different-group-id' }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            # Should not include assignment for different group
            $script:TestResultObject.AllAssignments.Count | Should -Be 0
        }
    }

    Context "Indirect Assignment Mode" {
        It "Should process All Users assignments correctly" {
            $testResources = @(
                @{ id = "app-1"; displayName = "All Users App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'Indirect'

            $script:TestResultObject.AllAssignments.Count | Should -Be 1
            $script:TestResultObject.AllAssignments[0].AssignmentScope | Should -Be 'All Users'
        }

        It "Should process All Devices assignments correctly" {
            $testResources = @(
                @{ id = "config-1"; displayName = "All Devices Config"; description = ""; '@odata.type' = '#microsoft.graph.windows10GeneralConfiguration' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' }
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Device Configurations' `
                -BaseUri 'deviceManagement/deviceConfigurations' -EndpointId 'deviceConfigs' `
                -AssignmentMode 'Indirect'

            $script:TestResultObject.AllAssignments.Count | Should -Be 1
            $script:TestResultObject.AllAssignments[0].AssignmentScope | Should -Be 'All Devices'
        }
    }

    Context "IndirectFiltered Assignment Mode" {
        It "Should include resources with BOTH group and All Users assignments" {
            $testResources = @(
                @{ id = "app-1"; displayName = "Dual Assignment App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "required"
                                    }
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
                                        intent = "available"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'IndirectFiltered' -GroupIdValue $script:TestGroupId

            # Should include the All Users assignment (not the group assignment)
            $script:TestResultObject.AllAssignments.Count | Should -Be 1
            $script:TestResultObject.AllAssignments[0].AssignmentScope | Should -Be 'All Users'
        }

        It "Should exclude resources with only group assignments" {
            $testResources = @(
                @{ id = "app-1"; displayName = "Group Only App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'IndirectFiltered' -GroupIdValue $script:TestGroupId

            # Should not include resource (has group but no All Users/All Devices)
            $script:TestResultObject.AllAssignments.Count | Should -Be 0
        }

        It "Should exclude resources with only All Users assignments" {
            $testResources = @(
                @{ id = "app-1"; displayName = "All Users Only App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'IndirectFiltered' -GroupIdValue $script:TestGroupId

            # Should not include resource (has All Users but no matching group)
            $script:TestResultObject.AllAssignments.Count | Should -Be 0
        }
    }

    Context "Batch Response Processing" {
        It "Should handle multiple resources in batch response" {
            $testResources = @(
                @{ id = "app-1"; displayName = "App 1"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                @{ id = "app-2"; displayName = "App 2"; description = ""; '@odata.type' = '#microsoft.graph.iosLobApp' }
                @{ id = "app-3"; displayName = "App 3"; description = ""; '@odata.type' = '#microsoft.graph.androidLobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                        @{
                            id     = "2"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "available"
                                    }
                                )
                            }
                        }
                        @{
                            id     = "3"
                            status = 200
                            body   = @{ value = @() }  # No assignments
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            $script:TestResultObject.AllAssignments.Count | Should -Be 2
            $script:TestResultObject.AllAssignments[0].Name | Should -Be 'App 1'
            $script:TestResultObject.AllAssignments[1].Name | Should -Be 'App 2'
        }

        It "Should skip batch responses with non-200 status" {
            $testResources = @(
                @{ id = "app-1"; displayName = "Success App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                @{ id = "app-2"; displayName = "Failed App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                        @{
                            id     = "2"
                            status = 403  # Failed request
                            body   = @{ error = @{ message = "Forbidden" } }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            # Should only include the successful assignment
            $script:TestResultObject.AllAssignments.Count | Should -Be 1
            $script:TestResultObject.AllAssignments[0].Name | Should -Be 'Success App'
        }
    }

    Context "Resource Categorization" {
        It "Should categorize Win32 app assignments correctly" {
            $testApp = @{ id = "app-1"; displayName = "Win32 App"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources @($testApp) -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            # Verify categorization
            $script:TestResultObject.AppAssignments.Count | Should -Be 1
            $script:TestResultObject.AppAssignments[0].Name | Should -Be 'Win32 App'
            $script:TestResultObject.AllAssignments.Count | Should -Be 1
        }
    }

    Context "Regression: Batch response ordering" {
        BeforeEach {
            $script:TestResultObject = Initialize-AssignmentResultObject -GroupName "Test Group" -GroupId $script:TestGroupId
        }

        It "Should correctly correlate responses returned in reverse order" {
            # This test would have FAILED before the Build-BatchResponseLookup fix.
            # The Graph API does not guarantee response ordering — responses for
            # resource 1 and resource 2 may arrive in any order. The fix keys
            # responses by their 'id' field rather than array position.
            $testResources = @(
                @{ id = "app-1"; displayName = "App One"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
                @{ id = "app-2"; displayName = "App Two"; description = ""; '@odata.type' = '#microsoft.graph.win32LobApp' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        # Response for request ID "2" (App Two) arrives FIRST
                        @{
                            id     = "2"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $script:TestGroupId }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                        # Response for request ID "1" (App One) arrives SECOND
                        @{
                            id     = "1"
                            status = 200
                            body   = @{ value = @() }  # App One has NO matching assignments
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Mobile Apps' `
                -BaseUri 'deviceAppManagement/mobileApps' -EndpointId 'mobileApps' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            # Only App Two should be in results — App One has no assignments for the group
            $script:TestResultObject.AllAssignments.Count | Should -Be 1
            $script:TestResultObject.AllAssignments[0].Name | Should -Be 'App Two'
        }
    }

    Context "Regression: Excluded group assignments" {
        BeforeEach {
            $script:TestResultObject = Initialize-AssignmentResultObject -GroupName "Test Group" -GroupId $script:TestGroupId
        }

        It "Should return excluded assignments with AssignmentScope 'Excluded'" {
            $testResources = @(
                @{ id = "policy-1"; displayName = "Compliance Policy"; description = ""; '@odata.type' = '#microsoft.graph.windows10CompliancePolicy' }
            )

            Mock CallGraphAPI {
                return @{
                    value = @(
                        @{
                            id     = "1"
                            status = 200
                            body   = @{
                                value = @(
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'
                                            groupId       = $script:TestGroupId
                                        }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Compliance Policies' `
                -BaseUri 'deviceManagement/deviceCompliancePolicies' -EndpointId 'compliancePolicies' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            $script:TestResultObject.AllAssignments.Count | Should -Be 1
            $script:TestResultObject.AllAssignments[0].AssignmentScope | Should -Be 'Excluded'
            $script:TestResultObject.AllAssignments[0].Name | Should -Be 'Compliance Policy'
        }

        It "Should return both Direct and Excluded assignments for the same resource" {
            $testResources = @(
                @{ id = "policy-1"; displayName = "Mixed Policy"; description = ""; '@odata.type' = '#microsoft.graph.windows10CompliancePolicy' }
            )
            $otherGroupId = "other-group-guid-99999"

            Mock CallGraphAPI {
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
                                            groupId       = $script:TestGroupId
                                        }
                                        intent = "required"
                                    }
                                    @{
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'
                                            groupId       = $script:TestGroupId
                                        }
                                        intent = "required"
                                    }
                                    @{
                                        # Assignment for a different group — should not appear
                                        target = @{
                                            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                                            groupId       = $otherGroupId
                                        }
                                        intent = "required"
                                    }
                                )
                            }
                        }
                    )
                }
            }

            Get-ResourceAssignments -ResultObject $script:TestResultObject -AccessToken $script:TestAccessToken `
                -ApiVersion 'v1.0' -Resources $testResources -ResourceType 'Compliance Policies' `
                -BaseUri 'deviceManagement/deviceCompliancePolicies' -EndpointId 'compliancePolicies' `
                -AssignmentMode 'Direct' -GroupIdValue $script:TestGroupId

            $script:TestResultObject.AllAssignments.Count | Should -Be 2
            $script:TestResultObject.AllAssignments | Where-Object { $_.AssignmentScope -eq 'Direct' } | Should -Not -BeNullOrEmpty
            $script:TestResultObject.AllAssignments | Where-Object { $_.AssignmentScope -eq 'Excluded' } | Should -Not -BeNullOrEmpty
        }
    }
}