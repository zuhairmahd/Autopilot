# Import test helpers
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-DeviceData" -Tags 'Unit' {
    
    BeforeAll {
        # Load the function and its dependencies
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/deviceFunctions/Get-DeviceData.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/graphFunctions/CallGraphApi.ps1"
        
        # Mock Write-Log
        Mock Write-Log {}
        
        # Mock settings global variable
        $global:settings = @{
            deviceNamePrefix = 'TEST-'
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
        # Clear cache after each test
        $script:DeviceDataCache = $null
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
            
            $script:DeviceDataCache | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.autopilot | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.autopilot.Data | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.autopilot.Timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should use cached autopilot devices on subsequent calls" {
            # First call
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $firstTimestamp = $script:DeviceDataCache.autopilot.Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call should use cache
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $secondTimestamp = $script:DeviceDataCache.autopilot.Timestamp
            
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
            
            $script:DeviceDataCache.managed | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.managed.Data | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.managed.Timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should invalidate cache when filter changes" {
            # First call with prefix from settings
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed'
            $firstTimestamp = $script:DeviceDataCache.managed.Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call with different prefix should refresh
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed' -DeviceNamePrefix 'PROD-'
            $secondTimestamp = $script:DeviceDataCache.managed.Timestamp
            
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
            
            $script:DeviceDataCache.imported | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.imported.Data | Should -Not -BeNullOrEmpty
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
            
            $script:DeviceDataCache.unmanaged | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.unmanaged.Data | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Cache Management" {
        
        It "Should maintain separate caches for each device type" {
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'managed'
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'imported'
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'unmanaged'
            
            $script:DeviceDataCache.autopilot.Data | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.managed.Data | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.imported.Data | Should -Not -BeNullOrEmpty
            $script:DeviceDataCache.unmanaged.Data | Should -Not -BeNullOrEmpty
            
            # Verify each cache has different data
            $script:DeviceDataCache.autopilot.Data.value[0].serialNumber | Should -Be 'AP001'
            $script:DeviceDataCache.managed.Data.value[0].serialNumber | Should -Be 'MG001'
        }
        
        It "Should refresh cache when -RefreshCache is specified" {
            # First call
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot'
            $firstTimestamp = $script:DeviceDataCache.autopilot.Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call with -RefreshCache
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot' -RefreshCache
            $secondTimestamp = $script:DeviceDataCache.autopilot.Timestamp
            
            $secondTimestamp | Should -Not -Be $firstTimestamp
        }
        
        It "Should respect CacheExpirationMinutes parameter" {
            # First call
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot' -CacheExpirationMinutes 0
            $firstTimestamp = $script:DeviceDataCache.autopilot.Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call should refresh due to expired cache
            Get-DeviceData -AccessToken 'mock-token' -DeviceType 'autopilot' -CacheExpirationMinutes 0
            $secondTimestamp = $script:DeviceDataCache.autopilot.Timestamp
            
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
