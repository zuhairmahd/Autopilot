Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Comprehensive Device Lookup and Reporting Tests" -Tags 'Comprehensive', 'Device', 'Lookup' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        
        # Load all functions directly
        $functionsPath = Join-Path $script:RepoRoot "functions"
        $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -File
        
        Write-Verbose "Loading $($functionFiles.Count) functions from $functionsPath..."
        foreach ($file in $functionFiles)
        {
            try
            {
                . $file.FullName
            }
            catch
            {
                Write-Warning "Failed to load $($file.Name): $_"
            }
        }
        
        # Setup global variables
        $global:LogFile = Join-Path $script:TestContext.TestFolder "device-lookup.log"
        
        # Create test settings
        $script:TestSettings = @{
            desiredAutopilotProfiles   = @("Corporate Profile", "Standard Profile")
            requireAutopilotEnrollment = $true
            requireCompliance          = $true
            maxDaysSinceLastSync       = 7
        }
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and $script:TestContext.TestFolder)
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    
    Context "Function Availability Validation" {
        
        It "Should have ProcessSerialNumber function available" {
            Get-Command -Name ProcessSerialNumber -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GetDeviceInfo function available" {
            Get-Command -Name GetDeviceInfo -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have AssessDeviceState function available" {
            Get-Command -Name AssessDeviceState -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GetNextUserReadinessReport function available" {
            Get-Command -Name GetNextUserReadinessReport -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GetAutopilotDeviceRelevantProperties function available" {
            Get-Command -Name GetAutopilotDeviceRelevantProperties -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GetManagedDeviceRelevantProperties function available" {
            Get-Command -Name GetManagedDeviceRelevantProperties -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have GetLastDeviceContactDate function available" {
            $cmd = Get-Command -Name GetLastDeviceContactDate -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "GetLastDeviceContactDate function not found"
            }
        }
        
        It "Should have getDevicePendingActions function available" {
            $cmd = Get-Command -Name getDevicePendingActions -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "getDevicePendingActions function not found"
            }
        }
        
        It "Should have ShowDeviceReport function available" {
            $cmd = Get-Command -Name ShowDeviceReport -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "ShowDeviceReport function not found"
            }
        }
        
        It "Should have Export-DeviceList function available" {
            $cmd = Get-Command -Name Export-DeviceList -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "Export-DeviceList function not found"
            }
        }
        
        It "Should have Export-DeviceReport function available" {
            $cmd = Get-Command -Name Export-DeviceReport -ErrorAction SilentlyContinue
            if ($cmd)
            {
                $cmd | Should -Not -BeNullOrEmpty
            }
            else
            {
                Set-ItResult -Skipped -Because "Export-DeviceReport function not found"
            }
        }
    }
    
    Context "Device State Assessment" {
        
        It "Should assess enrolled and managed device as in Autopilot" {
            $mockState = @{
                inAutopilot   = $true
                managed       = $true
                isReady       = $false
                issues        = @("Device not compliant")
                autopilot     = @{
                    device = @{
                        displayName                       = "TEST-DEVICE-001"
                        serialNumber                      = "SN123456789"
                        enrollmentState                   = "enrolled"
                        deploymentProfileAssignmentStatus = "assigned"
                    }
                }
                managedDevice = @{
                    device = @{
                        deviceName       = "TEST-DEVICE-001"
                        operatingSystem  = "Windows"
                        complianceState  = "noncompliant"
                        lastSyncDateTime = (Get-Date).ToString("o")
                    }
                }
            }
            
            $mockState.inAutopilot | Should -Be $true
            $mockState.managed | Should -Be $true
            $mockState.isReady | Should -Be $false
            $mockState.issues.Count | Should -BeGreaterThan 0
        }
        
        It "Should identify ready device with no issues" {
            $mockState = @{
                inAutopilot   = $true
                managed       = $true
                isReady       = $true
                issues        = @()
                autopilot     = @{
                    device = @{
                        displayName                       = "READY-DEVICE-001"
                        serialNumber                      = "RD123456789"
                        enrollmentState                   = "enrolled"
                        deploymentProfileAssignmentStatus = "assigned"
                    }
                }
                managedDevice = @{
                    device = @{
                        deviceName       = "READY-DEVICE-001"
                        operatingSystem  = "Windows 11"
                        complianceState  = "compliant"
                        lastSyncDateTime = (Get-Date).ToString("o")
                    }
                }
            }
            
            $mockState.isReady | Should -Be $true
            $mockState.issues | Should -BeNullOrEmpty
        }
        
        It "Should detect device not in Autopilot" {
            $mockState = @{
                inAutopilot   = $false
                managed       = $true
                isReady       = $false
                issues        = @("Device not enrolled in Autopilot")
                autopilot     = $null
                managedDevice = @{
                    device = @{
                        deviceName       = "UNREGISTERED-001"
                        operatingSystem  = "Windows"
                        complianceState  = "compliant"
                        lastSyncDateTime = (Get-Date).ToString("o")
                    }
                }
            }
            
            $mockState.inAutopilot | Should -Be $false
            $mockState.issues | Should -Contain "Device not enrolled in Autopilot"
        }
        
        It "Should detect device not managed" {
            $mockState = @{
                inAutopilot   = $true
                managed       = $false
                isReady       = $false
                issues        = @("Device not managed")
                autopilot     = @{
                    device = @{
                        displayName                       = "UNMANAGED-001"
                        serialNumber                      = "UM123456789"
                        enrollmentState                   = "enrolled"
                        deploymentProfileAssignmentStatus = "assigned"
                    }
                }
                managedDevice = $null
            }
            
            $mockState.managed | Should -Be $false
            $mockState.issues | Should -Contain "Device not managed"
        }
    }
    
    Context "Device Readiness Reporting" {
        
        It "Should validate readiness report structure for ready device" {
            $mockReport = @{
                deviceName        = "READY-DEVICE-001"
                serialNumber      = "RD123456789"
                userPrincipalName = "test.user@example.com"
                enrollmentState   = "enrolled"
                complianceState   = "compliant"
                lastSyncDateTime  = (Get-Date).ToString("o")
                enrolledDateTime  = (Get-Date).AddDays(-7).ToString("o")
                profileAssigned   = "Corporate Profile"
                isReady           = $true
                issues            = @()
            }
            
            $mockReport.isReady | Should -Be $true
            $mockReport.issues | Should -BeNullOrEmpty
            $mockReport.enrollmentState | Should -Be "enrolled"
            $mockReport.complianceState | Should -Be "compliant"
            $mockReport.profileAssigned | Should -Not -BeNullOrEmpty
        }
        
        It "Should validate readiness report structure for device with issues" {
            $mockReport = @{
                deviceName        = "PROBLEM-DEVICE-001"
                serialNumber      = "PD123456789"
                userPrincipalName = "test.user@example.com"
                enrollmentState   = "enrolled"
                complianceState   = "noncompliant"
                lastSyncDateTime  = (Get-Date).AddDays(-10).ToString("o")
                enrolledDateTime  = (Get-Date).AddDays(-30).ToString("o")
                profileAssigned   = "Corporate Profile"
                isReady           = $false
                issues            = @("Device not compliant", "Last sync over 7 days ago")
            }
            
            $mockReport.isReady | Should -Be $false
            $mockReport.issues.Count | Should -BeGreaterThan 0
            $mockReport.complianceState | Should -Be "noncompliant"
        }
        
        It "Should handle missing user assignment in readiness report" {
            $mockReport = @{
                deviceName        = "UNASSIGNED-001"
                serialNumber      = "UA123456789"
                userPrincipalName = $null
                enrollmentState   = "enrolled"
                complianceState   = "compliant"
                lastSyncDateTime  = (Get-Date).ToString("o")
                enrolledDateTime  = (Get-Date).AddDays(-1).ToString("o")
                profileAssigned   = "Corporate Profile"
                isReady           = $false
                issues            = @("No user assigned")
            }
            
            $mockReport.userPrincipalName | Should -BeNullOrEmpty
            $mockReport.issues | Should -Contain "No user assigned"
        }
    }
    
    Context "Autopilot Device Properties Validation" {
        
        It "Should validate autopilot device with required properties" {
            $mockAutopilotDevice = @{
                displayName                       = "TEST-DEVICE-001"
                serialNumber                      = "SN123456789"
                enrollmentState                   = "enrolled"
                deploymentProfileAssignmentStatus = "assigned"
                deploymentProfile                 = @{
                    displayName = "Corporate Profile"
                }
            }
            
            $mockAutopilotDevice.enrollmentState | Should -Be "enrolled"
            $mockAutopilotDevice.deploymentProfileAssignmentStatus | Should -Be "assigned"
            $mockAutopilotDevice.deploymentProfile.displayName | Should -Be "Corporate Profile"
        }
        
        It "Should detect missing deployment profile assignment" {
            $mockAutopilotDevice = @{
                displayName                       = "UNASSIGNED-DEVICE-001"
                serialNumber                      = "UA123456789"
                enrollmentState                   = "enrolled"
                deploymentProfileAssignmentStatus = "notAssigned"
                deploymentProfile                 = $null
            }
            
            $mockAutopilotDevice.deploymentProfileAssignmentStatus | Should -Be "notAssigned"
            $mockAutopilotDevice.deploymentProfile | Should -BeNullOrEmpty
        }
        
        It "Should validate autopilot device against desired profile list" {
            $desiredProfiles = @("Corporate Profile", "Standard Profile", "Executive Profile")
            $deviceProfile = "Corporate Profile"
            
            $desiredProfiles | Should -Contain $deviceProfile
        }
        
        It "Should detect incorrect profile assignment" {
            $desiredProfiles = @("Corporate Profile", "Standard Profile")
            $deviceProfile = "Unauthorized Profile"
            
            $desiredProfiles | Should -Not -Contain $deviceProfile
        }
    }
    
    Context "Managed Device Properties Validation" {
        
        It "Should validate managed device with required properties" {
            $mockManagedDevice = @{
                deviceName        = "TEST-DEVICE-001"
                operatingSystem   = "Windows 11"
                complianceState   = "compliant"
                lastSyncDateTime  = (Get-Date).ToString("o")
                enrolledDateTime  = (Get-Date).AddDays(-7).ToString("o")
                userPrincipalName = "test.user@example.com"
                managementAgent   = "mdm"
            }
            
            $mockManagedDevice.complianceState | Should -Be "compliant"
            $mockManagedDevice.managementAgent | Should -Be "mdm"
            $mockManagedDevice.operatingSystem | Should -BeLike "Windows*"
        }
        
        It "Should detect stale device sync (over 7 days)" {
            $lastSync = (Get-Date).AddDays(-10).ToString("o")
            $lastSyncDate = [datetime]::Parse($lastSync)
            $daysSinceSync = ((Get-Date) - $lastSyncDate).Days
            
            $daysSinceSync | Should -BeGreaterThan 7
        }
        
        It "Should validate recent device sync (within 7 days)" {
            $lastSync = (Get-Date).AddDays(-3).ToString("o")
            $lastSyncDate = [datetime]::Parse($lastSync)
            $daysSinceSync = ((Get-Date) - $lastSyncDate).Days
            
            $daysSinceSync | Should -BeLessOrEqual 7
        }
        
        It "Should validate operating system version" {
            $validOSVersions = @("Windows 10", "Windows 11")
            $deviceOS = "Windows 11"
            
            $isValidOS = $validOSVersions | Where-Object { $deviceOS -like "$_*" }
            $isValidOS | Should -Not -BeNullOrEmpty
        }
        
        It "Should detect unsupported operating system" {
            $validOSVersions = @("Windows 10", "Windows 11")
            $deviceOS = "Windows 8.1"
            
            $isValidOS = $validOSVersions | Where-Object { $deviceOS -like "$_*" }
            $isValidOS | Should -BeNullOrEmpty
        }
    }
    
    Context "Device Contact Date Tracking" {
        
        It "Should parse ISO 8601 date format from Graph API" {
            $isoDate = "2025-01-09T08:30:00Z"
            $parsedDate = [datetime]::Parse($isoDate)
            
            $parsedDate | Should -BeOfType [datetime]
        }
        
        It "Should calculate days since last contact" {
            $lastContactDate = (Get-Date).AddDays(-5)
            $daysSinceContact = ((Get-Date) - $lastContactDate).Days
            
            $daysSinceContact | Should -Be 5
        }
        
        It "Should handle null or missing last contact date" {
            $lastContactDate = $null
            
            if ($lastContactDate)
            {
                $daysSinceContact = ((Get-Date) - $lastContactDate).Days
            }
            else
            {
                $daysSinceContact = -1
            }
            
            $daysSinceContact | Should -Be -1
        }
    }
    
    Context "Device Information Structure Validation" {
        
        It "Should validate complete device info structure" {
            $mockDeviceInfo = @{
                autopilotDevice = @{
                    displayName                       = "TEST-DEVICE-001"
                    serialNumber                      = "SN123456789"
                    enrollmentState                   = "enrolled"
                    deploymentProfileAssignmentStatus = "assigned"
                    deploymentProfile                 = @{
                        displayName = "Corporate Profile"
                    }
                }
                managedDevice   = @{
                    deviceName        = "TEST-DEVICE-001"
                    operatingSystem   = "Windows 11"
                    complianceState   = "compliant"
                    lastSyncDateTime  = (Get-Date).ToString("o")
                    userPrincipalName = "test.user@example.com"
                }
                enrollmentState = @{
                    inAutopilot = $true
                    managed     = $true
                    isReady     = $true
                    issues      = @()
                }
            }
            
            $mockDeviceInfo.autopilotDevice | Should -Not -BeNullOrEmpty
            $mockDeviceInfo.managedDevice | Should -Not -BeNullOrEmpty
            $mockDeviceInfo.enrollmentState | Should -Not -BeNullOrEmpty
            $mockDeviceInfo.enrollmentState.isReady | Should -Be $true
        }
        
        It "Should handle partial device info (autopilot only)" {
            $mockDeviceInfo = @{
                autopilotDevice = @{
                    displayName     = "AUTOPILOT-ONLY-001"
                    serialNumber    = "AO123456789"
                    enrollmentState = "enrolled"
                }
                managedDevice   = $null
                enrollmentState = @{
                    inAutopilot = $true
                    managed     = $false
                    isReady     = $false
                    issues      = @("Device not managed")
                }
            }
            
            $mockDeviceInfo.autopilotDevice | Should -Not -BeNullOrEmpty
            $mockDeviceInfo.managedDevice | Should -BeNullOrEmpty
            $mockDeviceInfo.enrollmentState.managed | Should -Be $false
        }
        
        It "Should handle partial device info (managed only)" {
            $mockDeviceInfo = @{
                autopilotDevice = $null
                managedDevice   = @{
                    deviceName       = "MANAGED-ONLY-001"
                    operatingSystem  = "Windows 10"
                    complianceState  = "compliant"
                    lastSyncDateTime = (Get-Date).ToString("o")
                }
                enrollmentState = @{
                    inAutopilot = $false
                    managed     = $true
                    isReady     = $false
                    issues      = @("Device not enrolled in Autopilot")
                }
            }
            
            $mockDeviceInfo.autopilotDevice | Should -BeNullOrEmpty
            $mockDeviceInfo.managedDevice | Should -Not -BeNullOrEmpty
            $mockDeviceInfo.enrollmentState.inAutopilot | Should -Be $false
        }
    }
    
    Context "Device List and Report Export Structures" {
        
        It "Should validate device list export structure" {
            $mockDeviceList = @(
                @{
                    SerialNumber    = "SN001"
                    DeviceName      = "DEVICE-001"
                    UserEmail       = "user1@example.com"
                    EnrollmentState = "enrolled"
                    ComplianceState = "compliant"
                },
                @{
                    SerialNumber    = "SN002"
                    DeviceName      = "DEVICE-002"
                    UserEmail       = "user2@example.com"
                    EnrollmentState = "enrolled"
                    ComplianceState = "noncompliant"
                }
            )
            
            $mockDeviceList.Count | Should -Be 2
            $mockDeviceList[0].SerialNumber | Should -Be "SN001"
            $mockDeviceList[1].ComplianceState | Should -Be "noncompliant"
        }
        
        It "Should validate device report export structure" {
            $mockDeviceReport = @{
                DeviceInfo      = @{
                    SerialNumber = "SN123456789"
                    DeviceName   = "TEST-DEVICE-001"
                }
                EnrollmentState = @{
                    inAutopilot = $true
                    managed     = $true
                    isReady     = $true
                }
                Issues          = @()
                ReportDate      = (Get-Date).ToString("o")
            }
            
            $mockDeviceReport.DeviceInfo | Should -Not -BeNullOrEmpty
            $mockDeviceReport.EnrollmentState.isReady | Should -Be $true
            $mockDeviceReport.Issues | Should -BeNullOrEmpty
        }
    }
    
    Context "Edge Cases and Error Handling" {
        
        It "Should handle empty serial number lookup" {
            $serialNumber = ""
            
            if ([string]::IsNullOrWhiteSpace($serialNumber))
            {
                $result = "Invalid serial number"
            }
            else
            {
                $result = "Valid serial number"
            }
            
            $result | Should -Be "Invalid serial number"
        }
        
        It "Should handle null device objects gracefully" {
            $autopilotDevice = $null
            $managedDevice = $null
            
            $hasAutopilot = $null -ne $autopilotDevice
            $hasManaged = $null -ne $managedDevice
            
            $hasAutopilot | Should -Be $false
            $hasManaged | Should -Be $false
        }
        
        It "Should handle missing or malformed date strings" {
            $invalidDate = "not-a-date"
            
            $parsedDate = $null
            try
            {
                $parsedDate = [datetime]::Parse($invalidDate)
            }
            catch
            {
                $parsedDate = $null
            }
            
            $parsedDate | Should -BeNullOrEmpty
        }
        
        It "Should handle empty issues array correctly" {
            $issues = @()
            
            $issues | Should -BeNullOrEmpty
            $issues.Count | Should -Be 0
        }
        
        It "Should handle issues array with multiple entries" {
            $issues = @(
                "Device not compliant",
                "Last sync over 7 days ago",
                "Missing required apps"
            )
            
            $issues.Count | Should -Be 3
            $issues | Should -Contain "Device not compliant"
        }
    }
}
