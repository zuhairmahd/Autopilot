<#
.SYNOPSIS
    Unit tests for DisplayNumericMenu function

.DESCRIPTION
    Tests menu display functionality including support for both string arrays (legacy format)
    and hashtable arrays (new format with descriptions). Tests are designed to avoid interactive input.

.NOTES
    Test Category: Unit
    Function: DisplayNumericMenu
    Module: menuFunctions
    Coverage Target: Menu display with dual format support, parameter validation
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
        It "Should have choices parameter that accepts any type (for dual format support)" {
            # Get the function's parameter info
            $cmd = Get-Command DisplayNumericMenu
            $choicesParam = $cmd.Parameters['choices']
            
            $choicesParam | Should -Not -BeNull
            # The parameter should accept any type to support both string[] and hashtable[]
            $choicesParam.ParameterType | Should -Be ([System.Object])
        }
        
        It "Should have choices parameter as mandatory" {
            $cmd = Get-Command DisplayNumericMenu
            $choicesParam = $cmd.Parameters['choices']
            
            $mandatoryAttr = $choicesParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatoryAttr | Should -Not -BeNull
        }
        
        It "Should have all expected parameters" {
            $cmd = Get-Command DisplayNumericMenu
            
            $cmd.Parameters.ContainsKey('choices') | Should -Be $true
            $cmd.Parameters.ContainsKey('banner') | Should -Be $true
            $cmd.Parameters.ContainsKey('Prompt') | Should -Be $true
            $cmd.Parameters.ContainsKey('errorMessage') | Should -Be $true
            $cmd.Parameters.ContainsKey('RequireEnter') | Should -Be $true
            $cmd.Parameters.ContainsKey('MaxItemsPerPage') | Should -Be $true
        }
    }
    
    Context "Empty Choices Handling" {
        It "Should return NoMenusConfigured for empty choices array" {
            $result = DisplayNumericMenu -choices @() -banner "Test"
            $result | Should -Be "No menus configured"
        }
        
        It "Should throw for null choices due to mandatory parameter validation" {
            # PowerShell rejects null for mandatory parameters
            { DisplayNumericMenu -choices $null -banner "Test" } | Should -Throw
        }
    }
    
    Context "Dual Format Support" {
        It "Should document support for string array format (legacy)" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match 'String array'
        }
        
        It "Should document support for hashtable array format (new)" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match 'Hashtable array'
        }
        
        It "Should document that descriptions are displayed in Gray color" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match 'Gray'
        }
        
        It "Should have example with hashtable format in documentation" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match '@\{name='
        }
    }
    
    Context "Function Documentation" {
        It "Should have documentation for choices parameter explaining dual format" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match '\.PARAMETER choices'
            $functionDef | Should -Match 'auto-detect'
        }
        
        It "Should have synopsis describing the function" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match '\.SYNOPSIS'
        }
        
        It "Should have description explaining menu behavior" {
            $functionDef = Get-Content "$script:RepoRoot/functions/menuFunctions/DisplayNumericMenu.ps1" -Raw
            $functionDef | Should -Match '\.DESCRIPTION'
        }
    }
}
