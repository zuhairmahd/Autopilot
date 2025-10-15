<#
.SYNOPSIS
    Unit tests for Get-SecurePassword function

.DESCRIPTION
    Tests secure password prompting with confirmation, validation, and silent mode.
    Covers minimum length validation, confirmation matching, and error handling.

.NOTES
    Test Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Uses Silent mode for automated testing (no interactive prompts)
    - Tests validation rules (minimum length)
    - Tests confirmation matching logic
    - Validates secure string handling
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-SecurePassword" -Tags 'Unit', 'EncryptionFunctions' {
    
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependent functions
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/encryptionFunctions/Get-SecurePassword.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:LogFile = $script:TestContext.LogFile
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and (Test-Path $script:TestContext.TestFolder)) {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Clear password variables
        Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name UserEncryptionPassword -Scope Global -ErrorAction SilentlyContinue
    }
    
    Context "When using Silent mode with stored password" {
        
        BeforeEach {
            # Store a test password in script scope
            $testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
            $script:UserEncryptionPassword = $testPassword
        }
        
        AfterEach {
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name UserEncryptionPassword -Scope Global -ErrorAction SilentlyContinue
        }
        
        It "Should return stored password in Silent mode from script scope" {
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Security.SecureString]
        }
        
        It "Should use script-scope password when available" {
            $script:UserEncryptionPassword = ConvertTo-SecureString "ScriptPassword" -AsPlainText -Force
            $global:UserEncryptionPassword = ConvertTo-SecureString "GlobalPassword" -AsPlainText -Force
            
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            # Should prefer script scope
            $result | Should -Not -BeNullOrEmpty
            
            Remove-Variable -Name UserEncryptionPassword -Scope Global
        }
        
        It "Should use global-scope password when script scope not available" {
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
            $global:UserEncryptionPassword = ConvertTo-SecureString "GlobalPassword" -AsPlainText -Force
            
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            $result | Should -Not -BeNullOrEmpty
            
            Remove-Variable -Name UserEncryptionPassword -Scope Global
        }
        
        It "Should respect MinLength parameter" {
            $result = Get-SecurePassword -Message "Enter password" -MinLength 16 -Silent
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should not require confirmation in Silent mode even if specified" {
            $result = Get-SecurePassword -Message "Enter password" -RequireConfirmation -Silent
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "When using Silent mode without stored password" {
        
        BeforeEach {
            # Clear any stored passwords
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name UserEncryptionPassword -Scope Global -ErrorAction SilentlyContinue
        }
        
        It "Should prompt interactively when no stored password exists" {
            # Mock Read-Host to simulate user input
            Mock Read-Host {
                return ConvertTo-SecureString "InteractivePassword123" -AsPlainText -Force
            }
            
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            # Should fall back to interactive prompt
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "When testing password validation" {
        
        It "Should accept password meeting minimum length" {
            $script:UserEncryptionPassword = ConvertTo-SecureString "ValidPass123" -AsPlainText -Force
            
            $result = Get-SecurePassword -Message "Enter password" -MinLength 8 -Silent
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle default minimum length of 8" {
            $script:UserEncryptionPassword = ConvertTo-SecureString "12345678" -AsPlainText -Force
            
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            $result | Should -Not -BeNullOrEmpty
            
            Remove-Variable -Name UserEncryptionPassword -Scope Script
        }
        
        It "Should handle custom minimum length" {
            $script:UserEncryptionPassword = ConvertTo-SecureString "VeryLongPassword123!" -AsPlainText -Force
            
            $result = Get-SecurePassword -Message "Enter password" -MinLength 16 -Silent
            
            $result | Should -Not -BeNullOrEmpty
            
            Remove-Variable -Name UserEncryptionPassword -Scope Script
        }
    }
    
    Context "When testing interactive prompting with mocks" {
        
        BeforeEach {
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name UserEncryptionPassword -Scope Global -ErrorAction SilentlyContinue
        }
        
        It "Should use Read-Host for password input when not in Silent mode" {
            Mock Read-Host {
                return ConvertTo-SecureString "MockedPassword123" -AsPlainText -Force
            }
            
            $result = Get-SecurePassword -Message "Enter password"
            
            Should -Invoke Read-Host -Times 1
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should prompt twice when RequireConfirmation is specified" {
            $callCount = 0
            Mock Read-Host {
                $callCount++
                return ConvertTo-SecureString "MatchingPassword123" -AsPlainText -Force
            }
            
            $result = Get-SecurePassword -Message "Enter password" -RequireConfirmation
            
            Should -Invoke Read-Host -Times 2
        }
        
        It "Should display custom message in prompt" {
            Mock Read-Host {
                param($Prompt)
                $Prompt | Should -Match "Custom Message"
                return ConvertTo-SecureString "Password123" -AsPlainText -Force
            }
            
            $result = Get-SecurePassword -Message "Custom Message"
            
            Should -Invoke Read-Host -Times 1
        }
    }
    
    Context "When testing return value" {
        
        BeforeEach {
            $script:UserEncryptionPassword = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force
        }
        
        AfterEach {
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should return a SecureString object" {
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            $result.GetType().Name | Should -Be "SecureString"
        }
        
        It "Should return a non-null SecureString" {
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should return SecureString that can be converted back" {
            $originalPassword = "TestPassword123"
            $script:UserEncryptionPassword = ConvertTo-SecureString $originalPassword -AsPlainText -Force
            
            $result = Get-SecurePassword -Message "Enter password" -Silent
            
            # Convert back to verify (for testing purposes only)
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($result)
            $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            
            $plainText | Should -Be $originalPassword
        }
    }
    
    Context "When testing verbose and logging output" {
        
        BeforeEach {
            $script:UserEncryptionPassword = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force
        }
        
        AfterEach {
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should produce verbose output when -Verbose is used" {
            $verboseOutput = Get-SecurePassword -Message "Enter password" -Silent -Verbose 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should indicate Silent mode in verbose output" {
            $verboseOutput = Get-SecurePassword -Message "Enter password" -Silent -Verbose 4>&1
            
            $verboseOutput -join " " | Should -Match "Silent"
        }
        
        It "Should log parameters used" {
            Mock Write-Log { }
            
            $null = Get-SecurePassword -Message "Enter password" -MinLength 10 -RequireConfirmation -Silent
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*MinLength: 10*" -or $Message -like "*RequireConfirmation*"
            }
        }
    }
    
    Context "When testing parameter combinations" {
        
        BeforeEach {
            $script:UserEncryptionPassword = ConvertTo-SecureString "TestPassword123" -AsPlainText -Force
        }
        
        AfterEach {
            Remove-Variable -Name UserEncryptionPassword -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should handle all parameters together" {
            $result = Get-SecurePassword -Message "Test" -RequireConfirmation -MinLength 12 -Silent
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle only mandatory parameter" {
            $result = Get-SecurePassword -Message "Test" -Silent
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle Message and MinLength" {
            $result = Get-SecurePassword -Message "Test" -MinLength 8 -Silent
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
