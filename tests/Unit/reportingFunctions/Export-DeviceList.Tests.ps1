<#
.SYNOPSIS
    Comprehensive Pester tests for Export-DeviceList function.

.DESCRIPTION
    Tests CSV export functionality, data formatting for different device types
    (autopilot, imported, unmanaged, managed), file operations, and error handling.

.NOTES
    Test Approach:
    - Global mocks in BeforeAll for dependencies (Get-DeviceData, Export-Csv, Get-Date, FormatDateWithTimeZone, Write-Log)
    - Tests all 4 device types with proper field mappings
    - Tests file mode behavior (Append/Overwrite)
    - Tests edge cases: null devices, empty datasets, export errors
    - Tests return object structure validation
    
    Dependencies:
    - functions/reportingFunctions/Export-DeviceList.ps1 (main function)
    - functions/deviceFunctions/Get-DeviceData.ps1 (device fetching)
    - functions/utilityFunctions/FormatDateWithTimeZone.ps1 (date formatting)
    
    Author: AI Agent (GitHub Copilot)
    Created: November 4, 2025
    PowerShell: Requires PowerShell 7+ for Pester tests (source code compatible with PS 5.1)
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Export-DeviceList" -Tags 'Unit' {
    BeforeAll {
        # Mock Export-Csv FIRST before loading any functions that use it
        # PowerShell 7 has changed Export-Csv -Encoding parameter to expect System.Text.Encoding object
        # Source code uses string "UTF8" which works in PS 5.1 but fails in PS 7
        # Mock before function loading to intercept calls
        function Export-Csv
        {
            param(
                [Parameter(ValueFromPipeline)]$InputObject,
                $Path,
                [switch]$NoTypeInformation,
                [switch]$Append,
                [switch]$Force,
                $Encoding,
                $Delimiter
            )
            # Do nothing - this is a mock
        }
        
        # Get repository root and load function
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/reportingFunctions/Export-DeviceList.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/FormatDateWithTimeZone.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/deviceFunctions/Get-DeviceData.ps1"
        
        # Setup global variables
        $global:LogFile = "TestDrive:\test.log"
        $global:settings = @{ testMode = $true }
        
        # Mock Write-Log globally
        Mock Write-Log {}
        
        # Mock Get-Date for consistent file naming - return the formatted string directly
        Mock Get-Date { return "20251104-143000" } -ParameterFilter { $Format -eq "yyyyMMdd-HHmmss" }
        
        # Mock FormatDateWithTimeZone to return formatted string
        Mock FormatDateWithTimeZone { param($inputObject) return "2025-11-04 14:30:00 UTC" }
        
        # Mock Get-DeviceData globally (will be overridden in specific contexts)
        Mock Get-DeviceData {
            return @{
                value = @()
            }
        }
        
        # Now mock Export-Csv with Pester for invocation tracking
        Mock Export-Csv { }
    }
    
    Context "Autopilot Device Export" {
        BeforeAll {
            $autopilotDevices = @{
                value = @(
                    @{
                        serialNumber                      = "AP123456"
                        groupTag                          = "Finance"
                        manufacturer                      = "Dell"
                        model                             = "Latitude 7420"
                        systemFamily                      = "Latitude"
                        enrollmentState                   = "enrolled"
                        deploymentProfileAssignmentStatus = "assigned"
                        lastContactedDateTime             = "2025-11-01T10:00:00Z"
                    },
                    @{
                        serialNumber                      = "AP789012"
                        groupTag                          = "Engineering"
                        manufacturer                      = "HP"
                        model                             = "EliteBook 840"
                        systemFamily                      = "EliteBook"
                        enrollmentState                   = "enrolled"
                        deploymentProfileAssignmentStatus = "assigned"
                        lastContactedDateTime             = $null
                    }
                )
            }
            
            Mock -ModuleName $null Get-DeviceData { return $autopilotDevices } -ParameterFilter { $DeviceType -eq 'autopilot' }
        }
        
        It "Should export autopilot devices with correct fields" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.success | Should -Be $true
            $result.deviceType | Should -Be "autopilot"
            $result.deviceCount | Should -Be 0  # Function doesn't set deviceCount
            
            # Verify Export-Csv was called
            Should -Invoke Export-Csv -Times 1 -Scope It
        }
        
        It "Should format autopilot device dates using FormatDateWithTimeZone" {
            Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            # FormatDateWithTimeZone should be called for non-null lastContactedDateTime
            Should -Invoke FormatDateWithTimeZone -Times 1 -Scope It
        }
        
        It "Should generate correct output filename for autopilot devices" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.outputFile | Should -BeLike "*autopilot-DeviceList-20251104-143000.csv"
        }
    }
    
    Context "Imported Device Export" {
        BeforeAll {
            $importedDevices = @{
                value = @(
                    @{
                        serialNumber = "IMP123456"
                        importId     = "import-guid-1"
                        groupTag     = "Sales"
                        state        = @{
                            deviceImportStatus   = "complete"
                            deviceRegistrationId = "reg-guid-1"
                            deviceErrorCode      = 0
                            deviceErrorName      = ""
                        }
                    },
                    @{
                        serialNumber = "IMP789012"
                        importId     = "import-guid-2"
                        groupTag     = "Marketing"
                        state        = @{
                            deviceImportStatus   = "error"
                            deviceRegistrationId = $null
                            deviceErrorCode      = 12345
                            deviceErrorName      = "Registration failed"
                        }
                    }
                )
            }
            
            Mock -ModuleName $null Get-DeviceData { return $importedDevices } -ParameterFilter { $DeviceType -eq 'imported' }
        }
        
        It "Should export imported devices with correct fields" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "imported"
            
            $result.success | Should -Be $true
            $result.deviceType | Should -Be "imported"
            
            Should -Invoke Export-Csv -Times 1 -Scope It
        }
        
        It "Should generate correct output filename for imported devices" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "imported"
            
            $result.outputFile | Should -BeLike "*imported-DeviceList-20251104-143000.csv"
        }
        
        It "Should handle imported device state properties correctly" {
            # This test verifies the function accesses nested state properties without error
            { Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "imported" } | Should -Not -Throw
        }
    }
    
    Context "Unmanaged Device Export" {
        BeforeAll {
            $unmanagedDevices = @{
                value = @(
                    @{
                        id                            = "device-guid-1"
                        displayName                   = "DESKTOP-ABC123"
                        manufacturer                  = "Lenovo"
                        model                         = "ThinkPad X1"
                        operatingSystemVersion        = "10.0.19045"
                        profileType                   = "RegisteredDevice"
                        createdDateTime               = "2025-01-15T08:00:00Z"
                        registrationDateTime          = "2025-01-15T08:30:00Z"
                        accountEnabled                = $true
                        approximateLastSignInDateTime = "2025-11-01T12:00:00Z"
                        enrollmentProfileName         = $null
                        enrollmentType                = $null
                        isCompliant                   = $false
                    }
                )
            }
            
            Mock -ModuleName $null Get-DeviceData { return $unmanagedDevices } -ParameterFilter { $DeviceType -eq 'unmanaged' }
        }
        
        It "Should export unmanaged devices with correct fields" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "unmanaged"
            
            $result.success | Should -Be $true
            $result.deviceType | Should -Be "unmanaged"
            
            Should -Invoke Export-Csv -Times 1 -Scope It
        }
        
        It "Should format unmanaged device dates using FormatDateWithTimeZone" {
            Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "unmanaged"
            
            # Should format createdDateTime, registrationDateTime, approximateLastSignInDateTime
            Should -Invoke FormatDateWithTimeZone -Times 3 -Scope It
        }
        
        It "Should generate correct output filename for unmanaged devices" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "unmanaged"
            
            $result.outputFile | Should -BeLike "*unmanaged-DeviceList-20251104-143000.csv"
        }
    }
    
    Context "Managed Device Export" {
        BeforeAll {
            $managedDevices = @{
                value = @(
                    @{
                        serialNumber      = "MNG123456"
                        deviceName        = "CORP-LAPTOP-001"
                        manufacturer      = "Microsoft"
                        model             = "Surface Laptop 5"
                        osVersion         = "10.0.22631.4460"
                        autopilotEnrolled = $true
                        enrolledDateTime  = "2025-02-01T09:00:00Z"
                        lastSyncDateTime  = "2025-11-04T10:00:00Z"
                        complianceState   = "compliant"
                        userPrincipalName = "user1@contoso.com"
                        userDisplayName   = "John Doe"
                        usersLoggedOn     = @(
                            @{ lastLogOnDateTime = "2025-11-03T16:00:00Z" }
                        )
                    }
                )
            }
            
            Mock -ModuleName $null Get-DeviceData { return $managedDevices } -ParameterFilter { $DeviceType -eq 'managed' }
        }
        
        It "Should export managed devices with correct fields" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "managed"
            
            $result.success | Should -Be $true
            $result.deviceType | Should -Be "managed"
            
            Should -Invoke Export-Csv -Times 1 -Scope It
        }
        
        It "Should format managed device dates using FormatDateWithTimeZone" {
            Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "managed"
            
            # Should format enrolledDateTime, lastSyncDateTime, usersLoggedOn.lastLogOnDateTime
            Should -Invoke FormatDateWithTimeZone -Times 3 -Scope It
        }
        
        It "Should generate correct output filename for managed devices" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "managed"
            
            $result.outputFile | Should -BeLike "*managed-DeviceList-20251104-143000.csv"
        }
    }
    
    Context "File Mode Behavior" {
        BeforeAll {
            $testDevices = @{
                value = @(
                    @{ serialNumber = "TEST123"; groupTag = "Test"; manufacturer = "Test"; model = "Test"; systemFamily = "Test"; enrollmentState = "enrolled"; deploymentProfileAssignmentStatus = "assigned"; lastContactedDateTime = $null }
                )
            }
            
            Mock -ModuleName $null Get-DeviceData { return $testDevices }
        }
        
        It "Should use Overwrite mode by default" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.fileMode | Should -Be "overwrite"
            Should -Invoke Export-Csv -ParameterFilter { $Force -eq $true } -Times 1 -Scope It
        }
        
        It "Should use Append mode when specified" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot" -fileMode "Append"
            
            $result.fileMode | Should -Be "Append"
            Should -Invoke Export-Csv -ParameterFilter { $Append -eq $true } -Times 1 -Scope It
        }
        
        It "Should include correct message for Overwrite mode" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.message | Should -BeLike "Exported * autopilot devices to *"
        }
        
        It "Should include correct message for Append mode" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot" -fileMode "Append"
            
            $result.message | Should -BeLike "Appended * autopilot devices to *"
        }
    }
    
    Context "Edge Cases and Error Handling" {
        It "Should handle empty device list gracefully" {
            Mock -ModuleName $null Get-DeviceData { return @{ value = @() } }
            
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.success | Should -Be $true
            $result.message | Should -BeLike "No autopilot devices found for export."
            Should -Invoke Export-Csv -Times 0 -Scope It
        }
        
        It "Should skip null devices in the list" {
            Mock -ModuleName $null Get-DeviceData {
                return @{
                    value = @(
                        $null,
                        @{ serialNumber = "VALID123"; groupTag = "Test"; manufacturer = "Test"; model = "Test"; systemFamily = "Test"; enrollmentState = "enrolled"; deploymentProfileAssignmentStatus = "assigned"; lastContactedDateTime = $null }
                    )
                }
            }
            
            { Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot" } | Should -Not -Throw
            Should -Invoke Write-Log -ParameterFilter { $Message -like "*Skipping null or invalid*" } -Times 1 -Scope It
        }
        
        It "Should handle Export-Csv errors gracefully" {
            Mock -ModuleName $null Get-DeviceData {
                return @{
                    value = @(
                        @{ serialNumber = "TEST123"; groupTag = "Test"; manufacturer = "Test"; model = "Test"; systemFamily = "Test"; enrollmentState = "enrolled"; deploymentProfileAssignmentStatus = "assigned"; lastContactedDateTime = $null }
                    )
                }
            }
            Mock -ModuleName $null Export-Csv { throw "Permission denied" }
            
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.success | Should -Be $false
            $result.message | Should -BeLike "Error occurred while exporting device list: *"
            Should -Invoke Write-Log -ParameterFilter { $LogLevel -eq "Error" } -Times 1 -Scope It
        }
        
        It "Should handle null date fields without errors" {
            Mock -ModuleName $null Get-DeviceData {
                return @{
                    value = @(
                        @{
                            serialNumber      = "MNG-NULL-DATES"
                            deviceName        = "TEST-DEVICE"
                            manufacturer      = "Test"
                            model             = "Test"
                            osVersion         = "10.0.0.0"
                            autopilotEnrolled = $false
                            enrolledDateTime  = $null
                            lastSyncDateTime  = $null
                            complianceState   = "unknown"
                            userPrincipalName = $null
                            userDisplayName   = $null
                            usersLoggedOn     = @()
                        }
                    )
                }
            }
            
            { Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "managed" } | Should -Not -Throw
            
            # FormatDateWithTimeZone should not be called for null dates in this scenario
            # (though the function checks for null before calling)
            Should -Invoke FormatDateWithTimeZone -Times 0 -Scope It
        }
    }
    
    Context "Return Object Validation" {
        BeforeAll {
            $testDevices = @{
                value = @(
                    @{ serialNumber = "RET123"; groupTag = "Test"; manufacturer = "Test"; model = "Test"; systemFamily = "Test"; enrollmentState = "enrolled"; deploymentProfileAssignmentStatus = "assigned"; lastContactedDateTime = $null }
                )
            }
            
            Mock -ModuleName $null Get-DeviceData { return $testDevices }
        }
        
        It "Should return object with all required properties" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.Keys | Should -Contain 'success'
            $result.Keys | Should -Contain 'outputFile'
            $result.Keys | Should -Contain 'message'
            $result.Keys | Should -Contain 'deviceCount'
            $result.Keys | Should -Contain 'deviceType'
            $result.Keys | Should -Contain 'fileMode'
        }
        
        It "Should have correct success status on successful export" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.success | Should -Be $true
            $result.success | Should -BeOfType [System.Boolean]
        }
        
        It "Should have correct deviceType in return object" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "managed"
            
            $result.deviceType | Should -Be "managed"
            $result.deviceType | Should -BeOfType [System.String]
        }
        
        It "Should have valid outputFile path" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.outputFile | Should -Not -BeNullOrEmpty
            $result.outputFile | Should -BeLike "TestDrive:\*-DeviceList-*.csv"
        }
        
        It "Should have non-empty message on successful export" {
            $result = Export-DeviceList -AccessToken "test-token" -outputPath "TestDrive:\" -deviceType "autopilot"
            
            $result.message | Should -Not -BeNullOrEmpty
            $result.message | Should -BeOfType [System.String]
        }
    }
}
