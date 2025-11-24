# Import test helpers
Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Export-DeviceAssignmentReport" -Tags 'Unit' {
    
    BeforeAll {
        # Load the function and its dependencies
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        . "$script:RepoRoot/functions/utilityFunctions/Get-CachedData.ps1"
        . "$script:RepoRoot/functions/reportingFunctions/Export-DeviceAssignmentReport.ps1"
        . "$script:RepoRoot/functions/deviceFunctions/Get-DeviceData.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/graphFunctions/CallGraphApi.ps1"
        
        # Create temp output directory
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $script:TestOutputPath = New-Item -Path (Join-Path $tempPath "DeviceReportTest_$(Get-Date -Format 'yyyyMMddHHmmss')") -ItemType Directory -Force
        
        # Mock Write-Log globally (no -ModuleName needed for dot-sourced functions)
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
        $global:LogFile = "$($script:TestOutputPath.FullName)\test.log"
        
        # Create mock data based on ACTUAL Microsoft Graph API responses
        # Note: Autopilot API does NOT support 'id' in select parameter - it causes 0 results
        # Real API call: GET deviceManagement/windowsAutopilotDeviceIdentities (no select filter)
        $script:MockAutopilotDevices = @{
            value = @(
                # Assigned device with user
                @{
                    serialNumber    = 'SN001'
                    groupTag        = 'Engineering'
                    manufacturer    = 'Dell Inc.'
                    model           = 'Latitude 5420'
                    systemFamily    = 'Latitude'
                    enrollmentState = 'enrolled'
                    managedDeviceId = 'managed-001'
                },
                # Unassigned device (no user) - enrolled
                @{
                    serialNumber    = 'SN002'
                    groupTag        = 'Sales'
                    manufacturer    = 'HP'
                    model           = 'EliteBook 840'
                    systemFamily    = 'EliteBook'
                    enrollmentState = 'enrolled'
                    managedDeviceId = 'managed-002'
                },
                # Preprovisioned device (enrolled state, no user)
                @{
                    serialNumber    = 'SN003'
                    groupTag        = 'Warehouse'
                    manufacturer    = 'Lenovo'
                    model           = 'ThinkPad X1'
                    systemFamily    = 'ThinkPad'
                    enrollmentState = 'enrolled'  # This is the key for preprovisioned
                    managedDeviceId = 'managed-003'
                },
                # Not contacted yet (no managed device match)
                @{
                    serialNumber    = 'SN004'
                    groupTag        = 'IT'
                    manufacturer    = 'Microsoft'
                    model           = 'Surface Laptop 4'
                    systemFamily    = 'Surface'
                    enrollmentState = 'notContacted'
                    managedDeviceId = $null
                },
                # Another assigned device
                @{
                    serialNumber    = 'SN005'
                    groupTag        = 'Finance'
                    manufacturer    = 'Dell Inc.'
                    model           = 'Precision 5560'
                    systemFamily    = 'Precision'
                    enrollmentState = 'enrolled'
                    managedDeviceId = 'managed-005'
                }
            )
        }
        
        $script:MockManagedDevices = @{
            value = @(
                # Assigned device - has BOTH userPrincipalName AND userDisplayName (not empty/null)
                @{
                    id                     = 'managed-001'
                    serialNumber           = 'SN001'
                    deviceName             = 'TEST-LAPTOP-001'
                    manufacturer           = 'Dell Inc.'
                    model                  = 'Latitude 5420'
                    osVersion              = '10.0.19045.3803'
                    deviceEnrollmentType   = 'windowsAzureADJoin'
                    enrolledDateTime       = '2024-01-15T10:30:00Z'
                    lastSyncDateTime       = '2024-10-21T08:00:00Z'
                    complianceState        = 'compliant'
                    userPrincipalName      = 'john.doe@contoso.com'  # NOT empty
                    userDisplayName        = 'John Doe'  # NOT empty
                    userId                 = 'user-001'
                    managedDeviceOwnerType = 'company'
                    azureADRegistered      = $true
                },
                # Unassigned device - userPrincipalName is EMPTY STRING (not null)
                @{
                    id                     = 'managed-002'
                    serialNumber           = 'SN002'
                    deviceName             = 'TEST-LAPTOP-002'
                    manufacturer           = 'HP'
                    model                  = 'EliteBook 840'
                    osVersion              = '10.0.19045.3803'
                    deviceEnrollmentType   = 'windowsAzureADJoin'
                    enrolledDateTime       = '2024-02-10T14:20:00Z'
                    lastSyncDateTime       = '2024-10-20T16:30:00Z'
                    complianceState        = 'noncompliant'
                    userPrincipalName      = ''  # EMPTY STRING (key issue!)
                    userDisplayName        = ''  # EMPTY STRING
                    userId                 = $null
                    managedDeviceOwnerType = 'company'
                    azureADRegistered      = $true
                },
                # Preprovisioned device - BOTH are empty strings
                @{
                    id                     = 'managed-003'
                    serialNumber           = 'SN003'
                    deviceName             = 'TEST-LAPTOP-003'
                    manufacturer           = 'Lenovo'
                    model                  = 'ThinkPad X1'
                    osVersion              = '10.0.22631.3155'
                    deviceEnrollmentType   = 'windowsAzureADJoin'
                    enrolledDateTime       = '2024-03-05T09:15:00Z'
                    lastSyncDateTime       = '2024-10-21T07:45:00Z'
                    complianceState        = 'compliant'
                    userPrincipalName      = ''  # Empty for preprovisioned
                    userDisplayName        = ''  # Empty for preprovisioned
                    userId                 = $null
                    managedDeviceOwnerType = 'company'
                    azureADRegistered      = $true
                },
                # Another assigned device
                @{
                    id                     = 'managed-005'
                    serialNumber           = 'SN005'
                    deviceName             = 'TEST-LAPTOP-005'
                    manufacturer           = 'Dell Inc.'
                    model                  = 'Precision 5560'
                    osVersion              = '10.0.22631.3155'
                    deviceEnrollmentType   = 'windowsAzureADJoin'
                    enrolledDateTime       = '2024-04-20T11:00:00Z'
                    lastSyncDateTime       = '2024-10-21T09:00:00Z'
                    complianceState        = 'compliant'
                    userPrincipalName      = 'jane.smith@contoso.com'
                    userDisplayName        = 'Jane Smith'
                    userId                 = 'user-005'
                    managedDeviceOwnerType = 'company'
                    azureADRegistered      = $true
                }
            )
        }
        
        # Mock CallGraphApi
        Mock CallGraphApi {
            param($ResourcePath)
            if ($ResourcePath -like '*autopilot*')
            {
                return $script:MockAutopilotDevices
            }
            else
            {
                return $script:MockManagedDevices
            }
        }
    }
    
    AfterAll {
        # Cleanup temp directory
        if (Test-Path $script:TestOutputPath.FullName)
        {
            Remove-Item -Path $script:TestOutputPath.FullName -Recurse -Force
        }
        
        # Clear unified cache
        Clear-UnifiedCache -CacheType 'Devices'
    }
    
    Context "Report Type: Assigned" {
        
        It "Should return only devices with BOTH userPrincipalName AND userDisplayName populated" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            $result.success | Should -Be $true
            $result.ReportType | Should -Be 'Assigned'
            $result.deviceCount | Should -Be 2
            
            # Read the generated CSV
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Assigned-*.csv" | Select-Object -First 1
            $csvFile | Should -Not -BeNullOrEmpty
            
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should have exactly 2 assigned devices (SN001 and SN005)
            $csvData.Count | Should -Be 2
            
            # Verify all have user information
            foreach ($device in $csvData)
            {
                $device.UserPrincipalName | Should -Not -BeNullOrEmpty
                $device.UserDisplayName | Should -Not -BeNullOrEmpty
                $device.SerialNumber | Should -BeIn @('SN001', 'SN005')
            }
        }
        
        It "Should exclude devices with empty string userPrincipalName" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Assigned-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should NOT include SN002 (empty userPrincipalName)
            $csvData.SerialNumber | Should -Not -Contain 'SN002'
        }
    }
    
    Context "Report Type: Unassigned" {
        
        It "Should return devices with EITHER userPrincipalName OR userDisplayName missing/empty" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Unassigned'
            
            $result.success | Should -Be $true
            $result.ReportType | Should -Be 'Unassigned'
            $result.deviceCount | Should -BeGreaterThan 0
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Unassigned-*.csv" | Select-Object -First 1
            $csvFile | Should -Not -BeNullOrEmpty
            
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should have devices with empty user info (SN002, SN003)
            $csvData.Count | Should -BeGreaterThan 0
            
            # Should include SN002 and SN003
            $csvData.SerialNumber | Should -Contain 'SN002'
            $csvData.SerialNumber | Should -Contain 'SN003'
        }
        
        It "Should exclude devices with BOTH userPrincipalName AND userDisplayName populated" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Unassigned'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Unassigned-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should NOT include SN001 or SN005 (both have users)
            $csvData.SerialNumber | Should -Not -Contain 'SN001'
            $csvData.SerialNumber | Should -Not -Contain 'SN005'
        }
        
        It "Should properly detect empty strings as missing user info" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Unassigned'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Unassigned-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Find SN002 which has empty string userPrincipalName
            $device002 = $csvData | Where-Object { $_.SerialNumber -eq 'SN002' }
            $device002 | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Report Type: Preprovisioned" {
        
        It "Should return only devices with enrollmentState='enrolled' AND no user assignment" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Preprovisioned'
            
            $result.success | Should -Be $true
            $result.ReportType | Should -Be 'Preprovisioned'
            $result.deviceCount | Should -BeGreaterThan 0
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Preprovisioned-*.csv" | Select-Object -First 1
            $csvFile | Should -Not -BeNullOrEmpty
            
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should have at least SN003 (enrolled + no user)
            $csvData.Count | Should -BeGreaterThan 0
            $csvData.SerialNumber | Should -Contain 'SN003'
        }
        
        It "Should exclude enrolled devices that have user assignment" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Preprovisioned'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Preprovisioned-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should NOT include SN001 (enrolled but has user)
            $csvData.SerialNumber | Should -Not -Contain 'SN001'
        }
        
        It "Should exclude devices with enrollmentState='notContacted'" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Preprovisioned'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Preprovisioned-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should NOT include SN004 (notContacted state)
            $csvData.SerialNumber | Should -Not -Contain 'SN004'
        }
    }
    
    Context "Report Type: All" {
        
        It "Should return all autopilot devices" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $result.success | Should -Be $true
            $result.ReportType | Should -Be 'All'
            $result.deviceCount | Should -Be 5
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "All-*.csv" | Select-Object -First 1
            $csvFile | Should -Not -BeNullOrEmpty
            
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should have all autopilot devices (5 in mock data, but only 4 have managed devices)
            $csvData.Count | Should -Be 5  # Including SN004 which has no managed device match
        }
        
        It "Should include devices without managed device matches" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "All-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            # Should include SN004 even though it has no managed device
            $csvData.SerialNumber | Should -Contain 'SN004'
            
            # Verify SN004 has empty managed device properties
            $device004 = $csvData | Where-Object { $_.SerialNumber -eq 'SN004' }
            $device004.DeviceName | Should -Be ''
            $device004.OSVersion | Should -Be ''
        }
    }
    
    Context "Caching Functionality" {
        
        BeforeEach {
            # Clear unified cache before each test
            Clear-UnifiedCache -CacheType 'Devices'
        }
        
        It "Should cache data on first call" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $global:UnifiedCache | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices.Keys | Should -Contain 'device:autopilot'
            $autopilotKey = 'device:autopilot'
            $managedKey = $global:UnifiedCache.Devices.Keys | Where-Object { $_ -like 'device:managed*' }
            $managedKey | Should -Not -BeNullOrEmpty
            $global:UnifiedCache.Devices[$autopilotKey].Timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should use cached data on subsequent calls" {
            # First call
            Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $firstTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call
            Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            # Timestamp should be the same (using cache)
            $global:UnifiedCache.Devices['device:autopilot'].Timestamp | Should -Be $firstTimestamp
        }
        
        It "Should refresh cache when -RefreshCache is specified" {
            # First call
            Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $firstTimestamp = $global:UnifiedCache.Devices['device:autopilot'].Timestamp
            
            Start-Sleep -Milliseconds 100
            
            # Second call with -RefreshCache
            Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All' -RefreshCache
            
            # Timestamp should be different (cache refreshed)
            $global:UnifiedCache.Devices['device:autopilot'].Timestamp | Should -Not -Be $firstTimestamp
        }
    }
    
    Context "Error Handling and Robustness" {
        
        BeforeEach {
            # Clear unified cache before each test to ensure clean state
            Clear-UnifiedCache -CacheType 'Devices'
        }
        
        It "Should handle empty result set gracefully" {
            # Mock to return empty data
            Mock CallGraphApi {
                return @{ value = @() }
            }
            
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            $result.success | Should -Be $true
            $result.deviceCount | Should -Be 0
            $result.message | Should -Match "No devices found"
            
            # Should create file with headers
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Assigned-*.csv" | Select-Object -First 1
            $csvFile | Should -Not -BeNullOrEmpty
        }
        
        It "Should return success status when export completes" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $result.success | Should -Be $true
            $result | Should -BeOfType [hashtable]
        }
        
        It "Should create output file with timestamp in filename" {
            Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Assigned-DeviceList-*.csv"
            $csvFile | Should -Not -BeNullOrEmpty
            $csvFile.Name | Should -Match 'Assigned-DeviceList-\d{8}-\d{6}\.csv'
        }
    }
    
    Context "Data Integrity" {
        
        It "Should include all expected properties in output" {
            Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "All-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            $firstDevice = $csvData | Select-Object -First 1
            
            # Verify all expected properties exist
            $firstDevice.PSObject.Properties.Name | Should -Contain 'SerialNumber'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'GroupTag'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'DeviceName'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'Manufacturer'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'Model'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'SystemFamily'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'OSVersion'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'EnrollmentState'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'DeviceEnrollmentType'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'AzureADRegistered'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'ComplianceState'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'OwnerType'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'UserPrincipalName'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'UserDisplayName'
            $firstDevice.PSObject.Properties.Name | Should -Contain 'UserId'
        }
        
        It "Should preserve device properties from autopilot and managed sources correctly" {
            Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            $csvFile = Get-ChildItem -Path $script:TestOutputPath.FullName -Filter "Assigned-*.csv" | Select-Object -First 1
            $csvData = Import-Csv -Path $csvFile.FullName
            
            $device = $csvData | Where-Object { $_.SerialNumber -eq 'SN001' }
            
            # Verify autopilot properties
            $device.SerialNumber | Should -Be 'SN001'
            $device.GroupTag | Should -Be 'Engineering'
            $device.Manufacturer | Should -Be 'Dell Inc.'
            $device.Model | Should -Be 'Latitude 5420'
            
            # Verify managed device properties
            $device.DeviceName | Should -Be 'TEST-LAPTOP-001'
            $device.UserPrincipalName | Should -Be 'john.doe@contoso.com'
            $device.UserDisplayName | Should -Be 'John Doe'
        }
    }
    
    Context "Return Object Structure and Properties" {
        
        BeforeEach {
            # Clear unified cache before each test to ensure clean state
            Clear-UnifiedCache -CacheType 'Devices'
        }
        
        It "Should return a hashtable with all required properties" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain 'ReportType'
            $result.Keys | Should -Contain 'OutputFile'
            $result.Keys | Should -Contain 'deviceCount'
            $result.Keys | Should -Contain 'success'
            $result.Keys | Should -Contain 'message'
        }
        
        It "Should set ReportType correctly" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            $result.ReportType | Should -Be 'Assigned'
        }
        
        It "Should include the output file path" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Unassigned'
            
            $result.OutputFile | Should -Not -BeNullOrEmpty
            $result.OutputFile | Should -Match 'Unassigned-DeviceList-\d{8}-\d{6}\.csv'
            Test-Path $result.OutputFile | Should -Be $true
        }
        
        It "Should return correct device count for each report type" {
            $assignedResult = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            $unassignedResult = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Unassigned'
            $allResult = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $assignedResult.deviceCount | Should -Be 2
            $unassignedResult.deviceCount | Should -BeGreaterThan 0
            $allResult.deviceCount | Should -Be 5
        }
        
        It "Should set success to true when export completes" {
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'All'
            
            $result.success | Should -Be $true
        }
        
        It "Should populate message when no devices found" {
            Mock CallGraphApi {
                return @{ value = @() }
            }
            
            $result = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            
            $result.success | Should -Be $true
            $result.deviceCount | Should -Be 0
            $result.message | Should -Not -BeNullOrEmpty
            $result.message | Should -Match "No devices found"
        }
        
        It "Should return different device counts for different report types" {
            $assigned = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Assigned'
            $unassigned = Export-DeviceAssignmentReport -AccessToken 'mock-token' -outputPath $script:TestOutputPath.FullName -reportType 'Unassigned'
            
            $assigned.deviceCount | Should -Not -Be $unassigned.deviceCount
            $assigned.deviceCount + $unassigned.deviceCount | Should -BeLessOrEqual 5  # Total in mock data
        }
    }
}
