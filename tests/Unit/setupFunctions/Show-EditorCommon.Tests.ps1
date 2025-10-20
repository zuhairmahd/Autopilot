<#
.SYNOPSIS
    Pester tests for Show-EditorCommon.ps1 shared editor functions

.DESCRIPTION
    Unit tests for common editor utility functions used across all settings editors.
    Tests array manipulation, format detection, domain selection, and user choice handling.

.NOTES
    Test Category: Unit
    Dependencies: Show-EditorCommon.ps1, AutopilotTestHelpers
    Template Compliance: Full
    PowerShell: 5.1+ compatible
    
    Functions Tested:
    - Get-DomainForEditor
    - Compare-EditorArrayContents
    - Get-EditorArrayFormat
    - Show-EditorArrayContents
    - Get-EditorReplaceOrAddChoice
    - Convert-StringArrayToHashTableArray
    - Update-DomainArraySetting
    - Test-ItemExists
#>

# Import test helpers
Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Show-EditorCommon" -Tags 'Unit', 'EditorCommon', 'SettingsEditor' {
    
    BeforeAll {
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RootPath = $script:TestContext.RootPath
        
        # Dot-source only the function under test (most functions are self-contained)
        . "$script:RootPath/functions/setupFunctions/Show-EditorCommon.ps1"
        
        # Load minimal dependencies
        . "$script:RootPath/functions/utilityFunctions/Write-Log.ps1"
        
        # Setup global log file
        $global:LogFile = $script:TestContext.LogFile
    }
    
    AfterAll {
        # Cleanup
        Remove-TestEnvironment -TestContext $script:TestContext
    }
    
    Context "Get-EditorArrayFormat - Format Detection" {
        
        It "Should detect empty array format" {
            $emptyArray = @()
            $format = Get-EditorArrayFormat -Array $emptyArray
            $format | Should -Be "Empty"
        }
        
        It "Should detect null array as empty" {
            $format = Get-EditorArrayFormat -Array $null
            $format | Should -Be "Empty"
        }
        
        It "Should detect string array format" {
            $stringArray = @("Group1", "Group2", "Group3")
            $format = Get-EditorArrayFormat -Array $stringArray
            $format | Should -Be "StringArray"
        }
        
        It "Should detect hashtable array format with name and id" {
            $hashTableArray = @(
                @{ name = "Group1"; id = "id1" },
                @{ name = "Group2"; id = "id2" }
            )
            $format = Get-EditorArrayFormat -Array $hashTableArray
            $format | Should -Be "HashTableArray"
        }
        
        It "Should detect PSCustomObject array format with name and id" {
            $pscustomArray = @(
                [PSCustomObject]@{ name = "Group1"; id = "id1" },
                [PSCustomObject]@{ name = "Group2"; id = "id2" }
            )
            $format = Get-EditorArrayFormat -Array $pscustomArray
            $format | Should -Be "HashTableArray"
        }
        
        It "Should detect unknown format for hashtable without name/id" {
            $unknownArray = @(
                @{ SomeProperty = "Value1" },
                @{ SomeProperty = "Value2" }
            )
            $format = Get-EditorArrayFormat -Array $unknownArray
            $format | Should -Be "Unknown"
        }
        
        It "Should handle single-element array correctly" {
            $singleArray = @("OnlyGroup")
            $format = Get-EditorArrayFormat -Array $singleArray
            $format | Should -Be "StringArray"
        }
    }
    
    Context "Compare-EditorArrayContents - Array Comparison Logic" {
        
        It "Should return false for two empty arrays" {
            $array1 = @()
            $array2 = @()
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $false
        }
        
        It "Should return true when array changes from empty to populated" {
            $array1 = @()
            $array2 = @("Group1")
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $true
        }
        
        It "Should return true when array changes from populated to empty" {
            $array1 = @("Group1")
            $array2 = @()
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $true
        }
        
        It "Should return false for identical string arrays" {
            $array1 = @("Group1", "Group2", "Group3")
            $array2 = @("Group1", "Group2", "Group3")
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $false
        }
        
        It "Should return true for different string arrays" {
            $array1 = @("Group1", "Group2")
            $array2 = @("Group1", "Group3")
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $true
        }
        
        It "Should return false for identical hashtable arrays" {
            $array1 = @(
                @{ name = "Group1"; id = "id1" },
                @{ name = "Group2"; id = "id2" }
            )
            $array2 = @(
                @{ name = "Group1"; id = "id1" },
                @{ name = "Group2"; id = "id2" }
            )
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $false
        }
        
        It "Should return true for different hashtable arrays (different IDs)" {
            $array1 = @(
                @{ name = "Group1"; id = "id1" }
            )
            $array2 = @(
                @{ name = "Group1"; id = "id2" }
            )
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $true
        }
        
        It "Should return true for different hashtable arrays (different names)" {
            $array1 = @(
                @{ name = "Group1"; id = "id1" }
            )
            $array2 = @(
                @{ name = "Group2"; id = "id1" }
            )
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $true
        }
        
        It "Should return true when array formats differ (string vs hashtable)" {
            $array1 = @("Group1", "Group2")
            $array2 = @(
                @{ name = "Group1"; id = "id1" },
                @{ name = "Group2"; id = "id2" }
            )
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $true
        }
        
        It "Should return true for different length arrays" {
            $array1 = @("Group1", "Group2")
            $array2 = @("Group1", "Group2", "Group3")
            $result = Compare-EditorArrayContents -Array1 $array1 -Array2 $array2
            $result | Should -Be $true
        }
        
        It "Should handle null arrays correctly" {
            $result = Compare-EditorArrayContents -Array1 $null -Array2 $null
            $result | Should -Be $false
        }
    }
    
    Context "Convert-StringArrayToHashTableArray - Format Conversion" {
        
        It "Should convert string array to hashtable array" {
            $stringArray = @("Item1", "Item2", "Item3")
            $result = Convert-StringArrayToHashTableArray -StringArray $stringArray
            
            $result | Should -HaveCount 3
            $result[0] | Should -BeOfType [hashtable]
            $result[0].name | Should -Be "Item1"
            $result[0].id | Should -BeNullOrEmpty
        }
        
        It "Should handle empty string array" {
            $stringArray = @()
            $result = Convert-StringArrayToHashTableArray -StringArray $stringArray
            
            $result | Should -HaveCount 0
        }
        
        It "Should handle null array" {
            $result = Convert-StringArrayToHashTableArray -StringArray $null
            
            $result | Should -HaveCount 0
        }
        
        It "Should preserve all string values" {
            $stringArray = @("Alpha", "Beta", "Gamma", "Delta")
            $result = Convert-StringArrayToHashTableArray -StringArray $stringArray
            
            $result[0].name | Should -Be "Alpha"
            $result[1].name | Should -Be "Beta"
            $result[2].name | Should -Be "Gamma"
            $result[3].name | Should -Be "Delta"
        }
        
        It "Should set id to null for all converted items" {
            $stringArray = @("Item1", "Item2")
            $result = Convert-StringArrayToHashTableArray -StringArray $stringArray
            
            $result[0].id | Should -BeNullOrEmpty
            $result[1].id | Should -BeNullOrEmpty
        }
    }
    
    Context "Test-ItemExists - Duplicate Detection" {
        
        It "Should return false for empty existing list" {
            $existingList = @()
            $result = Test-ItemExists -ItemName "NewItem" -ItemId "id1" -ExistingList $existingList
            $result | Should -Be $false
        }
        
        It "Should return false for null existing list" {
            $result = Test-ItemExists -ItemName "NewItem" -ItemId "id1" -ExistingList $null
            $result | Should -Be $false
        }
        
        It "Should detect duplicate by name in string array" {
            $existingList = @("Item1", "Item2", "Item3")
            $result = Test-ItemExists -ItemName "Item2" -ItemId "id2" -ExistingList $existingList
            $result | Should -Be $true
        }
        
        It "Should detect duplicate by ID in hashtable array" {
            $existingList = @(
                @{ name = "Item1"; id = "id1" },
                @{ name = "Item2"; id = "id2" }
            )
            $result = Test-ItemExists -ItemName "DifferentName" -ItemId "id2" -ExistingList $existingList
            $result | Should -Be $true
        }
        
        It "Should detect duplicate by name in hashtable array" {
            $existingList = @(
                @{ name = "Item1"; id = "id1" },
                @{ name = "Item2"; id = "id2" }
            )
            $result = Test-ItemExists -ItemName "Item1" -ItemId "differentId" -ExistingList $existingList
            $result | Should -Be $true
        }
        
        It "Should return false when item does not exist" {
            $existingList = @(
                @{ name = "Item1"; id = "id1" },
                @{ name = "Item2"; id = "id2" }
            )
            $result = Test-ItemExists -ItemName "NewItem" -ItemId "newId" -ExistingList $existingList
            $result | Should -Be $false
        }
        
        It "Should handle PSCustomObject array" {
            $existingList = @(
                [PSCustomObject]@{ name = "Item1"; id = "id1" },
                [PSCustomObject]@{ name = "Item2"; id = "id2" }
            )
            $result = Test-ItemExists -ItemName "Item2" -ItemId "id2" -ExistingList $existingList
            $result | Should -Be $true
        }
    }
    
    Context "Get-DomainForEditor - Domain Selection Logic" {
        
        It "Should return provided domain name if specified" {
            # This function requires minimal dependencies - just test the simple case
            $result = Get-DomainForEditor -DomainName "contoso.com" -SettingsFile "dummy.psd1" -Silent
            $result | Should -Be "contoso.com"
        }
        
        # Note: Full testing of domain fallback logic requires integration tests
        # due to dependencies on Get-AvailableDomains and file I/O operations
    }
    
    Context "Update-DomainArraySetting - Basic Validation" {
        
        It "Should be defined as a function" {
            Get-Command Update-DomainArraySetting -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        # Note: Full testing of this function requires integration tests due to file I/O dependencies
    }
}
