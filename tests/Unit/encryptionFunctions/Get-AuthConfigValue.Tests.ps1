<#
.SYNOPSIS
    Unit tests for Get-AuthConfigValue function

.DESCRIPTION
    Tests the retrieval of authentication configuration values from script-level $Auth variable.
    Covers property path navigation, error handling, and edge cases.

.NOTES
    Test Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Tests property path navigation through nested objects
    - Validates error handling for missing configuration
    - Tests various data types and structures
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-AuthConfigValue" -Tags 'Unit', 'EncryptionFunctions' {
    
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependent function
        . "$script:RepoRoot/functions/encryptionFunctions/Get-AuthConfigValue.ps1"
    }
    
    AfterAll {
        # Clear script-level Auth variable
        Remove-Variable -Name Auth -Scope Script -ErrorAction SilentlyContinue
    }
    
    Context "When auth configuration is available" {
        
        BeforeEach {
            # Set up script-level Auth configuration
            $script:Auth = @{
                AppId       = "test-app-id-12345"
                TenantId    = "test-tenant-id-67890"
                authType    = "ClientSecret"
                scope       = "https://graph.microsoft.com/.default"
                redirectUri = "http://localhost:8080"
                settings    = @{
                    timeout       = 30
                    maxRetries    = 3
                    enableLogging = $true
                }
                nested      = @{
                    level1 = @{
                        level2 = "deep-value"
                    }
                }
            }
        }
        
        AfterEach {
            Remove-Variable -Name Auth -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should retrieve a simple string property" {
            $result = Get-AuthConfigValue -PropertyPath "AppId"
            
            $result | Should -Be "test-app-id-12345"
        }
        
        It "Should retrieve another simple property" {
            $result = Get-AuthConfigValue -PropertyPath "authType"
            
            $result | Should -Be "ClientSecret"
        }
        
        It "Should retrieve nested property value" {
            $result = Get-AuthConfigValue -PropertyPath "settings.timeout"
            
            $result | Should -Be 30
        }
        
        It "Should retrieve deeply nested property value" {
            $result = Get-AuthConfigValue -PropertyPath "nested.level1.level2"
            
            $result | Should -Be "deep-value"
        }
        
        It "Should retrieve boolean property value" {
            $result = Get-AuthConfigValue -PropertyPath "settings.enableLogging"
            
            $result | Should -Be $true
        }
        
        It "Should retrieve numeric property value" {
            $result = Get-AuthConfigValue -PropertyPath "settings.maxRetries"
            
            $result | Should -Be 3
            $result | Should -BeOfType [int]
        }
        
        It "Should retrieve URI property value" {
            $result = Get-AuthConfigValue -PropertyPath "redirectUri"
            
            $result | Should -Be "http://localhost:8080"
        }
        
        It "Should retrieve scope value" {
            $result = Get-AuthConfigValue -PropertyPath "scope"
            
            $result | Should -Be "https://graph.microsoft.com/.default"
        }
        
        It "Should return null for non-existent property" {
            $result = Get-AuthConfigValue -PropertyPath "NonExistentProperty"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return null for invalid nested path" {
            $result = Get-AuthConfigValue -PropertyPath "settings.invalid.path"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle property path with multiple levels" {
            $result = Get-AuthConfigValue -PropertyPath "settings.enableLogging"
            
            $result | Should -Be $true
        }
    }
    
    Context "When auth configuration is not available" {
        
        BeforeEach {
            # Clear script-level Auth variable
            Remove-Variable -Name Auth -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should return null when Auth is not set" {
            $result = Get-AuthConfigValue -PropertyPath "AppId" -ErrorAction SilentlyContinue
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should write an error when Auth is unavailable" {
            $errorCount = $Error.Count
            $null = Get-AuthConfigValue -PropertyPath "AppId" -ErrorAction SilentlyContinue
            
            $Error.Count | Should -BeGreaterThan $errorCount
        }
        
        It "Should handle missing Auth gracefully" {
            $result = Get-AuthConfigValue -PropertyPath "TenantId" -ErrorAction SilentlyContinue
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "When testing edge cases" {
        
        BeforeEach {
            $script:Auth = @{
                simpleValue    = "test"
                emptyString    = ""
                nullValue      = $null
                zeroValue      = 0
                falseValue     = $false
                arrayValue     = @(1, 2, 3)
                hashtableValue = @{ key = "value" }
            }
        }
        
        AfterEach {
            Remove-Variable -Name Auth -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should handle empty string value" {
            $result = Get-AuthConfigValue -PropertyPath "emptyString"
            
            $result | Should -Be ""
        }
        
        It "Should handle null value" {
            $result = Get-AuthConfigValue -PropertyPath "nullValue"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle zero value" {
            $result = Get-AuthConfigValue -PropertyPath "zeroValue"
            
            $result | Should -Be 0
        }
        
        It "Should handle false value" {
            $result = Get-AuthConfigValue -PropertyPath "falseValue"
            
            $result | Should -Be $false
        }
        
        It "Should handle array value" {
            $result = Get-AuthConfigValue -PropertyPath "arrayValue"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
        }
        
        It "Should handle hashtable value" {
            $result = Get-AuthConfigValue -PropertyPath "hashtableValue"
            
            $result | Should -Not -BeNullOrEmpty
            $result.key | Should -Be "value"
        }
        
        It "Should handle nested property in hashtable value" {
            $result = Get-AuthConfigValue -PropertyPath "hashtableValue.key"
            
            $result | Should -Be "value"
        }
    }
    
    Context "When testing different Auth structures" {
        
        It "Should handle Auth with only simple properties" {
            $script:Auth = @{
                prop1 = "value1"
                prop2 = "value2"
                prop3 = "value3"
            }
            
            $result = Get-AuthConfigValue -PropertyPath "prop2"
            
            $result | Should -Be "value2"
            
            Remove-Variable -Name Auth -Scope Script
        }
        
        It "Should handle Auth with deep nesting" {
            $script:Auth = @{
                level1 = @{
                    level2 = @{
                        level3 = @{
                            level4 = @{
                                value = "deep-nested-value"
                            }
                        }
                    }
                }
            }
            
            $result = Get-AuthConfigValue -PropertyPath "level1.level2.level3.level4.value"
            
            $result | Should -Be "deep-nested-value"
            
            Remove-Variable -Name Auth -Scope Script
        }
        
        It "Should handle Auth with mixed data types" {
            $script:Auth = @{
                stringValue = "test"
                intValue    = 42
                boolValue   = $true
                arrayValue  = @("a", "b", "c")
                dateValue   = Get-Date "2025-01-01"
            }
            
            $result = Get-AuthConfigValue -PropertyPath "intValue"
            $result | Should -Be 42
            
            $result = Get-AuthConfigValue -PropertyPath "arrayValue"
            $result.Count | Should -Be 3
            
            Remove-Variable -Name Auth -Scope Script
        }
    }
    
    Context "When testing verbose output" {
        
        BeforeEach {
            $script:Auth = @{
                testProperty = "testValue"
            }
        }
        
        AfterEach {
            Remove-Variable -Name Auth -Scope Script -ErrorAction SilentlyContinue
        }
        
        It "Should produce verbose output when -Verbose is used" {
            $verboseOutput = Get-AuthConfigValue -PropertyPath "testProperty" -Verbose 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should include property path in verbose output" {
            $verboseOutput = Get-AuthConfigValue -PropertyPath "testProperty" -Verbose 4>&1
            
            $verboseOutput -join " " | Should -Match "testProperty"
        }
    }
}
