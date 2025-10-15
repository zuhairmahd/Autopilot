<#
.SYNOPSIS
    Unit tests for GetDeviceInfo function
.DESCRIPTION
    Tests device information retrieval, WMI/CIM interaction, and vendor validation
    Compatible with PowerShell 5.1 and Pester 5.x
.NOTES
    Part of Week 2 Phase 1 coverage improvement initiative
    Tests use mocked CIM cmdlets to avoid dependencies on actual hardware
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: GetDeviceInfo" -Tags 'Unit', 'AutopilotFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load Write-Log dependency
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Load function under test
        . "$script:RepoRoot/functions/autopilotFunctions/GetDeviceInfo.ps1"
        
        # Mock Write-Log for all tests
        Mock Write-Log {}
        
        # Initialize required script variables
        $script:LogFile = "TestDrive:\test.log"
        $script:maxJSONDepth = 10
        $script:settings = @{
            autopilotDeviceAllowedVendors = @('Dell', 'HP', 'Lenovo', 'Microsoft')
        }
        
        # Mock CIM session and queries
        # Return null to avoid type casting issues - Get-CimInstance will still work with mocked responses
        Mock New-CimSession {
            return $null
        }
        
        Mock Remove-CimSession {}
    }
    
    Context "When retrieving device info without hardware hash" {
        BeforeEach {
            Mock Get-CimInstance {
                param($Class)
                
                if ($Class -eq 'Win32_BIOS') {
                    return [PSCustomObject]@{
                        SerialNumber = 'ABC123456789'
                    }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return [PSCustomObject]@{
                        Manufacturer = 'Dell Inc.    '
                        Model = 'Latitude 7490   '
                    }
                }
            }
        }
        
        It "Should return device hashtable without hardware hash when -NoHash is specified" {
            $result = GetDeviceInfo -NoHash
            
            $result | Should -Not -BeNullOrEmpty
            $result.SerialNumber | Should -Be 'ABC123456789'
            $result.Manufacturer | Should -Be 'Dell Inc.'
            $result.Model | Should -Be 'Latitude 7490'
            $result.ContainsKey('HardwareHash') | Should -Be $false
        }
        
        It "Should trim whitespace from manufacturer and model" {
            $result = GetDeviceInfo -NoHash
            
            $result.Manufacturer | Should -Not -Match '\s$'
            $result.Model | Should -Not -Match '\s$'
        }
        
        It "Should include group tag when provided" {
            $result = GetDeviceInfo -GroupTag 'Engineering' -NoHash
            
            $result.GroupTag | Should -Be 'Engineering'
        }
        
        It "Should include assigned user when provided" {
            $result = GetDeviceInfo -AssignedUser 'user@domain.com' -NoHash
            
            $result.AssignedUser | Should -Be 'user@domain.com'
        }
        
        It "Should set Product to empty string" {
            $result = GetDeviceInfo -NoHash
            
            $result.Product | Should -Be ''
        }
        
        It "Should set deviceAllowed to true by default" {
            $result = GetDeviceInfo -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
    }
    
    Context "When retrieving device info with hardware hash" {
        BeforeEach {
            Mock Get-CimInstance {
                param($Class, $Namespace, $Filter)
                
                if ($Class -eq 'Win32_BIOS') {
                    return [PSCustomObject]@{
                        SerialNumber = 'XYZ987654321'
                    }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return [PSCustomObject]@{
                        Manufacturer = 'HP'
                        Model = 'EliteBook 840'
                    }
                }
                elseif ($Class -eq 'MDM_DevDetail_Ext01') {
                    return [PSCustomObject]@{
                        DeviceHardwareData = 'BASE64ENCODEDHASH=='
                    }
                }
            }
        }
        
        It "Should return device with hardware hash when not using -NoHash" {
            $result = GetDeviceInfo
            
            $result.HardwareHash | Should -Be 'BASE64ENCODEDHASH=='
        }
        
        It "Should query MDM namespace for hardware hash" {
            $result = GetDeviceInfo
            
            Should -Invoke Get-CimInstance -ParameterFilter {
                $Namespace -eq 'root/cimv2/mdm/dmmap' -and
                $Class -eq 'MDM_DevDetail_Ext01'
            }
        }
        
        It "Should return null when hardware hash is not found" {
            Mock Get-CimInstance {
                param($Class)
                if ($Class -eq 'Win32_BIOS') {
                    return @{ SerialNumber = 'TEST' }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return @{ Manufacturer = 'Dell'; Model = 'Test' }
                }
                elseif ($Class -eq 'MDM_DevDetail_Ext01') {
                    return $null
                }
            }
            Mock Write-Error {}
            
            $result = GetDeviceInfo
            
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Error -Times 1
        }
    }
    
    Context "When testing manufacturer override" {
        BeforeEach {
            Mock Get-CimInstance {
                param($Class)
                if ($Class -eq 'Win32_BIOS') {
                    return @{ SerialNumber = 'TEST123' }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return @{ Manufacturer = 'RealManufacturer'; Model = 'TestModel' }
                }
            }
        }
        
        It "Should use ManufacturerOverride when provided" {
            $result = GetDeviceInfo -ManufacturerOverride 'CustomVendor' -NoHash
            
            $result.Manufacturer | Should -Be 'CustomVendor'
        }
        
        It "Should trim whitespace from override value" {
            $result = GetDeviceInfo -ManufacturerOverride '  Lenovo  ' -NoHash
            
            $result.Manufacturer | Should -Be 'Lenovo'
        }
    }
    
    Context "When testing vendor validation" {
        BeforeEach {
            Mock Get-CimInstance {
                param($Class)
                if ($Class -eq 'Win32_BIOS') {
                    return @{ SerialNumber = 'TEST' }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return @{ Manufacturer = 'TestManufacturer'; Model = 'TestModel' }
                }
            }
        }
        
        It "Should allow Dell manufacturer" {
            $result = GetDeviceInfo -ManufacturerOverride 'Dell' -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        It "Should allow Dell Inc. (with Corporation suffix)" {
            $result = GetDeviceInfo -ManufacturerOverride 'Dell Inc.' -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        It "Should allow HP manufacturer" {
            $result = GetDeviceInfo -ManufacturerOverride 'HP' -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        It "Should allow Lenovo manufacturer" {
            $result = GetDeviceInfo -ManufacturerOverride 'Lenovo' -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        It "Should allow Microsoft manufacturer" {
            $result = GetDeviceInfo -ManufacturerOverride 'Microsoft' -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        It "Should reject unknown manufacturer" {
            $result = GetDeviceInfo -ManufacturerOverride 'UnknownBrand' -NoHash
            
            $result.deviceAllowed | Should -Be $false
        }
        
        It "Should handle case-insensitive matching" {
            $result = GetDeviceInfo -ManufacturerOverride 'dell' -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        It "Should normalize corporation suffixes" {
            $result = GetDeviceInfo -ManufacturerOverride 'Dell Corporation' -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        It "Should handle partial prefix matching" {
            $result = GetDeviceInfo -ManufacturerOverride 'Hewlett-Packard' -NoHash
            
            # Should match 'HP' from allowed list via prefix matching
            $result.deviceAllowed | Should -Be $false  # HP doesn't start with Hewlett-Packard
        }
    }
    
    Context "When no allowed vendors list is configured" {
        BeforeAll {
            $script:settings = @{
                autopilotDeviceAllowedVendors = @()
            }
        }
        
        BeforeEach {
            Mock Get-CimInstance {
                param($Class)
                if ($Class -eq 'Win32_BIOS') {
                    return @{ SerialNumber = 'TEST' }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return @{ Manufacturer = 'AnyManufacturer'; Model = 'AnyModel' }
                }
            }
        }
        
        It "Should allow any manufacturer when list is empty" {
            $result = GetDeviceInfo -NoHash
            
            $result.deviceAllowed | Should -Be $true
        }
        
        AfterAll {
            # Restore default settings
            $script:settings = @{
                autopilotDeviceAllowedVendors = @('Dell', 'HP', 'Lenovo', 'Microsoft')
            }
        }
    }
    
    Context "When testing CIM session management" {
        BeforeEach {
            Mock Get-CimInstance {
                param($Class)
                if ($Class -eq 'Win32_BIOS') {
                    return @{ SerialNumber = 'TEST' }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return @{ Manufacturer = 'Dell'; Model = 'Test' }
                }
            }
        }
        
        It "Should create CIM session" {
            $result = GetDeviceInfo -NoHash
            
            Should -Invoke New-CimSession -Times 1 -Exactly
        }
        
        It "Should remove CIM session after retrieval" {
            $result = GetDeviceInfo -NoHash
            
            Should -Invoke Remove-CimSession -Times 1 -Exactly
        }
    }
    
    Context "When testing logging behavior" {
        BeforeEach {
            Mock Get-CimInstance {
                param($Class)
                if ($Class -eq 'Win32_BIOS') {
                    return @{ SerialNumber = 'LOG-TEST' }
                }
                elseif ($Class -eq 'Win32_ComputerSystem') {
                    return @{ Manufacturer = 'Dell'; Model = 'LogTest' }
                }
            }
        }
        
        It "Should log device info collected" {
            Mock Write-Log {} -ParameterFilter { $message -match "Device info collected" }
            
            $result = GetDeviceInfo -NoHash
            
            Should -Invoke Write-Log -ParameterFilter { $message -match "Device info collected" }
        }
        
        It "Should log vendor validation check" {
            Mock Write-Log {} -ParameterFilter { $message -match "Checking whether the device manufacturer" }
            
            $result = GetDeviceInfo -NoHash
            
            Should -Invoke Write-Log -ParameterFilter { $message -match "Checking whether the device manufacturer" }
        }
    }
}
