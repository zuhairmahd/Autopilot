<#
.SYNOPSIS
    PowerShell syntax validation tests
.DESCRIPTION
    Validates that all PowerShell files in the repository have valid syntax
    Converted from TestScripts/test-syntax.ps1
#>

BeforeAll {
    # Get repository root
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Describe "PowerShell Syntax Validation" -Tags 'Syntax', 'Unit', 'Fast' {
    
    Context "Main scripts" {
        
        It "main.ps1 should have valid syntax" {
            # Arrange
            $file = Join-Path $script:RepoRoot "main.ps1"
            $content = Get-Content $file -Raw
            
            # Act
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            
            # Assert
            $parseErrors | Should -BeNullOrEmpty -Because "main.ps1 must have valid PowerShell syntax"
        }
        
        It "CreateRelease.ps1 should have valid syntax" {
            $file = Join-Path $script:RepoRoot "CreateRelease.ps1"
            $content = Get-Content $file -Raw
            $parseErrors = @()
            $tokens = @()
            $null = [System.Management.Automation.Language.Parser]::ParseInput(
                $content, [ref]$tokens, [ref]$parseErrors
            )
            $parseErrors | Should -BeNullOrEmpty
        }
    }
    
    Context "Function files" {
        
        BeforeAll {
            # Get all function files
            $functionsPath = Join-Path $script:RepoRoot "functions"
            $script:FunctionFiles = Get-ChildItem -Path $functionsPath -Filter '*.ps1' -Recurse
        }
        
        It "All function files should have valid syntax" {
            # Test all function files
            $failedFiles = @()
            
            foreach ($file in $script:FunctionFiles)
            {
                $content = Get-Content $file.FullName -Raw
                $parseErrors = @()
                $tokens = @()
                $null = [System.Management.Automation.Language.Parser]::ParseInput(
                    $content, [ref]$tokens, [ref]$parseErrors
                )
                
                if ($parseErrors.Count -gt 0)
                {
                    $failedFiles += [PSCustomObject]@{
                        Name   = $file.Name
                        Path   = $file.FullName
                        Errors = $parseErrors
                    }
                }
            }
            
            # Assert no files failed
            if ($failedFiles.Count -gt 0)
            {
                $errorMessage = "The following function files have syntax errors:`n"
                foreach ($failed in $failedFiles)
                {
                    $errorMessage += "  - $($failed.Name):`n"
                    foreach ($err in $failed.Errors)
                    {
                        $errorMessage += "    Line $($err.Extent.StartLineNumber): $($err.Message)`n"
                    }
                }
                $failedFiles | Should -BeNullOrEmpty -Because $errorMessage
            }
            
            $failedFiles | Should -BeNullOrEmpty -Because "all $($script:FunctionFiles.Count) function files must have valid PowerShell syntax"
        }
    }
    
    # Context "Test scripts" {
        
    #     BeforeAll {
    #         $testsPath = Join-Path $script:RepoRoot "TestScripts"
    #         $script:TestFiles = Get-ChildItem -Path $testsPath -Filter '*.ps1' -Recurse
    #     }
        
    #     It "All test scripts should have valid syntax" {
    #         # Test all test files
    #         $failedFiles = @()
            
    #         foreach ($file in $script:TestFiles) {
    #             $content = Get-Content $file.FullName -Raw
    #             $parseErrors = @()
    #             $tokens = @()
    #             $null = [System.Management.Automation.Language.Parser]::ParseInput(
    #                 $content, [ref]$tokens, [ref]$parseErrors
    #             )
                
    #             if ($parseErrors.Count -gt 0) {
    #                 $failedFiles += [PSCustomObject]@{
    #                     Name = $file.Name
    #                     Path = $file.FullName
    #                     Errors = $parseErrors
    #                 }
    #             }
    #         }
            
    #         # Assert no files failed
    #         if ($failedFiles.Count -gt 0) {
    #             $errorMessage = "The following test files have syntax errors:`n"
    #             foreach ($failed in $failedFiles) {
    #                 $errorMessage += "  - $($failed.Name):`n"
    #                 foreach ($err in $failed.Errors) {
    #                     $errorMessage += "    Line $($err.Extent.StartLineNumber): $($err.Message)`n"
    #                 }
    #             }
    #             $failedFiles | Should -BeNullOrEmpty -Because $errorMessage
    #         }
            
    #         $failedFiles | Should -BeNullOrEmpty -Because "all $($script:TestFiles.Count) test scripts must have valid PowerShell syntax"
    #     }
    # }

}
