<#
.SYNOPSIS
    Pester tests for Export-PowerShellDataFile PSCustomObject array handling fix.

.DESCRIPTION
    Tests to validate that arrays containing PSCustomObject items are correctly
    converted to PSD1 format without data loss.

.NOTES
    Test Categories:
    - PSCustomObject array handling in Export-PowerShellDataFile
    - Single-item and multi-item PSCustomObject arrays
    - Data integrity after save/load cycles
    
    PowerShell Compatibility: 7+
    Dependencies: AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Export-PowerShellDataFile - PSCustomObject Array Handling" -Tags 'Unit', 'UtilityFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load required functions
        . "$script:RepoRoot/functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-Psd1String.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Export-PowershellDataFile/ConvertTo-HashtableFromPSCustomObject.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        # Create test directory
        $script:TestOutputDir = Join-Path $TestDrive "export-tests"
        New-Item -Path $script:TestOutputDir -ItemType Directory -Force | Out-Null
    }

    Context "PSCustomObject Array Export" {
        It "Should export multi-item PSCustomObject array without data loss" {
            $profile1 = [PSCustomObject]@{ id = 'id1'; name = 'Profile 1' }
            $profile2 = [PSCustomObject]@{ id = 'id2'; name = 'Profile 2' }
            $testData = @{
                autopilotProfilesToInclude = @($profile1, $profile2)
            }
            
            $testFile = Join-Path $script:TestOutputDir "multi-item.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            # Verify file doesn't contain empty strings or System.Object[]
            $content = Get-Content $testFile -Raw
            $content | Should -Not -Match "''\s*,?"
            $content | Should -Not -Match "System\.Object\[\]"
            
            # Verify data integrity
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.autopilotProfilesToInclude.Count | Should -Be 2
            $imported.autopilotProfilesToInclude[0].id | Should -Be 'id1'
            $imported.autopilotProfilesToInclude[1].name | Should -Be 'Profile 2'
        }

        It "Should export single-item PSCustomObject array without unwrapping" {
            $profile = [PSCustomObject]@{ id = 'single-id'; name = 'Single Profile' }
            $testData = @{
                autopilotProfilesToInclude = @($profile)
            }
            
            $testFile = Join-Path $script:TestOutputDir "single-item.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            # Verify file doesn't contain empty strings
            $content = Get-Content $testFile -Raw
            $content | Should -Not -Match "''\s*,?"
            
            # Verify data integrity and array type preservation
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.autopilotProfilesToInclude.Count | Should -Be 1
            $imported.autopilotProfilesToInclude[0].id | Should -Be 'single-id'
            $imported.autopilotProfilesToInclude[0].name | Should -Be 'Single Profile'
        }

        It "Should handle complex nested PSCustomObject structures" {
            $testData = @{
                autopilotProfilesToInclude = @(
                    [PSCustomObject]@{ id = 'guid1'; name = 'Profile 1' },
                    [PSCustomObject]@{ id = 'guid2'; name = 'Profile 2' }
                )
                appModes                   = @('full', 'registration')
                groupsToInclude            = @(
                    [PSCustomObject]@{ id = 'group1'; name = 'Group 1' }
                )
            }
            
            $testFile = Join-Path $script:TestOutputDir "complex-nested.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.autopilotProfilesToInclude.Count | Should -Be 2
            $imported.appModes.Count | Should -Be 2
            $imported.groupsToInclude.Count | Should -Be 1
            $imported.autopilotProfilesToInclude[0].id | Should -Be 'guid1'
            $imported.groupsToInclude[0].name | Should -Be 'Group 1'
        }

        It "Should handle empty PSCustomObject arrays" {
            $testData = @{
                autopilotProfilesToInclude = @()
            }
            
            $testFile = Join-Path $script:TestOutputDir "empty-array.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.autopilotProfilesToInclude.Count | Should -Be 0
        }
    }

    Context "Data Integrity After Save/Load Cycle" {
        It "Should preserve data through multiple save/load cycles" {
            $originalData = @{
                autopilotProfilesToInclude = @(
                    [PSCustomObject]@{
                        id   = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
                        name = 'windowsCloudConfig Autopilot profile'
                    }
                )
                appModes                   = @('full')
            }
            
            # First save
            $testFile1 = Join-Path $script:TestOutputDir "cycle-1.psd1"
            Export-PowerShellDataFile -InputObject $originalData -Path $testFile1 -Force | Should -Not -BeNullOrEmpty
            
            # First load
            $loaded1 = Import-PowerShellDataFile -Path $testFile1
            
            # Second save (re-saving loaded data)
            $testFile2 = Join-Path $script:TestOutputDir "cycle-2.psd1"
            Export-PowerShellDataFile -InputObject $loaded1 -Path $testFile2 -Force | Should -Not -BeNullOrEmpty
            
            # Second load
            $loaded2 = Import-PowerShellDataFile -Path $testFile2
            
            # Verify data integrity through the cycle
            $loaded2.autopilotProfilesToInclude.Count | Should -Be 1
            $loaded2.autopilotProfilesToInclude[0].id | Should -Be 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
            $loaded2.autopilotProfilesToInclude[0].name | Should -Be 'windowsCloudConfig Autopilot profile'
            $loaded2.appModes.Count | Should -Be 1
            $loaded2.appModes[0] | Should -Be 'full'
        }

        It "Should handle real-world domain config scenario" {
            $domainConfig = @{
                domain                     = 'test.com'
                autopilotProfilesToInclude = @(
                    [PSCustomObject]@{
                        id   = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
                        name = 'windowsCloudConfig Autopilot profile'
                    }
                )
                appModes                   = @('full', 'registration')
                groupsToInclude            = @(
                    [PSCustomObject]@{
                        id   = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
                        name = 'Cloud Managed PC User'
                    }
                )
                groupsToExclude            = @(
                    [PSCustomObject]@{
                        id   = 'a0138743-e4fe-45db-a231-737b10a2615d'
                        name = 'autoPilot-device-preparation-user'
                    }
                )
            }
            
            $testFile = Join-Path $script:TestOutputDir "domain-config.psd1"
            Export-PowerShellDataFile -InputObject $domainConfig -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            # Verify no data loss
            $content = Get-Content $testFile -Raw
            $content | Should -Not -Match "''\s*,?"
            $content | Should -Not -Match "System\.Object\[\]"
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.domain | Should -Be 'test.com'
            $imported.autopilotProfilesToInclude.Count | Should -Be 1
            $imported.appModes.Count | Should -Be 2
            $imported.groupsToInclude.Count | Should -Be 1
            $imported.groupsToExclude.Count | Should -Be 1
        }
    }

    Context "Backward Compatibility" {
        It "Should still handle hashtable arrays correctly" {
            $testData = @{
                items = @(
                    @{ id = '1'; name = 'Item 1' },
                    @{ id = '2'; name = 'Item 2' }
                )
            }
            
            $testFile = Join-Path $script:TestOutputDir "hashtable-array.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.items.Count | Should -Be 2
            $imported.items[0].id | Should -Be '1'
        }

        It "Should still handle string arrays correctly" {
            $testData = @{
                appModes = @('full', 'registration', 'helpdesk')
            }
            
            $testFile = Join-Path $script:TestOutputDir "string-array.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.appModes.Count | Should -Be 3
            $imported.appModes[1] | Should -Be 'registration'
        }
    }

    Context "String Arrays (userPatternsToExclude, autopilotDeviceAllowedVendors)" {
        It "Should handle single string in array correctly" {
            $testData = @{
                userPatternsToExclude = @('-test')
            }
            
            $testFile = Join-Path $script:TestOutputDir "single-string.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.userPatternsToExclude.Count | Should -Be 1
            $imported.userPatternsToExclude[0] | Should -Be '-test'
            $imported.userPatternsToExclude[0] | Should -BeOfType [string]
        }

        It "Should handle multiple strings in array correctly" {
            $testData = @{
                autopilotDeviceAllowedVendors = @('Dell', 'HP', 'Lenovo')
            }
            
            $testFile = Join-Path $script:TestOutputDir "multiple-strings.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.autopilotDeviceAllowedVendors.Count | Should -Be 3
            $imported.autopilotDeviceAllowedVendors[0] | Should -Be 'Dell'
            $imported.autopilotDeviceAllowedVendors[1] | Should -Be 'HP'
            $imported.autopilotDeviceAllowedVendors[2] | Should -Be 'Lenovo'
        }

        It "Should handle empty string array correctly" {
            $testData = @{
                userPatternsToExclude = @()
            }
            
            $testFile = Join-Path $script:TestOutputDir "empty-string-array.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.userPatternsToExclude.Count | Should -Be 0
        }
    }

    Context "Hashtable Arrays (groupsToInclude, groupsToExclude, autopilotProfilesToInclude)" {
        It "Should handle single hashtable with id and name correctly" {
            $testData = @{
                groupsToInclude = @(
                    @{ id = 'group-id-1'; name = 'Marketing Team' }
                )
            }
            
            $testFile = Join-Path $script:TestOutputDir "single-hashtable.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.groupsToInclude.Count | Should -Be 1
            $imported.groupsToInclude[0].id | Should -Be 'group-id-1'
            $imported.groupsToInclude[0].name | Should -Be 'Marketing Team'
        }

        It "Should handle multiple hashtables with id and name correctly" {
            $testData = @{
                autopilotProfilesToInclude = @(
                    @{ id = 'profile-1'; name = 'Profile One' },
                    @{ id = 'profile-2'; name = 'Profile Two' }
                )
            }
            
            $testFile = Join-Path $script:TestOutputDir "multiple-hashtables.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.autopilotProfilesToInclude.Count | Should -Be 2
            $imported.autopilotProfilesToInclude[0].id | Should -Be 'profile-1'
            $imported.autopilotProfilesToInclude[0].name | Should -Be 'Profile One'
            $imported.autopilotProfilesToInclude[1].id | Should -Be 'profile-2'
            $imported.autopilotProfilesToInclude[1].name | Should -Be 'Profile Two'
        }

        It "Should handle empty hashtable array correctly" {
            $testData = @{
                groupsToExclude = @()
            }
            
            $testFile = Join-Path $script:TestOutputDir "empty-hashtable-array.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            $imported.groupsToExclude.Count | Should -Be 0
        }
    }

    Context "Mixed Array Types in Single Configuration" {
        It "Should handle realistic domain configuration with mixed array types" {
            $testData = @{
                userPatternsToExclude         = @('-test', 'onmicrosoft.com')
                autopilotDeviceAllowedVendors = @('Dell')
                groupsToInclude               = @(
                    @{ id = 'group1-id'; name = 'Group 1' }
                )
                autopilotProfilesToInclude    = @(
                    @{ id = 'profile1-id'; name = 'Profile 1' },
                    @{ id = 'profile2-id'; name = 'Profile 2' }
                )
            }
            
            $testFile = Join-Path $script:TestOutputDir "mixed-arrays.psd1"
            Export-PowerShellDataFile -InputObject $testData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            $imported = Import-PowerShellDataFile -Path $testFile
            
            # Verify string arrays
            $imported.userPatternsToExclude.Count | Should -Be 2
            $imported.userPatternsToExclude[0] | Should -Be '-test'
            $imported.autopilotDeviceAllowedVendors.Count | Should -Be 1
            $imported.autopilotDeviceAllowedVendors[0] | Should -Be 'Dell'
            
            # Verify hashtable arrays
            $imported.groupsToInclude.Count | Should -Be 1
            $imported.groupsToInclude[0].name | Should -Be 'Group 1'
            $imported.autopilotProfilesToInclude.Count | Should -Be 2
            $imported.autopilotProfilesToInclude[1].id | Should -Be 'profile2-id'
        }
    }

    Context "Save-Load-Modify-Save Cycles" {
        It "Should preserve string array data through save-load-modify-save cycle" {
            $originalData = @{
                autopilotDeviceAllowedVendors = @('Dell')
            }
            
            # First save
            $testFile = Join-Path $script:TestOutputDir "cycle-strings.psd1"
            Export-PowerShellDataFile -InputObject $originalData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            # Load
            $loaded = Import-PowerShellDataFile -Path $testFile
            
            # Modify
            $loaded.autopilotDeviceAllowedVendors = $loaded.autopilotDeviceAllowedVendors + @('HP')
            
            # Second save
            Export-PowerShellDataFile -InputObject $loaded -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            # Final load and verify
            $finalLoaded = Import-PowerShellDataFile -Path $testFile
            $finalLoaded.autopilotDeviceAllowedVendors.Count | Should -Be 2
            $finalLoaded.autopilotDeviceAllowedVendors[0] | Should -Be 'Dell'
            $finalLoaded.autopilotDeviceAllowedVendors[1] | Should -Be 'HP'
        }

        It "Should preserve hashtable array data through save-load-modify-save cycle" {
            $originalData = @{
                groupsToInclude = @(
                    @{ id = 'g1'; name = 'Group 1' }
                )
            }
            
            # First save
            $testFile = Join-Path $script:TestOutputDir "cycle-hashtables.psd1"
            Export-PowerShellDataFile -InputObject $originalData -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            # Load
            $loaded = Import-PowerShellDataFile -Path $testFile
            
            # Modify
            $loaded.groupsToInclude = $loaded.groupsToInclude + @(@{ id = 'g2'; name = 'Group 2' })
            
            # Second save
            Export-PowerShellDataFile -InputObject $loaded -Path $testFile -Force | Should -Not -BeNullOrEmpty
            
            # Final load and verify
            $finalLoaded = Import-PowerShellDataFile -Path $testFile
            $finalLoaded.groupsToInclude.Count | Should -Be 2
            $finalLoaded.groupsToInclude[0].id | Should -Be 'g1'
            $finalLoaded.groupsToInclude[1].name | Should -Be 'Group 2'
        }
    }
}
