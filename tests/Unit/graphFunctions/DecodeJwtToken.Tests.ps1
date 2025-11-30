<#
.SYNOPSIS
    Unit tests for DecodeJwtToken function

.DESCRIPTION
    Tests JWT token decoding functionality including:
    - Raw mode returns unfiltered claims (including scp, roles, etc.)
    - Human-readable mode filters and transforms claims
    - Proper handling of token structure and validation
    
.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers for temp environment
    Related Issue: Scope validation cache bug (scp claim filtering)
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: DecodeJwtToken" -Tags 'Unit', 'GraphFunctions', 'TokenDecoding' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
        
        # Load function under test
        . "$script:RepoRoot/functions/graphFunctions/DecodeJwtToken.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Mock Write-Log globally
        Mock Write-Log {}
        
        # Initialize script variables
        $script:LogFile = Join-Path $script:TestContext.TestFolder "test.log"
        $global:maxJSONDepth = 20
        
        # Create a sample JWT token for testing
        # Header: {"alg":"RS256","typ":"JWT"}
        # Payload includes common claims plus scp and roles
        $samplePayload = @{
            aud                = "00000003-0000-0000-c000-000000000000"
            iss                = "https://sts.windows.net/tenant-id/"
            iat                = 1700000000
            nbf                = 1700000000
            exp                = 1700003600
            scp                = "User.Read Mail.Send Device.ReadWrite.All"
            roles              = @("Application.ReadWrite.All", "Directory.ReadWrite.All")
            sub                = "subject-id"
            tid                = "tenant-id"
            oid                = "object-id"
            preferred_username = "user@domain.com"
            email              = "user@domain.com"
            ver                = "2.0"
        } | ConvertTo-Json -Compress
        
        # Base64 encode the payload (URL-safe)
        $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($samplePayload)
        $payloadBase64 = [Convert]::ToBase64String($payloadBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        
        # Create a minimal JWT (header.payload.signature)
        $header = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9"  # {"alg":"RS256","typ":"JWT"}
        $signature = "fake-signature"
        $script:TestToken = "$header.$payloadBase64.$signature"
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "When using -raw switch (unfiltered claims)" {
        It "Should return all claims including scp" {
            $result = DecodeJwtToken -Token $script:TestToken -raw
            
            $result.scp | Should -Not -BeNullOrEmpty
            $result.scp | Should -Be "User.Read Mail.Send Device.ReadWrite.All"
        }
        
        It "Should return all claims including roles" {
            $result = DecodeJwtToken -Token $script:TestToken -raw
            
            $result.roles | Should -Not -BeNullOrEmpty
            $result.roles.Count | Should -Be 2
            $result.roles | Should -Contain "Application.ReadWrite.All"
            $result.roles | Should -Contain "Directory.ReadWrite.All"
        }
        
        It "Should return all standard claims without filtering" {
            $result = DecodeJwtToken -Token $script:TestToken -raw
            
            # These should all be present in raw mode
            $result.aud | Should -Not -BeNullOrEmpty
            $result.iss | Should -Not -BeNullOrEmpty
            $result.sub | Should -Not -BeNullOrEmpty
            $result.tid | Should -Not -BeNullOrEmpty
            $result.oid | Should -Not -BeNullOrEmpty
            $result.preferred_username | Should -Not -BeNullOrEmpty
            $result.email | Should -Not -BeNullOrEmpty
            $result.ver | Should -Not -BeNullOrEmpty
        }
        
        It "Should return raw claims as object (not transformed)" {
            $result = DecodeJwtToken -Token $script:TestToken -raw
            
            # Time claims should be numbers, not formatted dates
            $result.iat | Should -BeOfType [long]
            $result.nbf | Should -BeOfType [long]
            $result.exp | Should -BeOfType [long]
        }
        
        It "Should support -RawJSON parameter in raw mode" {
            $result = DecodeJwtToken -Token $script:TestToken -raw -RawJSON
            
            $result | Should -BeOfType [string]
            $parsed = $result | ConvertFrom-Json
            $parsed.scp | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "When using human-readable mode (default)" {
        It "Should filter out non-whitelisted claims" {
            $result = DecodeJwtToken -Token $script:TestToken
            
            # scp is not in HRIdentifyers, so it should be filtered out
            $result.scp | Should -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Not -Contain "scp"
        }
        
        It "Should include whitelisted claims with human-readable names" {
            $result = DecodeJwtToken -Token $script:TestToken
            
            # These are in HRIdentifyers and should be renamed
            $result.Roles | Should -Not -BeNullOrEmpty  # 'roles' -> 'Roles'
            $result.'Object Identifier' | Should -Not -BeNullOrEmpty  # 'oid' -> 'Object Identifier'
            $result.TenantID | Should -Not -BeNullOrEmpty  # 'tid' -> 'TenantID'
        }
        
        It "Should convert unix timestamps to formatted dates" {
            Mock FormatDateWithTimeZone { return "2023-11-15 00:00:00 UTC" }
            
            $result = DecodeJwtToken -Token $script:TestToken
            
            # Time claims should be formatted strings, not numbers
            $result.IssuedAt | Should -BeOfType [string]
            $result.NotBefore | Should -BeOfType [string]
            $result.ExpirationTime | Should -BeOfType [string]
        }
        
        It "Should convert arrays to comma-separated strings" {
            $result = DecodeJwtToken -Token $script:TestToken
            
            # roles array should be converted to comma-separated string
            $result.Roles | Should -BeOfType [string]
            $result.Roles | Should -Match "Application.ReadWrite.All"
        }
        
        It "Should support -RawJSON parameter in human-readable mode" {
            $result = DecodeJwtToken -Token $script:TestToken -RawJSON
            
            $result | Should -BeOfType [string]
            $parsed = $result | ConvertFrom-Json
            # Should have transformed keys
            $parsed.Roles | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "When handling invalid tokens" {
        BeforeEach {
            # Mock returnValues global variable that DecodeJwtToken expects
            $global:returnValues = @{
                invalidJWTTokenMessage   = "Invalid JWT token"
                invalidJWTPayloadMessage = "Invalid JWT payload"
            }
        }
        
        It "Should return error message for tokens with insufficient parts" {
            # Create a token with only one part (invalid)
            $invalidToken = "onlyonepart"
            
            $result = DecodeJwtToken -Token $invalidToken
            
            # Should return error message from returnValues
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Be $global:returnValues.invalidJWTTokenMessage
        }
        
        It "Should handle tokens with minimal valid structure" {
            # Create token with valid structure (3 parts) and minimal payload
            # Use the same payload structure as our test token
            $minimalPayload = @{ sub = "test" } | ConvertTo-Json -Compress
            $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($minimalPayload)
            $payloadBase64 = [Convert]::ToBase64String($payloadBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
            $validToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.$payloadBase64.signature"
            
            $result = DecodeJwtToken -Token $validToken -raw
            
            # Should return an object with at least the sub claim
            $result | Should -Not -BeNullOrEmpty
            $result.sub | Should -Be "test"
        }
    }
    
    Context "When extracting scope information for cache validation" {
        It "Should extract delegated scopes (scp) in raw mode" {
            $result = DecodeJwtToken -Token $script:TestToken -raw
            
            $scopes = $result.scp -split ' '
            $scopes | Should -Contain "User.Read"
            $scopes | Should -Contain "Mail.Send"
            $scopes | Should -Contain "Device.ReadWrite.All"
        }
        
        It "Should extract application roles in raw mode" {
            $result = DecodeJwtToken -Token $script:TestToken -raw
            
            $result.roles | Should -Contain "Application.ReadWrite.All"
            $result.roles | Should -Contain "Directory.ReadWrite.All"
        }
        
        It "Should support scope comparison scenarios" {
            $result = DecodeJwtToken -Token $script:TestToken -raw
            
            # Simulate what Test-CachedTokenValidity does
            $grantedScopes = @()
            if ($result.scp)
            {
                $grantedScopes = $result.scp -split ' ' | Where-Object { $_ -and $_.Trim() }
            }
            
            $requestedScopes = @("User.Read", "Mail.Send")
            $missingScopes = $requestedScopes | Where-Object { $grantedScopes -notcontains $_ }
            
            $missingScopes.Count | Should -Be 0
        }
    }
}
