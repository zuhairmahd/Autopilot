<#
.SYNOPSIS
    Function loading validation tests
.DESCRIPTION
    Validates that the test framework properly loads functions and that they can be called within test scripts
    Converted from TestScripts/test-function-loading-validation.ps1
#>

Describe "Function Loading Validation" -Tags 'Unit', 'FunctionLoading', 'Fast' {
    
    BeforeAll {
        # Get repository root
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        
        # Setup minimal global variables that some functions require
        $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $global:LogFile = Join-Path $tempPath "test-function-loading-validation.log"
        $global:settings = @{ appMode = "full" }
        
        # Load all functions directly using dot-sourcing
        $functionsPath = Join-Path $script:RepoRoot "functions"
        $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 -ErrorAction Stop
        
        $script:LoadErrors = @()
        foreach ($file in $functionFiles) {
            try {
                . $file.FullName
            }
            catch {
                $script:LoadErrors += @{
                    File = $file.Name
                    Error = $_.Exception.Message
                }
            }
        }
        
        Write-Verbose "Loaded $($functionFiles.Count) function files with $($script:LoadErrors.Count) errors"
        
        # Define critical functions from each category
        $script:CriticalFunctions = @{
            'Write-Log' = 'Core utility function'
            'Get-ConfigurationData' = 'Setup function'
            'Test-MenuItemIncluded' = 'Menu function'
            'MergeSettings' = 'Settings function'
            'GetNextUserReadinessReport' = 'User readiness function'
            'Start-FirstRunWizard' = 'Wizard function'
        }
    }
    
    Context "Core utility functions" {
        
        It "Write-Log function should be available and executable" {
            # Check availability
            $writeLogAvailable = Get-Command "Write-Log" -ErrorAction SilentlyContinue
            $writeLogAvailable | Should -Not -BeNullOrEmpty -Because "Write-Log is a core utility function"
            
            # Test execution
            $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
            $testLogFile = Join-Path $tempPath "test-function-loading-validation.log"
            { Write-Log -LogFile $testLogFile -Module "Test" -Message "Function loading test" -LogLevel "Information" } | Should -Not -Throw
            
            # Clean up
            if (Test-Path $testLogFile) {
                Remove-Item $testLogFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Setup functions" {
        
        It "Get-ConfigurationData function should be available and executable" {
            # Check availability
            $configDataAvailable = Get-Command "Get-ConfigurationData" -ErrorAction SilentlyContinue
            $configDataAvailable | Should -Not -BeNullOrEmpty -Because "Get-ConfigurationData is a setup function"
            
            # Test execution with temp file
            $tempPath = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
            $tempConfigPath = Join-Path $tempPath "test-nonexistent"
            $testResult = Get-ConfigurationData -ConfigurationPath $tempConfigPath -DefaultValues @{test = "value"} -ErrorAction SilentlyContinue
            
            $testResult.test | Should -Be "value" -Because "function should return default values when file doesn't exist"
            
            # Clean up any created file
            $createdFile = "$tempConfigPath.psd1"
            if (Test-Path $createdFile) {
                Remove-Item $createdFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Menu functions" {
        
        It "Test-MenuItemIncluded function should be available and executable" {
            # Check availability
            $menuTestAvailable = Get-Command "Test-MenuItemIncluded" -ErrorAction SilentlyContinue
            $menuTestAvailable | Should -Not -BeNullOrEmpty -Because "Test-MenuItemIncluded is a menu function"
            
            # Test execution
            { 
                $result = Test-MenuItemIncluded -MenuItemName "Test Item" -Menus $null
            } | Should -Not -Throw
        }
    }
    
    Context "Function loading summary" {
        
        It "All critical functions should be available" {
            $missingFunctions = @()
            
            foreach ($functionName in $script:CriticalFunctions.Keys) {
                $isAvailable = Get-Command $functionName -ErrorAction SilentlyContinue
                if (-not $isAvailable) {
                    $missingFunctions += "$functionName ($($script:CriticalFunctions[$functionName]))"
                }
            }
            
            if ($missingFunctions.Count -gt 0) {
                $errorMessage = "Missing critical functions:`n  - $($missingFunctions -join "`n  - ")"
                $missingFunctions | Should -BeNullOrEmpty -Because $errorMessage
            }
            
            $missingFunctions | Should -BeNullOrEmpty -Because "all $($script:CriticalFunctions.Count) critical functions must be available"
        }
        
        It "Should have loaded at least 180 function files" {
            $functionsPath = Join-Path $script:RepoRoot "functions"
            $functionFiles = Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1
            
            $functionFiles.Count | Should -BeGreaterThan 180 -Because "expected approximately 185 function files"
        }
    }
}
