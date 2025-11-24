<#
.SYNOPSIS
    Pester tests for Show-GroupsEditor.ps1 utility functions
    
.DESCRIPTION
    Comprehensive unit tests for group editor utility functions:
    - Get-GroupArrayInput: Array input processing (utility aspects)
    - Format detection and conversion (string vs hashtable arrays)
    - Duplicate prevention logic via Test-ItemExists
    - Array comparison and merging
    
.NOTES
    Framework: Pester 5.x
    Compatibility: PowerShell 5.1+
    Test Category: Unit
    
    Interactive functions (Show-GroupsEditor, Resolve-SingleGroupInteractive) are
    tested via integration tests, not unit tests, to avoid input prompts during
    automated testing.
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-GroupArrayInput - Array Format Detection" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load required functions
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Initialize log file (required for Write-Log)
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should detect empty array format" {
        $groups = @()
        $format = Get-EditorArrayFormat -Array $groups
        $format | Should -Be "Empty"
    }
    
    It "Should detect string array format (legacy)" {
        $groups = @("Group1", "Group2", "Group3")
        $format = Get-EditorArrayFormat -Array $groups
        $format | Should -Be "StringArray"
    }
    
    It "Should detect hashtable array format (new)" {
        $groups = @(
            @{ name = "Group1"; id = "id-1" }
            @{ name = "Group2"; id = "id-2" }
        )
        $format = Get-EditorArrayFormat -Array $groups
        $format | Should -Be "HashTableArray"
    }
    
    It "Should detect PSCustomObject array format" {
        $groups = @(
            [PSCustomObject]@{ name = "Group1"; id = "id-1" }
            [PSCustomObject]@{ name = "Group2"; id = "id-2" }
        )
        $format = Get-EditorArrayFormat -Array $groups
        $format | Should -Be "HashTableArray"
    }
}

Describe "Function: Get-GroupArrayInput - Array Unwrapping Regression Tests" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should demonstrate PowerShell single-element array unwrapping bug" {
        $domainConfig = @{
            groupsToInclude = @(@{ name = "SingleGroup"; id = "id-1" })
        }
        
        $groupsUnwrapped = $domainConfig.groupsToInclude
        $groupsUnwrapped | Should -BeOfType [hashtable]
        
        $groupsWrapped = @($domainConfig.groupsToInclude)
        $groupsWrapped.Count | Should -Be 1
    }
    
    It "Should preserve single-element array type with @() wrapper" {
        $domainConfig = @{
            groupsToInclude = @(@{ name = "SingleGroup"; id = "id-1" })
        }
        
        $currentGroups = @($domainConfig.groupsToInclude)
        $currentGroups.Count | Should -Be 1
        $currentGroups[0] | Should -BeOfType [hashtable]
    }
    
    It "Should handle empty array without unwrapping" {
        $domainConfig = @{
            groupsToInclude = @()
        }
        
        $currentGroups = @($domainConfig.groupsToInclude)
        $currentGroups.Count | Should -Be 0
    }
    
    It "Should handle multi-element array without unwrapping" {
        $domainConfig = @{
            groupsToInclude = @(
                @{ name = "Group1"; id = "id-1" }
                @{ name = "Group2"; id = "id-2" }
            )
        }
        
        $currentGroups = @($domainConfig.groupsToInclude)
        $currentGroups.Count | Should -Be 2
    }
}

Describe "Function: Show-GroupsEditor - Duplicate Detection" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should detect duplicate groups by name" {
        $existingGroups = @(
            @{ name = "Marketing"; id = "id-1" }
            @{ name = "Sales"; id = "id-2" }
        )
        
        $isDuplicate = Test-ItemExists -ItemName "Marketing" -ExistingList $existingGroups
        $isDuplicate | Should -Be $true
    }
    
    It "Should detect duplicate groups by ID" {
        $existingGroups = @(
            @{ name = "Marketing"; id = "id-1" }
            @{ name = "Sales"; id = "id-2" }
        )
        
        $isDuplicate = Test-ItemExists -ItemId "id-2" -ExistingList $existingGroups
        $isDuplicate | Should -Be $true
    }
    
    It "Should not report false positives for unique groups" {
        $existingGroups = @(
            @{ name = "Marketing"; id = "id-1" }
        )
        
        $isDuplicate = Test-ItemExists -ItemName "Engineering" -ExistingList $existingGroups
        $isDuplicate | Should -Be $false
    }
    
    It "Should handle empty existing list" {
        $existingGroups = @()
        
        $isDuplicate = Test-ItemExists -ItemName "Any Group" -ExistingList $existingGroups
        $isDuplicate | Should -Be $false
    }
    
    It "Should handle string array format (legacy)" {
        $existingGroups = @("Marketing", "Sales", "Engineering")
        
        $isDuplicate = Test-ItemExists -ItemName "Marketing" -ExistingList $existingGroups
        $isDuplicate | Should -Be $true
    }
}

Describe "Function: Convert-StringArrayToHashTableArray - Format Conversion" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should convert string array to hashtable array" {
        $stringGroups = @("Marketing", "Sales", "Engineering")
        $hashGroups = Convert-StringArrayToHashTableArray -StringArray $stringGroups
        
        $hashGroups.Count | Should -Be 3
        $hashGroups[0] | Should -BeOfType [hashtable]
        $hashGroups[0].name | Should -Be "Marketing"
        $hashGroups[0].id | Should -Be $null
    }
    
    It "Should handle empty string array" {
        $stringGroups = @()
        $hashGroups = Convert-StringArrayToHashTableArray -StringArray $stringGroups
        
        $hashGroups.Count | Should -Be 0
    }
    
    It "Should handle single-element string array" {
        $stringGroups = @("SingleGroup")
        $hashGroups = @(Convert-StringArrayToHashTableArray -StringArray $stringGroups)
        
        $hashGroups.Count | Should -Be 1
        $hashGroups[0].name | Should -Be "SingleGroup"
        $hashGroups[0].id | Should -Be $null
    }
    
    It "Should preserve group names during conversion" {
        $stringGroups = @("Group A", "Group B", "Group C")
        $hashGroups = Convert-StringArrayToHashTableArray -StringArray $stringGroups
        
        $hashGroups[0].name | Should -Be "Group A"
        $hashGroups[1].name | Should -Be "Group B"
        $hashGroups[2].name | Should -Be "Group C"
    }
}

Describe "Function: Compare-EditorArrayContents - Array Comparison" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should detect differences between string and hashtable format" {
        $stringGroups = @("Marketing", "Sales")
        $hashGroups = @(
            @{ name = "Marketing"; id = "id-1" }
            @{ name = "Sales"; id = "id-2" }
        )
        
        $hasChanges = Compare-EditorArrayContents -Array1 $stringGroups -Array2 $hashGroups
        $hasChanges | Should -Be $true
    }
    
    It "Should detect identical string arrays as unchanged" {
        $groups1 = @("Marketing", "Sales", "Engineering")
        $groups2 = @("Marketing", "Sales", "Engineering")
        
        $hasChanges = Compare-EditorArrayContents -Array1 $groups1 -Array2 $groups2
        $hasChanges | Should -Be $false
    }
    
    It "Should detect identical hashtable arrays as unchanged" {
        $groups1 = @(
            @{ name = "Marketing"; id = "id-1" }
            @{ name = "Sales"; id = "id-2" }
        )
        $groups2 = @(
            @{ name = "Marketing"; id = "id-1" }
            @{ name = "Sales"; id = "id-2" }
        )
        
        $hasChanges = Compare-EditorArrayContents -Array1 $groups1 -Array2 $groups2
        $hasChanges | Should -Be $false
    }
    
    It "Should detect additions to group array" {
        $groups1 = @("Marketing", "Sales")
        $groups2 = @("Marketing", "Sales", "Engineering")
        
        $hasChanges = Compare-EditorArrayContents -Array1 $groups1 -Array2 $groups2
        $hasChanges | Should -Be $true
    }
    
    It "Should detect removals from group array" {
        $groups1 = @("Marketing", "Sales", "Engineering")
        $groups2 = @("Marketing", "Sales")
        
        $hasChanges = Compare-EditorArrayContents -Array1 $groups1 -Array2 $groups2
        $hasChanges | Should -Be $true
    }
}

Describe "Function: Show-GroupsEditor - Configuration Validation" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should load domain configuration with group arrays in hashtable structure" {
        $domainConfig = @{
            domainName      = "contoso.com"
            groupsToInclude = @(
                @{ name = "Marketing"; id = "id-1" }
                @{ name = "Sales"; id = "id-2" }
            )
            groupsToExclude = @(
                @{ name = "Guests"; id = "id-3" }
            )
        }
        
        $domainConfig.groupsToInclude.Count | Should -Be 2
        $domainConfig.groupsToExclude.Count | Should -Be 1
        $domainConfig.groupsToInclude[0].name | Should -Be "Marketing"
        $domainConfig.groupsToInclude[0].id | Should -Be "id-1"
    }
    
    It "Should handle domain configuration with missing group IDs" {
        $domainConfig = @{
            domainName      = "contoso.com"
            groupsToInclude = @(
                @{ name = "UnresolvedGroup"; id = $null }
            )
        }
        
        $domainConfig.groupsToInclude[0].name | Should -Be "UnresolvedGroup"
        $domainConfig.groupsToInclude[0].id | Should -Be $null
    }
    
    It "Should preserve array type when loading single-element group arrays" {
        $domainConfig = @{
            domainName      = "contoso.com"
            groupsToInclude = @(@{ name = "SingleGroup"; id = "id-1" })
        }
        
        $currentGroups = @($domainConfig.groupsToInclude)
        $currentGroups.Count | Should -Be 1
    }
}

Describe "Function: Show-GroupsEditor - Edge Cases" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should handle null group arrays gracefully" {
        $groups1 = $null
        $groups2 = @()
        
        # Compare-EditorArrayContents treats null and empty array as equivalent (no changes)
        $hasChanges = Compare-EditorArrayContents -Array1 $groups1 -Array2 $groups2
        $hasChanges | Should -Be $false
    }
    
    It "Should handle empty string in group name conversion" {
        $stringGroups = @("")
        $hashGroups = @(Convert-StringArrayToHashTableArray -StringArray $stringGroups)
        
        $hashGroups.Count | Should -Be 1
        $hashGroups[0].name | Should -Be ""
    }
    
    It "Should handle mixed case in duplicate detection" {
        $existingGroups = @(
            @{ name = "Marketing"; id = "id-1" }
        )
        
        $isDuplicate = Test-ItemExists -ItemName "MARKETING" -ExistingList $existingGroups
        $isDuplicate | Should -Be $true
    }
    
    It "Should handle whitespace in group names" {
        $stringGroups = @("  Marketing  ", "Sales", "  Engineering  ")
        $hashGroups = Convert-StringArrayToHashTableArray -StringArray $stringGroups
        
        $hashGroups[0].name | Should -Be "  Marketing  "
        $hashGroups[2].name | Should -Be "  Engineering  "
    }
    
    It "Should handle special characters in group names" {
        $stringGroups = @("IT & Operations", "R&D (Research)", "Sales/Marketing")
        $hashGroups = Convert-StringArrayToHashTableArray -StringArray $stringGroups
        
        $hashGroups[0].name | Should -Be "IT & Operations"
        $hashGroups[1].name | Should -Be "R&D (Research)"
        $hashGroups[2].name | Should -Be "Sales/Marketing"
    }
}

Describe "Function: Show-GroupsEditor - Array Merging" -Tags 'Unit', 'SetupFunctions' {
    BeforeAll {
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/setupFunctions/Show-EditorCommon.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        $script:logFile = Join-Path $TestDrive "test.log"
    }
    
    It "Should merge string array with hashtable array" {
        $existingGroups = @("Marketing", "Sales")
        $newGroups = @(
            @{ name = "Engineering"; id = "id-1" }
        )
        
        $convertedExisting = Convert-StringArrayToHashTableArray -StringArray $existingGroups
        $mergedGroups = $convertedExisting + $newGroups
        
        $mergedGroups.Count | Should -Be 3
        $mergedGroups[0].name | Should -Be "Marketing"
        $mergedGroups[1].name | Should -Be "Sales"
        $mergedGroups[2].name | Should -Be "Engineering"
    }
    
    It "Should merge two hashtable arrays" {
        $existingGroups = @(
            @{ name = "Marketing"; id = "id-1" }
            @{ name = "Sales"; id = "id-2" }
        )
        $newGroups = @(
            @{ name = "Engineering"; id = "id-3" }
        )
        
        $mergedGroups = $existingGroups + $newGroups
        
        $mergedGroups.Count | Should -Be 3
        $mergedGroups[2].name | Should -Be "Engineering"
    }
    
    It "Should handle merging with empty existing array" {
        $existingGroups = @()
        $newGroups = @(
            @{ name = "Engineering"; id = "id-1" }
        )
        
        $mergedGroups = $existingGroups + $newGroups
        
        $mergedGroups.Count | Should -Be 1
        $mergedGroups[0].name | Should -Be "Engineering"
    }
    
    It "Should handle merging with empty new array" {
        $existingGroups = @(
            @{ name = "Marketing"; id = "id-1" }
        )
        $newGroups = @()
        
        $mergedGroups = $existingGroups + $newGroups
        
        $mergedGroups.Count | Should -Be 1
        $mergedGroups[0].name | Should -Be "Marketing"
    }
}
