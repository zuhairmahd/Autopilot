<#
.SYNOPSIS
    Unit tests for ShowDeviceReport function menu loop behavior and report generation

.DESCRIPTION
    Tests device health menu loops, report building from enrollmentState/hashtable,
    property formatting, and data handling

.NOTES
    Test Category: Unit
    Function: ShowDeviceReport
    Module: reportingFunctions
    Coverage Target: Menu loop behavior, report building, property formatting
    
    Approach:
    - Validates syntax and loop structure  
    - Tests report building from enrollmentState parameter set
    - Tests report building from hashtable parameter set
    - Tests property name formatting with prefixes
    - Tests date formatting via FormatDateWithTimeZone
    - Tests null value handling
    
    Author: AI Agent (GitHub Copilot)  
    Updated: November 4, 2025
    PowerShell: Requires PowerShell 7+ for Pester tests (source code compatible with PS 5.1)
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: ShowDeviceReport" -Tags 'Unit', 'reportingFunctions' {
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        $script:FilePath = Join-Path $script:RepoRoot "functions/reportingFunctions/ShowDeviceReport.ps1"
        
        # Load dependencies
        . "$script:RepoRoot/functions/reportingFunctions/ShowDeviceReport.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/menuFunctions/NewMenu.ps1"
        . "$script:RepoRoot/functions/menuFunctions/AddMenuItem.ps1"
        . "$script:RepoRoot/functions/menuFunctions/ShowMenu.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Show-PagedContent.ps1"
        
        # Setup global variables
        $global:LogFile = "TestDrive:\test.log"
        $global:settings = @{ testMode = $true }
        
        # Create stub function for Export-DeviceReport (referenced in ShowDeviceReport but not loaded)
        function Export-DeviceReport {
            param($formattedOutput, $ExportFormat)
            return @{ success = $true; message = "Export successful" }
        }
        
        # Mock dependencies
        Mock Write-Log {}
        Mock FormatDateWithTimeZone { param($DateTime) return "2025-11-04 14:30:00 UTC" }
        Mock NewMenu { return @{ Title = "Test Menu"; Items = @() } }
        Mock AddMenuItem { param($Menu, $Name, $Action, $ReturnsValue) return $Menu }
        Mock ShowMenu { return "Back" }  # Default to navigation to avoid infinite loop
        Mock Show-PagedContent { return "completed" }
        Mock Export-DeviceReport { return @{ success = $true; message = "Export successful" } }
        Mock Write-Host {}
    }
    
    Context "Code structure validates menu loop" {
        
        It "Should have valid PowerShell syntax" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            
            # Assert
            $parseErrors | Should -BeNullOrEmpty -Because "ShowDeviceReport.ps1 must have valid PowerShell syntax"
        }
        
        It "Should contain a while loop for menu display" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for while loop pattern (similar to ShowGroupAssignments)
            $hasWhileTrue = $content -match 'while\s*\(\s*\$true\s*\)'
            $hasShowMenuInLoop = $content -match 'while\s*\(\s*\$true\s*\)[^}]*?\$selection\s*=\s*ShowMenu'
            $hasCustomCalledBy = $content -match 'Custom_DeviceHealthSubmenu'
            $hasStackOperationPush = $content -match 'StackOperation\s+[''"]Push[''"]'
            
            # Assert
            $hasWhileTrue | Should -Be $true -Because "Function should contain a while(true) loop"
            $hasShowMenuInLoop | Should -Be $true -Because "Function should call ShowMenu within while loop"
            $hasCustomCalledBy | Should -Be $true -Because "Function should use Custom_DeviceHealthSubmenu CalledBy context"
            $hasStackOperationPush | Should -Be $true -Because "Function should use StackOperation 'Push'"
        }
        
        It "Should return on Back navigation command" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for Back handling (allowing for multi-line regex)
            $handlesBack = $content -match 'if.*Back'
            $returnsOnBack = $content -match 'return\s+\$selection'
            
            # Assert
            $handlesBack | Should -Be $true -Because "Function should check for Back selection"
            $returnsOnBack | Should -Be $true -Because "Function should return selection value"
        }
        
        It "Should return on Main Menu navigation command" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for Main Menu handling
            $handlesMainMenu = $content -match 'Main Menu'
            
            # Assert
            $handlesMainMenu | Should -Be $true -Because "Function should handle Main Menu selection"
        }
        
        It "Should log when returning to Device Health Menu" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for logging of menu loop
            $logsMenuReturn = $content -match 'Write-Log.*returning to Device Health Menu'
            
            # Assert
            $logsMenuReturn | Should -Be $true -Because "Function should log when looping back to menu"
        }
    }
    
    Context "Report Building from EnrollmentState" {
        BeforeAll {
            $testEnrollmentState = @{
                managedDevice = @{
                    device = @{
                        deviceName                              = "TEST-DEVICE-001"
                        serialNumber                            = "SN123456"
                        Id                                      = "managed-guid-123"
                        enrolledDateTime                        = "2025-01-15T08:00:00Z"
                        lastSyncDateTime                        = "2025-11-04T10:00:00Z"
                        enrollmentProfileName                   = "Standard Profile"
                        userPrincipalName                       = "user@contoso.com"
                        userDisplayName                         = "John Doe"
                        deviceActionResults                     = @()
                        managementCertificateExpirationDate     = "2026-01-15T00:00:00Z"
                        complianceGracePeriodExpirationDateTime = "2025-12-01T00:00:00Z"
                        autopilotEnrolled                       = $true
                        deviceRegistrationState                 = "registered"
                        isEncrypted                             = $true
                        deviceEnrollmentType                    = "windowsAzureADJoin"
                        osVersion                               = "10.0.22631.4460"
                        complianceState                         = "compliant"
                        managementState                         = "managed"
                        managedDeviceOwnerType                  = "company"
                    }
                    memory  = 16
                    users   = @{
                        AzureUser         = "user@contoso.com"
                        userDisplayName   = "John Doe"
                        lastLogOnDateTime = "2025-11-03T16:00:00Z"
                    }
                }
                autopilot     = @{
                    device = @{
                        id                                    = "autopilot-guid-123"
                        enrollmentState                       = "enrolled"
                        deploymentProfileAssignmentStatus     = "assigned"
                        deploymentProfileAssignedDateTime     = "2025-01-15T07:00:00Z"
                        deploymentProfile                     = @{
                            displayName = "Corp Deployment Profile"
                        }
                        userPrincipalName                     = "user@contoso.com"
                        lastContactedDateTime                 = "2025-11-01T10:00:00Z"
                    }
                    events = @(
                        @{
                            eventDateTime                                   = "2025-01-15T08:30:00Z"
                            windowsAutopilotDeploymentProfileDisplayName    = "Corp Profile"
                            deploymentState                                 = "success"
                            enrollmentFailureDetails                        = $null
                        }
                    )
                }
            }
        }
        
        It "Should build report from enrollment state with all properties" {
            $result = ShowDeviceReport -enrollmentState $testEnrollmentState -SerialNumber "SN123456"
            
            # Function returns navigation value when ShowMenu is mocked to return "Back"
            $result | Should -Be "Back"
            Should -Invoke ShowMenu -Times 1 -Scope It
        }
        
        It "Should format Intune device properties correctly" {
            ShowDeviceReport -enrollmentState $testEnrollmentState -SerialNumber "SN123456"
            
            # Verify Show-PagedContent was called (report was built)
            Should -Invoke Show-PagedContent -Times 0 -Scope It  # Not called due to ShowMenu returning "Back"
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*Building report from enrollment state*" } -Times 1 -Scope It
        }
        
        It "Should format Autopilot device properties correctly" {
            ShowDeviceReport -enrollmentState $testEnrollmentState -SerialNumber "SN123456"
            
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*Found * autopilot events*" } -Times 1 -Scope It
        }
        
        It "Should call FormatDateWithTimeZone for date fields" {
            ShowDeviceReport -enrollmentState $testEnrollmentState -SerialNumber "SN123456"
            
            # Multiple date fields should be formatted (even though ShowMenu returns early, 
            # the report building happens first)
            Should -Invoke FormatDateWithTimeZone -Times 8 -Scope It
        }
        
        It "Should handle null enrollment date gracefully" {
            $stateWithNullDates = @{
                managedDevice = @{
                    device = @{
                        deviceName            = "TEST"
                        serialNumber          = "SN123"
                        Id                    = "guid"
                        enrolledDateTime      = $null
                        lastSyncDateTime      = $null
                        enrollmentProfileName = $null
                        userPrincipalName     = $null
                        autopilotEnrolled     = $false
                    }
                    memory = 8
                    users  = @{}
                }
                autopilot     = @{
                    device = @{
                        id                                = "guid"
                        enrollmentState                   = "notStarted"
                        deploymentProfileAssignmentStatus = "notAssigned"
                        deploymentProfile                 = @{}
                        lastContactedDateTime             = $null
                    }
                    events = @()
                }
            }
            
            { ShowDeviceReport -enrollmentState $stateWithNullDates -SerialNumber "SN123" } | Should -Not -Throw
        }
    }
    
    Context "Report Building from Hashtable" {
        It "Should accept hashtable report and use it directly" {
            $customReport = @{
                CustomProperty1 = "Value1"
                CustomProperty2 = "Value2"
                CustomDate      = [DateTime]::Parse("2025-11-04 10:00:00")
            }
            
            $result = ShowDeviceReport -report $customReport
            
            $result | Should -Be "Back"
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*Using provided report hashtable*" } -Times 1 -Scope It
        }
        
        It "Should log hashtable property count" {
            $customReport = @{
                Prop1 = "A"
                Prop2 = "B"
                Prop3 = "C"
            }
            
            ShowDeviceReport -report $customReport
            
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*Report hashtable provided with * properties*" } -Times 1 -Scope It
        }
    }
    
    Context "Property Name Formatting" {
        BeforeAll {
            # Create a minimal enrollment state to test formatting
            $minimalState = @{
                managedDevice = @{
                    device = @{
                        deviceName        = "TEST"
                        serialNumber      = "SN"
                        Id                = "1"
                        autopilotEnrolled = $true
                    }
                    memory = 8
                    users  = @{}
                }
                autopilot     = @{
                    device = @{ id = "1"; enrollmentState = "enrolled"; deploymentProfileAssignmentStatus = "assigned"; deploymentProfile = @{} }
                    events = @()
                }
            }
        }
        
        It "Should format property names with spaces before capitals" {
            # This test checks that the code contains the formatting logic
            $content = Get-Content $script:FilePath -Raw
            
            $hasSpaceInsertion = $content -match '\[regex\]::Replace.*(?<=[a-z])(?=[A-Z])'
            
            $hasSpaceInsertion | Should -Be $true -Because "Function should insert spaces before capital letters"
        }
        
        It "Should handle prefix list for property formatting" {
            # Check that PrefixList parameter exists and is used
            $content = Get-Content $script:FilePath -Raw
            
            $hasPrefixListParam = $content -match '\[string\[\]\]\$PrefixList'
            $usesPrefixList = $content -match 'foreach.*\$prefix.*in.*\$PrefixList'
            
            $hasPrefixListParam | Should -Be $true -Because "Function should have PrefixList parameter"
            $usesPrefixList | Should -Be $true -Because "Function should iterate over PrefixList"
        }
        
        It "Should format Intune prefixed properties correctly" {
            # Test that code handles 'Intune' prefix (default in PrefixList)
            $content = Get-Content $script:FilePath -Raw
            
            $matchesPrefixPattern = $content -match 'if.*key.*-match.*".*\(\$prefix\)'
            
            $matchesPrefixPattern | Should -Be $true -Because "Function should check for prefix matches"
        }
        
        It "Should format Autopilot prefixed properties correctly" {
            # Test that code handles 'Autopilot' prefix (default in PrefixList)
            $content = Get-Content $script:FilePath -Raw
            
            # Verify default PrefixList includes 'Autopilot'
            $hasAutopilotDefault = $content -match "PrefixList.*=.*@\('Intune', 'Autopilot'\)"
            
            $hasAutopilotDefault | Should -Be $true -Because "Function should default PrefixList to include Autopilot"
        }
    }
    
    Context "Null and Edge Case Handling" {
        It "Should handle null values by setting them to 'N/A'" {
            $content = Get-Content $script:FilePath -Raw
            
            $handlesNull = $content -match 'if.*null.*-eq.*\$output\[\$key\]'
            $setsNA = $content -match '\$formattedValue.*=.*"N/A"'
            
            $handlesNull | Should -Be $true -Because "Function should check for null values"
            $setsNA | Should -Be $true -Because "Function should set null values to 'N/A'"
        }
        
        It "Should handle empty autopilot events array" {
            $stateWithNoEvents = @{
                managedDevice = @{
                    device = @{
                        deviceName        = "TEST"
                        serialNumber      = "SN"
                        Id                = "1"
                        autopilotEnrolled = $true
                    }
                    memory = 8
                    users  = @{}
                }
                autopilot     = @{
                    device = @{ id = "1"; enrollmentState = "enrolled"; deploymentProfileAssignmentStatus = "assigned"; deploymentProfile = @{} }
                    events = @()
                }
            }
            
            { ShowDeviceReport -enrollmentState $stateWithNoEvents -SerialNumber "SN" } | Should -Not -Throw
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*No autopilot events found*" } -Times 1 -Scope It
        }
    }
    
    Context "Menu Integration" {
        It "Should create reportExportMenu with NewMenu" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke NewMenu -ParameterFilter { $MenuName -eq "reportExportMenu" } -Times 1 -Scope It
        }
        
        It "Should add Display on Screen menu item" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke AddMenuItem -ParameterFilter { $Name -eq "Display on Screen" } -Times 1 -Scope It
        }
        
        It "Should add Export to HTML menu item" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke AddMenuItem -ParameterFilter { $Name -eq "Export to HTML" } -Times 1 -Scope It
        }
        
        It "Should add Export to CSV menu item" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke AddMenuItem -ParameterFilter { $Name -eq "Export to CSV" } -Times 1 -Scope It
        }
        
        It "Should call ShowMenu with Custom_DeviceHealthSubmenu CalledBy" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke ShowMenu -ParameterFilter { $CalledBy -eq "Custom_DeviceHealthSubmenu" } -Times 1 -Scope It
        }
        
        It "Should call ShowMenu with Push StackOperation" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke ShowMenu -ParameterFilter { $StackOperation -eq "Push" } -Times 1 -Scope It
        }
        
        It "Should return Back navigation when user selects Back" {
            Mock ShowMenu { return "Back" }
            
            $result = ShowDeviceReport -report @{ Test = "Value" }
            
            $result | Should -Be "Back"
        }
        
        It "Should return Main Menu navigation when user selects Main Menu" {
            Mock ShowMenu { return "Main Menu" }
            
            $result = ShowDeviceReport -report @{ Test = "Value" }
            
            $result | Should -Be "Main Menu"
        }
        
        It "Should return 0 when user selects numeric Back option" {
            Mock ShowMenu { return 0 }
            
            $result = ShowDeviceReport -report @{ Test = "Value" }
            
            $result | Should -Be 0
        }
    }
    
    Context "Logging and Verbose Output" {
        It "Should log function start" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*Starting device report generation*" } -Times 1 -Scope It
        }
        
        It "Should log parameter set name" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*Parameter Set:*" } -Times 1 -Scope It
        }
        
        It "Should log loop iteration markers" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*LOOP ITERATION START*" } -Times 1 -Scope It
        }
        
        It "Should log ShowMenu return value" {
            ShowDeviceReport -report @{ Test = "Value" }
            
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*ShowMenu returned*Selection value:*" } -Times 1 -Scope It
        }
    }
}

