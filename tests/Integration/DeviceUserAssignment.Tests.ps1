<#
.SYNOPSIS
    Integration tests for assigning users to Autopilot devices.

.DESCRIPTION
    Tests the device-user assignment functionality by calling ImportAutopilotDevice
    and verifying the assignment status using a mock Graph API backend.
    Addresses Phase 3 of the Pester Migration Plan.

.NOTES
    Test Category: Integration
    Template Compliance: Full
    Uses: AutopilotGraphMocks, AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Device User Assignment Integration" -Tags 'Integration', 'Device', 'User' {

    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $TestContext.RootPath

        # Load the function to be tested
        . (Join-Path $script:RepoRoot "functions/autopilotFunctions/v1/ImportAutopilotDevice.ps1")

        Initialize-GraphMockEnvironment -ClearCache

        # Add mock data for tests
        Add-MockDevice -SerialNumber "DEV-ASSIGN" -DeviceName "DeviceForAssignment" -Id "device-assign-01"
        Add-MockUser -UserPrincipalName "assign.user@contoso.com" -DisplayName "Assign User" -Id "user-assign-01" -GivenName "Assign" -Surname "User"

        # Mock the global CallGraphAPI function to use our enhanced mock
        function global:CallGraphAPI {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel, [string]$Method = 'GET', $Body = $null, [string]$apiVersion = 'v1.0')
            
            # The original mock didn't properly handle -Method and -Body, so we pass them through
            return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
                -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel `
                -Method $Method -Body $Body -apiVersion $apiVersion
        }

        $script:token = New-MockAuthToken
        $script:deviceToAssign = @{
            serialNumber = "DEV-ASSIGN"
            hardwareHash = "some-hash"
            manufacturer = "Test-Mfg"
            model        = "Test-Model"
        }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
    }

    BeforeEach {
        # Clear assignment state before each test
        Clear-MockDeviceAssignments
    }

    Context "Assign User to Device" {
        It "Should assign a user to a device during import" {
            # Arrange
            $userToAssign = "assign.user@contoso.com"

            # Act
            $result = ImportAutopilotDevice -AccessToken $script:token -DeviceObject $script:deviceToAssign -AssignedUser $userToAssign -CustomImport:$false

            # Assert
            $result | Should -Not -BeNull
            $result.assignedUserPrincipalName | Should -Be $userToAssign

            $assignedUser = Get-MockDeviceUserAssignments -DeviceId "device-assign-01"
            $assignedUser | Should -Be $userToAssign
        }
    }

    Context "Remove User from Device" {
        It "Should import a device with no user assigned" {
            # Arrange
            # First, assign a user so we can test removal
            Add-MockDeviceUserAssignment -DeviceId "device-assign-01" -UserId "assign.user@contoso.com"

            # Act: Import the same device with a blank user
            $result = ImportAutopilotDevice -AccessToken $script:token -DeviceObject $script:deviceToAssign -AssignedUser "" -CustomImport:$false

            # Assert
            $result | Should -Not -BeNull
            $result.assignedUserPrincipalName | Should -BeNullOrEmpty

            $assignedUser = Get-MockDeviceUserAssignments -DeviceId "device-assign-01"
            $assignedUser | Should -BeNullOrEmpty
        }
    }

    Context "Error Handling" {
        It "Should fail to import if a non-existent user is assigned" {
            # Arrange
            $nonExistentUser = "nouser@contoso.com"

            # Act
            $result = ImportAutopilotDevice -AccessToken $script:token -DeviceObject $script:deviceToAssign -AssignedUser $nonExistentUser -CustomImport:$false

            # Assert
            $result | Should -BeNull # The function returns null on failure
            
            $assignedUser = Get-MockDeviceUserAssignments -DeviceId "device-assign-01"
            $assignedUser | Should -BeNullOrEmpty
        }

        It "Should fail to import if the device serial does not exist" {
            # Arrange
            $badDevice = @{
                serialNumber = "DEV-NONEXISTENT"
                hardwareHash = "some-hash"
            }

            # Act
            $result = ImportAutopilotDevice -AccessToken $script:token -DeviceObject $badDevice -AssignedUser "assign.user@contoso.com" -CustomImport:$false

            # Assert
            $result | Should -BeNull
        }
    }
}
