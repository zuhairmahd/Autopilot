<#
.SYNOPSIS
    Unit tests for HasScope function

.DESCRIPTION
    Tests Microsoft Graph scope validation and authorization checking:
    - Direct scope matching
    - Hierarchical scope checking (broader scopes include narrower ones)
    - URI normalization (GUID, ID, UPN patterns)
    - Multiple resource path validation
    - Scope hierarchy for various Microsoft Graph APIs
    - Edge cases and error scenarios
    
    Part of Phase 2 Week 3 coverage improvement initiative

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotGraphMocks for mock token generation
    Complexity: High - Complex scope hierarchy and URI pattern matching
    Coverage Target: ~150 lines of 349-line function
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Function: HasScope" -Tags 'Unit', 'GraphFunctions', 'Authorization' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/graphFunctions/DecodeJwtToken.ps1"
        
        # Load function under test
        . "$script:RepoRoot/functions/graphFunctions/HasScope.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $global:LogFile = Join-Path $script:TestContext.LogsFolder "HasScope.log"
        
        # Mock Write-Log globally
        Mock Write-Log {}
        
        # Create mock settings with required scopes
        $script:mockSettings = @{
            requiredScopes = @(
                @{
                    Scope     = 'User.Read.All'
                    endpoints = @('users', 'users/{id}')
                },
                @{
                    Scope     = 'Group.Read.All'
                    endpoints = @('groups', 'groups/{id}', 'groups/{id}/members')
                },
                @{
                    Scope     = 'Device.Read.All'
                    endpoints = @('devices', 'devices/{id}')
                },
                @{
                    Scope     = 'DeviceManagementManagedDevices.ReadWrite.All'
                    endpoints = @('deviceManagement/managedDevices', 'deviceManagement/managedDevices/{id}')
                },
                @{
                    Scope     = 'Directory.Read.All'
                    endpoints = @('directory/administrativeUnits', 'organization')
                }
            )
        }
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "When validating direct scope matches" {
        It "Should authorize resource when exact scope is present" {
            # Create token with exact required scope
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.TotalUrisChecked | Should -Be 1
            $result.Details[0].IsAuthorized | Should -Be $true
            $result.Details[0].Details[0].AuthorizationType | Should -Be 'Direct'
        }
        
        It "Should authorize multiple resources when all exact scopes are present" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All', 'Group.Read.All', 'Device.Read.All')
            
            $result = HasScope -ResourcePath @('users', 'groups', 'devices') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.TotalUrisChecked | Should -Be 3
            $result.Details | Where-Object { -not $_.IsAuthorized } | Should -BeNullOrEmpty
        }
        
        It "Should deny access when exact scope is missing" {
            $mockToken = New-MockGraphToken -Scopes @('Group.Read.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $false
            $result.Details[0].IsAuthorized | Should -Be $false
        }
    }
    
    Context "When validating hierarchical scope relationships" {
        It "Should authorize with Directory.ReadWrite.All for User.Read.All requirement" {
            # Directory.ReadWrite.All includes User.Read.All in hierarchy
            $mockToken = New-MockGraphToken -Scopes @('Directory.ReadWrite.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].IsAuthorized | Should -Be $true
            $result.Details[0].Details[0].AuthorizationType | Should -Be 'Hierarchical'
            $result.Details[0].Details[0].SatisfyingScope | Should -Be 'Directory.ReadWrite.All'
        }
        
        It "Should authorize with Directory.Read.All for User.Read.All requirement" {
            $mockToken = New-MockGraphToken -Scopes @('Directory.Read.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].Details[0].AuthorizationType | Should -Be 'Hierarchical'
        }
        
        It "Should authorize with User.ReadWrite.All for User.Read.All requirement" {
            # User.ReadWrite.All includes User.Read.All
            $mockToken = New-MockGraphToken -Scopes @('User.ReadWrite.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].Details[0].SatisfyingScope | Should -Be 'User.ReadWrite.All'
        }
        
        It "Should authorize with Group.ReadWrite.All for Group.Read.All requirement" {
            $mockToken = New-MockGraphToken -Scopes @('Group.ReadWrite.All')
            
            $result = HasScope -ResourcePath @('groups') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].Details[0].AuthorizationType | Should -Be 'Hierarchical'
        }
        
        It "Should not authorize narrower scope for broader requirement" {
            # User.ReadBasic.All does NOT include User.Read.All
            $mockToken = New-MockGraphToken -Scopes @('User.ReadBasic.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $false
        }
    }
    
    Context "When normalizing URIs with dynamic parameters" {
        It "Should match URI with GUID to pattern with {id}" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All')
            $guidUri = 'users/12345678-1234-1234-1234-123456789abc'
            
            $result = HasScope -ResourcePath @($guidUri) -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].IsAuthorized | Should -Be $true
        }
        
        It "Should match full URL by extracting relative path" {
            $mockToken = New-MockGraphToken -Scopes @('Group.Read.All')
            $fullUrl = 'https://graph.microsoft.com/v1.0/groups/12345678-1234-1234-1234-123456789abc'
            
            $result = HasScope -ResourcePath @($fullUrl) -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].RelativeUri | Should -Be 'groups/12345678-1234-1234-1234-123456789abc'
        }
        
        It "Should strip query parameters from URI" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All')
            $uriWithQuery = 'users?$filter=displayName eq ''John'''
            
            $result = HasScope -ResourcePath @($uriWithQuery) -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
        }
        
        It "Should normalize numeric IDs to {id} pattern" {
            $mockToken = New-MockGraphToken -Scopes @('Device.Read.All')
            $numericIdUri = 'devices/123456789'
            
            $result = HasScope -ResourcePath @($numericIdUri) -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
        }
        
        It "Should normalize UPN (email) identifiers to {id} pattern" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All')
            $upnUri = 'users/john.doe@contoso.com'
            
            $result = HasScope -ResourcePath @($upnUri) -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
        }
    }
    
    Context "When handling token scope formats" {
        It "Should handle scopes as comma-separated string" {
            # Create token with roles as comma-separated string
            $tokenPayload = @{
                roles = 'User.Read.All, Group.Read.All'
                aud   = 'https://graph.microsoft.com'
                iss   = 'https://sts.windows.net/test/'
                exp   = ([DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds())
            }
            $mockToken = New-MockGraphToken -CustomPayload $tokenPayload
            
            $result = HasScope -ResourcePath @('users', 'groups') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
        }
        
        It "Should handle scopes as array" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All', 'Group.Read.All')
            
            $result = HasScope -ResourcePath @('users', 'groups') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
        }
        
        It "Should handle empty scopes array" {
            $mockToken = New-MockGraphToken -Scopes @()
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $false
        }
    }
    
    Context "When checking multiple resource paths" {
        It "Should return false if any resource is unauthorized" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All')
            
            $result = HasScope -ResourcePath @('users', 'groups', 'devices') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $false
            $result.TotalUrisChecked | Should -Be 3
            ($result.Details | Where-Object { $_.IsAuthorized }).Count | Should -Be 1
            ($result.Details | Where-Object { -not $_.IsAuthorized }).Count | Should -Be 2
        }
        
        It "Should provide detailed results for each resource" {
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All', 'Device.Read.All')
            
            $result = HasScope -ResourcePath @('users', 'groups', 'devices') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.Details.Count | Should -Be 3
            $result.Details[0].Uri | Should -Be 'users'
            $result.Details[0].IsAuthorized | Should -Be $true
            $result.Details[1].Uri | Should -Be 'groups'
            $result.Details[1].IsAuthorized | Should -Be $false
            $result.Details[2].Uri | Should -Be 'devices'
            $result.Details[2].IsAuthorized | Should -Be $true
        }
    }
    
    Context "When checking endpoints without defined scopes" {
        It "Should authorize public endpoints (no scope requirement)" {
            $mockToken = New-MockGraphToken -Scopes @()
            $publicEndpoint = 'publicEndpointWithNoScopeRequirement'
            
            $result = HasScope -ResourcePath @($publicEndpoint) -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].IsAuthorized | Should -Be $true
            $result.Details[0].RequiredScopes.Count | Should -Be 0
        }
    }
    
    Context "When validating DeviceManagement scope hierarchy" {
        It "Should authorize DeviceManagement endpoint with exact scope" {
            $mockToken = New-MockGraphToken -Scopes @('DeviceManagementManagedDevices.ReadWrite.All')
            
            $result = HasScope -ResourcePath @('deviceManagement/managedDevices') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].IsAuthorized | Should -Be $true
        }
        
        It "Should deny DeviceManagement endpoint with read-only scope" {
            $mockToken = New-MockGraphToken -Scopes @('DeviceManagementManagedDevices.Read.All')
            
            $result = HasScope -ResourcePath @('deviceManagement/managedDevices') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $false
        }
    }
    
    Context "When handling nested resource paths" {
        It "Should authorize nested resource path with appropriate scope" {
            $mockToken = New-MockGraphToken -Scopes @('Group.Read.All')
            
            $result = HasScope -ResourcePath @('groups/12345678-1234-1234-1234-123456789abc/members') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details[0].IsAuthorized | Should -Be $true
        }
    }
    
    Context "When validating scope hierarchy edge cases" {
        It "Should handle scope property name case sensitivity" {
            # Test with lowercase 'scope' property
            $customScopes = @(
                @{
                    scope     = 'User.Read.All'  # lowercase 'scope'
                    endpoints = @('users')
                }
            )
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $customScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
        }
        
        It "Should handle endpoints with leading slash" {
            $customScopes = @(
                @{
                    Scope     = 'User.Read.All'
                    endpoints = @('/users')  # With leading slash
                }
            )
            $mockToken = New-MockGraphToken -Scopes @('User.Read.All')
            
            $result = HasScope -ResourcePath @('users') -requiredScopes $customScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
        }
    }
    
    Context "When validating complex scope combinations" {
        It "Should authorize with Directory.ReadWrite.All for multiple endpoint types" {
            # Directory.ReadWrite.All should cover User, Group, Device, and Organization
            $mockToken = New-MockGraphToken -Scopes @('Directory.ReadWrite.All')
            
            $result = HasScope -ResourcePath @('users', 'groups', 'devices', 'organization') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.OverallAuthorized | Should -Be $true
            $result.Details | Where-Object { -not $_.IsAuthorized } | Should -BeNullOrEmpty
        }
        
        It "Should provide satisfying scope for each authorized resource" {
            $mockToken = New-MockGraphToken -Scopes @('Directory.Read.All')
            
            $result = HasScope -ResourcePath @('users', 'groups') -requiredScopes $script:mockSettings.requiredScopes -accessToken $mockToken
            
            $result.Details[0].Details[0].SatisfyingScope | Should -Be 'Directory.Read.All'
            $result.Details[1].Details[0].SatisfyingScope | Should -Be 'Directory.Read.All'
        }
    }
}
