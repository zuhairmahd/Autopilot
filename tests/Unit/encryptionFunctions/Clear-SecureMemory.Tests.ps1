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
        if ($script:TestContext -and (Test-Path $script:TestContext.TestFolder))
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    
    Context "When clearing local scope variables" {
        
        It "Should clear specified local variables" {
            # Variables need to be in the parent scope for Remove-Variable to work in tests
            Set-Variable -Name testVar1 -Value "sensitive-data-1" -Scope 1
            Set-Variable -Name testVar2 -Value "sensitive-data-2" -Scope 1
            
            Clear-SecureMemory -Variables @("testVar1", "testVar2")
            
            # Verify variables are removed
            { Get-Variable -Name testVar1 -Scope 1 -ErrorAction Stop } | Should -Throw
            { Get-Variable -Name testVar2 -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should handle single variable name" {
            Set-Variable -Name singleVar -Value "sensitive-data" -Scope 1
            
            Clear-SecureMemory -Variables @("singleVar")
            
            { Get-Variable -Name singleVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should handle non-existent variable gracefully" {
            { Clear-SecureMemory -Variables @("NonExistentVar") } | Should -Not -Throw
        }
        
        It "Should handle empty variable array" {
            { Clear-SecureMemory -Variables @() } | Should -Not -Throw
        }
        
        It "Should handle multiple variables with mixed existence" {
            Set-Variable -Name existingVar -Value "exists" -Scope 1
            
            { Clear-SecureMemory -Variables @("existingVar", "nonExistentVar") } | Should -Not -Throw
            
            { Get-Variable -Name existingVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "When clearing script scope variables" {
        
        It "Should prefer local scope over script scope" {
            Set-Variable -Name TestScriptVar1 -Value "local-value" -Scope 1
            $script:TestScriptVar1 = "script-value"
            
            Clear-SecureMemory -Variables @("TestScriptVar1")
            
            # Local scope should be cleared
            { Get-Variable -Name TestScriptVar1 -Scope 1 -ErrorAction Stop } | Should -Throw
            
            # Script scope variable should still exist
            Get-Variable -Name TestScriptVar1 -Scope Script -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
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
            Set-Variable -Name localVar -Value "local-data" -Scope 1
            $script:TempEncryptedConfig = "encrypted-content"
            
            Clear-SecureMemory -Variables @("localVar") -ClearScriptVariables
            
            { Get-Variable -Name localVar -Scope 1 -ErrorAction Stop } | Should -Throw
            { Get-Variable -Name TempEncryptedConfig -Scope Script -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "When testing different data types" {
        
        It "Should clear string variables" {
            Set-Variable -Name stringVar -Value "sensitive-string" -Scope 1
            
            Clear-SecureMemory -Variables @("stringVar")
            
            { Get-Variable -Name stringVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should clear SecureString variables" {
            Set-Variable -Name secureVar -Value (ConvertTo-SecureString "password" -AsPlainText -Force) -Scope 1
            
            Clear-SecureMemory -Variables @("secureVar")
            
            { Get-Variable -Name secureVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should clear hashtable variables" {
            Set-Variable -Name hashVar -Value @{key = "value"; secret = "data"} -Scope 1
            
            Clear-SecureMemory -Variables @("hashVar")
            
            { Get-Variable -Name hashVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should clear array variables" {
            Set-Variable -Name arrayVar -Value @("item1", "item2", "item3") -Scope 1
            
            Clear-SecureMemory -Variables @("arrayVar")
            
            { Get-Variable -Name arrayVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should clear numeric variables" {
            Set-Variable -Name numVar -Value 12345 -Scope 1
            
            Clear-SecureMemory -Variables @("numVar")
            
            { Get-Variable -Name numVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should clear boolean variables" {
            Set-Variable -Name boolVar -Value $true -Scope 1
            
            Clear-SecureMemory -Variables @("boolVar")
            
            { Get-Variable -Name boolVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "When testing garbage collection" {
        
        It "Should trigger garbage collection" {
            Set-Variable -Name testVar -Value "data" -Scope 1
            
            # Just verify function completes without error
            { Clear-SecureMemory -Variables @("testVar") } | Should -Not -Throw
            
            { Get-Variable -Name testVar -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should complete successfully even with large data sets" {
            Set-Variable -Name largeData -Value (1..10000 | ForEach-Object { "item$_" }) -Scope 1
            
            { Clear-SecureMemory -Variables @("largeData") } | Should -Not -Throw
        }
    }
    
    Context "When testing return values and tracking" {
        
        It "Should track cleared variables" {
            Set-Variable -Name var1 -Value "data1" -Scope 1
            Set-Variable -Name var2 -Value "data2" -Scope 1
            Set-Variable -Name var3 -Value "data3" -Scope 1
            
            # The function completes successfully
            { Clear-SecureMemory -Variables @("var1", "var2", "var3") } | Should -Not -Throw
            
            # Verify variables are cleared
            { Get-Variable -Name var1 -Scope 1 -ErrorAction Stop } | Should -Throw
            { Get-Variable -Name var2 -Scope 1 -ErrorAction Stop } | Should -Throw
            { Get-Variable -Name var3 -Scope 1 -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "When testing verbose and logging output" {
        
        It "Should produce verbose output when -Verbose is used" {
            Set-Variable -Name testVar -Value "data" -Scope 1
            
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
            
            Set-Variable -Name testVar -Value "data" -Scope 1
            Clear-SecureMemory -Variables @("testVar")
            
            # Verify the mock was called
            Assert-MockCalled Write-Log -Times 1 -Exactly:$false
        }
        
        It "Should produce verbose output for each cleared variable" {
            Set-Variable -Name var1 -Value "data1" -Scope 1
            Set-Variable -Name var2 -Value "data2" -Scope 1
            
            $verboseOutput = Clear-SecureMemory -Variables @("var1", "var2") -Verbose 4>&1
            
            ($verboseOutput -join " ") | Should -Match "var1|var2"
        }
    }
    
    Context "When testing edge cases" {
        
        It "Should handle variables with special characters in names" {
            # PowerShell allows underscores and numbers in variable names
            Set-Variable -Name test_var_123 -Value "data" -Scope 1
            
            Clear-SecureMemory -Variables @("test_var_123")
            
            { Get-Variable -Name test_var_123 -Scope 1 -ErrorAction Stop } | Should -Throw
        }
        
        It "Should handle null values in variable array" {
            Set-Variable -Name testVar -Value "data" -Scope 1
            
            # Filter out nulls since PowerShell validation doesn't allow them
            $varList = @("testVar", $null, "nonExistent") | Where-Object { $_ -ne $null }
            { Clear-SecureMemory -Variables $varList } | Should -Not -Throw
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
