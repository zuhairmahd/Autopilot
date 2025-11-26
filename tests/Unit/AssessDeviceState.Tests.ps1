<#
.SYNOPSIS
    Comprehensive Pester tests for AssessDeviceState function

.DESCRIPTION
    Tests the device state assessment function covering:
    - Next user readiness checks
    - Same-user device scenarios
    - Enrolled device readiness
    - NotContacted device readiness
    - Pending actions detection
    - Issue and action reporting

.NOTES
    Test Category: Unit
    Dependencies: AssessDeviceState, AutopilotTestHelpers module
#>

Describe "AssessDeviceState Function" -Tags 'Unit', 'DeviceManagement', 'Readiness' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Import helper modules
        Import-Module (Join-Path $PSScriptRoot "../Helpers/AutopilotTestHelpers.psm1") -Force
        
        # Load required utility functions
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Write-Log.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/FormatDateWithTimeZone.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/GetTimeZoneAbbreviation.ps1")
        
        # Load dependency functions
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/ConvertUserDisplayName.ps1")
        
        # Load the function being tested
        . (Join-Path $script:RepoRoot "functions/reportingFunctions/AssessDeviceState.ps1")
        
        # Setup test log file
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-assess-device-state.log"
        
        # Initialize global variables
        $global:maxJSONDepth = 20
        $global:deviceStates = @{
            ready = 'Ready'
            notReady = 'NotReady'
        }
        
        $global:deviceActions = @{
            none = 'None'
            turnOnDevice = 'Turn on the device'
            contactAdmin = 'Contact Administrator'
            WipeOrClean = 'Wipe or Clean Device'
            connectToNetwork = 'Connect to Network'
        }
        
        $global:returnValues = @{
            devicePendingActionsMessage = 'Device has pending actions'
        }
        
        # Mock accessToken
        $script:accessToken = "mock-token"
        
        # Initialize test settings
        $script:testSettings = @{
            MinimumDevicePhysicalMemoryInGB = 16
            includeEnrolledDevicesInNextUserReadiness = $true
        }
        
        # Mock dependency functions
        function global:GetAutopilotDeviceRelevantProperties
        {
            param($enrollmentState)
            return @{
                AutopilotAssignmentGood = $true
                CorrectProfile = $true
                ProfileAssigned = $true
                RemediationStateGood = $true
                EnrollmentStateGood = $true
            }
        }
        
        function global:GetManagedDeviceRelevantProperties
        {
            param($enrollmentState, $settings, $username)
            
            $hasUser = $enrollmentState.managedDevice.device.userId -ne $null -and $enrollmentState.managedDevice.device.userId -ne ''
            $validUser = if ($hasUser) { $enrollmentState.managedDevice.users.azureUser } else { $false }
            $registeredToSameUser = if ($username -and $hasUser) { 
                $enrollmentState.managedDevice.users.userPrincipalName -eq $username 
            } else { 
                $false 
            }
            
            return @{
                OrphanDevice = $false
                CorrectRam = $true
                HasUser = $hasUser
                ValidUser = $validUser
                ReadyForNextUser = (-not $hasUser)
                RegisteredToSameUser = $registeredToSameUser
            }
        }
        
        function global:GetLastDeviceContactDate
        {
            param($accessToken, $enrollmentState)
            return @{
                withinThreshold = $true
                latestContactDate = (Get-Date)
                numberOfDaysSinceLastContact = 1
            }
        }
        
        function global:getDevicePendingActions
        {
            param($enrollmentState)
            
            $hasPending = $enrollmentState.managedDevice.pendingActions.value.Count -gt 0
            return @{
                IsPendingAction = $hasPending
                PendingActions = $enrollmentState.managedDevice.pendingActions.value
            }
        }
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $global:LogFile)
        {
            Remove-Item $global:LogFile -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    
    Context "Same-user device scenarios" {
        
        It "Should mark device as ready when registered to same user and compliant" {
            $enrollmentState = @{
                inAutopilot = $true
                managed = $true
                autopilot = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        deploymentProfileAssignmentStatus = 'assignedInSync'
                        deploymentProfileAssignmentDetailedStatus = 'success'
                        remediationState = 'success'
                        managedDeviceId = "device-123"
                    }
                }
                managedDevice = @{
                    device = @{
                        id = "device-123"
                        userId = "user-456"
                        complianceState = 'compliant'
                    }
                    memory = 16
                    users = @{
                        userDisplayName = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser = $true
                        user = @{
                            givenName = "John"
                        }
                    }
                }
            }
            
            $result = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness' `
                -settings $script:testSettings -username "john.doe@contoso.com"
            
            $result.ReadinessState | Should -Be $global:deviceStates.ready
            $result.Action | Should -Be $global:deviceActions.none
            $result.IsReady | Should -Be $true
        }
        
        It "Should mark device as not ready when registered to same user but not compliant" {
            $enrollmentState = @{
                inAutopilot = $true
                managed = $true
                autopilot = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        deploymentProfileAssignmentStatus = 'assignedInSync'
                        deploymentProfileAssignmentDetailedStatus = 'success'
                        remediationState = 'success'
                        managedDeviceId = "device-123"
                    }
                }
                managedDevice = @{
                    device = @{
                        id = "device-123"
                        userId = "user-456"
                        complianceState = 'noncompliant'
                    }
                    memory = 16
                    users = @{
                        userDisplayName = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser = $true
                        user = @{
                            givenName = "John"
                        }
                    }
                }
            }
            
            $result = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness' `
                -settings $script:testSettings -username "john.doe@contoso.com"
            
            $result.ReadinessState | Should -Be $global:deviceStates.notReady
            $result.IsReady | Should -Be $false
        }
        
        It "Should mark device as not ready when registered to different user" {
            $enrollmentState = @{
                inAutopilot = $true
                managed = $true
                autopilot = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        deploymentProfileAssignmentStatus = 'assignedInSync'
                        deploymentProfileAssignmentDetailedStatus = 'success'
                        remediationState = 'success'
                        managedDeviceId = "device-123"
                    }
                }
                managedDevice = @{
                    device = @{
                        id = "device-123"
                        userId = "user-456"
                        complianceState = 'compliant'
                    }
                    memory = 16
                    users = @{
                        userDisplayName = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser = $true
                        user = @{
                            givenName = "John"
                        }
                    }
                }
            }
            
            $result = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness' `
                -settings $script:testSettings -username "jane.smith@contoso.com"
            
            $result.ReadinessState | Should -Be $global:deviceStates.notReady
            $result.IsReady | Should -Be $false
        }
        
        It "Should mark device as not ready when same-user device has pending actions" {
            $enrollmentState = @{
                inAutopilot = $true
                managed = $true
                autopilot = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        deploymentProfileAssignmentStatus = 'assignedInSync'
                        deploymentProfileAssignmentDetailedStatus = 'success'
                        remediationState = 'success'
                        managedDeviceId = "device-123"
                    }
                }
                managedDevice = @{
                    device = @{
                        id = "device-123"
                        userId = "user-456"
                        complianceState = 'compliant'
                    }
                    memory = 16
                    users = @{
                        userDisplayName = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser = $true
                        user = @{
                            givenName = "John"
                        }
                    }
                    pendingActions = @{
                        value = @(
                            @{
                                actionName = 'reboot'
                                actionState = 'pending'
                            }
                        )
                    }
                }
            }
            
            $result = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness' `
                -settings $script:testSettings -username "john.doe@contoso.com"
            
            $result.ReadinessState | Should -Be $global:deviceStates.notReady
            $result.IsReady | Should -Be $false
        }
    }
    
    Context "NotContacted device scenarios" {
        
        It "Should mark notContacted device as ready when properly configured" {
            $enrollmentState = @{
                inAutopilot = $true
                managed = $false
                autopilot = @{
                    device = @{
                        enrollmentState = 'notContacted'
                        deploymentProfileAssignmentStatus = 'assignedInSync'
                        deploymentProfileAssignmentDetailedStatus = 'success'
                        remediationState = 'success'
                    }
                }
            }
            
            $result = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness' `
                -settings $script:testSettings
            
            $result.ReadinessState | Should -Be $global:deviceStates.ready
            $result.Action | Should -Be $global:deviceActions.none
            $result.IsReady | Should -Be $true
        }
    }
    
    Context "Device not in Autopilot" {
        
        It "Should mark device as not ready when not in Autopilot" {
            $enrollmentState = @{
                inAutopilot = $false
                managed = $false
            }
            
            $result = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness' `
                -settings $script:testSettings
            
            $result.ReadinessState | Should -Be $global:deviceStates.notReady
            $result.Action | Should -Be $global:deviceActions.contactAdmin
            $result.IsReady | Should -Be $false
            $result.AllIssues | Should -Contain "The device is not registered in Autopilot."
        }
    }
    
    Context "Return value structure" {
        
        It "Should return all required properties" {
            $enrollmentState = @{
                inAutopilot = $true
                managed = $false
                autopilot = @{
                    device = @{
                        enrollmentState = 'notContacted'
                        deploymentProfileAssignmentStatus = 'assignedInSync'
                        deploymentProfileAssignmentDetailedStatus = 'success'
                        remediationState = 'success'
                    }
                }
            }
            
            $result = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness' `
                -settings $script:testSettings
            
            $result.Keys | Should -Contain 'ReadinessState'
            $result.Keys | Should -Contain 'Action'
            $result.Keys | Should -Contain 'Device'
            $result.Keys | Should -Contain 'AllIssues'
            $result.Keys | Should -Contain 'AllActions'
            $result.Keys | Should -Contain 'IssueCount'
            $result.Keys | Should -Contain 'IsReady'
        }
    }
}
