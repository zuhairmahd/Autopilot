<#
.SYNOPSIS
    Pester tests for Test-ScopeAvailability function

.DESCRIPTION
    Comprehensive unit tests validating scope availability checking logic for both
    delegated and application authentication flows. Tests include:
    - Delegated authentication with requested scopes
    - Application authentication with JWT token parsing
    - Empty/missing scope handling
    - OIDC protocol scope filtering
    - Scope hierarchy validation integration
    - Missing scope detection and recommendations
    - Error handling scenarios

.NOTES
    Test Structure: Unit test (isolated function testing with mocking)
    Dependencies: 
    - AutopilotTestHelpers.psm1 (temp folders, settings, cleanup)
    - AutopilotGraphMocks.psm1 (JWT token generation)
    - Direct dot-sourcing pattern for PS 5.1 compatibility
    
    Dependency Chain (loaded in order):
    1. Write-Log (base utility)
    2. GetTimeZoneAbbreviation (utility for date formatting)
    3. FormatDateWithTimeZone (utility for token date formatting)
    4. DecodeJwtToken (JWT parsing)
    5. Test-ScopeHierarchy (scope comparison logic)
    6. Test-ScopeAvailability (function under test)
    
    Helper Usage: Uses New-MockGraphToken from AutopilotGraphMocks for token generation
    
    Created: October 15, 2025
    Last Modified: October 15, 2025
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Function: Test-ScopeAvailability" -Tags 'Unit', 'GraphFunctions' {
    BeforeAll {
        # Get repository root and load dependencies in correct order
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load base utilities first
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        
        # Load Graph functions
        . "$script:RepoRoot/functions/graphFunctions/DecodeJwtToken.ps1"
        . "$script:RepoRoot/functions/graphFunctions/Test-ScopeHierarchy.ps1"
        . "$script:RepoRoot/functions/graphFunctions/Test-ScopeAvailability.ps1"
        
        # Initialize global log file variable
        $global:LogFile = Join-Path $TestDrive "test.log"
    }
    
    Context "When no required scopes are specified" {
        It "Should return success with empty required scopes array" {
            $authConfig = @{ Delegated = $true; scope = @("User.Read.All") }
            $token = New-MockGraphToken -Scopes @("User.Read.All") -Delegated
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes @() `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $true
            $result.RecommendedAction | Should -Match "No specific scopes required"
            $result.MissingScopes | Should -HaveCount 0
        }
        
        It "Should return success when RequiredScopes is null or not provided" {
            $authConfig = @{ Delegated = $true; scope = @("User.Read.All") }
            $token = New-MockGraphToken -Scopes @("User.Read.All") -Delegated
            
            # PowerShell 5.1 compatibility: Use empty array instead of null
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes @() `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $true
        }
    }
    
    Context "When using delegated authentication" {
        It "Should read granted scopes from JWT token scp claim" {
            $authConfig = @{ Delegated = $true; scope = @("User.Read.All", "Group.Read.All") }
            $token = New-MockGraphToken -Scopes @("User.Read.All", "Group.Read.All") -Delegated
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.ScopeSource | Should -Match "Delegated.*JWT.*scp"
            $result.AvailableScopes | Should -Contain "User.Read.All"
            $result.AvailableScopes | Should -Contain "Group.Read.All"
        }
        
        It "Should detect missing scopes in delegated auth" {
            $authConfig = @{ Delegated = $true; scope = @("User.Read.All") }
            $token = New-MockGraphToken -Scopes @("User.Read.All") -Delegated
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") },
                @{ Scope = "Group.ReadWrite.All"; Reason = "Manage groups"; Endpoints = @("/groups") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $false
            $result.MissingScopes | Should -HaveCount 1
            $result.MissingScopes[0].Scope | Should -Be "Group.ReadWrite.All"
            $result.RecommendedAction | Should -Match "Re-authenticate"
        }
        
        It "Should handle tokens with no scp claim gracefully" {
            $authConfig = @{ Delegated = $true; scope = @() }
            # Create token without scp claim
            $customPayload = @{ aud = "test" }
            $token = New-MockGraphToken -CustomPayload $customPayload
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.AvailableScopes | Should -HaveCount 0
            $result.HasAllRequiredScopes | Should -Be $false
        }
        
        It "Should satisfy requirements with hierarchical scopes in delegated auth" {
            $authConfig = @{ Delegated = $true; scope = @("User.ReadWrite.All") }
            $token = New-MockGraphToken -Scopes @("User.ReadWrite.All") -Delegated
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $true
            $result.MissingScopes.Count | Should -Be 0
        }
    }
    
    Context "When using application authentication" {
        It "Should parse JWT token and extract scopes from 'roles' claim" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All", "Group.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.ScopeSource | Should -Match "Application.*JWT"
            $result.AvailableScopes | Should -Contain "User.Read.All"
            $result.AvailableScopes | Should -Contain "Group.Read.All"
            $result.HasAllRequiredScopes | Should -Be $true
        }
        
        It "Should detect missing scopes in application auth" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") },
                @{ Scope = "Device.ReadWrite.All"; Reason = "Manage devices"; Endpoints = @("/devices") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $false
            $result.MissingScopes | Should -HaveCount 1
            $result.MissingScopes[0].Scope | Should -Be "Device.ReadWrite.All"
            $result.RecommendedAction | Should -Match "administrator"
        }
        
        It "Should satisfy requirements with hierarchical scopes in application auth" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.ReadWrite.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $true
            $result.MissingScopes.Count | Should -Be 0
        }
        
        It "Should handle tokens with no scope claims" {
            $authConfig = @{ Delegated = $false }
            # Create token with roles present but empty
            $customPayload = @{ roles = @() }
            $token = New-MockGraphToken -CustomPayload $customPayload
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig -ErrorAction SilentlyContinue
            
            # With empty available scopes and required scopes specified, should fail
            $result.HasAllRequiredScopes | Should -Be $false
            # AvailableScopes filtering may result in $null elements
            ($result.AvailableScopes | Where-Object { $_ -and $_.Trim() }) | Should -HaveCount 0
            # When decoding succeeds but no scopes found, returns generic validation failed message
            $result.RecommendedAction | Should -Match "validation failed|administrator|check the logs"
        }
    }
    
    Context "When filtering OIDC protocol scopes for application auth" {
        It "Should exclude 'openid' scope from required scopes in application auth" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "openid"; Reason = "OIDC protocol"; Endpoints = @() },
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # openid should be filtered out, User.Read.All should be satisfied
            $result.HasAllRequiredScopes | Should -Be $true
            $result.MissingScopes | Should -HaveCount 0
        }
        
        It "Should exclude 'profile' scope from required scopes in application auth" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("Group.Read.All")
            $requiredScopes = @(
                @{ Scope = "profile"; Reason = "OIDC protocol"; Endpoints = @() },
                @{ Scope = "Group.Read.All"; Reason = "Read groups"; Endpoints = @("/groups") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $true
        }
        
        It "Should exclude 'offline_access' scope from required scopes in application auth" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("Device.Read.All")
            $requiredScopes = @(
                @{ Scope = "offline_access"; Reason = "OIDC protocol"; Endpoints = @() },
                @{ Scope = "Device.Read.All"; Reason = "Read devices"; Endpoints = @("/devices") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $true
        }
        
        It "Should filter OIDC scopes from required list in delegated authentication" {
            $authConfig = @{ Delegated = $true; scope = @("openid", "profile", "User.Read.All") }
            $token = New-MockGraphToken -Scopes @("openid", "profile", "User.Read.All") -Delegated
            $requiredScopes = @(
                @{ Scope = "openid"; Reason = "OpenID"; Endpoints = @() },
                @{ Scope = "profile"; Reason = "Profile"; Endpoints = @() },
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @() }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # OIDC scopes should be filtered from required list, only User.Read.All validated
            $result.HasAllRequiredScopes | Should -Be $true
            # OIDC scopes should also be filtered from available scopes
            $result.AvailableScopes | Should -Contain "User.Read.All"
            $result.AvailableScopes | Should -Not -Contain "openid"
            $result.AvailableScopes | Should -Not -Contain "profile"
        }
        
        It "Should filter OIDC scopes from token claims in application auth" {
            $authConfig = @{ Delegated = $false }
            # Create token with both Graph API and OIDC scopes
            $customPayload = @{
                roles = @("openid", "profile", "offline_access", "User.Read.All", "Group.Read.All")
            }
            $token = New-MockGraphToken -CustomPayload $customPayload
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # Available scopes should NOT include OIDC scopes
            $result.AvailableScopes | Should -Contain "User.Read.All"
            $result.AvailableScopes | Should -Contain "Group.Read.All"
            $result.AvailableScopes | Should -Not -Contain "openid"
            $result.AvailableScopes | Should -Not -Contain "profile"
            $result.AvailableScopes | Should -Not -Contain "offline_access"
        }
    }
    
    Context "When handling unavailable functionality tracking" {
        It "Should populate UnavailableFunctionality for missing scopes" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "Group.ReadWrite.All"; Reason = "Manage groups"; Endpoints = @("/groups", "/groups/{id}/members") },
                @{ Scope = "Device.ReadWrite.All"; Reason = "Manage devices"; Endpoints = @("/devices") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.UnavailableFunctionality | Should -HaveCount 2
            $result.UnavailableFunctionality[0].Scope | Should -Be "Group.ReadWrite.All"
            $result.UnavailableFunctionality[0].Reason | Should -Be "Manage groups"
            $result.UnavailableFunctionality[0].Impact | Should -Match "not function"
            $result.UnavailableFunctionality[1].Scope | Should -Be "Device.ReadWrite.All"
        }
        
        It "Should include endpoint information in UnavailableFunctionality" {
            $authConfig = @{ Delegated = $true; scope = @() }
            # Create token with no scopes in scp claim
            $customPayload = @{ scp = "" }
            $token = New-MockGraphToken -CustomPayload $customPayload
            $requiredScopes = @(
                @{ Scope = "Mail.Send"; Reason = "Send mail"; Endpoints = @("/users/{id}/sendMail", "/me/sendMail") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.UnavailableFunctionality | Should -HaveCount 1
            $endpoints = $result.UnavailableFunctionality[0].Endpoints
            $endpoints | Should -Match "/users/.*/sendMail"
            $endpoints | Should -Match "/me/sendMail"
        }
        
        It "Should have empty UnavailableFunctionality when all scopes are satisfied" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All", "Group.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") },
                @{ Scope = "Group.Read.All"; Reason = "Read groups"; Endpoints = @("/groups") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.UnavailableFunctionality | Should -HaveCount 0
            $result.HasAllRequiredScopes | Should -Be $true
        }
    }
    
    Context "When generating recommended actions" {
        It "Should recommend re-authentication for delegated auth missing scopes" {
            $authConfig = @{ Delegated = $true; scope = @("User.Read.All") }
            $token = New-MockGraphToken -Scopes @("User.Read.All") -Delegated
            $requiredScopes = @(
                @{ Scope = "Group.ReadWrite.All"; Reason = "Manage groups"; Endpoints = @("/groups") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.RecommendedAction | Should -Match "Re-authenticate"
            $result.RecommendedAction | Should -Match "additional scopes"
        }
        
        It "Should recommend administrator action for application auth missing scopes" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "Device.ReadWrite.All"; Reason = "Manage devices"; Endpoints = @("/devices") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.RecommendedAction | Should -Match "administrator"
            $result.RecommendedAction | Should -Match "application permissions"
        }
        
        It "Should recommend no action when all scopes are available" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All", "Group.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") },
                @{ Scope = "Group.Read.All"; Reason = "Read groups"; Endpoints = @("/groups") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.RecommendedAction | Should -Match "No action needed"
        }
    }
    
    Context "When handling scope hierarchy validation" {
        It "Should use Test-ScopeHierarchy for scope comparison" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.ReadWrite.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # User.ReadWrite.All should satisfy User.Read.All requirement
            $result.HasAllRequiredScopes | Should -Be $true
            $result.MissingScopes | Should -HaveCount 0
        }
        
        It "Should correctly apply hierarchy for Device scopes" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("Device.ReadWrite.All")
            $requiredScopes = @(
                @{ Scope = "Device.Read.All"; Reason = "Read devices"; Endpoints = @("/devices") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -Be $true
        }
        
        It "Should correctly apply hierarchy for Directory scopes within same resource" {
            $authConfig = @{ Delegated = $false }
            # Use specific resource scopes - hierarchy only works within same resource
            $token = New-MockGraphToken -Scopes @("User.ReadWrite.All", "Group.ReadWrite.All", "Device.ReadWrite.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") },
                @{ Scope = "Group.Read.All"; Reason = "Read groups"; Endpoints = @("/groups") },
                @{ Scope = "Device.Read.All"; Reason = "Read devices"; Endpoints = @("/devices") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # Each ReadWrite scope should satisfy corresponding Read requirement
            $result.HasAllRequiredScopes | Should -Be $true
            $result.MissingScopes.Count | Should -Be 0
        }
        
        It "Should NOT allow lower privilege scope to satisfy higher requirement" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.ReadWrite.All"; Reason = "Write users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # User.Read.All should NOT satisfy User.ReadWrite.All requirement
            $result.HasAllRequiredScopes | Should -Be $false
            $result.MissingScopes | Should -HaveCount 1
        }
    }
    
    Context "When handling error scenarios" {
        It "Should handle invalid JWT token gracefully" {
            $authConfig = @{ Delegated = $false }
            $invalidToken = "not.a.valid.jwt.token"
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            # Suppress Write-Error output
            $result = Test-ScopeAvailability -AccessToken $invalidToken -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig -ErrorAction SilentlyContinue
            
            $result.HasAllRequiredScopes | Should -Be $false
            # When token decoding fails, available scopes will be empty, so admin action recommended
            $result.RecommendedAction | Should -Match "administrator|validation failed|check the logs"
        }
        
        It "Should handle malformed required scope objects" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            # Missing Reason and Endpoints properties
            $requiredScopes = @(
                @{ Scope = "User.Read.All" }
            )
            
            # Should not throw
            { Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                    -AuthConfiguration $authConfig } | Should -Not -Throw
        }
        
        It "Should handle exception during token decoding" {
            $authConfig = @{ Delegated = $false }
            # Create a malformed token with invalid Base64 in payload
            $malformedToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.!!!INVALID-BASE64!!!.signature"
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            # When token decoding fails, the function should still return a result
            # indicating that scope validation couldn't be completed
            $result = Test-ScopeAvailability -AccessToken $malformedToken -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            
            # The function should catch exceptions and return a failed validation result
            $result.HasAllRequiredScopes | Should -Be $false
            # Either we get an exception message or the standard admin contact message (both are valid)
            $result.RecommendedAction | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "When validating result structure" {
        It "Should return result with all expected properties" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # Check that result is a hashtable with all required keys
            $result | Should -BeOfType [hashtable]
            $result.ContainsKey('HasAllRequiredScopes') | Should -Be $true
            $result.ContainsKey('MissingScopes') | Should -Be $true
            $result.ContainsKey('AvailableScopes') | Should -Be $true
            $result.ContainsKey('ScopeSource') | Should -Be $true
            $result.ContainsKey('UnavailableFunctionality') | Should -Be $true
            $result.ContainsKey('RecommendedAction') | Should -Be $true
        }
        
        It "Should return hashtable result type" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result | Should -BeOfType [hashtable]
        }
        
        It "Should have boolean HasAllRequiredScopes property" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "User.Read.All"; Reason = "Read users"; Endpoints = @("/users") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            $result.HasAllRequiredScopes | Should -BeOfType [bool]
        }
        
        It "Should have array MissingScopes property" {
            $authConfig = @{ Delegated = $false }
            $token = New-MockGraphToken -Scopes @("User.Read.All")
            $requiredScopes = @(
                @{ Scope = "Group.Read.All"; Reason = "Read groups"; Endpoints = @("/groups") }
            )
            
            $result = Test-ScopeAvailability -AccessToken $token -RequiredScopes $requiredScopes `
                -AuthConfiguration $authConfig
            
            # MissingScopes should be an array when there are missing scopes
            $result.MissingScopes | Should -Not -BeNullOrEmpty
            $result.MissingScopes.GetType().BaseType.Name | Should -BeIn @('Array', 'Object')
            $result.MissingScopes.Count | Should -Be 1
        }
    }
}
