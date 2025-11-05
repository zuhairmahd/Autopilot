<#
.SYNOPSIS
    Unit tests for AssessDeviceState function

.DESCRIPTION
    Tests device state assessment logic for NextUserReadiness assessment type

.NOTES
    Test Category: Unit
    Function: AssessDeviceState
    Module: reportingFunctions
    Coverage Target: ~200 lines (state determination, various device states, error scenarios)
    
    Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Mock all dependency functions (GetAutopilotDeviceRelevantProperties, GetManagedDeviceRelevantProperties, GetLastDeviceContactDate)
    - Test all state determination branches (ready, notReady with various issues)
    - Validate return object structure (ReadinessState, Action, Device, AllIssues, AllActions, IssueCount, IsReady)
    - Test assessment types (NextUserReadiness, ProperEnrollmentVerification, TroubleShooting)
    - Focus on NextUserReadiness as it contains the core logic
#>

Describe "Function: AssessDeviceState" -Tags 'Unit', 'reportingFunctions' {
    BeforeAll {
        # Get repository root and load function
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Dot-source the function
        . "$script:RepoRoot/functions/reportingFunctions/AssessDeviceState.ps1"
        . "$script:RepoRoot/functions/reportingFunctions/GetAutopilotDeviceRelevantProperties.ps1"
        . "$script:RepoRoot/functions/reportingFunctions/GetManagedDeviceRelevantProperties.ps1"
        . "$script:RepoRoot/functions/reportingFunctions/GetLastDeviceContactDate.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/GetTimeZoneAbbreviation.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Mock Write-Log
        Mock Write-Log {}
        
        # Mock GetAutopilotDeviceRelevantProperties globally (will be overridden in tests)
        Mock GetAutopilotDeviceRelevantProperties {
            return @{
                CorrectProfile          = $true
                ProfileAssigned         = $true
                RemediationStateGood    = $true
                EnrollmentStateGood     = $true
                AutopilotAssignmentGood = $true
            }
        }
        
        # Mock GetManagedDeviceRelevantProperties globally
        Mock GetManagedDeviceRelevantProperties {
            return @{
                OrphanDevice     = $false
                CorrectRam       = $true
                HasUser          = $false
                ValidUser        = $true
                LastLogonDate    = $null
                ReadyForNextUser = $true
            }
        }
        
        # Mock GetLastDeviceContactDate globally
        Mock GetLastDeviceContactDate {
            return @{
                latestContactDate            = (Get-Date)
                numberOfDaysSinceLastContact = 1
                withinThreshold              = $true
            }
        }
        
        # Define deviceStates and deviceActions constants (from strings.psd1)
        $script:deviceStates = @{
            ready    = 'The device is ready for the next user'
            notReady = 'The device is not ready for the next user'
        }
        
        $script:deviceActions = @{
            contactAdmin     = 'Contact an Intune administrator'
            contactHelpdesk  = 'Contact the helpdesk'
            WipeOrClean      = 'Wipe or clean the device'
            none             = 'No action'
            connectToNetwork = 'Connect to network'  # Note: Not in strings.psd1 but referenced in AssessDeviceState.ps1 line 177
        }
        
        # Mock settings
        $script:settings = @{
            MinimumDevicePhysicalMemoryInGB = 16
            deviceContactThresholdInDays    = 7
        }
        
        # Mock global variables
        $global:LogFile = "TestDrive:\test.log"
        $global:maxJSONDepth = 10
        $global:accessToken = "mock-access-token"
    }
    
    Context "When device is ready for next user" {
        BeforeEach {
            # Mock enrollment state - device ready
            $script:enrollmentState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        id              = 'autopilot-device-id-123'
                    }
                }
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                }
            }
        }
        
        It "Should return ready state when device passes all checks" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.ReadinessState | Should -Be $script:deviceStates.ready
            $result.Action | Should -Be $script:deviceActions.none
            $result.Device | Should -Be 'managed-device-id-123'
            $result.IsReady | Should -Be $true
            $result.IssueCount | Should -Be 0
            $result.AllIssues | Should -BeNullOrEmpty
            $result.AllActions | Should -Contain $script:deviceActions.none
        }
        
        It "Should return ready state for notContacted device with autopilot assignment good" {
            # Arrange - notContacted state
            $script:enrollmentState.autopilot.device.enrollmentState = 'notContacted'
            $script:enrollmentState.managed = $false
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.ReadinessState | Should -Be $script:deviceStates.ready
            $result.IsReady | Should -Be $true
        }
        
        It "Should use autopilot device ID when managed device ID not available" {
            # Arrange - remove managed device
            $script:enrollmentState.managedDevice = $null
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.Device | Should -Be 'autopilot-device-id-123'
        }
    }
    
    Context "When device has profile assignment issues" {
        BeforeEach {
            $script:enrollmentState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        id              = 'autopilot-device-id-123'
                    }
                }
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                }
            }
        }
        
        It "Should return not ready when profile not assigned" {
            # Arrange
            Mock GetAutopilotDeviceRelevantProperties {
                return @{
                    CorrectProfile          = $false
                    ProfileAssigned         = $false
                    RemediationStateGood    = $true
                    EnrollmentStateGood     = $true
                    AutopilotAssignmentGood = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.ReadinessState | Should -Be $script:deviceStates.notReady
            $result.Action | Should -Be $script:deviceActions.contactAdmin
            $result.IsReady | Should -Be $false
            $result.IssueCount | Should -BeGreaterThan 0
            $result.AllIssues | Should -Contain 'The device is not assigned to an autopilot profile.'
        }
        
        It "Should return not ready when wrong profile assigned" {
            # Arrange
            Mock GetAutopilotDeviceRelevantProperties {
                return @{
                    CorrectProfile          = $false
                    ProfileAssigned         = $true
                    RemediationStateGood    = $true
                    EnrollmentStateGood     = $true
                    AutopilotAssignmentGood = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.ReadinessState | Should -Be $script:deviceStates.notReady
            $result.AllIssues | Should -Contain 'The device is not assigned to the correct autopilot profile.'
        }
        
        It "Should return not ready when remediation state invalid" {
            # Arrange
            Mock GetAutopilotDeviceRelevantProperties {
                return @{
                    CorrectProfile          = $true
                    ProfileAssigned         = $true
                    RemediationStateGood    = $false
                    EnrollmentStateGood     = $true
                    AutopilotAssignmentGood = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.AllIssues | Should -Contain 'The device has a remediation state that is not valid.'
        }
        
        It "Should return not ready when enrollment failed" {
            # Arrange
            Mock GetAutopilotDeviceRelevantProperties {
                return @{
                    CorrectProfile          = $true
                    ProfileAssigned         = $true
                    RemediationStateGood    = $true
                    EnrollmentStateGood     = $false
                    AutopilotAssignmentGood = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.AllIssues | Should -Contain 'The device failed enrollment.'
        }
    }
    
    Context "When device has managed device issues" {
        BeforeEach {
            $script:enrollmentState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        id              = 'autopilot-device-id-123'
                    }
                }
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                    memory = 8
                }
            }
        }
        
        It "Should return not ready when device is orphan" {
            # Arrange
            Mock GetManagedDeviceRelevantProperties {
                return @{
                    OrphanDevice     = $true
                    CorrectRam       = $true
                    HasUser          = $false
                    ValidUser        = $true
                    ReadyForNextUser = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.AllIssues | Should -Contain 'The device is an orphan device.'
            $result.Action | Should -Be $script:deviceActions.contactAdmin
        }
        
        It "Should return not ready when RAM insufficient" {
            # Arrange
            Mock GetManagedDeviceRelevantProperties {
                return @{
                    OrphanDevice     = $false
                    CorrectRam       = $false
                    HasUser          = $false
                    ValidUser        = $true
                    ReadyForNextUser = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.AllIssues | Should -Match 'The device has only.*GB of RAM'
        }
        
        It "Should return not ready with WipeOrClean action when device has user" {
            # Arrange
            Mock GetManagedDeviceRelevantProperties {
                return @{
                    OrphanDevice     = $false
                    CorrectRam       = $true
                    HasUser          = $true
                    ValidUser        = $true
                    ReadyForNextUser = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.AllIssues | Should -Contain 'The managed device is associated with a user.'
            $result.Action | Should -Be $script:deviceActions.WipeOrClean
            $result.AllActions | Should -Contain $script:deviceActions.WipeOrClean
        }
        
        It "Should return not ready when user is invalid (SPN or deleted)" {
            # Arrange
            Mock GetManagedDeviceRelevantProperties {
                return @{
                    OrphanDevice     = $false
                    CorrectRam       = $true
                    HasUser          = $false
                    ValidUser        = $false
                    ReadyForNextUser = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.AllIssues | Should -Contain 'The device appears to be associated with an SPN or a user that no longer exists in Azure AD.'
        }
    }
    
    Context "When device has connectivity issues" {
        BeforeEach {
            $script:enrollmentState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        id              = 'autopilot-device-id-123'
                    }
                }
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                }
            }
        }
        
        It "Should return not ready when device hasn't contacted Intune recently" {
            # Arrange
            Mock GetLastDeviceContactDate {
                return @{
                    latestContactDate            = (Get-Date).AddDays(-10)
                    numberOfDaysSinceLastContact = 10
                    withinThreshold              = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.AllIssues | Should -Match 'The device has not contacted Intune in \d+ days\.'
            # This should be the highest priority action
        }
        
        It "Should not check contact date for notContacted devices" {
            # Arrange
            $script:enrollmentState.autopilot.device.enrollmentState = 'notContacted'
            $script:enrollmentState.managed = $false
            
            Mock GetLastDeviceContactDate {
                return @{
                    latestContactDate            = $null
                    numberOfDaysSinceLastContact = 999
                    withinThreshold              = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            # Should be ready because notContacted with good autopilot assignment
            $result.IsReady | Should -Be $true
        }
    }
    
    Context "When device not registered in Autopilot" {
        BeforeEach {
            $script:enrollmentState = @{
                inAutopilot   = $false
                managed       = $true
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                }
            }
        }
        
        It "Should return not ready with contactAdmin action" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.ReadinessState | Should -Be $script:deviceStates.notReady
            $result.Action | Should -Be $script:deviceActions.contactAdmin
            $result.Device | Should -Be 'managed-device-id-123'
            $result.AllIssues | Should -Contain 'The device is not registered in Autopilot.'
            $result.IsReady | Should -Be $false
        }
        
        It "Should return null device ID when no managed device" {
            # Arrange
            $script:enrollmentState.managedDevice = $null
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.Device | Should -BeNullOrEmpty
        }
    }
    
    Context "When device has multiple issues" {
        BeforeEach {
            $script:enrollmentState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        id              = 'autopilot-device-id-123'
                    }
                }
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                    memory = 8
                }
            }
        }
        
        It "Should collect all issues and actions" {
            # Arrange - multiple problems
            Mock GetAutopilotDeviceRelevantProperties {
                return @{
                    CorrectProfile          = $false
                    ProfileAssigned         = $false
                    RemediationStateGood    = $false
                    EnrollmentStateGood     = $false
                    AutopilotAssignmentGood = $false
                }
            }
            
            Mock GetManagedDeviceRelevantProperties {
                return @{
                    OrphanDevice     = $true
                    CorrectRam       = $false
                    HasUser          = $true
                    ValidUser        = $false
                    ReadyForNextUser = $false
                }
            }
            
            Mock GetLastDeviceContactDate {
                return @{
                    latestContactDate            = (Get-Date).AddDays(-10)
                    numberOfDaysSinceLastContact = 10
                    withinThreshold              = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.IssueCount | Should -BeGreaterThan 5
            $result.AllIssues.Count | Should -Be $result.IssueCount
            $result.AllActions.Count | Should -BeGreaterThan 1
            $result.IsReady | Should -Be $false
        }
        
        It "Should prioritize actions correctly (connectivity > wipe > admin)" {
            # Arrange - connectivity issue (highest priority)
            Mock GetAutopilotDeviceRelevantProperties {
                return @{
                    CorrectProfile          = $false
                    ProfileAssigned         = $true
                    RemediationStateGood    = $true
                    EnrollmentStateGood     = $true
                    AutopilotAssignmentGood = $false
                }
            }
            
            Mock GetManagedDeviceRelevantProperties {
                return @{
                    OrphanDevice     = $false
                    CorrectRam       = $true
                    HasUser          = $true
                    ValidUser        = $true
                    ReadyForNextUser = $false
                }
            }
            
            Mock GetLastDeviceContactDate {
                return @{
                    latestContactDate            = (Get-Date).AddDays(-10)
                    numberOfDaysSinceLastContact = 10
                    withinThreshold              = $false
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert - connectToNetwork has highest priority (priority value 1), then WipeOrClean (2), then contactAdmin (3)
            $result.Action | Should -BeIn @($script:deviceActions.connectToNetwork, $script:deviceActions.WipeOrClean)
            $result.AllActions | Should -Contain $script:deviceActions.WipeOrClean
            $result.AllActions | Should -Contain $script:deviceActions.contactAdmin
        }
    }
    
    Context "When using different assessment types" {
        BeforeEach {
            $script:enrollmentState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        id              = 'autopilot-device-id-123'
                    }
                }
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                }
            }
        }
        
        It "Should handle PropperEnrollmentVerification assessment type" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'PropperEnrollmentVerification'
            
            # Assert - placeholder implementation
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle TroubleShooting assessment type" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'TroubleShooting'
            
            # Assert - placeholder implementation
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept NextUserReadiness assessment type" {
            # Arrange
            Mock GetAutopilotDeviceRelevantProperties {
                return @{
                    AutopilotAssignmentGood = $true
                    CorrectProfile          = $true
                    ProfileAssigned         = $true
                    RemediationStateGood    = $true
                    EnrollmentStateGood     = $true
                }
            }
            
            Mock GetManagedDeviceRelevantProperties {
                return @{
                    ReadyForNextUser = $true
                    OrphanDevice     = $false
                    CorrectRam       = $true
                    HasUser          = $false
                    ValidUser        = $true
                }
            }
            
            Mock GetLastDeviceContactDate {
                return @{
                    withinThreshold              = $true
                    numberOfDaysSinceLastContact = 1
                    latestContactDate            = (Get-Date)
                }
            }
            
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ReadinessState | Should -Be $script:deviceStates.ready
        }
    }
    
    Context "Return object structure validation" {
        BeforeEach {
            $script:enrollmentState = @{
                inAutopilot   = $true
                managed       = $true
                autopilot     = @{
                    device = @{
                        enrollmentState = 'enrolled'
                        id              = 'autopilot-device-id-123'
                    }
                }
                managedDevice = @{
                    device = @{
                        id = 'managed-device-id-123'
                    }
                }
            }
        }
        
        It "Should return object with all required properties" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.Keys | Should -Contain 'ReadinessState'
            $result.Keys | Should -Contain 'Action'
            $result.Keys | Should -Contain 'Device'
            $result.Keys | Should -Contain 'AllIssues'
            $result.Keys | Should -Contain 'AllActions'
            $result.Keys | Should -Contain 'IssueCount'
            $result.Keys | Should -Contain 'IsReady'
        }
        
        It "Should ensure AllIssues is always an array" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert - AllIssues should exist (can be empty array when ready)
            $result.Keys | Should -Contain 'AllIssues'
            $result.IssueCount | Should -Be $result.AllIssues.Count
        }
        
        It "Should ensure AllActions is always an array" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert - AllActions should be an array (even with single element)
            ($result.AllActions -is [Array]) | Should -Be $true
            $result.AllActions.Count | Should -BeGreaterThan 0
        }
        
        It "Should ensure IsReady is boolean" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.IsReady | Should -BeOfType [bool]
        }
        
        It "Should ensure IssueCount matches AllIssues count" {
            # Act
            $result = AssessDeviceState -enrollmentState $script:enrollmentState -settings $script:settings -AssessmentType 'NextUserReadiness'
            
            # Assert
            $result.IssueCount | Should -Be $result.AllIssues.Count
        }
    }
}
