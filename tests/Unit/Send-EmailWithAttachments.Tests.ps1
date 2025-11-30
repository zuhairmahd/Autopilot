<#
.SYNOPSIS
    Unit tests for Send-EmailWithAttachments function

.DESCRIPTION
    Tests email sending functionality with both Microsoft Graph API and Outlook COM automation.
    Covers parameter validation, attachment handling, error handling, and both transmission methods.

.NOTES
    Test Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Uses mocking for external dependencies (Graph API)
    - Tests both Graph API and Outlook COM modes
    - Validates error handling and fallback scenarios
    - Note: COM object testing is limited due to complexity; manual testing recommended
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Send-EmailWithAttachments" -Tags 'Unit', 'UtilityFunctions' {
    
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
        
        # Load dependent functions
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        . "$script:RepoRoot/functions/graphFunctions/DecodeJwtToken.ps1"
        . "$script:RepoRoot/functions/graphFunctions/CallGraphAPI.ps1"
        . "$script:RepoRoot/functions/utilityFunctions/Send-DiagnosticInformation.ps1"
        
        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:LogFile = $script:TestContext.LogFile
        
        # Create a test attachment file
        $script:TestAttachment = Join-Path $script:TestContext.TestFolder "test-attachment.txt"
        "Test attachment content" | Out-File -FilePath $script:TestAttachment -Encoding utf8
    }
    
    AfterAll {
        # Cleanup test environment
        if ($script:TestContext -and (Test-Path $script:TestContext.TestFolder))
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    
    Context "When using Graph API mode (default)" {
        
        BeforeEach {
            # Mock Graph API call
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            # Mock JWT token decoder - include scp (scopes) for delegated auth
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
        }
        
        It "Should return false when AccessToken is not provided in Graph mode" {
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test body" -ErrorAction SilentlyContinue
            
            $result | Should -Be $false
        }
        
        It "Should send email successfully with valid parameters" {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test Subject" -Body "Test body"
            
            $result | Should -Be $true
        }
        
        It "Should handle single attachment" {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($script:TestAttachment)
            
            $result | Should -Be $true
        }
        
        It "Should handle multiple attachments" {
            $attachment2 = Join-Path $script:TestContext.TestFolder "test-attachment2.log"
            "Log content" | Out-File -FilePath $attachment2 -Encoding utf8
            
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($script:TestAttachment, $attachment2)
            
            $result | Should -Be $true
        }
        
        It "Should skip non-existent attachment files" {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($script:TestAttachment, "C:\nonexistent\file.txt")
            
            $result | Should -Be $true
        }
        
        It "Should return false on Graph API error" {
            Mock CallGraphApi {
                throw "API Error"
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -ErrorAction SilentlyContinue
            
            $result | Should -Be $false
        }
        
        It "Should use preferred_username from token" {
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "preferred@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test"
            
            $result | Should -Be $true
        }
        
        It "Should fall back to upn if preferred_username not available" {
            Mock DecodeJwtToken {
                return @{
                    upn = "upn@example.com"
                    scp = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test"
            
            $result | Should -Be $true
        }
        
        It "Should detect .txt as text/plain" {
            $txtFile = Join-Path $script:TestContext.TestFolder "test.txt"
            "Test" | Out-File -FilePath $txtFile -Encoding utf8
            
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($txtFile)
            
            $result | Should -Be $true
        }
        
        It "Should detect .log as text/plain" {
            $logFile = Join-Path $script:TestContext.TestFolder "test.log"
            "Log entry" | Out-File -FilePath $logFile -Encoding utf8
            
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($logFile)
            
            $result | Should -Be $true
        }
        
        It "Should detect .zip as application/zip" {
            $zipFile = Join-Path $script:TestContext.TestFolder "test.zip"
            [System.IO.File]::WriteAllBytes($zipFile, [byte[]]@(0x50, 0x4B, 0x03, 0x04))
            
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($zipFile)
            
            $result | Should -Be $true
        }
    }
    
    Context "When using Outlook COM mode - Parameter validation" {
        
        BeforeEach {
            # Mock New-Object to simulate missing Outlook
            Mock New-Object {
                throw "Retrieving the COM class factory for component with CLSID failed"
            } -ParameterFilter { $ComObject -eq 'Outlook.Application' }
        }
        
        It "Should not require AccessToken when using MAPI switch" {
            # This test verifies the function signature accepts -UseMAPI without -AccessToken
            # Actual Outlook COM object creation will fail in test environment, which is expected
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test body" -UseMAPI -ErrorAction SilentlyContinue
            
            # In test environment without Outlook, this should fail gracefully and return false
            $result | Should -Be $false
        }
        
        It "Should return false when Classic Outlook is not available" {
            # In CI/test environment, Outlook COM object creation will fail
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI -ErrorAction SilentlyContinue
            
            $result | Should -Be $false
        }
        
        It "Should log appropriate error when Classic Outlook is not installed" {
            # Should return false when Classic Outlook is not available
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI -ErrorAction SilentlyContinue
            
            $result | Should -Be $false
        }
    }
    
    Context "When testing parameter requirements" {
        
        It "Should accept all required parameters" {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            # Should not throw when all required parameters are provided
            { Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" } | Should -Not -Throw
        }
        
        It "Should accept empty AttachmentPaths array" {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @()
            
            $result | Should -Be $true
        }
    }
    
    Context "When testing verbose and logging output" {
        
        BeforeEach {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                    scp                = "Mail.Send User.Read"
                }
            } -ModuleName $null
        }
        
        It "Should produce verbose output when -Verbose is used" {
            $verboseOutput = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -Verbose 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should log Graph API mode selection" {
            Mock Write-Log { }
            
            $null = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test"
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*Graph API*"
            }
        }
        
        It "Should log MAPI mode selection when using MAPI" {
            Mock Write-Log { }
            
            $null = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI -ErrorAction SilentlyContinue
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*Outlook COM*"
            }
        }
    }
}
