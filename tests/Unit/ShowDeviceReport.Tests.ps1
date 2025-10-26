<#
.SYNOPSIS
    Unit tests for ShowDeviceReport function menu loop behavior

.DESCRIPTION
    Tests that the Device Health Menu (reportExportMenu) loops until user navigates away

.NOTES
    Test Category: Unit
    Function: ShowDeviceReport
    Module: reportingFunctions
    Coverage Target: Menu loop behavior for device health display/export
    
    Approach:
    - Validates that the code contains do-while loop structure
    - Validates proper handling of navigation commands
    - Uses syntax analysis to verify loop implementation
#>

Describe "Function: ShowDeviceReport - Menu Loop Implementation" -Tags 'Unit', 'reportingFunctions' {
    BeforeAll {
        # Get repository root
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        $script:FilePath = Join-Path $script:RepoRoot "functions/reportingFunctions/ShowDeviceReport.ps1"
    }
    
    Context "Code structure validates menu loop" {
        
        It "Should have valid PowerShell syntax" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            
            # Assert
            $parseErrors | Should -BeNullOrEmpty -Because "ShowDeviceReport.ps1 must have valid PowerShell syntax"
        }
        
        It "Should contain a do-while loop for menu display" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for do-while loop pattern
            $hasDoBlock = $content -match 'do\s*\{'
            $hasShowMenuInLoop = $content -match 'do\s*\{[^}]*?\$selection\s*=\s*ShowMenu'
            $hasContinueLoopVar = $content -match '\$continueLoop\s*=\s*\$true'
            $hasWhileCondition = $content -match 'while\s*\(\s*\$continueLoop\s*\)'
            
            # Assert
            $hasDoBlock | Should -Be $true -Because "Function should contain a do block"
            $hasShowMenuInLoop | Should -Be $true -Because "Function should call ShowMenu within do block"
            $hasContinueLoopVar | Should -Be $true -Because "Function should initialize continueLoop variable"
            $hasWhileCondition | Should -Be $true -Because "Function should have while(continueLoop) condition"
        }
        
        It "Should return on Back navigation command" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for Back handling (allowing for multi-line regex)
            $handlesBack = $content -match 'if.*Back'
            $returnsOnBack = $content -match 'return\s+\$selection'
            
            # Assert
            $handlesBack | Should -Be $true -Because "Function should check for Back selection"
            $returnsOnBack | Should -Be $true -Because "Function should return selection value"
        }
        
        It "Should return on Main Menu navigation command" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for Main Menu handling
            $handlesMainMenu = $content -match 'Main Menu'
            
            # Assert
            $handlesMainMenu | Should -Be $true -Because "Function should handle Main Menu selection"
        }
        
        It "Should log when returning to Device Health Menu" {
            # Arrange
            $content = Get-Content $script:FilePath -Raw
            
            # Act - Check for logging of menu loop
            $logsMenuReturn = $content -match 'Write-Log.*returning to Device Health Menu'
            
            # Assert
            $logsMenuReturn | Should -Be $true -Because "Function should log when looping back to menu"
        }
    }
}
