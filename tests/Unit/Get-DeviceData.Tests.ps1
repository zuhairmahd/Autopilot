# Import test helpers
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-DeviceData" -Tags 'Unit' {
    
    BeforeAll {
        # Load the function and its dependencies
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"
        . "$script:RepoRoot/functions/deviceFunctions/Get-DeviceData.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/graphFunctions/CallGraphApi.ps1"
        
        # Mock Write-Log
        Mock Write-Log {}
        
        # Mock settings global variable with cache configuration
        $global:settings = @{
            deviceNamePrefix = 'TEST-'
            cacheSettings    = @{
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
        
        # Mock LogFile global variable
        $global:LogFile = "$env:TEMP\test.log"
        
        # Create mock device data for each type
        $script:MockAutopilotDevices = @{
            value = @(
                @{
                    serialNumber    = 'AP001'
                    groupTag        = 'Engineering'
                    manufacturer    = 'Dell Inc.'
                    model           = 'Latitude 5420'
                    systemFamily    = 'Latitude'
                    enrollmentState = 'enrolled'
                },
                @{
                    serialNumber    = 'AP002'
                    groupTag        = 'Sales'
                    manufacturer    = 'HP'
                    model           = 'EliteBook 840'
                    systemFamily    = 'EliteBook'
                    enrollmentState = 'enrolled'
                }
            )
        }
        
        $script:MockManagedDevices = @{
            value = @(
                @{
                    id                   = 'managed-001'
                    serialNumber         = 'MG001'
                    deviceName           = 'TEST-LAPTOP-001'
                    manufacturer         = 'Dell Inc.'
                    model                = 'Latitude 5420'
                    osVersion            = '10.0.19045.3803'
                    deviceEnrollmentType = 'windowsAzureADJoin'
                    userPrincipalName    = 'user@contoso.com'
                    userDisplayName      = 'Test User'
                },
                @{
                    id                   = 'managed-002'
                    serialNumber         = 'MG002'
                    deviceName           = 'TEST-LAPTOP-002'
                    manufacturer         = 'HP'
                    model                = 'EliteBook 840'
                    osVersion            = '10.0.19045.3803'
                    deviceEnrollmentType = 'windowsAzureADJoin'
                    userPrincipalName    = ''
                    userDisplayName      = ''
                }
            )
        }
        
        $script:MockImportedDevices = @{
            value = @(
                @{
                    serialNumber = 'IM001'
                    importId     = 'import-001'
                    groupTag     = 'Import-Batch-1'
                    state        = @{
                        deviceImportStatus   = 'complete'
                        deviceRegistrationId = 'reg-001'
                    }
                }
            )
        }
        
        $script:MockUnmanagedDevices = @{
            value = @(
                @{
                    id                     = 'unmanaged-001'
                    displayName            = 'PC001'
                    manufacturer           = 'Dell Inc.'
                    model                  = 'OptiPlex 7090'
                    operatingSystemVersion = '10.0.19045'
                    profileType            = 'RegisteredDevice'
                }
            )
        }
        
        # Mock CallGraphApi
        Mock CallGraphApi {
            param($ResourcePath)
            if ($ResourcePath -like '*importedWindowsAutopilotDeviceIdentities')
            {
                return $script:MockImportedDevices
            }
            elseif ($ResourcePath -like '*windowsAutopilotDeviceIdentities')
            {
                return $script:MockAutopilotDevices
            }
            elseif ($ResourcePath -like '*managedDevices')
            {
                return $script:MockManagedDevices
            }
            elseif ($ResourcePath -like 'devices')
            {
                return $script:MockUnmanagedDevices
            }
        }
    }
    
    AfterEach {
        # Clear unified cache after each test
        Clear-UnifiedCache -CacheType 'Devices'
    }
    
    Context "Device Type: Autopilot" {
        
        It "Should fetch autopilot devices from API" {
            $result = Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 2
            $result.value[0].serialNumber | Should -Be 'AP001'
        }
        
        It "Should cache autopilot devices" {
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            
            $global:UnifiedCache | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices.Keys | Should -Contain 'device:autopilot'
            $global:UnifiedCache.Devices['device:autopilot'].Timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should use cached autopilot devices on subsequent calls" {
            # First call
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $firstTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call should use cache
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $secondTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            $secondTimestamp | Should -Be $firstTimestamp
        }
    }
    
    Context "Device Type: Managed" {
        
        It "Should fetch managed devices from API" {
            $result = Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed'
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 2
            $result.value[0].serialNumber | Should -Be 'MG001'
        }
        
        It "Should cache managed devices" {
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed'
            
            $global:UnifiedCache.Devices | Should -Not -BeNullOrEmpty
            # Cache key includes filter for managed devices
            $cacheKey = $global:UnifiedCache.Devices.Keys | Where-Object { $_ -like 'device:managed*' }
            $cacheKey | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices[$cacheKey].Timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should invalidate cache when filter changes" {
            # First call with prefix from settings
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed'
            $firstCacheKey = $global:UnifiedCache.Devices.Keys | Where-Object { $_ -like 'device:managed*TEST-*' }
            $firstTimestamp = $global:UnifiedCache.Devices[$firstCacheKey].Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call with different prefix should create new cache entry
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed' -DeviceNamePrefix 'PROD-'
            $secondCacheKey = $global:UnifiedCache.Devices.Keys | Where-Object { $_ -like 'device:managed*PROD-*' }
            $secondTimestamp = $global:UnifiedCache.Devices[$secondCacheKey].Timestamp
            
            # Should have two different cache entries with different timestamps
            $secondTimestamp | Should -Not -Be $firstTimestamp
        }
    }
    
    Context "Device Type: Imported" {
        
        It "Should fetch imported autopilot devices from API" {
            $result = Get-DeviceData -AccessToken 'mock-token' -DeviceType 'imported'
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 1
            $result.value[0].serialNumber | Should -Be 'IM001'
        }
        
        It "Should cache imported devices separately" {
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'imported'
            
            $global:UnifiedCache.Devices | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices.Keys | Should -Contain 'device:imported'
        }
    }
    
    Context "Device Type: Unmanaged" {
        
        It "Should fetch unmanaged devices from API" {
            $result = Get-DeviceData -AccessToken 'mock-token' -DeviceType 'unmanaged'
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 1
            $result.value[0].displayName | Should -Be 'PC001'
        }
        
        It "Should cache unmanaged devices separately" {
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'unmanaged'
            
            $global:UnifiedCache.Devices | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices.Keys | Should -Contain 'device:unmanaged'
        }
    }
    
    Context "Cache Management" {
        
        It "Should maintain separate caches for each device type" {
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed'
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'imported'
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'unmanaged'
            
            $global:UnifiedCache.Devices.Keys | Should -Contain 'device:autopilot'
            # Check if any managed key exists (includes filter in key)
            $managedKey = $global:UnifiedCache.Devices.Keys | Where-Object { $_ -like 'device:managed*' }
            $managedKey | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices.Keys | Should -Contain 'device:imported'
            $global:UnifiedCache.Devices.Keys | Should -Contain 'device:unmanaged'
            
            # Verify each cache has different data
            $autopilotData = $global:UnifiedCache.Devices['device:autopilot'].Data
            $managedData = $global:UnifiedCache.Devices[$managedKey].Data
            
            $autopilotData.value[0].serialNumber | Should -Be 'AP001'
            $managedData.value[0].serialNumber | Should -Be 'MG001'
        }
        
        It "Should refresh cache when -RefreshCache is specified" {
            # First call
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $firstTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call with -RefreshCache
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot' -RefreshCache
            $secondTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            $secondTimestamp | Should -Not -Be $firstTimestamp
        }
        
        It "Should respect CacheExpirationMinutes parameter" {
            # Note: CacheExpirationMinutes parameter is not actually used in Get-DeviceData
            # The function relies on the unified cache's expiration settings from $global:settings
            # This test verifies that setting a very short expiration in settings causes cache refresh
            
            # First call with default expiration
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $firstTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            # Modify settings to use very short expiration (0.01 minutes = ~0.6 seconds)
            $global:settings.cacheSettings.cacheTypes.Devices.expirationMinutes = 0.01
            Start-Sleep -Seconds 2
            
            # Second call should refresh due to expired cache
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $secondTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            $secondTimestamp | Should -Not -Be $firstTimestamp
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle empty API response gracefully" {
            Mock CallGraphApi { return $null }
            
            $result = Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -BeNullOrEmpty
        }
        
        It "Should handle API response without value property" {
            Mock CallGraphApi { return @{} }
            
            $result = Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            
            $result | Should -Not -BeNullOrEmpty
            $result.value | Should -BeNullOrEmpty
        }
    }
    
    Context "Filter Generation" {
        
        It "Get-ManagedDeviceFilter should use settings.deviceNamePrefix when no prefix provided" {
            $filter = Get-ManagedDeviceFilter
            
            $filter | Should -Match "startswith\(deviceName,'TEST-'\)"
        }
        
        It "Get-ManagedDeviceFilter should use provided prefix over settings" {
            $filter = Get-ManagedDeviceFilter -DeviceNamePrefix 'PROD-'
            
            $filter | Should -Match "startswith\(deviceName,'PROD-'\)"
        }
        
        It "Get-ManagedDeviceFilter should return basic filter when no prefix available" {
            $global:settings.deviceNamePrefix = $null
            
            $filter = Get-ManagedDeviceFilter
            
            $filter | Should -Be "operatingSystem eq 'Windows'"
        }
        
        It "Get-ManagedDeviceFilter should escape single quotes in prefix" {
            $filter = Get-ManagedDeviceFilter -DeviceNamePrefix "TEST'QUOTE"
            
            $filter | Should -Match "TEST''QUOTE"
        }
    }
}
