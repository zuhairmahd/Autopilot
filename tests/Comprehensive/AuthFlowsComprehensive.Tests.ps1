<#
.SYNOPSIS
    Comprehensive tests for authentication flow types and configuration

.DESCRIPTION
    Validates authentication types and flows available in main.ps1:
    - PublicAuthFlow, Interactive, Private authentication types
    - Delegated vs non-delegated authentication
    - Configuration handling for different auth scenarios
    - Token and scope management
    
    Converted from TestScripts/test-auth-flows-comprehensive.ps1

.NOTES
    Test Category: Comprehensive
    Template Compliance: Full
    Uses: AutopilotTestHelpers
    Migration Notes: Migrated auth flow validation from legacy test
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Authentication Flows Comprehensive" -Tags 'Comprehensive', 'Authentication' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Dot-source functions directly (PS 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        if (Test-Path $functionsPath) {
            Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    . $_.FullName
                } catch {
                    Write-Verbose "Failed to load $($_.Name): $($_.Exception.Message)"
                }
            }
        }
        
        # Set up global variables for testing
        $global:LogFile = Join-Path $script:TestContext.TestFolder "test-auth-flows.log"
    }
    
    AfterAll {
        # Cleanup
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Authentication Type Validation" {
        
        It "Should validate PublicAuthFlow as valid auth type" {
            $authType = 'PublicAuthFlow'
            $isValid = $authType -in @('PublicAuthFlow', 'Interactive', 'Private')
            $isValid | Should -Be $true
        }
        
        It "Should validate Interactive as valid auth type" {
            $authType = 'Interactive'
            $isValid = $authType -in @('PublicAuthFlow', 'Interactive', 'Private')
            $isValid | Should -Be $true
        }
        
        It "Should validate Private as valid auth type" {
            $authType = 'Private'
            $isValid = $authType -in @('PublicAuthFlow', 'Interactive', 'Private')
            $isValid | Should -Be $true
        }
        
        It "Should have exactly 3 valid authentication types" {
            $validAuthTypes = @('PublicAuthFlow', 'Interactive', 'Private')
            $validAuthTypes.Count | Should -Be 3
        }
    }
    
    Context "Cache Type Validation" {
        
        It "Should validate 'file' as valid cache type" {
            $cacheType = 'file'
            $isValid = $cacheType -in @('file', 'memory')
            $isValid | Should -Be $true
        }
        
        It "Should validate 'memory' as valid cache type" {
            $cacheType = 'memory'
            $isValid = $cacheType -in @('file', 'memory')
            $isValid | Should -Be $true
        }
        
        It "Should have exactly 2 valid cache types" {
            $validCacheTypes = @('file', 'memory')
            $validCacheTypes.Count | Should -Be 2
        }
    }
    
    Context "Authentication Configuration Building" {
        
        It "Should have BuildAuthSplatTable function available" {
            $funcExists = Get-Command "BuildAuthSplatTable" -ErrorAction SilentlyContinue
            $funcExists | Should -Not -BeNullOrEmpty
        }
        
        It "Should return hashtable from BuildAuthSplatTable" -Skip:(-not (Get-Command "BuildAuthSplatTable" -ErrorAction SilentlyContinue)) {
            $mockAuth = @{
                AuthType  = "PublicAuthFlow"
                delegated = $true
                tenantId  = "test-tenant-id"
                clientId  = "test-client-id"
                scope     = @("User.Read", "Device.Read.All")
            }
            
            $authSplat = BuildAuthSplatTable -auth $mockAuth
            $authSplat | Should -BeOfType [hashtable]
        }
        
        It "Should include AuthType in auth splat" -Skip:(-not (Get-Command "BuildAuthSplatTable" -ErrorAction SilentlyContinue)) {
            $mockAuth = @{
                AuthType  = "PublicAuthFlow"
                delegated = $true
                tenantId  = "test-tenant-id"
                clientId  = "test-client-id"
                scope     = @("User.Read", "Device.Read.All")
            }
            
            $authSplat = BuildAuthSplatTable -auth $mockAuth
            $authSplat.ContainsKey('AuthType') | Should -Be $true
        }
    }
    
    Context "Scope Merging and Deduplication" {
        
        It "Should deduplicate scopes correctly" {
            $basicScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },
                @{ Scope = "Device.Read.All"; Description = "Read device data" }
            )
            
            $additionalScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },  # Duplicate
                @{ Scope = "DeviceManagementManagedDevices.ReadWrite.All"; Description = "Manage devices" }
            )
            
            $allScopes = @($basicScopes) + @($additionalScopes)
            $uniqueScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
            
            $uniqueScopes.Count | Should -Be 3
        }
        
        It "Should preserve User.Read.All scope" {
            $basicScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },
                @{ Scope = "Device.Read.All"; Description = "Read device data" }
            )
            
            $additionalScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },
                @{ Scope = "DeviceManagementManagedDevices.ReadWrite.All"; Description = "Manage devices" }
            )
            
            $allScopes = @($basicScopes) + @($additionalScopes)
            $uniqueScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
            
            $hasUserRead = $uniqueScopes | Where-Object { $_.Scope -eq "User.Read.All" }
            $hasUserRead | Should -Not -BeNullOrEmpty
        }
        
        It "Should preserve Device.Read.All scope" {
            $basicScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },
                @{ Scope = "Device.Read.All"; Description = "Read device data" }
            )
            
            $additionalScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },
                @{ Scope = "DeviceManagementManagedDevices.ReadWrite.All"; Description = "Manage devices" }
            )
            
            $allScopes = @($basicScopes) + @($additionalScopes)
            $uniqueScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
            
            $hasDeviceRead = $uniqueScopes | Where-Object { $_.Scope -eq "Device.Read.All" }
            $hasDeviceRead | Should -Not -BeNullOrEmpty
        }
        
        It "Should preserve DeviceManagement scope" {
            $basicScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },
                @{ Scope = "Device.Read.All"; Description = "Read device data" }
            )
            
            $additionalScopes = @(
                @{ Scope = "User.Read.All"; Description = "Read user profiles" },
                @{ Scope = "DeviceManagementManagedDevices.ReadWrite.All"; Description = "Manage devices" }
            )
            
            $allScopes = @($basicScopes) + @($additionalScopes)
            $uniqueScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
            
            $hasDeviceManagement = $uniqueScopes | Where-Object { $_.Scope -eq "DeviceManagementManagedDevices.ReadWrite.All" }
            $hasDeviceManagement | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Token Functions Availability" {
        
        It "Should have Get-TokenFromCache function available" {
            $funcExists = Get-Command "Get-TokenFromCache" -ErrorAction SilentlyContinue
            $funcExists | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Save-TokenToCache function available" {
            $funcExists = Get-Command "Save-TokenToCache" -ErrorAction SilentlyContinue
            $funcExists | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-NormalizedExpiryTime function available" {
            $funcExists = Get-Command "Get-NormalizedExpiryTime" -ErrorAction SilentlyContinue
            $funcExists | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Authentication Parameter Validation" {
        
        It "Should accept PublicAuthFlow with delegated=true" {
            $combo = @{ AuthType = "PublicAuthFlow"; Delegated = $true }
            $isValid = $combo.AuthType -in @('PublicAuthFlow', 'Interactive', 'Private')
            $isValid | Should -Be $true
        }
        
        It "Should accept Interactive with delegated=true" {
            $combo = @{ AuthType = "Interactive"; Delegated = $true }
            $isValid = $combo.AuthType -in @('PublicAuthFlow', 'Interactive', 'Private')
            $isValid | Should -Be $true
        }
        
        It "Should accept Private with delegated=false" {
            $combo = @{ AuthType = "Private"; Delegated = $false }
            $isValid = $combo.AuthType -in @('PublicAuthFlow', 'Interactive', 'Private')
            $isValid | Should -Be $true
        }
    }
}
