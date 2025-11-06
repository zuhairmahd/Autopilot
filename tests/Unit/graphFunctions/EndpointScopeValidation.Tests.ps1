<#
.SYNOPSIS
    Integration tests for endpoint-level scope validation using composition pattern

.DESCRIPTION
    Tests the composition of Get-RequiredScopesForEndpoints + Test-ScopeAvailability
    to provide endpoint-level authorization checking.
    
    This replaces HasScope.ps1 functionality using a cleaner composition pattern:
    1. Get-RequiredScopesForEndpoints: Maps endpoints → required scopes
    2. Test-ScopeAvailability: Validates token has required scopes
    
    Migrated from HasScope.Tests.ps1 as part of HasScope deprecation (Option 1)
    
.NOTES
    Test Category: Integration (tests composition of multiple functions)
    Replaces: HasScope.Tests.ps1 (26 tests)
    Related Functions:
        - Get-RequiredScopesForEndpoints (endpoint mapping)
        - Test-ScopeAvailability (token validation)
        - Test-ScopeHierarchy (hierarchical permissions)
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Endpoint-Level Scope Validation (Composition Pattern)" -Tags 'Integration', 'GraphFunctions', 'Authorization' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/graphFunctions/DecodeJwtToken.ps1"
        . "$script:RepoRoot/functions/graphFunctions/Test-ScopeHierarchy.ps1"
        
        # Load functions under test (composition pattern)
        . "$script:RepoRoot/functions/graphFunctions/Get-RequiredScopesForEndpoints.ps1"
        . "$script:RepoRoot/functions/graphFunctions/Test-ScopeAvailability.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $global:LogFile = Join-Path $script:TestContext.LogsFolder "EndpointScopeValidation.log"
        
        # Mock Write-Log globally
        Mock Write-Log {}
        
        # Create mock settings with required scopes
        $script:mockSettings = @{
            requiredScopes = @(
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
        
        # Mock auth configuration for Test-ScopeAvailability
        $script:mockAuthConfig = @{
            Delegated       = $true  # Capital D - used by Test-ScopeAvailability
            tenantId        = 'test-tenant-id'
            graphResourceId = 'https://graph.microsoft.com'
        }
        
        # Helper scriptblock to perform endpoint-level authorization check
        $script:TestEndpointAuth = {
            param(
                [string[]]$Endpoints,
                [string]$AccessToken,
                [array]$RequiredScopes,
                [hashtable]$AuthConfig
            )
            
            # Step 1: Map endpoints to required scopes
            $endpointScopes = Get-RequiredScopesForEndpoints `
                -ResourcePaths $Endpoints `
                -RequiredScopes $RequiredScopes
            
            # Step 2: Validate token has those scopes
            if ($endpointScopes.Count -eq 0)
            {
                # Public endpoint - no scopes required
                return @{
                    IsAuthorized   = $true
                    Endpoints      = $Endpoints
                    RequiredScopes = @()
                    TokenScopes    = @()
                }
            }
            
            $scopeCheck = Test-ScopeAvailability `
                -AccessToken $AccessToken `
                -RequiredScopes $endpointScopes `
                -AuthConfiguration $AuthConfig
            
            return @{
                IsAuthorized     = $scopeCheck.HasAllRequiredScopes
                Endpoints        = $Endpoints
                RequiredScopes   = $endpointScopes
                ScopeCheckResult = $scopeCheck
            }
        }
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "When validating direct scope matches" {
        It "Should authorize endpoint when exact scope is present" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
            $result.RequiredScopes.Count | Should -BeGreaterThan 0
            $result.RequiredScopes[0].Scope | Should -Be 'User.Read.All'
        }
        
        It "Should authorize multiple endpoints when all scopes are present" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All', 'Group.Read.All', 'Device.Read.All') -Delegated
            
            # Check each endpoint individually (composition pattern checks one at a time)
            $endpoints = @('users', 'groups', 'devices')
            $results = @()
            
            foreach ($endpoint in $endpoints)
            {
                $result = & $script:TestEndpointAuth -Endpoints @($endpoint) `
                    -AccessToken $mockToken `
                    -RequiredScopes $script:mockSettings.requiredScopes `
                    -AuthConfig $script:mockAuthConfig
                $results += $result
            }
            
            $results | Where-Object { -not $_.IsAuthorized } | Should -BeNullOrEmpty
            $results.Count | Should -Be 3
        }
        
        It "Should deny access when exact scope is missing" {
            $mockToken = New-MockGraphToken -Scopes @('Group.Read.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $false
        }
    }
    
    Context "When validating hierarchical scope relationships" {
        It "Should not authorize with Directory.ReadWrite.All for User.Read.All requirement (different resources)" {
            # Test-ScopeHierarchy requires matching resource names
            # Directory.ReadWrite.All (resource=Directory) != User.Read.All (resource=User)
            # This tests that cross-resource scope hierarchies are NOT automatically satisfied
            $mockToken = New-MockGraphToken -Scopes @('Directory.ReadWrite.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $false
        }
        
        It "Should not authorize with Directory.Read.All for User.Read.All requirement (different resources)" {
            # Test-ScopeHierarchy requires matching resource names
            # Directory.Read.All (resource=Directory) != User.Read.All (resource=User)
            $mockToken = New-MockGraphToken -Scopes @('Directory.Read.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $false
        }
        
        It "Should authorize with User.ReadWrite.All for User.Read.All requirement" {
            $mockToken = New-MockGraphToken -Scopes @('User.ReadWrite.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should authorize with Group.ReadWrite.All for Group.Read.All requirement" {
            $mockToken = New-MockGraphToken -Scopes @('Group.ReadWrite.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('groups') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should not authorize narrower scope for broader requirement" {
            $mockToken = New-MockGraphToken -Scopes @('User.ReadBasic.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $false
        }
    }
    
    Context "When normalizing URIs with dynamic parameters" {
        It "Should match URI with GUID to pattern with {id}" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All') -Delegated
            $guidUri = 'users/12345678-1234-1234-1234-123456789abc'
            
            $result = & $script:TestEndpointAuth -Endpoints @($guidUri) `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should match full URL by extracting relative path" {
            $mockToken = New-MockGraphToken -Scopes @('Group.Read.All') -Delegated
            $fullUrl = 'https://graph.microsoft.com/v1.0/groups/12345678-1234-1234-1234-123456789abc'
            
            $result = & $script:TestEndpointAuth -Endpoints @($fullUrl) `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should strip query parameters from URI" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All') -Delegated
            $uriWithQuery = 'users?$filter=displayName eq ''John'''
            
            $result = & $script:TestEndpointAuth -Endpoints @($uriWithQuery) `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should normalize numeric IDs to {id} pattern" {
            $mockToken = New-MockGraphToken -Scopes @('Device.Read.All') -Delegated
            $numericIdUri = 'devices/123456789'
            
            $result = & $script:TestEndpointAuth -Endpoints @($numericIdUri) `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should normalize UPN (email) identifiers to {id} pattern" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All') -Delegated
            $upnUri = 'users/john.doe@contoso.com'
            
            $result = & $script:TestEndpointAuth -Endpoints @($upnUri) `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
    }
    
    Context "When checking endpoints without defined scopes" {
        It "Should authorize public endpoints (no scope requirement)" {
            $mockToken = New-MockGraphToken -Scopes @() -Delegated
            $publicEndpoint = 'publicEndpointWithNoScopeRequirement'
            
            $result = & $script:TestEndpointAuth -Endpoints @($publicEndpoint) `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
            $result.RequiredScopes.Count | Should -Be 0
        }
    }
    
    Context "When validating DeviceManagement scope hierarchy" {
        It "Should authorize DeviceManagement endpoint with exact scope" {
            $mockToken = New-MockGraphToken -Scopes @('DeviceManagementManagedDevices.ReadWrite.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('deviceManagement/managedDevices') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should deny DeviceManagement endpoint with read-only scope" {
            $mockToken = New-MockGraphToken -Scopes @('DeviceManagementManagedDevices.Read.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('deviceManagement/managedDevices') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $false
        }
    }
    
    Context "When handling nested resource paths" {
        It "Should authorize nested resource path with appropriate scope" {
            $mockToken = New-MockGraphToken -Scopes @('Group.Read.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('groups/12345678-1234-1234-1234-123456789abc/members') `
                -AccessToken $mockToken `
                -RequiredScopes $script:mockSettings.requiredScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
    }
    
    Context "When validating scope hierarchy edge cases" {
        It "Should handle scope property name case sensitivity" {
            $customScopes = @(
                @{
                    scope     = 'User.Read.All'  # lowercase 'scope'
                    endpoints = @('users')
                    Reason    = 'Test'
                }
            )
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $customScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
        
        It "Should handle endpoints with leading slash" {
            $customScopes = @(
                @{
                    Scope     = 'User.Read.All'
                    endpoints = @('/users')  # With leading slash
                    Reason    = 'Test'
                }
            )
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All') -Delegated
            
            $result = & $script:TestEndpointAuth -Endpoints @('users') `
                -AccessToken $mockToken `
                -RequiredScopes $customScopes `
                -AuthConfig $script:mockAuthConfig
            
            $result.IsAuthorized | Should -Be $true
        }
    }
    
    Context "When validating complex scope combinations" {
        It "Should not authorize with Directory.ReadWrite.All for resource-specific endpoints (different resources)" {
            # Test-ScopeAvailability validates hierarchical scopes via Test-ScopeHierarchy
            # Directory.ReadWrite.All does NOT satisfy User.*, Group.*, or Device.* (different resources)
            # Only Directory.* endpoints would be satisfied
            $mockToken = New-MockGraphToken -Scopes @('Directory.ReadWrite.All') -Delegated
            
            # Check multiple endpoints with different resources
            $endpoints = @('users', 'groups', 'devices')
            $results = @()
            
            foreach ($endpoint in $endpoints)
            {
                $result = & $script:TestEndpointAuth -Endpoints @($endpoint) `
                    -AccessToken $mockToken `
                    -RequiredScopes $script:mockSettings.requiredScopes `
                    -AuthConfig $script:mockAuthConfig
                $results += $result
            }
            
            # All should fail because resources don't match
            $results | Where-Object { $_.IsAuthorized } | Should -BeNullOrEmpty
            $results.Count | Should -Be 3
        }
    }
    
    Context "When checking multiple endpoints with partial authorization" {
        It "Should identify which endpoints are unauthorized with partial scopes" {
            # Test partial authorization: User.Read.All should only authorize 'users' endpoint
            # Other endpoints (groups, devices) require their respective scopes
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All') -Delegated
            
            # Check multiple endpoints
            $endpoints = @('users', 'groups', 'devices')
            $results = [System.Collections.ArrayList]::new()
            
            foreach ($endpoint in $endpoints)
            {
                $result = & $script:TestEndpointAuth -Endpoints @($endpoint) `
                    -AccessToken $mockToken `
                    -RequiredScopes $script:mockSettings.requiredScopes `
                    -AuthConfig $script:mockAuthConfig
                [void]$results.Add($result)
            }
            
            # Only 'users' endpoint should be authorized
            $authorizedResults = @($results | Where-Object { $_.IsAuthorized })
            
            $authorizedResults.Count | Should -Be 1
            $authorizedResults[0].Endpoints[0] | Should -Be 'users'
            @($results | Where-Object { -not $_.IsAuthorized }).Count | Should -Be 2
        }
    }
}
