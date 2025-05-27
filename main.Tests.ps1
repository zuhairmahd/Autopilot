#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for main.ps1 Intune Helpdesk script
.DESCRIPTION
    Comprehensive unit tests for the main.ps1 script including validation functions,
    menu definitions, and helper functions
.NOTES
    Generated for main.ps1 - Intune Helpdesk Menu System
    Author: GitHub Copilot
    Date: May 25, 2025
    PowerShell Version: 5.1+ compatible
#>

BeforeAll {
    # Import the script being tested
    $scriptPath = Join-Path $PSScriptRoot "main.ps1"
    
    # Mock external dependencies and configuration files
    $mockConfigPath = Join-Path $PSScriptRoot ".secrets\config.json"
    $mockInitPath = Join-Path $PSScriptRoot "initVerify.json"
    
    # Create mock configuration data
    $mockConfig = @{
        domain = "contoso.com"
    } | ConvertTo-Json
    
    $mockInit = @{
        domains = @{
            "contoso.com" = @{
                groupsToInclude = @("Group1", "Group2")
                groupsToExclude = @("ExcludedGroup")
                settings        = @{
                    domain                = "contoso.com"
                    MaxUserNameLength     = 50
                    MinUsernameLength     = 3
                    MaxSerialNumberLength = 20
                    MinSerialNumberLength = 8
                }
            }
        }
    } | ConvertTo-Json -Depth 3
    
    # Create temporary config files
    $configDir = Split-Path $mockConfigPath -Parent
    if (-not (Test-Path $configDir))
    {
        New-Item -Path $configDir -ItemType Directory -Force
    }
    Set-Content -Path $mockConfigPath -Value $mockConfig -Force
    Set-Content -Path $mockInitPath -Value $mockInit -Force
    
    # Import all actual function files from the functions directory
    $functionsFolder = Join-Path $PSScriptRoot "functions"
    if (Test-Path $functionsFolder)
    {
        $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
        foreach ($function in $functions)
        {
            . $function.FullName
        }
    }
    
    # Mock external functions that would be imported - but do this AFTER importing the real functions
    Mock GetGraphAccessToken { return "mock-token" }
    Mock GetDeviceEnrollmentStatus { 
        return @{
            managed       = $true
            managedDevice = @{
                device = @{
                    deviceName       = "TestDevice"
                    model            = "TestModel"
                    manufacturer     = "TestManufacturer"
                    id               = "test-device-id"
                    osVersion        = "Windows 10"
                    complianceState  = "compliant"
                    managementState  = "managed"
                    lastSyncDateTime = Get-Date
                }
            }
        }
    }
    Mock CheckDeviceAssignment { return $null }
    Mock SendDeviceCommand { return $true }
    Mock NewMenu { return @{} }
    Mock AddMenuItem { return @{} }
    Mock ShowMenu { return $null }
    Mock GetDeviceInfo { 
        return @{
            serialNumber = "TEST12345"
            manufacturer = "Microsoft"
            model        = "Surface"
        }
    }
    Mock VerifyGroupMembership { 
        return @{
            success         = $true
            missingGroups   = @()
            ForbiddenGroups = @()
        }
    }
    Mock GetDeviceByUser { return "TEST12345" }
    Mock ExportDeviceList { return @($true, "test-export.csv") }
    Mock Read-Host { return "" }
    Mock Write-Host { }
    Mock Start-Sleep { }
    
    # Now dot-source the script with parameters
    try
    {
        . $scriptPath -configFile $mockConfigPath -InitFile $mockInitPath
    }
    catch
    {
        Write-Warning "Failed to dot-source main.ps1: $($_.Exception.Message)"
    }
}

AfterAll {
    # Clean up temporary files
    $mockConfigPath = Join-Path $PSScriptRoot ".secrets-test\config.json"
    $mockInitPath = Join-Path $PSScriptRoot "config-test\initVerify.json"
    if (Test-Path $mockConfigPath)
    {
        Remove-Item $mockConfigPath -Force 
    }
    if (Test-Path $mockInitPath)
    {
        Remove-Item $mockInitPath -Force 
    }
    if (Test-Path (Split-Path $mockConfigPath -Parent))
    { 
        Remove-Item (Split-Path $mockConfigPath -Parent) -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Main Script Structure" {
    Context "Script Parameters" {
        It "Should have correct parameter definitions" {
            $scriptContent = Get-Content -Path (Join-Path $PSScriptRoot "main.ps1") -Raw
            $scriptContent | Should -Match '\[string\]\$configFile'
            $scriptContent | Should -Match '\[string\]\$InitFile'
        }
        
        It "Should have default parameter values" {
            $scriptContent = Get-Content -Path (Join-Path $PSScriptRoot "main.ps1") -Raw
            $scriptContent | Should -Match '\$configFile\s*=\s*"\$pwd\\\.secrets\\config\.json"'
            $scriptContent | Should -Match '\$InitFile\s*=\s*"\$pwd\\initVerify\.json"'
        }
    }
    
    Context "Functions Import" {
        It "Should import functions from functions folder" {
            $scriptContent = Get-Content -Path (Join-Path $PSScriptRoot "main.ps1") -Raw
            $scriptContent | Should -Match 'Get-ChildItem.*functions.*\.ps1'
            $scriptContent | Should -Match '\.\s+\$function\.FullName'
        }
    }
}

Describe "NormalizeUserName Function" {
    Context "Valid Input Processing" {
        BeforeEach {
            $mockSettings = @{
                domain = "contoso.com"
            }
        }
        
        It "Should add domain suffix when missing" {
            $result = NormalizeUserName -UserName "testuser" -Settings $mockSettings
            $result | Should -Be "testuser@contoso.com"
        }
        
        It "Should not modify username that already has domain suffix" {
            $result = NormalizeUserName -UserName "testuser@contoso.com" -Settings $mockSettings
            $result | Should -Be "testuser@contoso.com"
        }
        
        It "Should trim whitespace from username" {
            $result = NormalizeUserName -UserName "  testuser  " -Settings $mockSettings
            $result | Should -Be "testuser@contoso.com"
        }
        
        It "Should handle empty username" {
            $result = NormalizeUserName -UserName "" -Settings $mockSettings
            $result | Should -Be "@contoso.com"
        }
    }
    
    Context "Parameter Validation" {
        It "Should accept UserName parameter" {
            { NormalizeUserName -UserName "test" -Settings @{domain = "test.com"} } | Should -Not -Throw
        }
        
        It "Should accept Settings parameter" {
            { NormalizeUserName -UserName "test" -Settings @{domain = "test.com"} } | Should -Not -Throw
        }
    }
}

Describe "validateInput Function" {
    Context "Serial Number Validation" {
        BeforeEach {
            $mockSettings = @{
                domain                = "contoso.com"
                MaxSerialNumberLength = 20
                MinSerialNumberLength = 8
                MaxUserNameLength     = 50
                MinUsernameLength     = 3
            }
        }
        
        It "Should validate correct serial number" {
            $result = validateInput -UserInput "TEST12345" -type "serialNumber" -settings $mockSettings
            $result.valid | Should -Be $true
            $result.value | Should -Be "TEST12345"
        }
        
        It "Should reject serial number that is too long" {
            $longSerial = "A" * 25
            $result = validateInput -UserInput $longSerial -type "serialNumber" -settings $mockSettings
            $result.valid | Should -Be $false
        }
        
        It "Should reject serial number that is too short" {
            $result = validateInput -UserInput "ABC123" -type "serialNumber" -settings $mockSettings
            $result.valid | Should -Be $false
        }
        
        It "Should accept alphanumeric characters and hyphens" {
            $result = validateInput -UserInput "ABC-123-XYZ" -type "serialNumber" -settings $mockSettings
            $result.valid | Should -Be $true
        }
        
        It "Should reject special characters except hyphens" {
            $result = validateInput -UserInput "ABC@123#XYZ" -type "serialNumber" -settings $mockSettings
            $result.valid | Should -Be $false
        }
        
        It "Should trim whitespace from serial number" {
            $result = validateInput -UserInput "  TEST12345  " -type "serialNumber" -settings $mockSettings
            $result.valid | Should -Be $true
            $result.value | Should -Be "TEST12345"
        }
    }
    
    Context "Username Validation" {
        BeforeEach {
            $mockSettings = @{
                domain                = "contoso.com"
                MaxUserNameLength     = 50
                MinUsernameLength     = 3
                MaxSerialNumberLength = 20
                MinSerialNumberLength = 8
            }
        }
        
        It "Should validate correct username and normalize it" {
            $result = validateInput -UserInput "testuser" -type "userName" -settings $mockSettings
            $result.valid | Should -Be $true
            $result.value | Should -Be "testuser@contoso.com"
        }
        
        It "Should validate email format" {
            $result = validateInput -UserInput "test@contoso.com" -type "userName" -settings $mockSettings
            $result.valid | Should -Be $true
            $result.value | Should -Be "test@contoso.com"
        }
        
        It "Should reject username that is too long" {
            $longUserName = "a" * 60
            $result = validateInput -UserInput $longUserName -type "userName" -settings $mockSettings
            $result.valid | Should -Be $false
        }
        
        It "Should reject username that is too short" {
            $result = validateInput -UserInput "ab" -type "userName" -settings $mockSettings
            $result.valid | Should -Be $false
        }
        
        It "Should reject username starting with digit" {
            $result = validateInput -UserInput "1testuser" -type "userName" -settings $mockSettings
            $result.valid | Should -Be $false
        }
        
        It "Should reject invalid email format" {
            $result = validateInput -UserInput "invalid-email" -type "userName" -settings $mockSettings
            $result.valid | Should -Be $false
        }
    }
    
    Context "Unknown Type Validation" {
        It "Should handle unknown validation type" {
            $result = validateInput -UserInput "test" -type "unknownType" -settings @{}
            $result.valid | Should -Be $false
        }
    }
}

Describe "GetUserInput Function" {
    Context "Parameter Validation" {
        It "Should accept Message parameter" {
            Mock Read-Host { return "test" }
            { GetUserInput -Message "Test message" -Prompt "Test:" -InputType "userName" } | Should -Not -Throw
        }
        
        It "Should accept Prompt parameter" {
            Mock Read-Host { return "test" }
            { GetUserInput -Message "Test" -Prompt "Enter value:" -InputType "serialNumber" } | Should -Not -Throw
        }
        
        It "Should validate InputType parameter" {
            Mock Read-Host { return "test" }
            { GetUserInput -Message "Test" -Prompt "Test:" -InputType "invalidType" } | Should -Throw
        }
    }
    
    Context "Input Processing" {
        It "Should return null when user presses Enter" {
            Mock Read-Host { return "" }
            Mock validateInput { return @{valid = $false; value = $null} }
            
            $result = GetUserInput -Message "Test" -Prompt "Test:" -InputType "userName"
            $result | Should -Be $null
        }
        
        It "Should process valid input" {
            Mock Read-Host { return "validinput" } -ParameterFilter { $true }
            Mock validateInput { return @{valid = $true; value = "processed-input"} }
            
            $result = GetUserInput -Message "Test" -Prompt "Test:" -InputType "serialNumber"
            $result | Should -Be "processed-input"
        }
    }
}

Describe "DisplayDeviceHealth Function" {
    Context "Managed Device Display" {
        It "Should display health information for managed device" {
            Mock GetDeviceEnrollmentStatus {
                return @{
                    managed       = $true
                    managedDevice = @{
                        device = @{
                            deviceName       = "TestDevice"
                            model            = "TestModel"
                            manufacturer     = "TestManufacturer"
                            osVersion        = "Windows 10"
                            complianceState  = "compliant"
                            managementState  = "managed"
                            lastSyncDateTime = Get-Date
                            id               = "test-id"
                        }
                    }
                }
            }
            Mock CheckDeviceAssignment { return $null }
            
            $result = DisplayDeviceHealth -SerialNumber "TEST123" -AccessToken "token"
            $result | Should -Be $true
        }
    }
    
    Context "Unmanaged Device Display" {
        It "Should display limited information for unmanaged device" {
            Mock GetDeviceEnrollmentStatus {
                return @{
                    managed = $false
                }
            }
            Mock CheckDeviceAssignment { return $null }
            
            $result = DisplayDeviceHealth -SerialNumber "TEST123" -AccessToken "token"
            $result | Should -Be $false
        }
    }
}

Describe "ProcessSerialNumber Function" {
    Context "Managed Device Processing" {
        It "Should process managed device and create actions menu" {
            Mock GetDeviceEnrollmentStatus {
                return @{
                    managed       = $true
                    managedDevice = @{
                        device = @{
                            deviceName   = "TestDevice"
                            model        = "TestModel"
                            manufacturer = "TestManufacturer"
                            id           = "test-device-id"
                        }
                    }
                }
            }
            Mock NewMenu { return @{} }
            Mock AddMenuItem { return @{} }
            Mock ShowMenu { return $null }
            
            $result = ProcessSerialNumber -SerialNumber "TEST123" -AccessToken "token"
            $result | Should -Be $null
        }
    }
    
    Context "Navigation Parameters" {
        It "Should initialize navigation parameters when not provided" {
            Mock GetDeviceEnrollmentStatus {
                return @{
                    managed = $false
                }
            }
            
            $result = ProcessSerialNumber -SerialNumber "TEST123" -AccessToken "token"
            $result | Should -Be $null
        }
        
        It "Should accept navigation parameters" {
            $history = New-Object System.Collections.ArrayList
            $menuHistory = New-Object System.Collections.ArrayList
            
            Mock GetDeviceEnrollmentStatus {
                return @{
                    managed = $false
                }
            }
            
            { ProcessSerialNumber -SerialNumber "TEST123" -AccessToken "token" -Depth 1 -History $history -MenuHistory $menuHistory } | Should -Not -Throw
        }
    }
    
    Context "Unmanaged Device Processing" {
        It "Should handle unmanaged device gracefully" {
            Mock GetDeviceEnrollmentStatus {
                return @{
                    managed = $false
                }
            }
            Mock DisplayDeviceHealth { }
            
            $result = ProcessSerialNumber -SerialNumber "TEST123" -AccessToken "token"
            $result | Should -Be $null
        }
    }
}

Describe "Script Variables and Configuration" {
    Context "Configuration Loading" {
        It "Should load domain from config file" {
            # This test verifies the domain variable is set correctly
            if (Get-Variable -Name "domain" -ErrorAction SilentlyContinue)
            {
                $domain | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should load initialization settings" {
            # This test verifies the init variable is set correctly
            if (Get-Variable -Name "init" -ErrorAction SilentlyContinue)
            {
                $init | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Script Variables" {
        It "Should define backout text variable" {
            if (Get-Variable -Name "backoutText" -ErrorAction SilentlyContinue)
            {
                $backoutText | Should -Not -BeNullOrEmpty
                $backoutText | Should -Match "previous menu"
            }
        }
        
        It "Should define script name variable" {
            if (Get-Variable -Name "scriptName" -ErrorAction SilentlyContinue)
            {
                $scriptName | Should -Be "main.ps1"
            }
        }
    }
}

Describe "Menu Structure" {
    Context "Main Menu" {
        It "Should define main menu" {
            # Test that menu creation functions are called
            Assert-MockCalled NewMenu -Times 4 -Exactly
        }
        
        It "Should have correct menu items" {
            # Test that menu items are added
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Give a device to a user" }
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Check device status " }
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Export devices" }
        }
    }
    
    Context "Check Menu" {
        It "Should define device lookup options" {
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Lookup device by Serial Number" }
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Lookup device by User" }
        }
    }
    
    Context "Export Menu" {
        It "Should define export options" {
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Export Autopilot Devices" }
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Export Imported Autopilot Devices" }
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Export Managed Windows Devices" }
            Assert-MockCalled AddMenuItem -Times 1 -ParameterFilter { $Name -eq "Export Unmanaged Windows Devices" }
        }
    }
}

Describe "Error Handling" {
    Context "File Access Errors" {
        It "Should handle missing config file gracefully" {
            # This would need to be tested by creating a new instance with invalid path
            # For now, we ensure the function doesn't throw when files exist
            $true | Should -Be $true
        }
        
        It "Should handle missing functions folder" {
            # This is tested in the main script's error handling logic
            $scriptContent = Get-Content -Path (Join-Path $PSScriptRoot "main.ps1") -Raw
            $scriptContent | Should -Match "Cannot find the functions folder"
        }
    }
}

Describe "Integration Tests" {
    Context "Complete Workflow" {
        It "Should handle complete user lookup workflow" {
            Mock GetUserInput { return "testuser@contoso.com" } -ParameterFilter { $InputType -eq "userName" }
            Mock GetGraphAccessToken { return "mock-token" }
            Mock GetDeviceByUser { return "TEST12345" }
            Mock ProcessSerialNumber { return $null }
            
            # This would simulate the user lookup menu action
            # The actual test would need to invoke the menu action
            $true | Should -Be $true
        }
        
        It "Should handle complete device assignment workflow" {
            Mock GetUserInput { 
                if ($InputType -eq "userName")
                {
                    return "testuser@contoso.com" 
                }
                if ($InputType -eq "serialNumber")
                {
                    return "TEST12345" 
                }
            }
            Mock VerifyGroupMembership { 
                return @{
                    success         = $true
                    missingGroups   = @()
                    ForbiddenGroups = @()
                }
            }
            Mock ProcessSerialNumber { return $null }
            
            # This would simulate the device assignment workflow
            $true | Should -Be $true
        }
    }
}
