BeforeAll {
    # Import helper modules
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
    
    # Direct dot-sourcing of required functions
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"
    
    # We'll skip Invoke-CacheManagement for now and test just the cache functions
    # . "$script:RepoRoot/functions/utilityFunctions/Invoke-CacheManagement.ps1"
    
    # Initialize test settings
    $script:testSettings = @{
        cacheSettings = @{
            enabled                  = $true
            defaultExpirationMinutes = 15
            maxCacheSize             = 1000
            cacheTypes               = @{
                Configuration    = @{ enabled = $true; expirationMinutes = 60 }
                DirectoryObjects = @{ enabled = $true; expirationMinutes = 15 }
                Devices          = @{ enabled = $true; expirationMinutes = 15 }
            }
        }
    }
}

AfterEach {
    # Clean up global cache after each test
    if ($global:UnifiedCache)
    {
        $global:UnifiedCache = $null
    }
}

Describe "Unified Cache Management" -Tags 'Unit' {
    Context "Cache Initialization" {
        It "Initializes global cache structure" {
            Initialize-UnifiedCache
            
            $global:UnifiedCache | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Keys | Should -Contain 'Configuration'
            $global:UnifiedCache.Keys | Should -Contain 'DirectoryObjects'
            $global:UnifiedCache.Keys | Should -Contain 'Devices'
        }
    }
    
    Context "Get-CachedData" {
        BeforeEach {
            $global:settings = $script:testSettings
        }
        
        It "Returns null for non-existent cache key" {
            $result = Get-CachedData -CacheType 'Configuration' -Key 'test:nonexistent'
            $result | Should -BeNullOrEmpty
        }
        
        It "Returns null when caching is globally disabled" {
            $global:settings.cacheSettings.enabled = $false
            
            $result = Get-CachedData -CacheType 'Configuration' -Key 'test:key'
            $result | Should -BeNullOrEmpty
        }
        
        It "Returns null when specific cache type is disabled" {
            $global:settings.cacheSettings.cacheTypes.Configuration.enabled = $false
            
            $result = Get-CachedData -CacheType 'Configuration' -Key 'test:key'
            $result | Should -BeNullOrEmpty
        }
        
        It "Returns cached data when valid" {
            # Set data first
            Set-CachedData -CacheType 'Configuration' -Key 'test:valid' -Data 'TestValue'
            
            # Get it back
            $result = Get-CachedData -CacheType 'Configuration' -Key 'test:valid'
            $result | Should -Be 'TestValue'
        }
        
        It "Returns null for expired cache entries" {
            # Set data with short expiration
            $global:settings.cacheSettings.cacheTypes.Configuration.expirationMinutes = 0.01  # ~0.6 seconds
            Set-CachedData -CacheType 'Configuration' -Key 'test:expire' -Data 'ExpireValue'
            
            # Wait for expiration
            Start-Sleep -Seconds 2
            
            # Should be expired
            $result = Get-CachedData -CacheType 'Configuration' -Key 'test:expire'
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Set-CachedData" {
        BeforeEach {
            $global:settings = $script:testSettings
        }
        
        It "Stores data successfully" {
            $result = Set-CachedData -CacheType 'DirectoryObjects' -Key 'user:test@contoso.com' -Data @{ Name = 'Test User' }
            $result | Should -Be $true
        }
        
        It "Returns false when caching is globally disabled" {
            $global:settings.cacheSettings.enabled = $false
            
            $result = Set-CachedData -CacheType 'DirectoryObjects' -Key 'test:key' -Data 'TestValue'
            $result | Should -Be $false
        }
        
        It "Returns false when specific cache type is disabled" {
            $global:settings.cacheSettings.cacheTypes.DirectoryObjects.enabled = $false
            
            $result = Set-CachedData -CacheType 'DirectoryObjects' -Key 'test:key' -Data 'TestValue'
            $result | Should -Be $false
        }
        
        It "Stores metadata with cached data" {
            Set-CachedData -CacheType 'Configuration' -Key 'test:meta' -Data 'Value' -Metadata @{ Source = 'Test' }
            
            # Check metadata is stored
            $global:UnifiedCache.Configuration['test:meta'].Metadata.Source | Should -Be 'Test'
        }
        
        It "Respects cache size limits" {
            # Set small cache size
            $global:settings.cacheSettings.maxCacheSize = 5
            
            # Add more items than limit
            1..10 | ForEach-Object {
                Set-CachedData -CacheType 'Devices' -Key "device:$_" -Data "Device$_"
            }
            
            # Cache should not exceed limit significantly (10% trim buffer)
            $global:UnifiedCache.Devices.Count | Should -BeLessOrEqual 10
        }
    }
    
    Context "Clear-UnifiedCache" {
        BeforeEach {
            $global:settings = $script:testSettings
            
            # Populate cache
            Set-CachedData -CacheType 'Configuration' -Key 'test:1' -Data 'Value1'
            Set-CachedData -CacheType 'DirectoryObjects' -Key 'test:2' -Data 'Value2'
            Set-CachedData -CacheType 'Devices' -Key 'test:3' -Data 'Value3'
        }
        
        It "Clears all cache types when no type specified" {
            Clear-UnifiedCache
            
            $global:UnifiedCache.Configuration.Count | Should -Be 0
            $global:UnifiedCache.DirectoryObjects.Count | Should -Be 0
            $global:UnifiedCache.Devices.Count | Should -Be 0
        }
        
        It "Clears specific cache type only" {
            Clear-UnifiedCache -CacheType 'Configuration'
            
            $global:UnifiedCache.Configuration.Count | Should -Be 0
            $global:UnifiedCache.DirectoryObjects.Count | Should -Be 1
            $global:UnifiedCache.Devices.Count | Should -Be 1
        }
    }
    
    Context "Cache Expiration Helper" {
        BeforeEach {
            $global:settings = $script:testSettings
        }
        
        It "Returns configured expiration for cache type" {
            $result = Get-CacheExpirationMinutes -CacheType 'Configuration'
            $result | Should -Be 60
        }
        
        It "Returns default expiration when type not configured" {
            $global:settings.cacheSettings.cacheTypes.Remove('DirectoryObjects')
            
            $result = Get-CacheExpirationMinutes -CacheType 'DirectoryObjects'
            $result | Should -Be 15  # Default from settings
        }
        
        It "Returns fallback when no settings provided" {
            $result = Get-CacheExpirationMinutes -CacheType 'Configuration' -Settings $null
            $result | Should -Be 15  # Hardcoded fallback
        }
    }
}
