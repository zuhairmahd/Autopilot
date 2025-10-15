<#
.SYNOPSIS
    Get-UserStrongMapping function tests
.DESCRIPTION
    Tests the Get-UserStrongMapping function with various scenarios
    Converted from TestScripts/test-get-user-strong-mapping-simple.ps1

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers (global variables, Write-Log mock)
          AutopilotGraphMocks (Graph API mocking with CustomProperties for certificates)
    
    Refactored: 2025-10-10 to use helper infrastructure
    Previous: Manual CallGraphAPI mock with 80+ lines of switch logic
    Current: Clean helper-based mocking with CustomProperties support
#>

# Import helper modules
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Get-UserStrongMapping Function" -Tags 'Unit', 'User', 'StrongMapping' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Setup mock global variables using helper
        Initialize-MockGlobalVariables -LogFile "test-user-strong-mapping.log"
        
        # Setup Write-Log mock using helper
        New-MockWriteLog
        
        # Initialize Graph mocking environment
        Initialize-GraphMockEnvironment -ClearCache
        
        # Add mock users with certificate data using CustomProperties
        # Note: Tests call with short names like "user-with-certs", so we add both forms
        Add-MockUser -UserPrincipalName "user-with-certs" `
            -DisplayName "Test User With Certs" `
            -GivenName "Test" -Surname "WithCerts" `
            -Id "user123" `
            -Mail "user-with-certs@test.com" `
            -CustomProperties @{
            authorizationInfo = @{
                certificateUserIds = @(
                    "C=US,O=Entrust,OU=Certification Authorities,OU=Entrust Managed Services SSP CA",
                    "C=US,O=Microsoft,OU=Microsoft IT,CN=Microsoft IT TLS CA 5"
                )
            }
        }
        
        Add-MockUser -UserPrincipalName "user-no-certs" `
            -DisplayName "Test User No Certs" `
            -GivenName "Test" -Surname "NoCerts" `
            -Id "user456" `
            -Mail "user-no-certs@test.com" `
            -CustomProperties @{
            authorizationInfo = @{
                certificateUserIds = @()
            }
        }
        
        Add-MockUser -UserPrincipalName "user-null-certs" `
            -DisplayName "Test User Null Certs" `
            -GivenName "Test" -Surname "NullCerts" `
            -Id "user789" `
            -Mail "user-null-certs@test.com" `
            -CustomProperties @{
            authorizationInfo = @{
                certificateUserIds = $null
            }
        }
        
        # Add default user (called as "test-user" in tests)
        Add-MockUser -UserPrincipalName "test-user" `
            -DisplayName "Default Test User" `
            -GivenName "Default" -Surname "User" `
            -Id "defaultuser" `
            -Mail "default@test.com" `
            -CustomProperties @{
            authorizationInfo = @{
                certificateUserIds = @("C=US,O=Test,CN=Test Cert")
            }
        }
        
        # Mock CallGraphApi to use helper infrastructure
        function global:CallGraphApi
        {
            param($accessToken, $ResourcePath, $ExtraParameters)
            
            Write-Verbose "[CallGraphApi Mock] ResourcePath: $ResourcePath, ExtraParameters: $ExtraParameters"
            
            # Use Invoke-MockGraphAPI directly - it handles users/{upn} pattern
            $result = Invoke-MockGraphAPI -accessToken $accessToken `
                -ResourcePath $ResourcePath `
                -ExtraParameters $ExtraParameters
            
            # Return null if 404 (user not found)
            if ($result -eq 404)
            {
                Write-Verbose "[CallGraphApi Mock] User not found (404)"
                return $null
            }
            
            return $result
        }
        
        # Load the specific function being tested
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-UserStrongMapping.ps1")
    }
    
    AfterAll {
        # Cleanup using helpers
        Clear-MockGlobalVariables
        Clear-GraphMockEnvironment
    }
    
    Context "Function availability" {
        
        It "Get-UserStrongMapping function should exist" {
            Get-Command Get-UserStrongMapping -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "User with multiple certificates" {
        
        BeforeAll {
            $script:Result = Get-UserStrongMapping -accessToken "fake-token" -UserName "user-with-certs"
        }
        
        It "Should return StrongMapping as true" {
            $script:Result.StrongMapping | Should -Be $true
        }
        
        It "Should preserve UserName" {
            $script:Result.UserName | Should -Be "user-with-certs"
        }
        
        It "Should set DisplayName" {
            $script:Result.DisplayName | Should -Be "Test User With Certs"
        }
        
        It "Should set UserId" {
            $script:Result.UserId | Should -Be "user123"
        }
        
        It "Should have CertificateCount of 2" {
            $script:Result.CertificateCount | Should -Be 2
        }
        
        It "Should have 2 certificates in array" {
            $script:Result.Certificates.Count | Should -Be 2
        }
    }
    
    Context "User with no certificates" {
        
        BeforeAll {
            $script:Result = Get-UserStrongMapping -accessToken "fake-token" -UserName "user-no-certs"
        }
        
        It "Should return StrongMapping as false" {
            $script:Result.StrongMapping | Should -Be $false
        }
        
        It "Should have CertificateCount of 0" {
            $script:Result.CertificateCount | Should -Be 0
        }
        
        It "Should have empty certificates array" {
            $script:Result.Certificates.Count | Should -Be 0
        }
    }
    
    Context "User with null certificates" {
        
        BeforeAll {
            $script:Result = Get-UserStrongMapping -accessToken "fake-token" -UserName "user-null-certs"
        }
        
        It "Should return StrongMapping as false" {
            $script:Result.StrongMapping | Should -Be $false
        }
        
        It "Should have CertificateCount of 0" {
            $script:Result.CertificateCount | Should -Be 0
        }
        
        It "Should have empty certificates array" {
            $script:Result.Certificates.Count | Should -Be 0
        }
    }
    
    Context "Non-existent user" {
        
        BeforeAll {
            $script:Result = Get-UserStrongMapping -accessToken "fake-token" -UserName "nonexistent-user"
        }
        
        It "Should return StrongMapping as false" {
            $script:Result.StrongMapping | Should -Be $false
        }
        
        It "Should preserve UserName" {
            $script:Result.UserName | Should -Be "nonexistent-user"
        }
        
        It "Should have empty DisplayName" {
            $script:Result.DisplayName | Should -Be ""
        }
        
        It "Should have empty UserId" {
            $script:Result.UserId | Should -Be ""
        }
    }
    
    Context "Return object structure" {
        
        BeforeAll {
            $script:Result = Get-UserStrongMapping -accessToken "fake-token" -UserName "test-user"
        }
        
        It "Should have property: StrongMapping" {
            $script:Result.ContainsKey('StrongMapping') | Should -Be $true
        }
        
        It "Should have property: UserName" {
            $script:Result.ContainsKey('UserName') | Should -Be $true
        }
        
        It "Should have property: DisplayName" {
            $script:Result.ContainsKey('DisplayName') | Should -Be $true
        }
        
        It "Should have property: UserId" {
            $script:Result.ContainsKey('UserId') | Should -Be $true
        }
        
        It "Should have property: Certificates" {
            $script:Result.ContainsKey('Certificates') | Should -Be $true
        }
        
        It "Should have property: CertificateCount" {
            $script:Result.ContainsKey('CertificateCount') | Should -Be $true
        }
        
        It "StrongMapping should be boolean" {
            $script:Result.StrongMapping -is [bool] | Should -Be $true
        }
        
        It "Certificates should be array" {
            $script:Result.Certificates -is [array] | Should -Be $true
        }
        
        It "CertificateCount should be integer" {
            $script:Result.CertificateCount -is [int] | Should -Be $true
        }
    }
}
