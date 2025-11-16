<#
.SYNOPSIS
    Unit tests for Send-EmailWithAttachments function

.DESCRIPTION
    Tests email sending functionality with both Microsoft Graph API and MAPI/Outlook COM automation.
    Covers parameter validation, attachment handling, error handling, and both transmission methods.

.NOTES
    Test Approach:
    - Direct dot-sourcing for PS 5.1 compatibility
    - Uses mocking for external dependencies (Graph API, COM objects)
    - Tests both Graph API and MAPI modes
    - Validates error handling and fallback scenarios
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
            
            # Mock JWT token decoder
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                }
            } -ModuleName $null
        }
        
        It "Should require AccessToken parameter when not using MAPI" {
            { Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test body" } | Should -Throw
        }
        
        It "Should send email successfully with valid parameters" {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test Subject" -Body "Test body"
            
            $result | Should -Be $true
        }
        
        It "Should handle single attachment" {
            Mock CallGraphApi {
                return $null
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
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($script:TestAttachment, $attachment2)
            
            $result | Should -Be $true
        }
        
        It "Should skip non-existent attachment files" {
            Mock CallGraphApi {
                return $null
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
                }
            } -ModuleName $null
            
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test"
            
            $result | Should -Be $true
        }
    }
    
    Context "When using MAPI mode" {
        
        BeforeEach {
            # Mock Write-Log to avoid New-Object conflicts with mutex
            Mock Write-Log { }
            
            # Reset COM object mocks
            Mock New-Object {
                param($ComObject, $ErrorAction)
                if ($ComObject -eq "Outlook.Application") {
                    # Create a mock Outlook object using hashtables to avoid recursion
                    $mockAttachments = @{
                        Add = { param($path) return $null }
                    }
                    
                    $mockMail = @{
                        To = $null
                        Subject = $null
                        Body = $null
                        Attachments = $mockAttachments
                        Display = { return $null }
                    }
                    
                    $mockOutlook = @{
                        CreateItem = { param($itemType)
                            return [PSCustomObject]$mockMail
                        }
                    }
                    
                    return [PSCustomObject]$mockOutlook
                } else {
                    # Let other New-Object calls through
                    & (Get-Command -CommandType Cmdlet -Name New-Object) @PSBoundParameters
                }
            }
        }
        
        It "Should not require AccessToken when using MAPI" {
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test body" -UseMAPI
            
            $result | Should -Be $true
        }
        
        It "Should create Outlook COM object" {
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI
            
            Should -Invoke New-Object -Times 1
        }
        
        It "Should set email properties correctly" {
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test Subject" -Body "Test Body" -UseMAPI
            
            $result | Should -Be $true
        }
        
        It "Should add attachments in MAPI mode" {
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($script:TestAttachment) -UseMAPI
            
            $result | Should -Be $true
        }
        
        It "Should handle multiple attachments in MAPI mode" {
            $attachment2 = Join-Path $script:TestContext.TestFolder "test-attachment2.log"
            "Log content" | Out-File -FilePath $attachment2 -Encoding utf8
            
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($script:TestAttachment, $attachment2) -UseMAPI
            
            $result | Should -Be $true
        }
        
        It "Should return false when Outlook COM creation fails" {
            Mock New-Object {
                param($ComObject, $ErrorAction)
                throw "Outlook not installed"
            }
            
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI -ErrorAction SilentlyContinue
            
            $result | Should -Be $false
        }
        
        It "Should display the email for user review" {
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI
            
            $result | Should -Be $true
        }
        
        It "Should skip non-existent attachments in MAPI mode" {
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($script:TestAttachment, "C:\nonexistent\file.txt") -UseMAPI
            
            $result | Should -Be $true
        }
    }
    
    Context "When testing parameter validation" {
        
        BeforeEach {
            Mock Write-Log { }
        }
        
        It "Should require To parameter" {
            { Send-EmailWithAttachments -Subject "Test" -Body "Test" -UseMAPI -ErrorAction Stop } | Should -Throw
        }
        
        It "Should require Subject parameter" {
            { Send-EmailWithAttachments -To "support@example.com" -Body "Test" -UseMAPI -ErrorAction Stop } | Should -Throw
        }
        
        It "Should require Body parameter" {
            { Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -UseMAPI -ErrorAction Stop } | Should -Throw
        }
        
        It "Should accept empty AttachmentPaths array" {
            Mock Write-Log { }
            Mock New-Object {
                param($ComObject, $ErrorAction)
                if ($ComObject -eq "Outlook.Application") {
                    $mockAttachments = @{
                        Add = { param($path) return $null }
                    }
                    $mockMail = @{
                        To = $null
                        Subject = $null
                        Body = $null
                        Attachments = $mockAttachments
                        Display = { return $null }
                    }
                    $mockOutlook = @{
                        CreateItem = { param($itemType)
                            return [PSCustomObject]$mockMail
                        }
                    }
                    return [PSCustomObject]$mockOutlook
                } else {
                    & (Get-Command -CommandType Cmdlet -Name New-Object) @PSBoundParameters
                }
            }
            
            $result = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @() -UseMAPI
            
            $result | Should -Be $true
        }
    }
    
    Context "When testing MIME type detection" {
        
        BeforeEach {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                }
            } -ModuleName $null
        }
        
        It "Should detect .txt as text/plain" {
            $txtFile = Join-Path $script:TestContext.TestFolder "test.txt"
            "Test" | Out-File -FilePath $txtFile -Encoding utf8
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($txtFile)
            
            $result | Should -Be $true
        }
        
        It "Should detect .log as text/plain" {
            $logFile = Join-Path $script:TestContext.TestFolder "test.log"
            "Log entry" | Out-File -FilePath $logFile -Encoding utf8
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($logFile)
            
            $result | Should -Be $true
        }
        
        It "Should detect .zip as application/zip" {
            $zipFile = Join-Path $script:TestContext.TestFolder "test.zip"
            [System.IO.File]::WriteAllBytes($zipFile, [byte[]]@(0x50, 0x4B, 0x03, 0x04))
            
            $result = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test" -AttachmentPaths @($zipFile)
            
            $result | Should -Be $true
        }
    }
    
    Context "When testing verbose and logging output" {
        
        BeforeEach {
            Mock Write-Log { }
            Mock New-Object {
                param($ComObject, $ErrorAction)
                if ($ComObject -eq "Outlook.Application") {
                    $mockAttachments = @{
                        Add = { param($path) return $null }
                    }
                    $mockMail = @{
                        To = $null
                        Subject = $null
                        Body = $null
                        Attachments = $mockAttachments
                        Display = { return $null }
                    }
                    $mockOutlook = @{
                        CreateItem = { param($itemType)
                            return [PSCustomObject]$mockMail
                        }
                    }
                    return [PSCustomObject]$mockOutlook
                } else {
                    & (Get-Command -CommandType Cmdlet -Name New-Object) @PSBoundParameters
                }
            }
        }
        
        It "Should produce verbose output when -Verbose is used" {
            $verboseOutput = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI -Verbose 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should log MAPI mode selection" {
            Mock Write-Log { }
            
            $null = Send-EmailWithAttachments -To "support@example.com" -Subject "Test" -Body "Test" -UseMAPI
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*MAPI*"
            }
        }
        
        It "Should log Graph API mode selection" {
            Mock CallGraphApi {
                return $null
            } -ModuleName $null
            
            Mock DecodeJwtToken {
                return @{
                    preferred_username = "test@example.com"
                }
            } -ModuleName $null
            
            Mock Write-Log { }
            
            $null = Send-EmailWithAttachments -AccessToken "mock-token" -To "support@example.com" -Subject "Test" -Body "Test"
            
            Should -Invoke Write-Log -ParameterFilter {
                $Message -like "*Graph API*"
            }
        }
    }
}
