# GetDeviceIdFromSerial.Tests.ps1
# Pester tests for GetDeviceIdFromSerial function with unified cache integration

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Function: GetDeviceIdFromSerial" -Tags 'Unit' {
    BeforeAll {
        # Direct dot-sourcing (recommended pattern)
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Source dependencies first
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"
        . "$script:RepoRoot/functions/graphFunctions/CallGraphApi.ps1"
        
        # Source the function under test
        . "$script:RepoRoot/functions/deviceFunctions/GetDeviceIdFromSerial.ps1"
        
        # Set global LogFile variable (required by function)
        $global:LogFile = "$TestDrive\test.log"
        
        # Initialize global settings with cache configuration
        $global:settings = @{
            cacheSettings = @{
                enabled                  = $true
                defaultExpirationMinutes = 15
                maxCacheSize             = 1000
                cacheTypes               = @{
                    Devices = @{
                        enabled           = $true
                        expirationMinutes = 15
                    }
                }
            }
        }
        
        # Initialize cache
        Initialize-UnifiedCache
        
        # Test data
        $script:testSerialNumber = "TEST-SERIAL-123"
        $script:testDeviceId = "11111111-1111-1111-1111-111111111111"
        $script:testAccessToken = "test-access-token"
    }
    
    BeforeEach {
        # Clear cache before each test
        Clear-UnifiedCache -CacheType 'Devices'
        
        # Mock Write-Log to avoid file system dependencies
        Mock Write-Log { }
    }
    
    AfterAll {
        # Cleanup
        Clear-UnifiedCache
        Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name LogFile -Scope Global -ErrorAction SilentlyContinue
    }
    
    Context "Cache Hit Scenarios" {
        It "Should return cached device ID when cache hit occurs" {
            # Arrange - Pre-populate cache
            $cacheKey = "deviceid:$($script:testSerialNumber.ToLower())"
            Set-CachedData -CacheType 'Devices' -Key $cacheKey -Data $script:testDeviceId -Settings $global:settings
            
            # Act
            $result = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            $result | Should -Be $script:testDeviceId
        }
        
        It "Should not call Graph API when cache hit occurs" {
            # Arrange - Pre-populate cache
            $cacheKey = "deviceid:$($script:testSerialNumber.ToLower())"
            Set-CachedData -CacheType 'Devices' -Key $cacheKey -Data $script:testDeviceId -Settings $global:settings
            
            # Mock CallGraphApi to track if it's called
            Mock CallGraphApi { throw "Should not be called" }
            
            # Act
            $result = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            $result | Should -Be $script:testDeviceId
            Assert-MockCalled CallGraphApi -Times 0
        }
        
        It "Should handle cached null results (non-existent devices)" {
            # Arrange - Cache a sentinel value for not-found devices
            $cacheKey = "deviceid:$($script:testSerialNumber.ToLower())"
            # Use empty string instead of null for not-found devices
            Set-CachedData -CacheType 'Devices' -Key $cacheKey -Data "" -Metadata @{ NotFound = $true } -Settings $global:settings
            
            # Act
            $result = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
        
        It "Should use case-insensitive cache keys" {
            # Arrange - Cache with uppercase serial
            $upperSerial = "TEST-SERIAL-UPPER"
            $lowerSerial = "test-serial-upper"
            $cacheKey = "deviceid:$($upperSerial.ToLower())"
            Set-CachedData -CacheType 'Devices' -Key $cacheKey -Data $script:testDeviceId -Settings $global:settings
            
            # Act - Query with different case
            $result = GetDeviceIdFromSerial -SerialNumber $lowerSerial -AccessToken $script:testAccessToken
            
            # Assert
            $result | Should -Be $script:testDeviceId
        }
    }
    
    Context "Cache Miss Scenarios" {
        It "Should fetch from Graph API on cache miss and cache the result" {
            # Arrange
            Mock CallGraphApi {
                return @{
                    value = @{
                        Id = $script:testDeviceId
                    }
                }
            }
            
            # Act
            $result = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            $result | Should -Be $script:testDeviceId
            Assert-MockCalled CallGraphApi -Times 1
            
            # Verify result is cached
            $cacheKey = "deviceid:$($script:testSerialNumber.ToLower())"
            $cachedResult = Get-CachedData -CacheType 'Devices' -Key $cacheKey -Settings $global:settings
            $cachedResult | Should -Be $script:testDeviceId
        }
        
        It "Should cache device ID with proper metadata" {
            # Arrange
            Mock CallGraphApi {
                return @{
                    value = @{
                        Id = $script:testDeviceId
                    }
                }
            }
            
            # Act
            GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert - Check metadata
            $cacheKey = "deviceid:$($script:testSerialNumber.ToLower())"
            $cacheEntry = $global:UnifiedCache['Devices'][$cacheKey]
            $cacheEntry.Metadata.SerialNumber | Should -Be $script:testSerialNumber
            $cacheEntry.Metadata.DeviceType | Should -Be 'ManagedDevice'
            $cacheEntry.Metadata.CachedAt | Should -Not -BeNullOrEmpty
        }
        
        It "Should call Graph API with correct parameters" {
            # Arrange
            Mock CallGraphApi {
                param($AccessToken, $ResourcePath, $filter, $ExtraParameters, $Method)
                
                # Validate parameters
                $AccessToken | Should -Be $script:testAccessToken
                $ResourcePath | Should -Be "deviceManagement/managedDevices"
                $filter | Should -Be "serialNumber eq '$script:testSerialNumber'"
                $ExtraParameters | Should -Be "select=Id"
                $Method | Should -Be "GET"
                
                return @{
                    value = @{
                        Id = $script:testDeviceId
                    }
                }
            }
            
            # Act
            GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            Assert-MockCalled CallGraphApi -Times 1
        }
    }
    
    Context "Device Not Found Scenarios" {
        It "Should cache empty string sentinel when device is not found" {
            # Arrange
            Mock CallGraphApi {
                return $null
            }
            
            # Act
            $result = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            $result | Should -BeNullOrEmpty
            
            # Verify empty string sentinel is cached
            $cacheKey = "deviceid:$($script:testSerialNumber.ToLower())"
            $cachedResult = Get-CachedData -CacheType 'Devices' -Key $cacheKey -Settings $global:settings
            $cachedResult | Should -Be ""
        }
        
        It "Should cache not-found result with metadata" {
            # Arrange
            Mock CallGraphApi {
                return $null
            }
            
            # Act
            GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert - Check not-found metadata
            $cacheKey = "deviceid:$($script:testSerialNumber.ToLower())"
            $cacheEntry = $global:UnifiedCache['Devices'][$cacheKey]
            $cacheEntry.Metadata.SerialNumber | Should -Be $script:testSerialNumber
            $cacheEntry.Metadata.NotFound | Should -Be $true
        }
        
        It "Should not repeatedly call API for non-existent devices" {
            # Arrange
            Mock CallGraphApi {
                return $null
            }
            
            # Act - First call (cache miss)
            $result1 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Act - Second call (should use cached null)
            $result2 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            $result1 | Should -BeNullOrEmpty
            $result2 | Should -BeNullOrEmpty
            Assert-MockCalled CallGraphApi -Times 1  # Only called once
        }
    }
    
    Context "Parameter Validation" {
        It "Should return null when Graph API call fails with whitespace token" {
            # Mock CallGraphApi to return null (simulating failed API call)
            Mock CallGraphApi {
                return $null
            }
            
            # Act - whitespace passes PowerShell's truthiness test but should fail at API
            $result = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken " "
            
            # Assert
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Cache Expiration" {
        It "Should respect cache expiration settings" {
            # Arrange - Set very short expiration
            $global:settings.cacheSettings.cacheTypes.Devices.expirationMinutes = 0.001
            
            Mock CallGraphApi {
                return @{
                    value = @{
                        Id = $script:testDeviceId
                    }
                }
            }
            
            # Act - First call
            $result1 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Wait for expiration
            Start-Sleep -Milliseconds 100
            
            # Act - Second call (should hit API again due to expiration)
            $result2 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert
            $result1 | Should -Be $script:testDeviceId
            $result2 | Should -Be $script:testDeviceId
            Assert-MockCalled CallGraphApi -Times 2
            
            # Cleanup - Restore expiration
            $global:settings.cacheSettings.cacheTypes.Devices.expirationMinutes = 15
        }
    }
    
    Context "Cache Disabled Scenarios" {
        It "Should bypass cache when caching is globally disabled" {
            # Arrange
            $global:settings.cacheSettings.enabled = $false
            
            Mock CallGraphApi {
                return @{
                    value = @{
                        Id = $script:testDeviceId
                    }
                }
            }
            
            # Act - Multiple calls
            $result1 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            $result2 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert - API should be called twice (no caching)
            $result1 | Should -Be $script:testDeviceId
            $result2 | Should -Be $script:testDeviceId
            Assert-MockCalled CallGraphApi -Times 2
            
            # Cleanup
            $global:settings.cacheSettings.enabled = $true
        }
        
        It "Should bypass cache when Devices cache type is disabled" {
            # Arrange
            $global:settings.cacheSettings.cacheTypes.Devices.enabled = $false
            
            Mock CallGraphApi {
                return @{
                    value = @{
                        Id = $script:testDeviceId
                    }
                }
            }
            
            # Act - Multiple calls
            $result1 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            $result2 = GetDeviceIdFromSerial -SerialNumber $script:testSerialNumber -AccessToken $script:testAccessToken
            
            # Assert - API should be called twice (no caching)
            $result1 | Should -Be $script:testDeviceId
            $result2 | Should -Be $script:testDeviceId
            Assert-MockCalled CallGraphApi -Times 2
            
            # Cleanup
            $global:settings.cacheSettings.cacheTypes.Devices.enabled = $true
        }
    }
    
    Context "Multiple Device Lookups" {
        It "Should cache multiple devices independently" {
            # Arrange
            $serial1 = "SERIAL-001"
            $serial2 = "SERIAL-002"
            $deviceId1 = "11111111-1111-1111-1111-111111111111"
            $deviceId2 = "22222222-2222-2222-2222-222222222222"
            
            Mock CallGraphApi {
                param($filter)
                if ($filter -like "*$serial1*")
                {
                    return @{ value = @{ Id = $deviceId1 } }
                }
                else
                {
                    return @{ value = @{ Id = $deviceId2 } }
                }
            }
            
            # Act
            $result1 = GetDeviceIdFromSerial -SerialNumber $serial1 -AccessToken $script:testAccessToken
            $result2 = GetDeviceIdFromSerial -SerialNumber $serial2 -AccessToken $script:testAccessToken
            
            # Assert
            $result1 | Should -Be $deviceId1
            $result2 | Should -Be $deviceId2
            Assert-MockCalled CallGraphApi -Times 2
            
            # Verify both are cached
            $cachedResult1 = Get-CachedData -CacheType 'Devices' -Key "deviceid:$($serial1.ToLower())" -Settings $global:settings
            $cachedResult2 = Get-CachedData -CacheType 'Devices' -Key "deviceid:$($serial2.ToLower())" -Settings $global:settings
            $cachedResult1 | Should -Be $deviceId1
            $cachedResult2 | Should -Be $deviceId2
        }
    }
}
