<#
.SYNOPSIS
    Function loading validation tests
.DESCRIPTION
    Verifies that critical application functions can be loaded successfully
    Converted from TestScripts/test-simple-function-loading.ps1
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function Loading" -Tags 'Unit', 'FunctionLoading', 'Fast' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Initialize helpers for LogFile and settings
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $logPath = Join-Path $tempPath "test-function-loading.log"
        Initialize-MockGlobalVariables -LogFile $logPath `
            -Settings @{ appMode = "full" }
        
        # Load all functions directly using dot-sourcing
        $functionsPath = Join-Path $script:RepoRoot "functions"
        $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -ErrorAction Stop
        
        $script:LoadErrors = @()
        foreach ($file in $functionFiles)
        {
            try
            {
                . $file.FullName
            }
            catch
            {
                $script:LoadErrors += @{
                    File  = $file.Name
                    Error = $_.Exception.Message
                }
            }
        }
        
        Write-Verbose "Loaded $($functionFiles.Count) function files with $($script:LoadErrors.Count) errors"
        
        # Define critical functions that must be available
        $script:CriticalFunctions = @(
            'Write-Log',
            'GetGraphAccessToken', 
            'Test-MenuItemIncluded',
            'MergeSettings'
        )
    }
    
    AfterAll {
        Clear-MockGlobalVariables
    }
    
    Context "Critical functions" {
        
        It "All critical functions should be available" {
            # Test each critical function
            $missingFunctions = @()
            
            foreach ($functionName in $script:CriticalFunctions)
            {
                $command = Get-Command $functionName -ErrorAction SilentlyContinue
                if (-not $command)
                {
                    $missingFunctions += $functionName
                }
                elseif ($command.CommandType -ne 'Function')
                {
                    $missingFunctions += "$functionName (wrong type: $($command.CommandType))"
                }
            }
            
            # Assert
            if ($missingFunctions.Count -gt 0)
            {
                $errorMessage = "Missing critical functions: $($missingFunctions -join ', ')"
                $missingFunctions | Should -BeNullOrEmpty -Because $errorMessage
            }
            
            $missingFunctions | Should -BeNullOrEmpty -Because "all $($script:CriticalFunctions.Count) critical functions must be available"
        }
    }
    
    Context "Function count" {
        
        It "Should load at least 180 functions" {
            # Act
            $functionsPath = Join-Path $script:RepoRoot "functions"
            $functionFiles = Get-ChildItem -Path $functionsPath -Filter '*.ps1' -Recurse
            
            # Assert
            $functionFiles.Count | Should -BeGreaterThan 180 -Because "Expected approximately 185 function files"
        }
    }
    
    Context "Function execution" {
        
        It "Test-MenuItemIncluded should execute without errors" {
            # Act & Assert
            { Test-MenuItemIncluded -MenuItemName "Test" -Menus $null } | Should -Not -Throw
        }
    }
}
