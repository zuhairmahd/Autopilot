<#
.SYNOPSIS
    Comprehensive Pester tests for GetManagedDeviceRelevantProperties function

.DESCRIPTION
    Tests the managed device properties retrieval function covering:
    - Device registration to users
    - Same-user device detection
    - Orphan device detection
    - RAM validation
    - User association checks
    - Readiness assessment for next user

.NOTES
    Test Category: Unit
    Dependencies: GetManagedDeviceRelevantProperties, AutopilotGraphMocks module
#>

Describe "GetManagedDeviceRelevantProperties Function" -Tags 'Unit', 'DeviceManagement', 'Readiness' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Import helper modules
        Import-Module (Join-Path $PSScriptRoot "../Helpers/AutopilotTestHelpers.psm1") -Force
        
        # Load required utility functions
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Write-Log.ps1")
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/ConvertUserDisplayName.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/FormatDateWithTimeZone.ps1")
        
        # Load the function being tested
        . (Join-Path $script:RepoRoot "functions/reportingFunctions/GetManagedDeviceRelevantProperties.ps1")
        
        # Setup test log file
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-managed-device-properties.log"
        
        # Initialize test settings
        $script:testSettings = @{
            MinimumDevicePhysicalMemoryInGB = 16
        }
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $global:LogFile)
        {
            Remove-Item $global:LogFile -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    
    Context "Device with sufficient RAM and no user" {
        
        It "Should mark device as ready when RAM is sufficient and no user assigned" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = $null
                    }
                    memory = 16
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.OrphanDevice | Should -Be $false
            $result.CorrectRam | Should -Be $true
            $result.HasUser | Should -Be $false
            $result.ReadyForNextUser | Should -Be $true
        }
        
        It "Should mark device as not ready when RAM is insufficient" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = $null
                    }
                    memory = 8
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.CorrectRam | Should -Be $false
            $result.ReadyForNextUser | Should -Be $false
        }
    }
    
    Context "Device registered to a user" {
        
        It "Should detect device has a user when userId is present" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = "user-456"
                    }
                    memory = 16
                    users  = @{
                        userDisplayName   = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser         = $true
                        user              = @{
                            givenName = "John"
                        }
                        lastLogOnDateTime = $null
                    }
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.HasUser | Should -Be $true
            $result.ValidUser | Should -Be $true
            $result.ReadyForNextUser | Should -Be $false
        }
        
        It "Should detect same-user device when username matches" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = "user-456"
                    }
                    memory = 16
                    users  = @{
                        userDisplayName   = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser         = $true
                        user              = @{
                            givenName = "John"
                        }
                        lastLogOnDateTime = $null
                    }
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings -username "john.doe@contoso.com"
            
            $result.HasUser | Should -Be $true
            $result.ValidUser | Should -Be $true
            $result.RegisteredToSameUser | Should -Be $true
        }
        
        It "Should not detect same-user when username does not match" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = "user-456"
                    }
                    memory = 16
                    users  = @{
                        userDisplayName   = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser         = $true
                        user              = @{
                            givenName = "John"
                        }
                        lastLogOnDateTime = $null
                    }
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings -username "jane.smith@contoso.com"
            
            $result.HasUser | Should -Be $true
            $result.ValidUser | Should -Be $true
            $result.RegisteredToSameUser | Should -Be $false
        }
        
        It "Should handle missing username parameter gracefully" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = "user-456"
                    }
                    memory = 16
                    users  = @{
                        userDisplayName   = "John Doe"
                        userPrincipalName = "john.doe@contoso.com"
                        azureUser         = $true
                        user              = @{
                            givenName = "John"
                        }
                        lastLogOnDateTime = $null
                    }
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.RegisteredToSameUser | Should -Be $false
        }
        
        It "Should detect invalid user when azureUser is false" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = "user-456"
                    }
                    memory = 16
                    users  = @{
                        userDisplayName   = "Unknown User"
                        userPrincipalName = "unknown@contoso.com"
                        azureUser         = $false
                        user              = @{
                            givenName = "Unknown"
                        }
                    }
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.HasUser | Should -Be $true
            $result.ValidUser | Should -Be $false
            $result.ReadyForNextUser | Should -Be $false
        }
    }
    
    Context "Orphan device detection" {
        
        It "Should detect orphan device when IDs do not match" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = $null
                    }
                    memory = 16
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-456"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.OrphanDevice | Should -Be $true
            $result.ReadyForNextUser | Should -Be $false
        }
        
        It "Should not detect orphan when IDs match" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = $null
                    }
                    memory = 16
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.OrphanDevice | Should -Be $false
        }
    }
    
    Context "Non-managed device handling" {
        
        It "Should handle non-managed device with default values" {
            $enrollmentState = @{
                managed       = $false
                managedDevice = $null
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            # Verify all default values are set correctly
            $result.OrphanDevice | Should -Be $true
            $result.CorrectRam | Should -Be $false
            $result.HasUser | Should -Be $false
            $result.ValidUser | Should -Be $false
            $result.LastLogonDate | Should -BeNullOrEmpty
            $result.ReadyForNextUser | Should -Be $false
            $result.RegisteredToSameUser | Should -Be $false
        }
        
        It "Should handle non-managed device without errors" {
            $enrollmentState = @{
                managed = $false
            }
            
            { GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings } | Should -Not -Throw
        }
        
        It "Should return all required properties for non-managed device" {
            $enrollmentState = @{
                managed       = $false
                managedDevice = $null
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            # Verify structure is complete
            $result.Keys | Should -Contain 'OrphanDevice'
            $result.Keys | Should -Contain 'CorrectRam'
            $result.Keys | Should -Contain 'HasUser'
            $result.Keys | Should -Contain 'ValidUser'
            $result.Keys | Should -Contain 'LastLogonDate'
            $result.Keys | Should -Contain 'ReadyForNextUser'
            $result.Keys | Should -Contain 'RegisteredToSameUser'
        }
        
        It "Should handle non-managed device with username parameter" {
            $enrollmentState = @{
                managed       = $false
                managedDevice = $null
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings -username "john.doe@contoso.com"
            
            # Username should not affect non-managed device behavior
            $result.RegisteredToSameUser | Should -Be $false
            $result.HasUser | Should -Be $false
        }
        
        It "Should not be ready for next user when device is not managed" {
            $enrollmentState = @{
                managed = $false
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            # Non-managed devices should never be ready for next user
            $result.ReadyForNextUser | Should -Be $false
        }
        
        It "Should ensure all boolean variables are defined for non-managed device" {
            $enrollmentState = @{
                managed = $false
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            # Verify no null boolean values (all should be true or false)
            $result.OrphanDevice | Should -BeOfType [bool]
            $result.CorrectRam | Should -BeOfType [bool]
            $result.HasUser | Should -BeOfType [bool]
            $result.ValidUser | Should -BeOfType [bool]
            $result.ReadyForNextUser | Should -BeOfType [bool]
            $result.RegisteredToSameUser | Should -BeOfType [bool]
        }
    }
    
    Context "Return value structure" {
        
        It "Should return all required properties" {
            $enrollmentState = @{
                managed       = $true
                managedDevice = @{
                    device = @{
                        id     = "device-123"
                        userId = $null
                    }
                    memory = 16
                }
                autopilot     = @{
                    device = @{
                        managedDeviceId = "device-123"
                    }
                }
            }
            
            $result = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $script:testSettings
            
            $result.Keys | Should -Contain 'OrphanDevice'
            $result.Keys | Should -Contain 'CorrectRam'
            $result.Keys | Should -Contain 'HasUser'
            $result.Keys | Should -Contain 'ValidUser'
            $result.Keys | Should -Contain 'LastLogonDate'
            $result.Keys | Should -Contain 'ReadyForNextUser'
            $result.Keys | Should -Contain 'RegisteredToSameUser'
        }
    }
}
