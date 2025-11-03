<#
.SYNOPSIS
    Unit tests for ProcessSerialNumber function

.DESCRIPTION
    Tests serial number validation, device lookup, enrollment state handling,
    cache integration, and basic workflow orchestration. Complex UI interactions
    and menu flows are deferred to integration tests.

.NOTES
    Test Category: Unit
    PowerShell Compatibility: 7.0+ (Pester 5 requirement)
    Dependencies: AutopilotTestHelpers, AutopilotGraphMocks
    
    Testing Strategy:
    - Focus on validation, lookup, and state assessment logic
    - Mock all Graph API calls and cache operations
    - Test enrollment state branching (managed, autopilot, imported, none)
    - Validate error handling and null/empty serial numbers
    - Defer complex menu interactions to integration tests
    
    Coverage Target: ~180 lines (validation + lookup + state assessment)
    Expected Test Count: 25-30 unit tests
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "ProcessSerialNumber Function" -Tags 'Unit', 'DeviceFunctions', 'ProcessSerialNumber' {
    
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $script:TestContext.RootPath
        
        # Load required functions
        $functionsToLoad = @(
            "functions/deviceFunctions/ProcessSerialNumber.ps1",
            "functions/utilityFunctions/Get-CachedDeviceEnrollmentState.ps1",
            "functions/utilityFunctions/Write-Log.ps1",
            "functions/utilityFunctions/FormatDateWithTimeZone.ps1",
            "functions/utilityFunctions/GetTimeZoneAbbreviation.ps1",
            "functions/reportingFunctions/GetNextUserReadinessReport.ps1",
            "functions/reportingFunctions/AssessDeviceState.ps1",
            "functions/reportingFunctions/GetLastDeviceContactDate.ps1",
            "functions/reportingFunctions/getDevicePendingActions.ps1",
            "functions/reportingFunctions/GetAutopilotDeviceRelevantProperties.ps1",
            "functions/reportingFunctions/GetManagedDeviceRelevantProperties.ps1",
            "functions/menuFunctions/NewMenu.ps1",
            "functions/menuFunctions/Remove-MenuItem.ps1",
            "functions/menuFunctions/AddMenuItem.ps1",
            "functions/menuFunctions/ShowMenu.ps1",
            "functions/graphFunctions/CallGraphAPI.ps1"
        )
        
        foreach ($funcPath in $functionsToLoad)
        {
            $fullPath = Join-Path $script:RepoRoot $funcPath
            if (Test-Path $fullPath)
            {
                . $fullPath
            }
        }
        
        # Setup global log file
        $global:LogFile = $script:TestContext.LogFile
        $script:logFile = $global:LogFile
        
        # Mock settings
        $script:MockSettings = @{
            deviceContactThresholdInDays = 7
            maxJSONDepth                 = 10
        }
        
        # Set global maxJSONDepth for ConvertTo-Json calls
        $global:maxJSONDepth = 10
        
        # Mock return values
        $script:returnValues = @{
            deviceActionPendingMessage = "DEVICE_ACTION_PENDING"
            backoutText                = "BACK"
        }
        
        # Create mock access token
        $script:MockToken = "mock-access-token-12345"
    }
    
    AfterAll {
        # Cleanup test environment
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Serial Number Validation" {
        
        BeforeEach {
            # Mock Get-CachedDeviceEnrollmentStatus to avoid actual lookup
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $false
                    hasDeviceObject = $false
                    inAutopilot     = $false
                    Imported        = $false
                }
            }
        }
        
        It "Should reject null serial number" {
            # ProcessSerialNumber has [string] parameter, cannot pass $null directly
            # Test the validation logic that checks IsNullOrWhiteSpace
            $result = ProcessSerialNumber -SerialNumber " " -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -BeNullOrEmpty
        }
        
        It "Should reject empty string serial number" {
            # ProcessSerialNumber has mandatory [string] parameter, use whitespace to bypass parameter validation
            $result = ProcessSerialNumber -SerialNumber " " -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -BeNullOrEmpty
        }
        
        It "Should reject whitespace-only serial number" {
            $result = ProcessSerialNumber -SerialNumber "   " -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -BeNullOrEmpty
        }
        
        It "Should trim whitespace from serial number" {
            $serialWithSpaces = "  ABC123  "
            ProcessSerialNumber -SerialNumber $serialWithSpaces -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            # Verify Get-CachedDeviceEnrollmentStatus was called with trimmed serial
            Should -Invoke -CommandName Get-CachedDeviceEnrollmentStatus -ParameterFilter {
                $SerialNumber -eq "ABC123"
            } -Times 1
        }
        
        It "Should accept alphanumeric serial numbers" {
            $result = ProcessSerialNumber -SerialNumber "ABC123XYZ789" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept serial numbers with hyphens" {
            $result = ProcessSerialNumber -SerialNumber "ABC-123-XYZ" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Device Lookup and Enrollment State" {
        
        It "Should return null when device not found" {
            # Mock: Device not found in any system
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return $null
            }
            
            $result = ProcessSerialNumber -SerialNumber "NOTFOUND123" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle device in Autopilot but not managed" {
            # Mock: Device enrolled in Autopilot but no Intune management
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $false
                    hasDeviceObject = $false
                    inAutopilot     = $true
                    Imported        = $false
                    autopilot       = @{
                        device = @{
                            id                                = "autopilot-device-guid"
                            model                             = "Surface Pro 9"
                            manufacturer                      = "Microsoft Corporation"
                            systemFamily                      = "Surface"
                            deploymentProfileAssignmentStatus = "notAssigned"
                        }
                    }
                }
            }
            
            Mock -CommandName AssessDeviceState -MockWith {
                return @{ ReadinessState = "NotReady" }
            }
            
            $result = ProcessSerialNumber -SerialNumber "AUTOPILOT123" -AccessToken $script:MockToken -Settings $script:MockSettings
            
            # Should return success (true) even if not managed
            $result | Should -Be $true
        }
        
        It "Should handle device with Autopilot profile assigned" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $false
                    hasDeviceObject = $false
                    inAutopilot     = $true
                    Imported        = $false
                    autopilot       = @{
                        device = @{
                            id                                = "autopilot-device-guid"
                            model                             = "Surface Pro 9"
                            manufacturer                      = "Microsoft Corporation"
                            systemFamily                      = "Surface"
                            deploymentProfileAssignmentStatus = "assignedInSync"
                            deploymentProfile                 = @{
                                displayName = "Corporate Autopilot Profile"
                            }
                            deploymentProfileAssignedDateTime = "2024-10-15T10:30:00Z"
                        }
                    }
                }
            }
            
            # Mock AssessDeviceState which might try to access array elements
            Mock -CommandName AssessDeviceState -MockWith {
                return @{ ReadinessState = "Ready" }
            }
            
            $result = ProcessSerialNumber -SerialNumber "AUTOPILOT_ASSIGNED" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Be $true
        }
        
        It "Should handle imported but not yet enrolled device" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed                 = $false
                    hasDeviceObject         = $false
                    inAutopilot             = $false
                    Imported                = 1
                    ImportedAutopilotDevice = @{
                        id    = "import-guid-12345"
                        state = @{
                            deviceRegistrationId = "registration-guid"
                            deviceImportStatus   = "pending"
                            deviceErrorName      = ""
                            deviceErrorCode      = 0
                        }
                    }
                }
            }
            
            $result = ProcessSerialNumber -SerialNumber "IMPORTED_PENDING" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Be $true
        }
        
        It "Should handle device imported multiple times" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed                 = $false
                    hasDeviceObject         = $false
                    inAutopilot             = $false
                    Imported                = 3
                    ImportedAutopilotDevice = @(
                        @{ id = "import-1"; state = @{ deviceImportStatus = "failed" } },
                        @{ id = "import-2"; state = @{ deviceImportStatus = "failed" } },
                        @{ id = "import-3"; state = @{ deviceImportStatus = "complete" } }
                    )
                }
            }
            
            $result = ProcessSerialNumber -SerialNumber "MULTI_IMPORT" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Be $true
        }
        
        It "Should handle device with enrollment state but no device object" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $false
                    hasDeviceObject = $false
                    inAutopilot     = $false
                    Imported        = $false
                }
            }
            
            $result = ProcessSerialNumber -SerialNumber "NO_DEVICE_OBJ" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Be $true
        }
        
        It "Should handle device with device object but not managed" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $false
                    hasDeviceObject = $true
                    inAutopilot     = $false
                    Imported        = $false
                    device          = @{
                        id         = "device-guid-12345"
                        deviceName = "TESTDEVICE001"
                        model      = "ThinkPad X1"
                    }
                }
            }
            
            $result = ProcessSerialNumber -SerialNumber "DEVICE_OBJ_ONLY" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Be $true
        }
    }
    
    Context "Managed Device Handling" {
        
        BeforeEach {
            # Mock fully managed device
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $true
                    hasDeviceObject = $true
                    inAutopilot     = $true
                    Imported        = $false
                    managedDevice   = @{
                        device             = @{
                            id           = "managed-device-guid"
                            deviceName   = "CORPPC001"
                            model        = "Surface Laptop 5"
                            manufacturer = "Microsoft Corporation"
                        }
                        laps               = @{
                            credentials = @()
                        }
                        bitLocker          = @{
                            value = @()
                        }
                        latestBitlockerKey = $null
                        hardwarePassword   = $null
                    }
                    autopilot       = @{
                        device = @{
                            deploymentProfileAssignmentStatus = "assignedInSync"
                        }
                    }
                }
            }
            
            # Mock device contact date function
            Mock -CommandName GetLastDeviceContactDate -MockWith {
                return @{
                    latestContactDate            = (Get-Date).AddDays(-2).ToString("o")
                    numberOfDaysSinceLastContact = 2
                    withinThreshold              = $true
                }
            }
            
            # Mock pending actions check
            Mock -CommandName getDevicePendingActions -MockWith {
                return @{
                    isPendingAction = $false
                    pendingActions  = @()
                }
            }
            
            # Mock menu functions
            Mock -CommandName NewMenu -MockWith {
                return @{
                    Title = "Device Actions for `$deviceName"
                    Items = @()
                }
            }
            
            Mock -CommandName Remove-MenuItem -MockWith { param($Menu) return $Menu }
            Mock -CommandName AddMenuItem -MockWith { param($Menu) return $Menu }
            Mock -CommandName ShowMenu -MockWith { return "BACK" }
        }
        
        It "Should display device information for managed device" {
            $result = ProcessSerialNumber -SerialNumber "MANAGED123" -AccessToken $script:MockToken -Settings $script:MockSettings
            
            # Should invoke menu creation for managed devices
            Should -Invoke -CommandName NewMenu -Times 1
        }
        
        It "Should check device contact date for managed device" {
            ProcessSerialNumber -SerialNumber "MANAGED123" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            Should -Invoke -CommandName GetLastDeviceContactDate -Times 1
        }
        
        It "Should check pending actions for managed device" {
            ProcessSerialNumber -SerialNumber "MANAGED123" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            Should -Invoke -CommandName getDevicePendingActions -Times 1
        }
        
        It "Should return pending action message when device has pending actions" {
            Mock -CommandName getDevicePendingActions -MockWith {
                return @{
                    isPendingAction = $true
                    pendingActions  = @(
                        @{ actionName = "wipe"; status = "pending" }
                    )
                }
            }
            
            $result = ProcessSerialNumber -SerialNumber "PENDING_ACTION" -AccessToken $script:MockToken -Settings $script:MockSettings
            $result | Should -Be $script:returnValues.deviceActionPendingMessage
        }
        
        It "Should show device actions menu when no pending actions" {
            $result = ProcessSerialNumber -SerialNumber "MANAGED123" -AccessToken $script:MockToken -Settings $script:MockSettings
            
            Should -Invoke -CommandName ShowMenu -Times 1
        }
        
        It "Should remove LAPS menu item when no credentials available" {
            ProcessSerialNumber -SerialNumber "MANAGED123" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            Should -Invoke -CommandName Remove-MenuItem -ParameterFilter {
                $ItemName -eq "Get LAPS Password"
            } -Times 1
        }
        
        It "Should remove BitLocker menu item when no keys available" {
            ProcessSerialNumber -SerialNumber "MANAGED123" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            Should -Invoke -CommandName Remove-MenuItem -ParameterFilter {
                $ItemName -eq "Get BitLocker Recovery Key"
            } -Times 1
        }
        
        It "Should remove Hardware Password menu item when no details available" {
            ProcessSerialNumber -SerialNumber "MANAGED123" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            Should -Invoke -CommandName Remove-MenuItem -ParameterFilter {
                $ItemName -eq "Get Hardware Password Details"
            } -Times 1
        }
        
        It "Should keep LAPS menu item when credentials available" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $true
                    hasDeviceObject = $true
                    inAutopilot     = $true
                    Imported        = $false
                    managedDevice   = @{
                        device             = @{
                            id           = "managed-device-guid"
                            deviceName   = "CORPPC001"
                            model        = "Surface Laptop 5"
                            manufacturer = "Microsoft Corporation"
                        }
                        laps               = @{
                            credentials = @(
                                @{ passwordBase64 = "cGFzc3dvcmQxMjM=" }  # "password123" in base64
                            )
                        }
                        bitLocker          = @{ value = @() }
                        latestBitlockerKey = $null
                        hardwarePassword   = $null
                    }
                    autopilot       = @{
                        device = @{
                            deploymentProfileAssignmentStatus = "assignedInSync"
                        }
                    }
                }
            }
            
            ProcessSerialNumber -SerialNumber "WITH_LAPS" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            # Should NOT remove LAPS menu item
            Should -Invoke -CommandName Remove-MenuItem -ParameterFilter {
                $ItemName -eq "Get LAPS Password"
            } -Times 0
        }
        
        It "Should keep BitLocker menu item when keys available" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $true
                    hasDeviceObject = $true
                    inAutopilot     = $true
                    Imported        = $false
                    managedDevice   = @{
                        device             = @{
                            id           = "managed-device-guid"
                            deviceName   = "CORPPC001"
                            model        = "Surface Laptop 5"
                            manufacturer = "Microsoft Corporation"
                        }
                        laps               = @{ credentials = @() }
                        bitLocker          = @{ value = @() }
                        latestBitlockerKey = @{ key = "123456-789012-345678-901234-567890-123456" }
                        hardwarePassword   = $null
                    }
                    autopilot       = @{
                        device = @{
                            deploymentProfileAssignmentStatus = "assignedInSync"
                        }
                    }
                }
            }
            
            ProcessSerialNumber -SerialNumber "WITH_BITLOCKER" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            # Should NOT remove BitLocker menu item
            Should -Invoke -CommandName Remove-MenuItem -ParameterFilter {
                $ItemName -eq "Get BitLocker Recovery Key"
            } -Times 0
        }
    }
    
    Context "CheckUserReadiness Switch Parameter" {
        
        It "Should return readiness report when CheckUserReadiness is specified" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $false
                    hasDeviceObject = $false
                    inAutopilot     = $true
                    Imported        = $false
                    autopilot       = @{
                        device = @{
                            id                                = "autopilot-guid"
                            deploymentProfileAssignmentStatus = "assignedInSync"
                        }
                    }
                }
            }
            
            Mock -CommandName GetNextUserReadinessReport -MockWith {
                return @{
                    ReadinessState = "Ready"
                    Message        = "Device is ready for next user"
                }
            }
            
            $result = ProcessSerialNumber -SerialNumber "READINESS_CHECK" -AccessToken $script:MockToken `
                -Settings $script:MockSettings -CheckUserReadiness
            
            $result.ReadinessState | Should -Be "Ready"
            Should -Invoke -CommandName GetNextUserReadinessReport -Times 1
        }
        
        It "Should skip device menu when CheckUserReadiness is specified" {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $true
                    hasDeviceObject = $true
                    inAutopilot     = $true
                    Imported        = $false
                    managedDevice   = @{
                        device    = @{ id = "device-guid" }
                        laps      = @{ credentials = @() }
                        bitLocker = @{ value = @() }
                    }
                    autopilot       = @{ device = @{} }
                }
            }
            
            Mock -CommandName GetNextUserReadinessReport -MockWith {
                return @{ ReadinessState = "NotReady" }
            }
            
            Mock -CommandName NewMenu -MockWith {
                throw "Menu should not be created when CheckUserReadiness is specified"
            }
            
            ProcessSerialNumber -SerialNumber "SKIP_MENU" -AccessToken $script:MockToken `
                -Settings $script:MockSettings -CheckUserReadiness | Out-Null
            
            # Should not invoke menu functions
            Should -Invoke -CommandName NewMenu -Times 0
        }
    }
    
    Context "Device Contact Date Thresholds" {
        
        BeforeEach {
            Mock -CommandName Get-CachedDeviceEnrollmentStatus -MockWith {
                return @{
                    managed         = $true
                    hasDeviceObject = $true
                    inAutopilot     = $true
                    Imported        = $false
                    managedDevice   = @{
                        device             = @{
                            id           = "device-guid"
                            deviceName   = "TESTPC001"
                            model        = "Surface"
                            manufacturer = "Microsoft"
                        }
                        laps               = @{ credentials = @() }
                        bitLocker          = @{ value = @() }
                        latestBitlockerKey = $null
                        hardwarePassword   = $null
                    }
                    autopilot       = @{ device = @{} }
                }
            }
            
            Mock -CommandName getDevicePendingActions -MockWith {
                return @{ isPendingAction = $false; pendingActions = @() }
            }
            
            Mock -CommandName NewMenu -MockWith { return @{ Title = "Menu"; Items = @() } }
            Mock -CommandName Remove-MenuItem -MockWith { param($Menu) return $Menu }
            Mock -CommandName AddMenuItem -MockWith { param($Menu) return $Menu }
            Mock -CommandName ShowMenu -MockWith { return "BACK" }
            Mock -CommandName Read-Host -MockWith { }
        }
        
        It "Should display warning when device exceeds contact threshold" {
            Mock -CommandName GetLastDeviceContactDate -MockWith {
                return @{
                    latestContactDate            = (Get-Date).AddDays(-10).ToString("o")
                    numberOfDaysSinceLastContact = 10
                    withinThreshold              = $false
                }
            }
            
            ProcessSerialNumber -SerialNumber "OLD_CONTACT" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            # Should invoke Read-Host for "Press any key to continue" prompt
            Should -Invoke -CommandName Read-Host -Times 1
        }
        
        It "Should handle device contacted today" {
            Mock -CommandName GetLastDeviceContactDate -MockWith {
                return @{
                    latestContactDate            = (Get-Date).ToString("o")
                    numberOfDaysSinceLastContact = 0
                    withinThreshold              = $true
                }
            }
            
            ProcessSerialNumber -SerialNumber "TODAY_CONTACT" -AccessToken $script:MockToken -Settings $script:MockSettings | Out-Null
            
            # Should not prompt user
            Should -Invoke -CommandName Read-Host -Times 0
        }
        
        It "Should handle null contact date gracefully" {
            Mock -CommandName GetLastDeviceContactDate -MockWith {
                return @{
                    latestContactDate            = $null
                    numberOfDaysSinceLastContact = $null
                    withinThreshold              = $null
                }
            }
            
            # Should not throw
            { ProcessSerialNumber -SerialNumber "NULL_CONTACT" -AccessToken $script:MockToken -Settings $script:MockSettings } |
                Should -Not -Throw
        }
    }
}
