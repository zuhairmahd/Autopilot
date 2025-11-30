<#
.SYNOPSIS
    Integration tests for cache management system

.DESCRIPTION
    Tests Invoke-CacheManagement function to verify end-to-end cache workflows:
    - Cache initialization and configuration
    - Data storage and retrieval across cache types
    - Cache statistics and monitoring
    - Cache clearing (all types and specific types)
    - Cache expiration handling
    
    This complements the unit tests in Get-CachedData.Tests.ps1 by testing
    the higher-level Invoke-CacheManagement wrapper and cross-cache interactions.

.NOTES
    Unit tests for cache primitives exist in tests/Unit/Get-CachedData.Tests.ps1
    This integration test focuses on the Invoke-CacheManagement orchestration layer.
#>

BeforeAll {
    # Import helper modules
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
    
    # Direct dot-sourcing of required functions
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/Invoke-CacheManagement.ps1"
    
    # Set up log file for Write-Log
    $global:LogFile = Join-Path $TestDrive "cache-test.log"
    
    # Initialize test cache settings
    $script:testCacheSettings = @{
        enabled                  = $true
        defaultExpirationMinutes = 15
        maxCacheSize             = 1000
        cacheTypes               = @{
            Configuration    = @{ enabled = $true; expirationMinutes = 60 }
            DirectoryObjects = @{ enabled = $true; expirationMinutes = 15 }
            Devices          = @{ enabled = $true; expirationMinutes = 15 }
        }
    }
    
    # Set global cache settings for all tests
    $global:cacheSettings = $script:testCacheSettings
}

Describe "Cache Management Integration" -Tags 'Integration', 'CacheManagement' {
    
    Context "Cache Initialization and Configuration" {
        BeforeEach {
            # Clear all caches before each test
            Invoke-CacheManagement -Action Clear | Out-Null
            $global:cacheSettings = $script:testCacheSettings.PSObject.Copy()
        }
        
        It "Should initialize unified cache on first access" {
            # Clear to reset
            $global:UnifiedCache = $null
            
            # First Set operation should initialize cache
            $result = Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'test:init' -Data 'InitValue'
            
            $global:UnifiedCache | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Keys | Should -Contain 'Configuration'
            $result | Should -Be $true
        }
        
        It "Should list all available cache types" {
            $result = Invoke-CacheManagement -Action ListCaches
            
            $result | Should -Not -BeNullOrEmpty
            $result.UnifiedCaches | Should -Contain 'Configuration'
            $result.UnifiedCaches | Should -Contain 'DirectoryObjects'
            $result.UnifiedCaches | Should -Contain 'Devices'
        }
    }
    
    Context "Data Storage and Retrieval" {
        BeforeEach {
            Invoke-CacheManagement -Action Clear | Out-Null
            $global:cacheSettings = $script:testCacheSettings.PSObject.Copy()
        }
        
        It "Should store and retrieve data from Configuration cache" {
            # Store
            $setResult = Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'app:config1' -Data @{ Setting = 'Value1' }
            $setResult | Should -Be $true
            
            # Retrieve
            $getData = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'app:config1'
            $getData.Setting | Should -Be 'Value1'
        }
        
        It "Should store and retrieve data from DirectoryObjects cache" {
            $testUser = @{
                id          = 'user-123'
                displayName = 'Test User'
                mail        = 'test@contoso.com'
            }
            
            # Store
            $setResult = Invoke-CacheManagement -Action Set -CacheType 'DirectoryObjects' -Key 'user:test@contoso.com' -Data $testUser
            $setResult | Should -Be $true
            
            # Retrieve
            $getData = Invoke-CacheManagement -Action Get -CacheType 'DirectoryObjects' -Key 'user:test@contoso.com'
            $getData.displayName | Should -Be 'Test User'
            $getData.mail | Should -Be 'test@contoso.com'
        }
        
        It "Should store and retrieve data from Devices cache" {
            $testDevice = @{
                id              = 'device-456'
                deviceName      = 'TEST-PC-001'
                enrollmentState = 'Enrolled'
            }
            
            # Store
            $setResult = Invoke-CacheManagement -Action Set -CacheType 'Devices' -Key 'device:device-456' -Data $testDevice
            $setResult | Should -Be $true
            
            # Retrieve
            $getData = Invoke-CacheManagement -Action Get -CacheType 'Devices' -Key 'device:device-456'
            $getData.deviceName | Should -Be 'TEST-PC-001'
            $getData.enrollmentState | Should -Be 'Enrolled'
        }
        
        It "Should store metadata with cached data" {
            $metadata = @{
                Source    = 'GraphAPI'
                RequestId = 'req-123'
                Timestamp = Get-Date
            }
            
            # Store with metadata
            $setResult = Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'test:meta' -Data 'TestValue' -Metadata $metadata
            $setResult | Should -Be $true
            
            # Check metadata is stored (access cache directly since Get action may not return metadata)
            $global:UnifiedCache.Configuration['test:meta'].Metadata.Source | Should -Be 'GraphAPI'
            $global:UnifiedCache.Configuration['test:meta'].Metadata.RequestId | Should -Be 'req-123'
        }
        
        It "Should handle non-existent keys gracefully" {
            $result = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'nonexistent:key'
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Cache Statistics and Monitoring" {
        BeforeEach {
            Invoke-CacheManagement -Action Clear | Out-Null
            $global:cacheSettings = $script:testCacheSettings.PSObject.Copy()
            
            # Populate cache with test data
            Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'stat:1' -Data 'Value1' | Out-Null
            Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'stat:2' -Data 'Value2' | Out-Null
            Invoke-CacheManagement -Action Set -CacheType 'DirectoryObjects' -Key 'stat:3' -Data 'Value3' | Out-Null
            Invoke-CacheManagement -Action Set -CacheType 'Devices' -Key 'stat:4' -Data 'Value4' | Out-Null
        }
        
        It "Should return cache statistics" {
            $stats = Invoke-CacheManagement -Action GetStatistics
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.UnifiedCache | Should -Not -BeNullOrEmpty
            $stats.UnifiedCache.Configuration.EntryCount | Should -Be 2
            $stats.UnifiedCache.DirectoryObjects.EntryCount | Should -Be 1
            $stats.UnifiedCache.Devices.EntryCount | Should -Be 1
        }
        
        It "Should calculate total cache entries" {
            $stats = Invoke-CacheManagement -Action GetStatistics
            
            # Sum all entries
            $totalEntries = $stats.UnifiedCache.Configuration.EntryCount + 
            $stats.UnifiedCache.DirectoryObjects.EntryCount + 
            $stats.UnifiedCache.Devices.EntryCount
            
            $totalEntries | Should -Be 4
        }
        
        It "Should support monitoring with ShowDetails" {
            $result = Invoke-CacheManagement -Action Monitor -ShowDetails
            
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'Success'
        }
    }
    
    Context "Cache Clearing" {
        BeforeEach {
            Invoke-CacheManagement -Action Clear | Out-Null
            $global:cacheSettings = $script:testCacheSettings.PSObject.Copy()
            
            # Populate all cache types
            Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'clear:1' -Data 'Value1' | Out-Null
            Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'clear:2' -Data 'Value2' | Out-Null
            Invoke-CacheManagement -Action Set -CacheType 'DirectoryObjects' -Key 'clear:3' -Data 'Value3' | Out-Null
            Invoke-CacheManagement -Action Set -CacheType 'Devices' -Key 'clear:4' -Data 'Value4' | Out-Null
        }
        
        It "Should clear all caches with Clear action" {
            # Verify data exists
            $beforeStats = Invoke-CacheManagement -Action GetStatistics
            $beforeStats.UnifiedCache.Configuration.EntryCount | Should -BeGreaterThan 0
            
            # Clear all
            $result = Invoke-CacheManagement -Action Clear
            $result.Status | Should -Be 'Success'
            
            # Verify all caches empty
            $afterStats = Invoke-CacheManagement -Action GetStatistics
            $afterStats.UnifiedCache.Configuration.EntryCount | Should -Be 0
            $afterStats.UnifiedCache.DirectoryObjects.EntryCount | Should -Be 0
            $afterStats.UnifiedCache.Devices.EntryCount | Should -Be 0
        }
        
        It "Should clear specific cache type only" {
            # Clear Configuration cache only
            $result = Invoke-CacheManagement -Action ClearSpecific -CacheType 'Configuration'
            $result.Status | Should -Be 'Success'
            
            # Verify Configuration cleared but others remain
            $stats = Invoke-CacheManagement -Action GetStatistics
            $stats.UnifiedCache.Configuration.EntryCount | Should -Be 0
            $stats.UnifiedCache.DirectoryObjects.EntryCount | Should -Be 1
            $stats.UnifiedCache.Devices.EntryCount | Should -Be 1
        }
        
        It "Should clear DirectoryObjects cache independently" {
            # Clear DirectoryObjects cache only
            $result = Invoke-CacheManagement -Action ClearSpecific -CacheType 'DirectoryObjects'
            $result.Status | Should -Be 'Success'
            
            # Verify DirectoryObjects cleared but others remain
            $stats = Invoke-CacheManagement -Action GetStatistics
            $stats.UnifiedCache.Configuration.EntryCount | Should -Be 2
            $stats.UnifiedCache.DirectoryObjects.EntryCount | Should -Be 0
            $stats.UnifiedCache.Devices.EntryCount | Should -Be 1
        }
        
        It "Should clear Devices cache independently" {
            # Clear Devices cache only
            $result = Invoke-CacheManagement -Action ClearSpecific -CacheType 'Devices'
            $result.Status | Should -Be 'Success'
            
            # Verify Devices cleared but others remain
            $stats = Invoke-CacheManagement -Action GetStatistics
            $stats.UnifiedCache.Configuration.EntryCount | Should -Be 2
            $stats.UnifiedCache.DirectoryObjects.EntryCount | Should -Be 1
            $stats.UnifiedCache.Devices.EntryCount | Should -Be 0
        }
    }
    
    Context "Cache Expiration Handling" {
        BeforeEach {
            Invoke-CacheManagement -Action Clear | Out-Null
            
            # Set short expiration for testing
            $global:cacheSettings = @{
                enabled                  = $true
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = @{
                    Configuration    = @{ enabled = $true; expirationMinutes = 0.01 }  # ~0.6 seconds
                    DirectoryObjects = @{ enabled = $true; expirationMinutes = 15 }
                    Devices          = @{ enabled = $true; expirationMinutes = 15 }
                }
            }
        }
        
        It "Should return null for expired cache entries" {
            # Store data with short expiration
            Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'expire:test' -Data 'ExpireValue' | Out-Null
            
            # Verify data exists immediately
            $immediate = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'expire:test'
            $immediate | Should -Be 'ExpireValue'
            
            # Wait for expiration
            Start-Sleep -Seconds 2
            
            # Should be expired
            $expired = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'expire:test'
            $expired | Should -BeNullOrEmpty
        }
        
        It "Should not return expired data even when present in cache structure" {
            # Store and let expire
            Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'expire:test2' -Data 'Value' | Out-Null
            Start-Sleep -Seconds 2
            
            # Try to get expired data
            $result = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'expire:test2'
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Cache Disabled Scenarios" {
        It "Should not store data when caching is globally disabled" {
            $global:cacheSettings = @{
                enabled                  = $false
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = @{
                    Configuration = @{ enabled = $true; expirationMinutes = 60 }
                }
            }
            
            # Try to store
            $result = Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'disabled:global' -Data 'Value'
            $result | Should -Be $false
            
            # Verify not stored
            $getData = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'disabled:global'
            $getData | Should -BeNullOrEmpty
        }
        
        It "Should not store data when specific cache type is disabled" {
            $global:cacheSettings = @{
                enabled                  = $true
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = @{
                    Configuration = @{ enabled = $false; expirationMinutes = 60 }
                }
            }
            
            # Try to store
            $result = Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'disabled:type' -Data 'Value'
            $result | Should -Be $false
            
            # Verify not stored
            $getData = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'disabled:type'
            $getData | Should -BeNullOrEmpty
        }
    }
    
    Context "Cross-Cache Integration" {
        BeforeEach {
            Invoke-CacheManagement -Action Clear | Out-Null
            $global:cacheSettings = $script:testCacheSettings.PSObject.Copy()
        }
        
        It "Should handle concurrent access to multiple cache types" {
            # Store data in all cache types
            $results = @(
                (Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'cross:1' -Data 'ConfigValue'),
                (Invoke-CacheManagement -Action Set -CacheType 'DirectoryObjects' -Key 'cross:2' -Data 'DirectoryValue'),
                (Invoke-CacheManagement -Action Set -CacheType 'Devices' -Key 'cross:3' -Data 'DeviceValue')
            )
            
            $results | Should -Not -Contain $false
            
            # Retrieve from all cache types
            $config = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'cross:1'
            $directory = Invoke-CacheManagement -Action Get -CacheType 'DirectoryObjects' -Key 'cross:2'
            $device = Invoke-CacheManagement -Action Get -CacheType 'Devices' -Key 'cross:3'
            
            $config | Should -Be 'ConfigValue'
            $directory | Should -Be 'DirectoryValue'
            $device | Should -Be 'DeviceValue'
        }
        
        It "Should maintain cache isolation between types" {
            # Store same key in different cache types
            Invoke-CacheManagement -Action Set -CacheType 'Configuration' -Key 'isolation:test' -Data 'ConfigData' | Out-Null
            Invoke-CacheManagement -Action Set -CacheType 'DirectoryObjects' -Key 'isolation:test' -Data 'DirectoryData' | Out-Null
            
            # Retrieve and verify isolation
            $configData = Invoke-CacheManagement -Action Get -CacheType 'Configuration' -Key 'isolation:test'
            $directoryData = Invoke-CacheManagement -Action Get -CacheType 'DirectoryObjects' -Key 'isolation:test'
            
            $configData | Should -Be 'ConfigData'
            $directoryData | Should -Be 'DirectoryData'
        }
    }
}
