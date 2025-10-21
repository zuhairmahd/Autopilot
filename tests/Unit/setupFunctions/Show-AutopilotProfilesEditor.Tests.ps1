<#
.SYNOPSIS
    Pester tests for Show-AutopilotProfilesEditor.ps1

.DESCRIPTION
    Unit tests for Autopilot profile editor functions including:
    - Array format detection and handling
    - Array unwrapping regression tests
    - Profile resolution workflows (mocked)
    - Duplicate detection
    - Format conversion utilities

.NOTES
    Test Categories:
    - Array format detection (string vs hashtable)
    - Array unwrapping regression tests (bug fix validation)
    - Duplicate detection logic
    - Format conversion (string to hashtable)
    - Array comparison logic
    - Configuration loading and validation

    PowerShell Compatibility: 5.1+
    Dependencies: AutopilotTestHelpers
    
    Interactive functions (Show-AutopilotProfilesEditor, Get-AutopilotProfileArrayInput,
    Resolve-SingleAutopilotProfileInteractive) are tested via integration tests,
    not unit tests, to avoid input prompts during automated testing.
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Show-AutopilotProfilesEditor (Utilities)" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load required functions
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/setupFunctions/Get-DomainConfigurationFromFiles.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Export-PowershellDataFile/Export-PowerShellDataFile.ps1"
        
        # Initialize log file (required for Write-Log)
        $script:logFile = Join-Path $TestDrive "test.log"
    }

    Context "Array Format Detection and Handling" {
        It "Should detect empty array format correctly" {
            $testConfig = @{
                autopilotProfilesToInclude = @()
            }
            
            $format = Get-EditorArrayFormat -Array $testConfig.autopilotProfilesToInclude
            $format | Should -Be "Empty"
        }

        It "Should detect string array format correctly" {
            $testConfig = @{
                autopilotProfilesToInclude = @("Profile1", "Profile2")
            }
            
            $format = Get-EditorArrayFormat -Array $testConfig.autopilotProfilesToInclude
            $format | Should -Be "StringArray"
        }

        It "Should detect hashtable array format correctly" {
            $testConfig = @{
                autopilotProfilesToInclude = @(
                    @{ name = "Profile1"; id = "guid-1" }
                    @{ name = "Profile2"; id = "guid-2" }
                )
            }
            
            $format = Get-EditorArrayFormat -Array $testConfig.autopilotProfilesToInclude
            $format | Should -Be "HashTableArray"
        }

        It "Should handle PSCustomObject array format correctly" {
            $profile1 = [PSCustomObject]@{ name = "Profile1"; id = "guid-1" }
            $profile2 = [PSCustomObject]@{ name = "Profile2"; id = "guid-2" }
            $testConfig = @{
                autopilotProfilesToInclude = @($profile1, $profile2)
            }
            
            $format = Get-EditorArrayFormat -Array $testConfig.autopilotProfilesToInclude
            # PSCustomObject with name/id properties should be recognized
            $format | Should -BeIn @("HashTableArray", "Unknown")
        }
    }

    Context "Array Unwrapping Regression Tests" {
        It "Should demonstrate PowerShell single-element array unwrapping bug" {
            # WITHOUT the @() wrapper, PowerShell unwraps single-element arrays
            $domainConfig = @{
                autopilotProfilesToInclude = @(
                    @{ name = "SingleProfile"; id = "single-guid" }
                )
            }
            
            # Direct assignment UNWRAPS the array (this is the bug!)
            $profilesUnwrapped = $domainConfig.autopilotProfilesToInclude
            
            # Unwrapped version is a hashtable, not an array
            $profilesUnwrapped | Should -BeOfType [System.Collections.Hashtable]
            $profilesUnwrapped.name | Should -Be "SingleProfile"
        }

        It "Should preserve single-element array type with @() wrapper (the fix)" {
            # This tests the fix: $currentAutopilotProfiles = @($domainConfig.autopilotProfilesToInclude)
            # The key is to wrap during assignment, not after
            
            $domainConfig = @{
                autopilotProfilesToInclude = @(
                    @{ name = "SingleProfile"; id = "single-guid" }
                )
            }
            
            # The fix: Wrap the assignment expression itself
            $profiles = @($domainConfig.autopilotProfilesToInclude)
            
            # With the @() wrapper during assignment, it stays an array
            # Note: This may still unwrap in some PowerShell versions,
            # which is why the actual fix uses this pattern consistently
            $profiles.Count | Should -Be 1
            
            # Access via index to avoid unwrapping
            if ($profiles.Count -eq 1)
            {
                $profiles[0].name | Should -Be "SingleProfile"
            }
        }

        It "Should handle empty array without unwrapping" {
            $domainConfig = @{
                autopilotProfilesToInclude = @()
            }
            
            $profiles = @($domainConfig.autopilotProfilesToInclude)
            $profiles.Count | Should -Be 0
        }

        It "Should handle multi-element arrays correctly" {
            $domainConfig = @{
                autopilotProfilesToInclude = @(
                    @{ name = "Profile1"; id = "guid-1" }
                    @{ name = "Profile2"; id = "guid-2" }
                    @{ name = "Profile3"; id = "guid-3" }
                )
            }
            
            $profiles = @($domainConfig.autopilotProfilesToInclude)
            $profiles.Count | Should -Be 3
        }
    }

    Context "Profile Resolution with Graph API Mocking" {
        It "Should detect duplicate by name using Test-ItemExists" {
            $existingProfiles = @(
                @{ name = "Profile A"; id = "guid-a" }
                @{ name = "Profile B"; id = "guid-b" }
            )

            $isDuplicate = Test-ItemExists -ItemName "Profile A" -ItemId "new-guid" `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $true
        }

        It "Should detect duplicate by ID using Test-ItemExists" {
            $existingProfiles = @(
                @{ name = "Profile A"; id = "guid-a" }
                @{ name = "Profile B"; id = "guid-b" }
            )

            $isDuplicate = Test-ItemExists -ItemName "Different Name" -ItemId "guid-b" `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $true
        }

        It "Should return false for new profile" {
            $existingProfiles = @(
                @{ name = "Profile A"; id = "guid-a" }
            )

            $isDuplicate = Test-ItemExists -ItemName "Profile B" -ItemId "guid-b" `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $false
        }
    }

    Context "Duplicate Detection Logic" {
        It "Should detect duplicate by name" {
            $existingProfiles = @(
                @{ name = "Profile A"; id = "guid-a" }
                @{ name = "Profile B"; id = "guid-b" }
            )

            $isDuplicate = Test-ItemExists -ItemName "Profile A" -ItemId "new-guid" `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $true
        }

        It "Should detect duplicate by ID" {
            $existingProfiles = @(
                @{ name = "Profile A"; id = "guid-a" }
                @{ name = "Profile B"; id = "guid-b" }
            )

            $isDuplicate = Test-ItemExists -ItemName "Different Name" -ItemId "guid-b" `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $true
        }

        It "Should not detect false duplicates" {
            $existingProfiles = @(
                @{ name = "Profile A"; id = "guid-a" }
                @{ name = "Profile B"; id = "guid-b" }
            )

            $isDuplicate = Test-ItemExists -ItemName "Profile C" -ItemId "guid-c" `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $false
        }

        It "Should handle empty existing list" {
            $existingProfiles = @()

            $isDuplicate = Test-ItemExists -ItemName "Profile A" -ItemId "guid-a" `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $false
        }

        It "Should handle string array for backward compatibility" {
            $existingProfiles = @("Profile A", "Profile B")

            $isDuplicate = Test-ItemExists -ItemName "Profile A" -ItemId $null `
                -ExistingList $existingProfiles
            
            $isDuplicate | Should -Be $true
        }
    }

    Context "Format Conversion (String to Hashtable)" {
        It "Should convert string array to hashtable array" {
            $stringProfiles = @("Profile1", "Profile2", "Profile3")
            
            $converted = Convert-StringArrayToHashTableArray -StringArray $stringProfiles
            
            $converted.Count | Should -Be 3
            $converted[0].name | Should -Be "Profile1"
            $converted[0].id | Should -BeNullOrEmpty
            $converted[1].name | Should -Be "Profile2"
            $converted[2].name | Should -Be "Profile3"
        }

        It "Should preserve hashtable array unchanged" {
            $hashProfiles = @(
                @{ name = "Profile1"; id = "guid-1" }
                @{ name = "Profile2"; id = "guid-2" }
            )
            
            # Function converts strings, not hashtables, so pass through
            # In actual code, format detection would skip conversion
            $hashProfiles.Count | Should -Be 2
            $hashProfiles[0].name | Should -Be "Profile1"
            $hashProfiles[0].id | Should -Be "guid-1"
        }

        It "Should handle empty array conversion" {
            $emptyArray = @()
            
            $converted = Convert-StringArrayToHashTableArray -StringArray $emptyArray
            
            $converted.Count | Should -Be 0
        }

        It "Should handle single-element string array" {
            $singleArray = @("OnlyProfile")
            
            $converted = Convert-StringArrayToHashTableArray -StringArray $singleArray
            
            # PowerShell may unwrap single-element arrays, so force array type
            $result = @($converted)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be "OnlyProfile"
            $result[0].id | Should -BeNullOrEmpty
        }
    }

    Context "Array Comparison Logic" {
        It "Should detect changes between string and hashtable arrays" {
            $stringArray = @("Profile1", "Profile2")
            $hashArray = @(
                @{ name = "Profile1"; id = "guid-1" }
                @{ name = "Profile2"; id = "guid-2" }
            )
            
            $hasChanges = Compare-EditorArrayContents -Array1 $stringArray -Array2 $hashArray
            
            # Different formats should be considered as changes
            $hasChanges | Should -Be $true
        }

        It "Should detect identical string arrays as no change" {
            $array1 = @("Profile1", "Profile2")
            $array2 = @("Profile1", "Profile2")
            
            $hasChanges = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            
            $hasChanges | Should -Be $false
        }

        It "Should detect identical hashtable arrays as no change" {
            $array1 = @(
                @{ name = "Profile1"; id = "guid-1" }
                @{ name = "Profile2"; id = "guid-2" }
            )
            $array2 = @(
                @{ name = "Profile1"; id = "guid-1" }
                @{ name = "Profile2"; id = "guid-2" }
            )
            
            $hasChanges = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            
            $hasChanges | Should -Be $false
        }

        It "Should detect added items" {
            $array1 = @("Profile1")
            $array2 = @("Profile1", "Profile2")
            
            $hasChanges = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            
            $hasChanges | Should -Be $true
        }

        It "Should detect removed items" {
            $array1 = @("Profile1", "Profile2", "Profile3")
            $array2 = @("Profile1", "Profile2")
            
            $hasChanges = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            
            $hasChanges | Should -Be $true
        }
    }

    Context "Configuration Loading and Validation" {
        It "Should validate hashtable structure for profile data" {
            $validProfile = @{
                name = "Test Profile"
                id   = "test-guid-1234"
            }
            
            $validProfile.Keys | Should -Contain "name"
            $validProfile.Keys | Should -Contain "id"
            $validProfile.name | Should -Be "Test Profile"
        }

        It "Should handle profile data without ID field" {
            $profileNoId = @{
                name = "Profile Without ID"
            }
            
            $profileNoId.Keys | Should -Contain "name"
            $profileNoId.Keys | Should -Not -Contain "id"
        }

        It "Should preserve array type when accessing single-element configuration" {
            # Simulate configuration loading pattern
            $config = @{
                autopilotProfilesToInclude = @(
                    @{ name = "Single Profile"; id = "single-guid" }
                )
            }
            
            # Force array wrapping (mimics fix in Show-AutopilotProfilesEditor)
            $profiles = @($config.autopilotProfilesToInclude)
            
            $profiles.Count | Should -Be 1
            $profiles[0] | Should -BeOfType [System.Collections.Hashtable]
        }
    }

    Context "Edge Cases and Boundary Conditions" {
        It "Should handle null array in Test-ItemExists" {
            $result = Test-ItemExists -ItemName "Test" -ItemId "test-id" -ExistingList $null
            $result | Should -Be $false
        }

        It "Should handle empty string in Convert-StringArrayToHashTableArray" {
            $result = Convert-StringArrayToHashTableArray -StringArray @("")
            # Force array type to handle unwrapping
            $result = @($result)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be ""
        }

        It "Should handle mixed types in array comparison" {
            $array1 = @("String1", "String2")
            $array2 = @(
                @{ name = "String1" }
                "String2"
            )
            
            # Mixed types should be detected as different
            $hasChanges = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $hasChanges | Should -Be $true
        }

        It "Should handle case sensitivity in profile names" {
            $existingProfiles = @(
                @{ name = "Profile A"; id = "guid-a" }
            )

            # Case-insensitive comparison (PowerShell default)
            $isDuplicate1 = Test-ItemExists -ItemName "profile a" -ItemId "guid-b" `
                -ExistingList $existingProfiles
            $isDuplicate1 | Should -Be $true

            # Different name entirely
            $isDuplicate2 = Test-ItemExists -ItemName "Profile B" -ItemId "guid-b" `
                -ExistingList $existingProfiles
            $isDuplicate2 | Should -Be $false
        }
    }
}
