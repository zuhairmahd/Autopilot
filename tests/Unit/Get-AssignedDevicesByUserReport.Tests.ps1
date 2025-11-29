<#
.SYNOPSIS
    Tests for Get-AssignedDevicesByUserReport function

.DESCRIPTION
    Comprehensive unit tests for device assignment report generation.
    Tests all input methods (manual entry, file input, quit), output options
    (view, export, quit), and error handling scenarios.

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers, AutopilotGraphMocks
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Get-AssignedDevicesByUserReport" -Tags 'Unit', 'Reporting' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Dot-source functions (PowerShell 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Initialize-GraphMockEnvironment -ClearCache
        
        # Initialize global variables
        Initialize-MockGlobalVariables -Settings @{
            operatingSystem  = "Windows"
            deviceNamePrefix = ""
        }
        
        # Add mock users with devices
        Add-MockUser -UserPrincipalName "user1@contoso.com" -DisplayName "User One" -GivenName "User" -Surname "One" -Id "user-001"
        Add-MockUser -UserPrincipalName "user2@contoso.com" -DisplayName "User Two" -GivenName "User" -Surname "Two" -Id "user-002"
        Add-MockUser -UserPrincipalName "nodevice@contoso.com" -DisplayName "No Device User" -GivenName "NoDevice" -Surname "User" -Id "user-003"
        
        # Add mock devices for user1
        $device1 = @{
            id                            = "device-001"
            displayName                   = "DESKTOP-001"
            manufacturer                  = "Dell"
            model                         = "Latitude 5420"
            operatingSystem               = "Windows"
            operatingSystemVersion        = "10.0.19045"
            accountEnabled                = $true
            approximateLastSignInDateTime = "2025-11-28T10:00:00Z"
            trustType                     = "AzureAd"
            isCompliant                   = $true
            isManaged                     = $true
            deviceOwnership               = "Company"
            enrollmentType                = "WindowsAutoEnrollment"
            registrationDateTime          = "2025-01-15T08:00:00Z"
        }
        
        $device2 = @{
            id                            = "device-002"
            displayName                   = "LAPTOP-001"
            manufacturer                  = "HP"
            model                         = "EliteBook 840"
            operatingSystem               = "Windows"
            operatingSystemVersion        = "10.0.19045"
            accountEnabled                = $true
            approximateLastSignInDateTime = "2025-11-27T15:30:00Z"
            trustType                     = "AzureAd"
            isCompliant                   = $true
            isManaged                     = $true
            deviceOwnership               = "Company"
            enrollmentType                = "WindowsAutoEnrollment"
            registrationDateTime          = "2025-02-20T09:15:00Z"
        }
        
        # Mock Get-RegisteredDevicesByUser
        Mock Get-RegisteredDevicesByUser {
            param($usersList, $accessToken)
            
            $devices = @()
            foreach ($user in $usersList) {
                if ($user -eq "user1@contoso.com") {
                    $devices += [PSCustomObject]@{
                        UserName                      = "user1@contoso.com"
                        DeviceId                      = $device1.id
                        DisplayName                   = $device1.displayName
                        Manufacturer                  = $device1.manufacturer
                        Model                         = $device1.model
                        OperatingSystem               = $device1.operatingSystem
                        OperatingSystemVersion        = $device1.operatingSystemVersion
                        AccountEnabled                = $device1.accountEnabled
                        ApproximateLastSignInDateTime = $device1.approximateLastSignInDateTime
                        DeviceTrustType               = $device1.trustType
                        IsCompliant                   = $device1.isCompliant
                        IsManaged                     = $device1.isManaged
                        DeviceOwnership               = $device1.deviceOwnership
                        EnrollmentType                = $device1.enrollmentType
                        RegistrationDateTime          = $device1.registrationDateTime
                    }
                    $devices += [PSCustomObject]@{
                        UserName                      = "user1@contoso.com"
                        DeviceId                      = $device2.id
                        DisplayName                   = $device2.displayName
                        Manufacturer                  = $device2.manufacturer
                        Model                         = $device2.model
                        OperatingSystem               = $device2.operatingSystem
                        OperatingSystemVersion        = $device2.operatingSystemVersion
                        AccountEnabled                = $device2.accountEnabled
                        ApproximateLastSignInDateTime = $device2.approximateLastSignInDateTime
                        DeviceTrustType               = $device2.trustType
                        IsCompliant                   = $device2.isCompliant
                        IsManaged                     = $device2.isManaged
                        DeviceOwnership               = $device2.deviceOwnership
                        EnrollmentType                = $device2.enrollmentType
                        RegistrationDateTime          = $device2.registrationDateTime
                    }
                }
                elseif ($user -eq "user2@contoso.com") {
                    $devices += [PSCustomObject]@{
                        UserName                      = "user2@contoso.com"
                        DeviceId                      = $device1.id
                        DisplayName                   = $device1.displayName
                        Manufacturer                  = $device1.manufacturer
                        Model                         = $device1.model
                        OperatingSystem               = $device1.operatingSystem
                        OperatingSystemVersion        = $device1.operatingSystemVersion
                        AccountEnabled                = $device1.accountEnabled
                        ApproximateLastSignInDateTime = $device1.approximateLastSignInDateTime
                        DeviceTrustType               = $device1.trustType
                        IsCompliant                   = $device1.isCompliant
                        IsManaged                     = $device1.isManaged
                        DeviceOwnership               = $device1.deviceOwnership
                        EnrollmentType                = $device1.enrollmentType
                        RegistrationDateTime          = $device1.registrationDateTime
                    }
                }
            }
            return $devices
        }
        
        # Mock GetUserInput
        Mock GetUserInput {
            param($Message, $Prompt, $InputType)
            return $script:MockUserInput
        }
        
        # Mock validateInput
        Mock validateInput {
            param($userInput, $Type)
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                return @{ valid = $false; value = $null }
            }
            return @{ valid = $true; value = $userInput }
        }
        
        # Mock Read-Host for choice selections
        Mock Read-Host {
            param($Prompt)
            return $script:MockReadHostResponse
        }
        
        # Mock Show-PagedContent
        Mock Show-PagedContent {
            param($Content, $PageSize, $DisplayScriptBlock, $Title)
            return "completed"
        }
        
        # Mock Export-Csv
        Mock Export-Csv {
            param($Path, $NoTypeInformation, $Encoding)
            # Simulate successful export
        }
        
        # Get mock token
        $script:token = New-MockAuthToken
    }
    
    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
    }
    
    Context "User input method selection - Quit immediately" {
        BeforeAll {
            $script:MockReadHostResponse = 'Q'
        }
        
        It "Should return UserCancelled when user quits at input method prompt" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'UserCancelled'
            $result.Message | Should -BeLike "*cancelled*"
        }
    }
    
    Context "Manual entry (E) - Single user with devices" {
        BeforeAll {
            $script:MockReadHostResponse = 'E'
            $script:inputSequence = @("user1@contoso.com", "")
            $script:inputIndex = 0
            
            Mock GetUserInput {
                $value = $script:inputSequence[$script:inputIndex]
                $script:inputIndex++
                return $value
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'E'
                }
                elseif ($Prompt -like "*V/E/Q*") {
                    return 'V'
                }
                return 'Q'
            }
        }
        
        It "Should successfully retrieve and display devices for manually entered user" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'Displayed'
            $result.DeviceCount | Should -Be 2
            $result.UserCount | Should -Be 1
            $result.Message | Should -BeLike "*2 devices*"
        }
    }
    
    Context "Manual entry (E) - Multiple users" {
        BeforeAll {
            $script:MockReadHostResponse = 'E'
            $script:inputSequence = @("user1@contoso.com", "user2@contoso.com", "")
            $script:inputIndex = 0
            
            Mock GetUserInput {
                $value = $script:inputSequence[$script:inputIndex]
                $script:inputIndex++
                return $value
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'E'
                }
                elseif ($Prompt -like "*V/E/Q*") {
                    return 'E'
                }
                return 'Q'
            }
        }
        
        It "Should export devices for multiple users to CSV" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'Exported'
            $result.DeviceCount | Should -Be 3
            $result.UserCount | Should -Be 2
            $result.ExportPath | Should -BeLike "*.csv"
        }
    }
    
    Context "File input (F) - Valid file with users" {
        BeforeAll {
            $script:validFilePath = "C:\test\users.txt"
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'F'
                }
                elseif ($Prompt -like "*full path*") {
                    return $script:validFilePath
                }
                elseif ($Prompt -like "*V/E/Q*") {
                    return 'V'
                }
                return 'Q'
            }
            
            Mock Test-Path {
                param($Path)
                # Check if path matches our test file path
                if ($Path -eq $script:validFilePath) {
                    return $true
                }
                # Allow other paths (like .secrets directory) to pass through normally
                & (Get-Command Test-Path -CommandType Cmdlet) -Path $Path
            }
            
            Mock Get-Content {
                param($Path)
                if ($Path -eq $script:validFilePath) {
                    return @("user1@contoso.com", "user2@contoso.com")
                }
                # Don't try to read actual content for other paths
                return @()
            }
        }
        
        It "Should successfully read users from file and display devices" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'Displayed'
            $result.DeviceCount | Should -BeGreaterThan 0
            $result.UserCount | Should -Be 2
        }
    }
    
    Context "File input (F) - File not found" {
        BeforeAll {
            $script:MockFilePath = "C:\NonExistent\users.txt"
            $script:MockFileExists = $false
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'F'
                }
                elseif ($Prompt -like "*full path*") {
                    return $script:MockFilePath
                }
                return 'Q'
            }
        }
        
        It "Should return error when file not found" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $false
            $result.Action | Should -Be 'Error'
            $result.Message | Should -BeLike "*not found*"
        }
    }
    
    Context "File input (F) - File with invalid users" {
        BeforeAll {
            $script:invalidFilePath = "C:\test\invalid_users.txt"
            
            Mock validateInput {
                param($userInput, $Type)
                return @{ valid = $false; value = $null }
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'F'
                }
                elseif ($Prompt -like "*full path*") {
                    return $script:invalidFilePath
                }
                return 'Q'
            }
            
            Mock Test-Path {
                param($Path)
                if ($Path -eq $script:invalidFilePath) {
                    return $true
                }
                # Allow other paths to pass through normally
                & (Get-Command Test-Path -CommandType Cmdlet) -Path $Path
            }
            
            Mock Get-Content {
                param($Path)
                if ($Path -eq $script:invalidFilePath) {
                    return @("invalid", "also-invalid")
                }
                return @()
            }
        }
        
        It "Should return error when no valid users in file" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $false
            $result.Action | Should -Be 'Error'
            $result.Message | Should -BeLike "*No valid users*"
        }
    }
    
    Context "No devices found scenario" {
        BeforeAll {
            Mock Get-RegisteredDevicesByUser {
                return @()
            }
            
            $script:inputSequence = @("nodevice@contoso.com", "")
            $script:inputIndex = 0
            
            Mock GetUserInput {
                $value = $script:inputSequence[$script:inputIndex]
                $script:inputIndex++
                return $value
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'E'
                }
                return 'Q'
            }
        }
        
        It "Should return NoDevices action when no devices found" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'NoDevices'
            $result.DeviceCount | Should -Be 0
            $result.UserCount | Should -Be 1
            $result.Message | Should -BeLike "*No devices found*"
        }
    }
    
    Context "Output choice - View (V)" {
        BeforeAll {
            $script:inputSequence = @("user1@contoso.com", "")
            $script:inputIndex = 0
            
            Mock GetUserInput {
                $value = $script:inputSequence[$script:inputIndex]
                $script:inputIndex++
                return $value
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'E'
                }
                elseif ($Prompt -like "*V/E/Q*") {
                    return 'V'
                }
                return 'Q'
            }
        }
        
        It "Should display devices on screen" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'Displayed'
            Should -Invoke Show-PagedContent -Times 1
        }
    }
    
    Context "Output choice - Export (E)" {
        BeforeAll {
            $script:inputSequence = @("user1@contoso.com", "")
            $script:inputIndex = 0
            
            Mock GetUserInput {
                $value = $script:inputSequence[$script:inputIndex]
                $script:inputIndex++
                return $value
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'E'
                }
                elseif ($Prompt -like "*V/E/Q*") {
                    return 'E'
                }
                return 'Q'
            }
        }
        
        It "Should export devices to CSV file" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'Exported'
            $result.ExportPath | Should -Not -BeNullOrEmpty
            $result.ExportPath | Should -Match "AssignedDevicesByUserReport-\d{8}_\d{4}\.csv"
            Should -Invoke Export-Csv -Times 1
        }
    }
    
    Context "Output choice - Quit (Q) after device retrieval" {
        BeforeAll {
            $script:inputSequence = @("user1@contoso.com", "")
            $script:inputIndex = 0
            
            Mock GetUserInput {
                $value = $script:inputSequence[$script:inputIndex]
                $script:inputIndex++
                return $value
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'E'
                }
                elseif ($Prompt -like "*V/E/Q*") {
                    return 'Q'
                }
                return 'Q'
            }
        }
        
        It "Should return UserCancelled when user quits after device retrieval" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $true
            $result.Action | Should -Be 'UserCancelled'
            $result.DeviceCount | Should -Be 2
            $result.UserCount | Should -Be 1
        }
    }
    
    Context "Show-PagedContent error handling" {
        BeforeAll {
            $script:inputSequence = @("user1@contoso.com", "")
            $script:inputIndex = 0
            
            Mock GetUserInput {
                $value = $script:inputSequence[$script:inputIndex]
                $script:inputIndex++
                return $value
            }
            
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*E to enter*") {
                    return 'E'
                }
                elseif ($Prompt -like "*V/E/Q*") {
                    return 'V'
                }
                return 'Q'
            }
            
            Mock Show-PagedContent {
                return "error occurred"
            }
        }
        
        It "Should return error when Show-PagedContent fails" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -Be $false
            $result.Action | Should -Be 'Error'
            $result.Message | Should -BeLike "*Error displaying*"
        }
    }
    
    Context "Return object structure validation" {
        BeforeAll {
            Mock Read-Host { return 'Q' }
        }
        
        It "Should return object with all required properties" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'Success'
            $result.PSObject.Properties.Name | Should -Contain 'Action'
            $result.PSObject.Properties.Name | Should -Contain 'DeviceCount'
            $result.PSObject.Properties.Name | Should -Contain 'UserCount'
            $result.PSObject.Properties.Name | Should -Contain 'ExportPath'
            $result.PSObject.Properties.Name | Should -Contain 'Message'
            $result.PSObject.Properties.Name | Should -Contain 'ErrorDetails'
        }
        
        It "Should have correct property types" {
            $result = Get-AssignedDevicesByUserReport -accessToken $script:token
            
            $result.Success | Should -BeOfType [bool]
            $result.Action | Should -BeOfType [string]
            $result.DeviceCount | Should -BeOfType [int]
            $result.UserCount | Should -BeOfType [int]
            $result.ExportPath | Should -BeOfType [string]
            $result.Message | Should -BeOfType [string]
            $result.ErrorDetails | Should -BeOfType [string]
        }
    }
}
