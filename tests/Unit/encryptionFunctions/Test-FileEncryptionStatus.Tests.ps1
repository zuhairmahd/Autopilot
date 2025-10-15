<#
.SYNOPSIS
    Unit tests for Test-FileEncryptionStatus function

.DESCRIPTION
    Tests the detection of encrypted vs unencrypted JSON files.
    Covers file existence checks, Base64 detection, JSON validation, and error handling.

.NOTES
    Test Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Creates temporary test files with various content types
    - Tests Base64 detection for encrypted files
    - Tests JSON parsing for unencrypted files
    - Validates error handling for missing and malformed files
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Test-FileEncryptionStatus" -Tags 'Unit', 'EncryptionFunctions' {
    
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load dependent functions
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/encryptionFunctions/Test-FileEncryptionStatus.ps1"
        
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
    
    Context "When testing encrypted files" {
        
        BeforeEach {
            # Create a file with Base64 content (simulating encrypted file)
            $script:EncryptedFile = Join-Path $script:TestContext.TestFolder "encrypted.json"
            $base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("This is encrypted data"))
            Set-Content -Path $script:EncryptedFile -Value $base64Content -Encoding UTF8
        }
        
        AfterEach {
            if (Test-Path $script:EncryptedFile) {
                Remove-Item -Path $script:EncryptedFile -Force
            }
        }
        
        It "Should detect a Base64 encoded file as encrypted" {
            $result = Test-FileEncryptionStatus -FilePath $script:EncryptedFile
            
            $result.IsEncrypted | Should -Be $true
            $result.IsValidFile | Should -Be $true
            $result.ErrorMessage | Should -BeNullOrEmpty
        }
        
        It "Should return file content in result" {
            $result = Test-FileEncryptionStatus -FilePath $script:EncryptedFile
            
            $result.FileContent | Should -Not -BeNullOrEmpty
            $result.FileContent | Should -Match "^[A-Za-z0-9+/=]+$"
        }
        
        It "Should handle multiline Base64 content" {
            $base64Content = @"
VGhpcyBpcyBhIG11bHRpbGluZQ==
ZW5jcnlwdGVkIGRhdGEgZmlsZQ==
d2l0aCBtdWx0aXBsZSBsaW5lcw==
"@
            Set-Content -Path $script:EncryptedFile -Value $base64Content -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $script:EncryptedFile
            
            $result.IsEncrypted | Should -Be $true
        }
    }
    
    Context "When testing unencrypted JSON files" {
        
        BeforeEach {
            $script:JsonFile = Join-Path $script:TestContext.TestFolder "unencrypted.json"
        }
        
        AfterEach {
            if (Test-Path $script:JsonFile) {
                Remove-Item -Path $script:JsonFile -Force
            }
        }
        
        It "Should detect a valid JSON file as unencrypted" {
            $jsonContent = @{
                auth = @{
                    AppId = "test-app-id"
                    TenantId = "test-tenant-id"
                }
            } | ConvertTo-Json
            
            Set-Content -Path $script:JsonFile -Value $jsonContent -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $script:JsonFile
            
            $result.IsEncrypted | Should -Be $false
            $result.IsValidFile | Should -Be $true
        }
        
        It "Should detect complex nested JSON as unencrypted" {
            $jsonContent = @{
                level1 = @{
                    level2 = @{
                        level3 = @{
                            value = "deep-nested-value"
                            array = @(1, 2, 3)
                        }
                    }
                }
            } | ConvertTo-Json -Depth 10
            
            Set-Content -Path $script:JsonFile -Value $jsonContent -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $script:JsonFile
            
            $result.IsEncrypted | Should -Be $false
        }
        
        It "Should handle JSON with special characters" {
            $jsonContent = @{
                text = "Special chars: @#`$%^&*()_+-=[]{}|;:',.<>?/~``"
                unicode = "Unicode text with accents"
            } | ConvertTo-Json
            
            Set-Content -Path $script:JsonFile -Value $jsonContent -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $script:JsonFile
            
            $result.IsEncrypted | Should -Be $false
        }
    }
    
    Context "When testing file validation" {
        
        It "Should handle missing file gracefully" {
            $missingFile = Join-Path $script:TestContext.TestFolder "nonexistent.json"
            
            $result = Test-FileEncryptionStatus -FilePath $missingFile
            
            $result.IsEncrypted | Should -Be $false
            $result.IsValidFile | Should -Be $false
            $result.ErrorMessage | Should -Match "File does not exist"
        }
        
        It "Should handle empty file" {
            $emptyFile = Join-Path $script:TestContext.TestFolder "empty.json"
            New-Item -Path $emptyFile -ItemType File -Force | Out-Null
            
            $result = Test-FileEncryptionStatus -FilePath $emptyFile
            
            $result.IsValidFile | Should -Be $true
            Remove-Item -Path $emptyFile -Force
        }
        
        It "Should handle file with only whitespace" {
            $whitespaceFile = Join-Path $script:TestContext.TestFolder "whitespace.json"
            Set-Content -Path $whitespaceFile -Value "   `n  `t  " -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $whitespaceFile
            
            $result.IsValidFile | Should -Be $true
            Remove-Item -Path $whitespaceFile -Force
        }
        
        It "Should handle file with invalid JSON but not Base64" {
            $invalidFile = Join-Path $script:TestContext.TestFolder "invalid.json"
            Set-Content -Path $invalidFile -Value "This is not JSON and not Base64!" -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $invalidFile
            
            $result.IsValidFile | Should -Be $true
            $result.IsEncrypted | Should -Be $false
            Remove-Item -Path $invalidFile -Force
        }
    }
    
    Context "When testing edge cases" {
        
        It "Should handle file with mixed Base64 and non-Base64 characters" {
            $mixedFile = Join-Path $script:TestContext.TestFolder "mixed.json"
            Set-Content -Path $mixedFile -Value "VGhpcyBpcyBhIG11bHRpbGluZQ== Not Base64!" -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $mixedFile
            
            $result.IsEncrypted | Should -Be $false
            Remove-Item -Path $mixedFile -Force
        }
        
        It "Should handle very large files efficiently" {
            $largeFile = Join-Path $script:TestContext.TestFolder "large.json"
            $largeJson = @{
                data = 1..1000 | ForEach-Object {
                    @{
                        id = $_
                        name = "Item$_"
                        description = "Description for item $_"
                    }
                }
            } | ConvertTo-Json -Depth 5
            
            Set-Content -Path $largeFile -Value $largeJson -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $largeFile
            
            $result.IsValidFile | Should -Be $true
            $result.IsEncrypted | Should -Be $false
            Remove-Item -Path $largeFile -Force
        }
        
        It "Should handle file paths with special characters" {
            $specialFolder = Join-Path $script:TestContext.TestFolder "folder with spaces"
            New-Item -Path $specialFolder -ItemType Directory -Force | Out-Null
            
            $specialFile = Join-Path $specialFolder "file-with-dashes.json"
            Set-Content -Path $specialFile -Value '{"test": "value"}' -Encoding UTF8
            
            $result = Test-FileEncryptionStatus -FilePath $specialFile
            
            $result.IsValidFile | Should -Be $true
            Remove-Item -Path $specialFolder -Recurse -Force
        }
    }
    
    Context "When testing result object structure" {
        
        BeforeEach {
            $script:TestFile = Join-Path $script:TestContext.TestFolder "test.json"
            Set-Content -Path $script:TestFile -Value '{"test": "value"}' -Encoding UTF8
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item -Path $script:TestFile -Force
            }
        }
        
        It "Should return hashtable with all required properties" {
            $result = Test-FileEncryptionStatus -FilePath $script:TestFile
            
            $result.Keys | Should -Contain "IsEncrypted"
            $result.Keys | Should -Contain "IsValidFile"
            $result.Keys | Should -Contain "FileContent"
            $result.Keys | Should -Contain "ErrorMessage"
        }
        
        It "Should return boolean for IsEncrypted property" {
            $result = Test-FileEncryptionStatus -FilePath $script:TestFile
            
            $result.IsEncrypted | Should -BeOfType [bool]
        }
        
        It "Should return boolean for IsValidFile property" {
            $result = Test-FileEncryptionStatus -FilePath $script:TestFile
            
            $result.IsValidFile | Should -BeOfType [bool]
        }
    }
    
    Context "When testing verbose and logging output" {
        
        BeforeEach {
            $script:TestFile = Join-Path $script:TestContext.TestFolder "test.json"
            Set-Content -Path $script:TestFile -Value '{"test": "value"}' -Encoding UTF8
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item -Path $script:TestFile -Force
            }
        }
        
        It "Should produce verbose output when -Verbose is used" {
            $verboseOutput = Test-FileEncryptionStatus -FilePath $script:TestFile -Verbose 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should log file path being checked" {
            Mock Write-Log { }
            
            $null = Test-FileEncryptionStatus -FilePath $script:TestFile
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*TestFile*"
            }
        }
    }
}
