<#
.SYNOPSIS
    Replace/Add logic tests
.DESCRIPTION
    Tests the replace/add logic used in Get-GroupArrayInput function
    Converted from TestScripts/test-replace-logic-simple.ps1
#>

Describe "Replace/Add Logic" -Tags 'Unit', 'Logic', 'GroupArray' {
    
    Context "Replace mode (ShouldReplaceExisting = true)" {
        
        BeforeAll {
            $script:CurrentGroups = @(
                @{ name = "Old1"; id = "old-1" },
                @{ name = "Old2"; id = "old-2" }
            )
            $script:NewGroups = @(
                @{ name = "New1"; id = "new-1" }
            )
            $script:Decision = @{ ShouldReplaceExisting = $true }
            
            # Apply logic from Get-GroupArrayInput
            if ($script:Decision.ShouldReplaceExisting -or -not $script:CurrentGroups -or $script:CurrentGroups.Count -eq 0) {
                $script:Result = $script:NewGroups
            }
            else {
                $combinedGroups = @()
                $combinedGroups += $script:CurrentGroups
                $combinedGroups += $script:NewGroups
                $script:Result = $combinedGroups
            }
        }
        
        It "Should have exactly 1 group" {
            $script:Result.Count | Should -Be 1
        }
        
        It "Should contain only the new group" {
            $script:Result[0].name | Should -Be "New1"
        }
        
        It "Should not contain old groups" {
            $script:Result.name | Should -Not -Contain "Old1"
            $script:Result.name | Should -Not -Contain "Old2"
        }
    }
    
    Context "Add mode (ShouldReplaceExisting = false)" {
        
        BeforeAll {
            $script:CurrentGroups = @(
                @{ name = "Old1"; id = "old-1" },
                @{ name = "Old2"; id = "old-2" }
            )
            $script:NewGroups = @(
                @{ name = "New1"; id = "new-1" }
            )
            $script:Decision = @{ ShouldReplaceExisting = $false }
            
            # Apply logic from Get-GroupArrayInput
            if ($script:Decision.ShouldReplaceExisting -or -not $script:CurrentGroups -or $script:CurrentGroups.Count -eq 0) {
                $script:Result = $script:NewGroups
            }
            else {
                $combinedGroups = @()
                $combinedGroups += $script:CurrentGroups
                $combinedGroups += $script:NewGroups
                $script:Result = $combinedGroups
            }
        }
        
        It "Should have exactly 3 groups" {
            $script:Result.Count | Should -Be 3
        }
        
        It "Should contain all old groups" {
            $script:Result[0].name | Should -Be "Old1"
            $script:Result[1].name | Should -Be "Old2"
        }
        
        It "Should contain the new group" {
            $script:Result[2].name | Should -Be "New1"
        }
        
        It "Should maintain order (old groups first, then new)" {
            $script:Result.name | Should -Be @("Old1", "Old2", "New1")
        }
    }
    
    Context "Edge case: Empty current groups with add mode" {
        
        BeforeAll {
            $script:CurrentGroups = @()
            $script:NewGroups = @(
                @{ name = "New1"; id = "new-1" }
            )
            $script:Decision = @{ ShouldReplaceExisting = $false }
            
            # Apply logic
            if ($script:Decision.ShouldReplaceExisting -or -not $script:CurrentGroups -or $script:CurrentGroups.Count -eq 0) {
                $script:Result = $script:NewGroups
            }
            else {
                $combinedGroups = @()
                $combinedGroups += $script:CurrentGroups
                $combinedGroups += $script:NewGroups
                $script:Result = $combinedGroups
            }
        }
        
        It "Should return only new groups when current is empty" {
            $script:Result.Count | Should -Be 1
            $script:Result[0].name | Should -Be "New1"
        }
    }
    
    Context "Edge case: Null current groups" {
        
        BeforeAll {
            $script:CurrentGroups = $null
            $script:NewGroups = @(
                @{ name = "New1"; id = "new-1" }
            )
            $script:Decision = @{ ShouldReplaceExisting = $false }
            
            # Apply logic
            if ($script:Decision.ShouldReplaceExisting -or -not $script:CurrentGroups -or $script:CurrentGroups.Count -eq 0) {
                $script:Result = $script:NewGroups
            }
            else {
                $combinedGroups = @()
                $combinedGroups += $script:CurrentGroups
                $combinedGroups += $script:NewGroups
                $script:Result = $combinedGroups
            }
        }
        
        It "Should return only new groups when current is null" {
            $script:Result.Count | Should -Be 1
            $script:Result[0].name | Should -Be "New1"
        }
    }
}
