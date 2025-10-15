<#
.SYNOPSIS
    Unit tests for Get-DecryptedConfigValue function

.DESCRIPTION
    Tests the retrieval of decrypted configuration values from temporary encrypted configuration.
    Covers normal operation, error handling, and edge cases.

.NOTES
    Test Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Mocks Invoke-JsonFileEncryption for controlled decryption simulation
    - Tests property path navigation through nested objects
    - Validates error handling for missing configuration and invalid paths
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-DecryptedConfigValue" -Tags 'Unit', 'EncryptionFunctions' {
    
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependent functions
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/encryptionFunctions/Invoke-JsonFileEncryption.ps1"
        . "$script:RepoRoot/functions/encryptionFunctions/Get-DecryptedConfigValue.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:LogFile = $script:TestContext.LogFile
        
        # Sample decrypted configuration
        $script:MockConfig = @{
            auth     = @{
                AppId    = "test-app-id"
                TenantId = "test-tenant-id"
                authType = "ClientSecret"
            }
            settings = @{
                maxRetries = 3
                timeout    = 30
                debugMode  = $true
            }
            nested   = @{
                level1 = @{
                    level2 = @{
                        value = "deep-value"
                    }
                }
            }
        } | ConvertTo-Json -Depth 10
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and (Test-Path $script:TestContext.TestFolder))
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Clear script variables
        Remove-Variable -Name TempEncryptedConfig -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name TempEncryptionKey -Scope Script -ErrorAction SilentlyContinue
    }
    
    Context "When configuration is available" {
        
        BeforeEach {
            # Set up temporary encrypted config
            $script:TempEncryptedConfig = "mock-encrypted-content"
            $script:TempEncryptionKey = "mock-encryption-key"
            
            # Mock Invoke-JsonFileEncryption to return successful decryption
            Mock Invoke-JsonFileEncryption {
                return @{
                    Success = $true
                    Content = $script:MockConfig
                }
            }
        }
        
        It "Should retrieve a simple property value" {
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId"
            
            $result | Should -Be "test-app-id"
            Should -Invoke Invoke-JsonFileEncryption -Times 1
        }
        
        It "Should retrieve a nested property value" {
            $result = Get-DecryptedConfigValue -PropertyPath "auth.authType"
            
            $result | Should -Be "ClientSecret"
        }
        
        It "Should retrieve a deeply nested property value" {
            $result = Get-DecryptedConfigValue -PropertyPath "nested.level1.level2.value"
            
            $result | Should -Be "deep-value"
        }
        
        It "Should retrieve a numeric property value" {
            $result = Get-DecryptedConfigValue -PropertyPath "settings.maxRetries"
            
            $result | Should -Be 3
        }
        
        It "Should retrieve a boolean property value" {
            $result = Get-DecryptedConfigValue -PropertyPath "settings.debugMode"
            
            $result | Should -Be $true
        }
        
        It "Should return null for non-existent property" {
            $result = Get-DecryptedConfigValue -PropertyPath "auth.NonExistentProperty"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return null for invalid path segment" {
            $result = Get-DecryptedConfigValue -PropertyPath "invalid.path.segment"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle single-level property path" {
            # Add a root-level property to mock config
            $mockConfigWithRoot = $script:MockConfig | ConvertFrom-Json
            $mockConfigWithRoot | Add-Member -NotePropertyName "rootProperty" -NotePropertyValue "root-value"
            
            Mock Invoke-JsonFileEncryption {
                return @{
                    Success = $true
                    Content = ($mockConfigWithRoot | ConvertTo-Json -Depth 10)
                }
            }
            
            $result = Get-DecryptedConfigValue -PropertyPath "rootProperty"
            
            $result | Should -Be "root-value"
        }
    }
    
    Context "When configuration is not available" {
        
        BeforeEach {
            # Clear script variables to simulate missing configuration
            Remove-Variable -Name TempEncryptedConfig -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name TempEncryptionKey -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should return null when TempEncryptedConfig is missing" {
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId" -ErrorAction SilentlyContinue
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should write an error when configuration is unavailable" {
            $errorCount = $Error.Count
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId" -ErrorAction SilentlyContinue
            
            $Error.Count | Should -BeGreaterThan $errorCount
        }
    }
    
    Context "When decryption fails" {
        
        BeforeEach {
            # Set up temporary encrypted config
            $script:TempEncryptedConfig = "mock-encrypted-content"
            $script:TempEncryptionKey = "mock-encryption-key"
            
            # Mock Invoke-JsonFileEncryption to return failed decryption
            Mock Invoke-JsonFileEncryption {
                return @{
                    Success      = $false
                    ErrorMessage = "Decryption failed"
                }
            }
        }
        
        It "Should return null when decryption fails" {
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should invoke decryption with correct parameters" {
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId"
            
            Should -Invoke Invoke-JsonFileEncryption -Times 1 -ParameterFilter {
                $Decrypt -eq $true -and
                $InMemoryOnly -eq $true -and
                $Key -eq "mock-encryption-key"
            }
        }
    }
    
    Context "When handling edge cases" {
        
        BeforeEach {
            $script:TempEncryptedConfig = "mock-encrypted-content"
            $script:TempEncryptionKey = "mock-encryption-key"
        }
        
        It "Should handle empty property path gracefully" {
            Mock Invoke-JsonFileEncryption {
                return @{
                    Success = $true
                    Content = $script:MockConfig
                }
            }
            
            $result = Get-DecryptedConfigValue -PropertyPath ""
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle property path with trailing dot" {
            Mock Invoke-JsonFileEncryption {
                return @{
                    Success = $true
                    Content = $script:MockConfig
                }
            }
            
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId."
            
            # Should handle gracefully even if not ideal input
            $result | Should -BeNullOrEmpty
        }
        
        It "Should clean up temporary file after operation" {
            Mock Invoke-JsonFileEncryption {
                return @{
                    Success = $true
                    Content = $script:MockConfig
                }
            }
            
            Mock Set-Content { }
            Mock Remove-Item { }
            
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId"
            
            # Verify temporary file cleanup is attempted
            Should -Invoke Remove-Item -Times 1
        }
    }
    
    Context "When testing verbose and logging output" {
        
        BeforeEach {
            $script:TempEncryptedConfig = "mock-encrypted-content"
            $script:TempEncryptionKey = "mock-encryption-key"
            
            Mock Invoke-JsonFileEncryption {
                return @{
                    Success = $true
                    Content = $script:MockConfig
                }
            }
        }
        
        It "Should produce verbose output when -Verbose is used" {
            $verboseOutput = Get-DecryptedConfigValue -PropertyPath "auth.AppId" -Verbose 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should log the property path being retrieved" {
            Mock Write-Log { }
            
            $result = Get-DecryptedConfigValue -PropertyPath "auth.AppId"
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*Retrieving config value for path: auth.AppId*"
            }
        }
    }
}
