<#
.SYNOPSIS
    Get-UserStrongMapping function tests
.DESCRIPTION
    Tests the Get-UserStrongMapping function with various scenarios
    Converted from TestScripts/test-get-user-strong-mapping-simple.ps1
#>

Describe "Get-UserStrongMapping Function" -Tags 'Unit', 'User', 'StrongMapping' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Setup global log file
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-user-strong-mapping.log"
        
        # Create global CallGraphApi mock function
        function global:CallGraphApi {
            param($accessToken, $ResourcePath, $ExtraParameters)
            
            switch -Wildcard ($ResourcePath) {
                "*user-with-certs*" {
                    return @{
                        id                = "user123"
                        displayName       = "Test User With Certs"
                        userPrincipalName = "user-with-certs@test.com"
                        authorizationInfo = @{
                            certificateUserIds = @(
                                "C=US,O=Entrust,OU=Certification Authorities,OU=Entrust Managed Services SSP CA",
                                "C=US,O=Microsoft,OU=Microsoft IT,CN=Microsoft IT TLS CA 5"
                            )
                        }
                    }
                }
                "*user-no-certs*" {
                    return @{
                        id                = "user456"
                        displayName       = "Test User No Certs"
                        userPrincipalName = "user-no-certs@test.com"
                        authorizationInfo = @{
                            certificateUserIds = @()
                        }
                    }
                }
                "*user-null-certs*" {
                    return @{
                        id                = "user789"
                        displayName       = "Test User Null Certs"
                        userPrincipalName = "user-null-certs@test.com"
                        authorizationInfo = @{
                            certificateUserIds = $null
                        }
                    }
                }
                "*nonexistent-user*" {
                    return $null
                }
                default {
                    return @{
                        id                = "defaultuser"
                        displayName       = "Default Test User"
                        userPrincipalName = "default@test.com"
                        authorizationInfo = @{
                            certificateUserIds = @("C=US,O=Test,CN=Test Cert")
                        }
                    }
                }
            }
        }
        
        # Create global Write-Log mock function
        function global:Write-Log { 
            param($LogFile, $Module, $Message, $LogLevel) 
        }
        
        # Load the specific function being tested
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-UserStrongMapping.ps1")
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
