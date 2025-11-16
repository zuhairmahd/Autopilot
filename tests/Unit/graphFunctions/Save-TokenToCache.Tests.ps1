<#
.SYNOPSIS
    Unit tests for Save-TokenToCache function

.DESCRIPTION
    Tests token cache save operations including:
    - Proper extraction of delegated scopes (scp claim)
    - Proper extraction of application scopes (roles claim)
    - Memory cache storage
    - File cache storage
    
.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers for temp environment
    Related Issue: Scope validation cache bug (scp vs roles extraction)
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Save-TokenToCache" -Tags 'Unit', 'GraphFunctions', 'TokenCaching' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
        . "$script:RepoRoot/functions/graphFunctions/DecodeJwtToken.ps1"
        
        # Load function under test
        . "$script:RepoRoot/functions/graphFunctions/Save-TokenToCache.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Mock Write-Log globally
        Mock Write-Log {}
        
        # Initialize script variables
        $script:LogFile = Join-Path $script:TestContext.TestFolder "test.log"
        $global:maxJSONDepth = 20
        
        # Create test tokens with different auth types
        
        # Delegated token (has scp claim)
        $delegatedPayload = @{
            aud = "00000003-0000-0000-c000-000000000000"
            iss = "https://sts.windows.net/tenant-id/"
            iat = 1700000000
            nbf = 1700000000
            exp = 1700003600
            scp = "User.Read Mail.Send Device.ReadWrite.All DeviceManagementApps.Read.All"
            sub = "subject-id"
            tid = "tenant-id"
            oid = "object-id"
            preferred_username = "user@domain.com"
        } | ConvertTo-Json -Compress
        
        $delegatedBytes = [System.Text.Encoding]::UTF8.GetBytes($delegatedPayload)
        $delegatedBase64 = [Convert]::ToBase64String($delegatedBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        $script:DelegatedToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.$delegatedBase64.sig"
        
        # Application token (has roles claim)
        $appPayload = @{
            aud = "00000003-0000-0000-c000-000000000000"
            iss = "https://sts.windows.net/tenant-id/"
            iat = 1700000000
            nbf = 1700000000
            exp = 1700003600
            roles = @("Application.ReadWrite.All", "Directory.ReadWrite.All", "Device.ReadWrite.All")
            sub = "app-id"
            tid = "tenant-id"
            oid = "object-id"
        } | ConvertTo-Json -Compress
        
        $appBytes = [System.Text.Encoding]::UTF8.GetBytes($appPayload)
        $appBase64 = [Convert]::ToBase64String($appBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        $script:ApplicationToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.$appBase64.sig"
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "When saving delegated auth token to memory cache" {
        BeforeEach {
            # Clear global memory cache
            if (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue) {
                Remove-Variable -Name 'MemoryCache' -Scope Global -Force
            }
        }
        
        It "Should extract and save delegated scopes (scp claim)" {
            $cachedToken = @{
                access_token = $script:DelegatedToken
                token_type = "Bearer"
                expires_in = 3600
            }
            
            Save-TokenToCache -cachedToken $cachedToken -cacheType 'memory'
            
            $Global:MemoryCache['accessToken'].scope | Should -Not -BeNullOrEmpty
            $Global:MemoryCache['accessToken'].scope.Count | Should -Be 4
            $Global:MemoryCache['accessToken'].scope | Should -Contain "User.Read"
            $Global:MemoryCache['accessToken'].scope | Should -Contain "Mail.Send"
            $Global:MemoryCache['accessToken'].scope | Should -Contain "Device.ReadWrite.All"
            $Global:MemoryCache['accessToken'].scope | Should -Contain "DeviceManagementApps.Read.All"
        }
        
        It "Should preserve original token properties" {
            $cachedToken = @{
                access_token = $script:DelegatedToken
                token_type = "Bearer"
                expires_in = 3600
            }
            
            Save-TokenToCache -cachedToken $cachedToken -cacheType 'memory'
            
            $Global:MemoryCache['accessToken'].access_token | Should -Be $script:DelegatedToken
            $Global:MemoryCache['accessToken'].token_type | Should -Be "Bearer"
            $Global:MemoryCache['accessToken'].expires_in | Should -Be 3600
        }
        
        It "Should handle token with existing scope property" {
            $cachedToken = @{
                access_token = $script:DelegatedToken
                token_type = "Bearer"
                expires_in = 3600
                scope = @("OldScope1", "OldScope2")
            }
            
            Save-TokenToCache -cachedToken $cachedToken -cacheType 'memory'
            
            # Should replace old scopes with extracted scopes
            $Global:MemoryCache['accessToken'].scope | Should -Not -Contain "OldScope1"
            $Global:MemoryCache['accessToken'].scope | Should -Contain "User.Read"
        }
    }
    
    Context "When saving application auth token to memory cache" {
        BeforeEach {
            if (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue) {
                Remove-Variable -Name 'MemoryCache' -Scope Global -Force
            }
        }
        
        It "Should extract and save application scopes (roles claim)" {
            $cachedToken = @{
                access_token = $script:ApplicationToken
                token_type = "Bearer"
                expires_in = 3600
            }
            
            Save-TokenToCache -cachedToken $cachedToken -cacheType 'memory'
            
            $Global:MemoryCache['accessToken'].scope | Should -Not -BeNullOrEmpty
            $Global:MemoryCache['accessToken'].scope.Count | Should -Be 3
            $Global:MemoryCache['accessToken'].scope | Should -Contain "Application.ReadWrite.All"
            $Global:MemoryCache['accessToken'].scope | Should -Contain "Directory.ReadWrite.All"
            $Global:MemoryCache['accessToken'].scope | Should -Contain "Device.ReadWrite.All"
        }
    }
    
    Context "When saving token to file cache" {
        BeforeEach {
            $script:TestCacheFolder = Join-Path $script:TestContext.TestFolder "cache"
            $script:TestCacheFile = Join-Path $script:TestCacheFolder "token.json"
        }
        
        AfterEach {
            if (Test-Path $script:TestCacheFolder) {
                Remove-Item $script:TestCacheFolder -Recurse -Force
            }
        }
        
        It "Should create cache folder if it doesn't exist" {
            $cachedToken = @{
                access_token = $script:DelegatedToken
                token_type = "Bearer"
                expires_in = 3600
            }
            
            Save-TokenToCache -cachedToken $cachedToken -cacheType 'file' -cacheTokenFile $script:TestCacheFile -cacheFolder $script:TestCacheFolder
            
            Test-Path $script:TestCacheFolder | Should -Be $true
        }
        
        It "Should save token with extracted scopes to file" {
            $cachedToken = @{
                access_token = $script:DelegatedToken
                token_type = "Bearer"
                expires_in = 3600
            }
            
            Save-TokenToCache -cachedToken $cachedToken -cacheType 'file' -cacheTokenFile $script:TestCacheFile -cacheFolder $script:TestCacheFolder
            
            Test-Path $script:TestCacheFile | Should -Be $true
            
            $savedToken = Get-Content $script:TestCacheFile | ConvertFrom-Json
            $savedToken.scope | Should -Not -BeNullOrEmpty
            $savedToken.scope.Count | Should -Be 4
            $savedToken.scope | Should -Contain "User.Read"
        }
    }
    
    Context "When handling tokens without scope claims" {
        BeforeEach {
            if (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue) {
                Remove-Variable -Name 'MemoryCache' -Scope Global -Force
            }
        }
        
        It "Should warn when no scope claims are present" {
            # Create token without scp or roles
            $noScopePayload = @{
                aud = "00000003-0000-0000-c000-000000000000"
                sub = "test"
                exp = 1700003600
            } | ConvertTo-Json -Compress
            
            $noScopeBytes = [System.Text.Encoding]::UTF8.GetBytes($noScopePayload)
            $noScopeBase64 = [Convert]::ToBase64String($noScopeBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
            $noScopeToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.$noScopeBase64.sig"
            
            $cachedToken = @{
                access_token = $noScopeToken
                token_type = "Bearer"
            }
            
            Mock Write-Warning {}
            
            Save-TokenToCache -cachedToken $cachedToken -cacheType 'memory'
            
            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -match "No scope information found"
            }
        }
        
        It "Should handle token without scope claims gracefully" {
            # Create token without scp or roles
            $noScopePayload = @{
                aud = "00000003-0000-0000-c000-000000000000"
                sub = "test"
                exp = 1700003600
            } | ConvertTo-Json -Compress
            
            $noScopeBytes = [System.Text.Encoding]::UTF8.GetBytes($noScopePayload)
            $noScopeBase64 = [Convert]::ToBase64String($noScopeBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
            $noScopeToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.$noScopeBase64.sig"
            
            $cachedToken = @{
                access_token = $noScopeToken
                token_type = "Bearer"
            }
            
            Mock Write-Warning {}
            
            # Should not throw, even with no scope claims
            { Save-TokenToCache -cachedToken $cachedToken -cacheType 'memory' } | Should -Not -Throw
            
            # Token should still be saved
            $Global:MemoryCache['accessToken'].access_token | Should -Be $noScopeToken
        }
    }
}
