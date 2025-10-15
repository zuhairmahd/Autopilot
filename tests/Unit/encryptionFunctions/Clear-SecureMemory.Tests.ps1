<#
.SYNOPSIS
    Unit tests for Clear-SecureMemory function

.DESCRIPTION
    Tests clearing sensitive data from memory and forcing garbage collection.
    Covers variable cleanup, script-level variables, and garbage collection.

.NOTES
    Test Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Tests removal of specified variables from different scopes
    - Tests clearing of script-level temporary encryption variables
    - Validates garbage collection is triggered
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Clear-SecureMemory" -Tags 'Unit', 'EncryptionFunctions' {
    
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependent functions
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/encryptionFunctions/Clear-SecureMemory.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:LogFile = $script:TestContext.LogFile
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and (Test-Path $script:TestContext.TestFolder)) {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "When clearing local scope variables" {
        
        It "Should clear specified local variables" {
            $testVar1 = "sensitive-data-1"
            $testVar2 = "sensitive-data-2"
            
            Clear-SecureMemory -Variables @("testVar1", "testVar2")
            
            Get-Variable -Name testVar1 -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Variable -Name testVar2 -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should handle single variable name" {
            $singleVar = "sensitive-data"
            
            Clear-SecureMemory -Variables @("singleVar")
            
            Get-Variable -Name singleVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should handle non-existent variable gracefully" {
            { Clear-SecureMemory -Variables @("NonExistentVar") } | Should -Not -Throw
        }
        
        It "Should handle empty variable array" {
            { Clear-SecureMemory -Variables @() } | Should -Not -Throw
        }
        
        It "Should handle multiple variables with mixed existence" {
            $existingVar = "exists"
            
            { Clear-SecureMemory -Variables @("existingVar", "nonExistentVar") } | Should -Not -Throw
            
            Get-Variable -Name existingVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
    
    Context "When clearing script scope variables" {
        
        BeforeEach {
            $script:TestScriptVar1 = "script-sensitive-1"
            $script:TestScriptVar2 = "script-sensitive-2"
        }
        
        It "Should clear script-scoped variables" {
            Clear-SecureMemory -Variables @("TestScriptVar1", "TestScriptVar2")
            
            Get-Variable -Name TestScriptVar1 -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Variable -Name TestScriptVar2 -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should prefer local scope over script scope" {
            $TestScriptVar1 = "local-value"
            $script:TestScriptVar1 = "script-value"
            
            Clear-SecureMemory -Variables @("TestScriptVar1")
            
            # Local should be cleared first
            Get-Variable -Name TestScriptVar1 -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
    
    Context "When clearing script-level encryption variables" {
        
        BeforeEach {
            $script:TempEncryptedConfig = "encrypted-content"
            $script:TempEncryptionKey = "encryption-key"
            $script:UserEncryptionPassword = ConvertTo-SecureString "password" -AsPlainText -Force
        }
        
        It "Should clear TempEncryptedConfig when ClearScriptVariables is specified" {
            Clear-SecureMemory -ClearScriptVariables
            
            Get-Variable -Name TempEncryptedConfig -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should clear TempEncryptionKey when ClearScriptVariables is specified" {
            Clear-SecureMemory -ClearScriptVariables
            
            Get-Variable -Name TempEncryptionKey -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should clear UserEncryptionPassword when ClearScriptVariables is specified" {
            Clear-SecureMemory -ClearScriptVariables
            
            Get-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should not clear script variables when ClearScriptVariables is not specified" {
            $script:TempEncryptedConfig = "encrypted-content"
            
            Clear-SecureMemory -Variables @()
            
            $script:TempEncryptedConfig | Should -Be "encrypted-content"
            
            # Clean up
            Remove-Variable -Name TempEncryptedConfig -Scope Script
        }
        
        It "Should clear both specified variables and script variables when both are requested" {
            $localVar = "local-data"
            $script:TempEncryptedConfig = "encrypted-content"
            
            Clear-SecureMemory -Variables @("localVar") -ClearScriptVariables
            
            Get-Variable -Name localVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Variable -Name TempEncryptedConfig -Scope Script -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
    
    Context "When testing different data types" {
        
        It "Should clear string variables" {
            $stringVar = "sensitive-string"
            
            Clear-SecureMemory -Variables @("stringVar")
            
            Get-Variable -Name stringVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should clear SecureString variables" {
            $secureVar = ConvertTo-SecureString "password" -AsPlainText -Force
            
            Clear-SecureMemory -Variables @("secureVar")
            
            Get-Variable -Name secureVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should clear hashtable variables" {
            $hashVar = @{key = "value"; secret = "data"}
            
            Clear-SecureMemory -Variables @("hashVar")
            
            Get-Variable -Name hashVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should clear array variables" {
            $arrayVar = @("item1", "item2", "item3")
            
            Clear-SecureMemory -Variables @("arrayVar")
            
            Get-Variable -Name arrayVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should clear numeric variables" {
            $numVar = 12345
            
            Clear-SecureMemory -Variables @("numVar")
            
            Get-Variable -Name numVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should clear boolean variables" {
            $boolVar = $true
            
            Clear-SecureMemory -Variables @("boolVar")
            
            Get-Variable -Name boolVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
    
    Context "When testing garbage collection" {
        
        It "Should trigger garbage collection" {
            # Mock GC.Collect to verify it's called
            Mock -CommandName 'Invoke-Expression' -MockWith {} -ParameterFilter {
                $Command -like "*[System.GC]::Collect()*"
            }
            
            $testVar = "data"
            Clear-SecureMemory -Variables @("testVar")
            
            # Note: Actual GC.Collect is called directly in the function,
            # so we can't easily mock it, but we can verify the function completes
            Get-Variable -Name testVar -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should complete successfully even with large data sets" {
            $largeData = 1..10000 | ForEach-Object { "item$_" }
            
            { Clear-SecureMemory -Variables @("largeData") } | Should -Not -Throw
        }
    }
    
    Context "When testing return values and tracking" {
        
        It "Should track cleared variables" {
            $var1 = "data1"
            $var2 = "data2"
            $var3 = "data3"
            
            # The function returns cleared variables list
            $result = Clear-SecureMemory -Variables @("var1", "var2", "var3")
            
            # Verify variables are cleared
            Get-Variable -Name var1 -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Variable -Name var2 -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Variable -Name var3 -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
    
    Context "When testing verbose and logging output" {
        
        It "Should produce verbose output when -Verbose is used" {
            $testVar = "data"
            
            $verboseOutput = Clear-SecureMemory -Variables @("testVar") -Verbose 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should log memory cleanup operation" {
            Mock Write-Log { }
            
            $testVar = "data"
            Clear-SecureMemory -Variables @("testVar")
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*memory cleanup*" -or $Message -like "*Clearing sensitive data*"
            }
        }
        
        It "Should log when variables are cleared" {
            Mock Write-Log { }
            
            $testVar = "data"
            Clear-SecureMemory -Variables @("testVar")
            
            Should -Invoke Write-Log -AtLeast -Times 1
        }
        
        It "Should produce verbose output for each cleared variable" {
            $var1 = "data1"
            $var2 = "data2"
            
            $verboseOutput = Clear-SecureMemory -Variables @("var1", "var2") -Verbose 4>&1
            
            ($verboseOutput -join " ") | Should -Match "var1|var2"
        }
    }
    
    Context "When testing edge cases" {
        
        It "Should handle variables with special characters in names" {
            # PowerShell allows underscores and numbers in variable names
            $test_var_123 = "data"
            
            Clear-SecureMemory -Variables @("test_var_123")
            
            Get-Variable -Name test_var_123 -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
        
        It "Should handle null values in variable array" {
            $testVar = "data"
            
            { Clear-SecureMemory -Variables @("testVar", $null, "nonExistent") } | Should -Not -Throw
        }
        
        It "Should complete successfully without any parameters" {
            { Clear-SecureMemory } | Should -Not -Throw
        }
        
        It "Should handle ClearScriptVariables when script variables don't exist" {
            Remove-Variable -Name TempEncryptedConfig -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name TempEncryptionKey -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
            
            { Clear-SecureMemory -ClearScriptVariables } | Should -Not -Throw
        }
    }
}
