<#
.SYNOPSIS
    Unit tests for Get-RequiredScopesForEndpoints function

.DESCRIPTION
    Tests endpoint-to-scope mapping functionality:
    - URI normalization (GUID, ID, UPN patterns)
    - Endpoint pattern matching with wildcards
    - Query parameter stripping
    - Multiple resource path mapping
    - Duplicate scope elimination
    - Public endpoint handling (no scopes required)
    
    This function was extracted from HasScope.ps1 as part of the scope validation refactoring.
    It focuses solely on mapping Graph API endpoints to their required permission scopes.

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers for test environment
    Complexity: Medium - URI pattern matching and scope mapping
    Coverage Target: ~200 lines of new function
    Related: Test-ScopeAvailability.Tests.ps1, HasScope.Tests.ps1 (deprecated)
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-RequiredScopesForEndpoints" -Tags 'Unit', 'GraphFunctions', 'Authorization' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Load function under test
        . "$script:RepoRoot/functions/graphFunctions/Get-RequiredScopesForEndpoints.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $global:LogFile = Join-Path $script:TestContext.LogsFolder "Get-RequiredScopesForEndpoints.log"
        
        # Mock Write-Log globally
        Mock Write-Log {}
        
        # Create mock required scopes configuration
        # Note: Each scope should have unique endpoints to test mapping correctly
        $script:mockRequiredScopes = @(
            @{
                Scope     = 'User.Read.All'
                endpoints = @('users', 'users/{id}')
                Reason    = 'Read user profiles'
            },
            @{
                Scope     = 'Group.Read.All'
                endpoints = @('groups', 'groups/{id}', 'groups/{id}/members')
                Reason    = 'Read group information'
            },
            @{
                Scope     = 'Device.Read.All'
                endpoints = @('devices', 'devices/{id}')
                Reason    = 'Read device information'
            },
            @{
                Scope     = 'DeviceManagementManagedDevices.ReadWrite.All'
                endpoints = @('deviceManagement/managedDevices', 'deviceManagement/managedDevices/{id}')
                Reason    = 'Manage Intune devices'
            },
            @{
                Scope     = 'Directory.Read.All'
                endpoints = @('directory/administrativeUnits', 'organization')
                Reason    = 'Read directory data'
            }
        )
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "When mapping simple endpoint paths" {
        It "Should map 'users' endpoint to User.Read.All scope" {
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @('users') `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'User.Read.All'
        }
        
        It "Should map 'groups' endpoint to Group.Read.All scope" {
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @('groups') `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'Group.Read.All'
        }
        
        It "Should map multiple endpoints to multiple scopes" {
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @('users', 'groups', 'devices') `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 3
            $scopeNames = $result | ForEach-Object { $_.Scope } | Sort-Object
            $scopeNames | Should -Contain 'User.Read.All'
            $scopeNames | Should -Contain 'Group.Read.All'
            $scopeNames | Should -Contain 'Device.Read.All'
        }
        
        It "Should eliminate duplicate scopes from multiple endpoints" {
            # Both 'users' and 'users/{id}' map to User.Read.All
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @('users', 'users/{id}') `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'User.Read.All'
        }
    }
    
    Context "When normalizing URIs with GUIDs" {
        It "Should normalize GUID in users/{guid} to users/{id} pattern" {
            $guidUri = 'users/12345678-1234-1234-1234-123456789abc'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($guidUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'User.Read.All'
        }
        
        It "Should normalize GUID in groups/{guid}/members" {
            $guidUri = 'groups/abcdef12-3456-7890-abcd-ef1234567890/members'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($guidUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'Group.Read.All'
        }
        
        It "Should normalize GUID in deviceManagement/managedDevices/{guid}" {
            $guidUri = 'deviceManagement/managedDevices/aaaabbbb-cccc-dddd-eeee-ffff00001111'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($guidUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'DeviceManagementManagedDevices.ReadWrite.All'
        }
    }
    
    Context "When normalizing URIs with other ID patterns" {
        It "Should normalize numeric IDs" {
            $numericIdUri = 'groups/12345/members'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($numericIdUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'Group.Read.All'
        }
        
        It "Should normalize UPN (email) patterns" {
            $upnUri = 'users/john.doe@contoso.com'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($upnUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'User.Read.All'
        }
        
        It "Should normalize alphanumeric serial numbers" {
            # Create scope that handles device serial numbers
            $deviceScopes = $script:mockRequiredScopes + @{
                Scope     = 'DeviceManagementManagedDevices.Read.All'
                endpoints = @('deviceManagement/managedDevices/{id}')
            }
            
            $serialUri = 'deviceManagement/managedDevices/ABC123XYZ7890'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($serialUri) `
                -RequiredScopes $deviceScopes
            
            $result.Count | Should -BeGreaterThan 0
            $scopeNames = $result | ForEach-Object { $_.Scope }
            $scopeNames | Should -Contain 'DeviceManagementManagedDevices.ReadWrite.All'
        }
    }
    
    Context "When handling full URLs" {
        It "Should extract relative path from v1.0 URL" {
            $fullUrl = 'https://graph.microsoft.com/v1.0/users'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($fullUrl) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'User.Read.All'
        }
        
        It "Should extract relative path from beta URL" {
            $fullUrl = 'https://graph.microsoft.com/beta/groups'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($fullUrl) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'Group.Read.All'
        }
        
        It "Should handle full URL with GUID" {
            $fullUrl = 'https://graph.microsoft.com/v1.0/devices/12345678-abcd-ef12-3456-7890abcdef12'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($fullUrl) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'Device.Read.All'
        }
    }
    
    Context "When handling query parameters" {
        It "Should strip query parameters from URI before matching" {
            $uriWithQuery = 'users?$filter=startswith(displayName,''John'')'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($uriWithQuery) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'User.Read.All'
        }
        
        It "Should strip complex query parameters" {
            $uriWithQuery = 'groups?$select=id,displayName&$filter=groupTypes/any(c:c eq ''Unified'')'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($uriWithQuery) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'Group.Read.All'
        }
    }
    
    Context "When handling public endpoints" {
        It "Should return empty array for endpoints with no scope requirement" {
            $publicEndpoint = 'publicEndpointNotInConfig'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($publicEndpoint) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 0
        }
    }
    
    Context "When handling nested endpoints" {
        It "Should map nested group members endpoint" {
            $nestedUri = 'groups/{id}/members'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($nestedUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'Group.Read.All'
        }
        
        It "Should map nested deviceManagement endpoint" {
            $nestedUri = 'deviceManagement/managedDevices'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($nestedUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'DeviceManagementManagedDevices.ReadWrite.All'
        }
    }
    
    Context "When handling edge cases" {
        It "Should handle endpoints with leading slashes" {
            # Scope config typically doesn't have leading slashes, but function should handle them
            $slashUri = '/users'
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @($slashUri) `
                -RequiredScopes $script:mockRequiredScopes
            
            $result.Count | Should -Be 1
            $result[0].Scope | Should -Be 'User.Read.All'
        }
        
        It "Should handle mixed case Scope property" {
            # Function handles both 'Scope' and 'scope' property names
            $mixedCaseScopes = @(
                @{
                    scope     = 'User.Read.All'  # lowercase
                    endpoints = @('users')
                }
            )
            
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @('users') `
                -RequiredScopes $mixedCaseScopes
            
            $result.Count | Should -Be 1
            # Access using lowercase 'scope'
            $result[0].scope | Should -Be 'User.Read.All'
        }
        
        It "Should return empty array for empty ResourcePaths" {
            # Empty array should fail parameter validation
            { Get-RequiredScopesForEndpoints -ResourcePaths @() `
                -RequiredScopes $script:mockRequiredScopes } | Should -Throw
        }
    }
    
    Context "When validating integration with Test-ScopeAvailability" {
        It "Should return scope objects compatible with Test-ScopeAvailability" {
            $result = Get-RequiredScopesForEndpoints -ResourcePaths @('users', 'groups') `
                -RequiredScopes $script:mockRequiredScopes
            
            # Verify structure is compatible with Test-ScopeAvailability expectations
            $result.Count | Should -BeGreaterThan 0
            
            foreach ($scope in $result) {
                # Each scope object should have Scope, endpoints, and optionally Reason properties
                $scopeName = if ($scope.Scope) { $scope.Scope } else { $scope.scope }
                $scopeName | Should -Not -BeNullOrEmpty
                $scope.endpoints | Should -Not -BeNullOrEmpty
            }
        }
    }
}
