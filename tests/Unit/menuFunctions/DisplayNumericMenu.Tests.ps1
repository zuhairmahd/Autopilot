<#
.SYNOPSIS
    Unit tests for DisplayNumericMenu function

.DESCRIPTION
    Tests menu display functionality including the new description parameter,
    parameter validation, and edge cases. Tests are designed to avoid interactive input.

.NOTES
    Test Category: Unit
    Function: DisplayNumericMenu
    Module: menuFunctions
    Coverage Target: Menu display with descriptions, parameter validation
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: DisplayNumericMenu" -Tags 'Unit', 'menuFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependencies
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Load the function under test
        . "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1"
        
        # Mock Write-Log to avoid file I/O
        Mock Write-Log { }
    }
    
    BeforeEach {
        # Initialize mock global variables with cross-platform temp path
        $tempPath = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $Global:LogFile = Join-Path $tempPath "autopilot-test.log"
        Initialize-MockGlobalVariables -Settings @{ maxMenuItemsPerPage = 15 } -LogFile $Global:LogFile
        
        # Initialize returnValues for edge cases
        $Global:returnValues = @{
            NoMenusConfigured = "No menus configured"
        }
    }
    
    AfterEach {
        # Clean up mock global variables
        Clear-MockGlobalVariables
    }
    
    Context "Parameter Definitions" {
        It "Should have descriptions parameter accepting string array" {
            # Get the function's parameter info
            $cmd = Get-Command DisplayNumericMenu
            $descParam = $cmd.Parameters['descriptions']
            
            $descParam | Should -Not -BeNull
            $descParam.ParameterType | Should -Be ([string[]])
        }
        
        It "Should have descriptions parameter as optional" {
            $cmd = Get-Command DisplayNumericMenu
            $descParam = $cmd.Parameters['descriptions']
            
            # Verify parameter exists and is not mandatory
            $descParam | Should -Not -BeNull
            $mandatoryAttr = $descParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -BeNull
        }
        
        It "Should have all expected parameters" {
            $cmd = Get-Command DisplayNumericMenu
            
            $cmd.Parameters.ContainsKey('choices') | Should -Be $true
            $cmd.Parameters.ContainsKey('descriptions') | Should -Be $true
            $cmd.Parameters.ContainsKey('banner') | Should -Be $true
            $cmd.Parameters.ContainsKey('Prompt') | Should -Be $true
            $cmd.Parameters.ContainsKey('errorMessage') | Should -Be $true
            $cmd.Parameters.ContainsKey('RequireEnter') | Should -Be $true
            $cmd.Parameters.ContainsKey('MaxItemsPerPage') | Should -Be $true
        }
        
        It "Should have choices parameter as mandatory" {
            $cmd = Get-Command DisplayNumericMenu
            $choicesParam = $cmd.Parameters['choices']
            
            $mandatoryAttr = $choicesParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNull
        }
    }
    
    Context "Empty Choices Handling" {
        It "Should throw for empty choices array due to mandatory parameter validation" {
            # PowerShell rejects empty arrays for mandatory string[] parameters
            { DisplayNumericMenu -choices @() -banner "Test" } | Should -Throw
        }
    }
    
    Context "Function Documentation" {
        It "Should have documentation for descriptions parameter" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match '\.PARAMETER descriptions'
        }
        
        It "Should have example with descriptions in documentation" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match '-descriptions'
        }
        
        It "Should document that descriptions are displayed in Gray color" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match 'Gray'
        }
    }
}
