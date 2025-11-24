<#
.SYNOPSIS
    Pester tests for Get-CachedDeviceEnrollmentStatus function

.DESCRIPTION
    Tests the unified cache-enabled device enrollment status retrieval covering:
    - Enrollment state caching
    - Cache refresh with -flushCache
    - Error handling
    - Metadata storage
    
.NOTES
    Test Category: Unit
    Dependencies: Get-CachedDeviceEnrollmentStatus, Get-DeviceEnrollmentStatus, Get-CachedData
    Cache Type: Devices
#>

Describe "Get-CachedDeviceEnrollmentStatus Function" -Tags 'Unit', 'Device', 'Enrollment', 'Cache' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Load unified cache functions
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Get-CachedData.ps1")
        
        # Load Write-Log function
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Write-Log.ps1")
        
        # Load Get-DeviceEnrollmentStatus function (dependency)
        . (Join-Path $script:RepoRoot "functions/deviceFunctions/Get-DeviceEnrollmentStatus.ps1")
        
        # Load the function being tested
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Get-CachedDeviceEnrollmentState.ps1")
        
        # Setup test log file
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-deviceenrollment.log"
        
        # Initialize cache settings
        $global:cacheSettings = @{
            enabled                  = $true
            defaultExpirationMinutes = 15
            maxCacheSize             = 1000
            cacheTypes               = @{
                Configuration    = @{ enabled = $true; expirationMinutes = 60 }
                DirectoryObjects = @{ enabled = $true; expirationMinutes = 15 }
                Devices          = @{ enabled = $true; expirationMinutes = 15 }
            }
        }
        
        # Also set $global:settings for function parameter compatibility
        $global:settings = @{
            cacheSettings = $global:cacheSettings
        }
        
        # Test data
        $script:testSerialNumber = "TEST-SERIAL-12345"
        $script:testEnrollmentState = @{
            enrollmentState       = "Enrolled"
            lastContactedDateTime = "2024-10-24T10:00:00Z"
            managementState       = "Managed"
            serialNumber          = $script:testSerialNumber
        }
        $script:mockAccessToken = "mock-access-token-12345"
    }
    
    BeforeEach {
        # Clear cache before each test
        Clear-UnifiedCache
        
        # Setup mock for Get-DeviceEnrollmentStatus
        Mock -CommandName Get-DeviceEnrollmentStatus -MockWith {
            param($serialNumber, $AccessToken, $Settings)
            
            if ($serialNumber -eq $script:testSerialNumber)
            {
                return $script:testEnrollmentState
            }
            
            return $null
        }
    }
    
    Context "Basic Enrollment State Retrieval" {
        
        It "Should fetch enrollment state from API" {
            $result = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            
            $result | Should -Not -BeNullOrEmpty
            $result.enrollmentState | Should -Be "Enrolled"
            $result.serialNumber | Should -Be $testSerialNumber
        }
        
        It "Should return null for non-existent serial number" {
            $result = Get-CachedDeviceEnrollmentStatus -SerialNumber "NONEXISTENT-SERIAL" -AccessToken $mockAccessToken
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Caching Behavior" {
        
        It "Should cache enrollment state after first retrieval" {
            # First call - should hit API
            $result = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            $result | Should -Not -BeNullOrEmpty
            
            # Verify cache contains the data
            $cacheKey = "enrollment:$testSerialNumber"
            $cachedData = Get-CachedData -CacheType 'Devices' -Key $cacheKey -CacheSettings $global:cacheSettings
            
            $cachedData | Should -Not -BeNullOrEmpty
            $cachedData.enrollmentState | Should -Be "Enrolled"
        }
        
        It "Should use cached enrollment state on subsequent calls" {
            # Prime the cache
            $null = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            
            # Remove the API mock to prove it doesn't get called
            Mock -CommandName Get-DeviceEnrollmentStatus -MockWith { 
                throw "API should not be called - data should be cached" 
            }
            
            # Second call - should use cache
            $result = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            
            $result | Should -Not -BeNullOrEmpty
            $result.enrollmentState | Should -Be "Enrolled"
        }
        
        It "Should refresh cache when -flushCache is specified" {
            # Prime the cache with initial data
            $null = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            
            # Mock returns updated enrollment state
            Mock -CommandName Get-DeviceEnrollmentStatus -MockWith {
                return @{
                    enrollmentState       = "Updated"
                    lastContactedDateTime = "2024-10-24T12:00:00Z"
                    managementState       = "Updated-Managed"
                    serialNumber          = $script:testSerialNumber
                }
            }
            
            # Call with flushCache - should bypass cache and get new data
            $result = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken -flushCache
            
            $result | Should -Not -BeNullOrEmpty
            $result.enrollmentState | Should -Be "Updated"
            $result.managementState | Should -Be "Updated-Managed"
        }
        
        It "Should not cache null/empty results" {
            # Call with non-existent serial
            $result = Get-CachedDeviceEnrollmentStatus -SerialNumber "NONEXISTENT" -AccessToken $mockAccessToken
            
            $result | Should -BeNullOrEmpty
            
            # Verify cache does NOT contain entry
            $cacheKey = "enrollment:NONEXISTENT"
            $cachedData = Get-CachedData -CacheType 'Devices' -Key $cacheKey -CacheSettings $global:cacheSettings
            
            $cachedData | Should -BeNullOrEmpty
        }
    }
    
    Context "Cache Metadata" {
        
        It "Should store serial number in cache metadata" {
            # Fetch and cache enrollment state
            $null = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            
            # Access cache entry directly to check metadata
            $cacheKey = "enrollment:$testSerialNumber"
            $cacheEntry = $global:UnifiedCache.Devices[$cacheKey]
            
            $cacheEntry | Should -Not -BeNullOrEmpty
            $cacheEntry.Metadata | Should -Not -BeNullOrEmpty
            $cacheEntry.Metadata.SerialNumber | Should -Be $testSerialNumber
        }
    }
    
    Context "Cache Expiration" {
        
        It "Should respect cache expiration settings" {
            # First call - populate cache
            $result1 = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            $result1 | Should -Not -BeNullOrEmpty
            
            # Manually expire the cache entry by setting old timestamp
            $cacheKey = "enrollment:$testSerialNumber"
            $oldTimestamp = (Get-Date).AddMinutes(-20)  # Older than 15-minute default
            
            # Access internal cache structure to expire entry
            if ($global:UnifiedCache.Devices.ContainsKey($cacheKey))
            {
                $global:UnifiedCache.Devices[$cacheKey].Timestamp = $oldTimestamp
            }
            
            # Mock API call to return updated data
            Mock -CommandName Get-DeviceEnrollmentStatus -MockWith {
                return @{
                    enrollmentState       = "RefreshedAfterExpiration"
                    lastContactedDateTime = "2024-10-24T14:00:00Z"
                    managementState       = "Managed"
                    serialNumber          = $script:testSerialNumber
                }
            }
            
            # Second call - should detect expiration and call API
            $result2 = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
            
            $result2.enrollmentState | Should -Be "RefreshedAfterExpiration"
        }
    }
    
    Context "Multiple Device Caching" {
        
        It "Should cache multiple devices independently" {
            $serial1 = "SERIAL-001"
            $serial2 = "SERIAL-002"
            
            # Mock different enrollment states for different serials
            Mock -CommandName Get-DeviceEnrollmentStatus -MockWith {
                param($serialNumber)
                
                if ($serialNumber -eq $serial1)
                {
                    return @{
                        enrollmentState = "Enrolled"
                        serialNumber    = $serial1
                    }
                }
                elseif ($serialNumber -eq $serial2)
                {
                    return @{
                        enrollmentState = "Pending"
                        serialNumber    = $serial2
                    }
                }
                return $null
            }
            
            # Fetch both
            $result1 = Get-CachedDeviceEnrollmentStatus -SerialNumber $serial1 -AccessToken $mockAccessToken
            $result2 = Get-CachedDeviceEnrollmentStatus -SerialNumber $serial2 -AccessToken $mockAccessToken
            
            # Verify both are cached independently
            $result1.enrollmentState | Should -Be "Enrolled"
            $result2.enrollmentState | Should -Be "Pending"
            
            $cache1 = Get-CachedData -CacheType 'Devices' -Key "enrollment:$serial1" -CacheSettings $global:cacheSettings
            $cache2 = Get-CachedData -CacheType 'Devices' -Key "enrollment:$serial2" -CacheSettings $global:cacheSettings
            
            $cache1.enrollmentState | Should -Be "Enrolled"
            $cache2.enrollmentState | Should -Be "Pending"
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle API errors gracefully" {
            Mock -CommandName Get-DeviceEnrollmentStatus -MockWith {
                throw "API error"
            }
            
            { Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken } |
                Should -Throw
        }
    }
    
    Context "Cache Disabled" {
        
        It "Should work when caching is disabled" {
            # Disable caching
            $disabledSettings = @{
                cacheSettings = @{
                    enabled                  = $false
                    defaultExpirationMinutes = 15
                    maxCacheSize             = 1000
                    cacheTypes               = @{
                        Devices = @{ enabled = $false; expirationMinutes = 15 }
                    }
                }
            }
            
            # Temporarily override global cache settings
            $originalSettings = $global:cacheSettings
            $global:cacheSettings = $disabledSettings.cacheSettings
            
            try {
                $result = Get-CachedDeviceEnrollmentStatus -SerialNumber $testSerialNumber -AccessToken $mockAccessToken
                
                $result | Should -Not -BeNullOrEmpty
                $result.enrollmentState | Should -Be "Enrolled"
                
                # Verify nothing was cached
                $cacheKey = "enrollment:$testSerialNumber"
                $cachedData = Get-CachedData -CacheType 'Devices' -Key $cacheKey -CacheSettings $global:cacheSettings
                
                $cachedData | Should -BeNullOrEmpty
            }
            finally {
                $global:cacheSettings = $originalSettings
            }
        }
    }
}
