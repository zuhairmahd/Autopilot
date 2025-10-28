<#
.SYNOPSIS
    Unit tests for Get-FileVersion function
.DESCRIPTION
    Tests file version extraction, error handling, and version parsing
    Compatible with PowerShell 5.1 and Pester 5.x
.NOTES
    Part of Week 2 Phase 1 coverage improvement initiative
    Tests use temporary test files and mocked logging functions
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Get-FileVersion" -Tags 'Unit', 'UpdateFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load Write-Log dependency
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Load function under test
        . "$script:RepoRoot/functions/updateFunctions/Get-FileVersion.ps1"
        
        # Mock Write-Log for all tests
        Mock Write-Log {}
        
        # Initialize required script variables
        $script:LogFile = "TestDrive:\test.log"
        $script:maxJSONDepth = 10
    }
    
    Context "When file does not exist" {
        It "Should return null for non-existent file" {
            $result = Get-FileVersion -executableFileName "C:\NonExistent\file.exe"
            
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Log -Times 2 -Exactly
        }
        
        It "Should log error message for missing file" {
            Mock Write-Log {} -ParameterFilter { $LogLevel -eq "Error" }
            
            $result = Get-FileVersion -executableFileName "C:\Missing\app.exe"
            
            Should -Invoke Write-Log -ParameterFilter { $LogLevel -eq "Error" } -Times 1
        }
    }
    
    Context "When executable file name is invalid" {
        It "Should return null for empty string" {
            $result = Get-FileVersion -executableFileName ""
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return null for null parameter" {
            $result = Get-FileVersion -executableFileName $null
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should return null for PowerShell script file (.ps1)" {
            $result = Get-FileVersion -executableFileName "script.ps1"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should log error for .ps1 file" {
            Mock Write-Log {} -ParameterFilter { $LogLevel -eq "Error" }
            
            $result = Get-FileVersion -executableFileName "test.ps1"
            
            Should -Invoke Write-Log -ParameterFilter { $LogLevel -eq "Error" } -Times 1
        }
    }
    
    Context "When testing with real executable files" {
        BeforeAll {
            # Use PowerShell executable as test file (always available)
            $script:TestExe = (Get-Command powershell.exe).Source
        }
        
        It "Should extract version info from PowerShell executable" {
            $result = Get-FileVersion -executableFileName $script:TestExe
            
            $result | Should -Not -BeNullOrEmpty
            $result.version | Should -Not -BeNullOrEmpty
        }
        
        It "Should return hashtable with expected properties" {
            $result = Get-FileVersion -executableFileName $script:TestExe
            
            $result.major | Should -Not -BeNullOrEmpty
            $result.minor | Should -Not -BeNullOrEmpty
            $result.build | Should -Not -BeNullOrEmpty
            $result.revision | Should -Not -BeNullOrEmpty
            $result.version | Should -BeOfType [System.Version]
            $result.companyName | Should -Not -BeNullOrEmpty
            $result.hash | Should -Not -BeNullOrEmpty
        }
        
        It "Should extract company name" {
            $result = Get-FileVersion -executableFileName $script:TestExe
            
            $result.companyName | Should -Not -BeNullOrEmpty
            $result.companyName | Should -Be "Microsoft Corporation"
        }
        
        It "Should calculate SHA256 hash" {
            $result = Get-FileVersion -executableFileName $script:TestExe
            
            $result.hash | Should -Not -BeNullOrEmpty
            $result.hash.Length | Should -Be 64  # SHA256 is 64 hex characters
        }
        
        It "Should parse version to System.Version object" {
            $result = Get-FileVersion -executableFileName $script:TestExe
            
            $result.version | Should -BeOfType [System.Version]
            $result.version.Major | Should -Be $result.major
            $result.version.Minor | Should -Be $result.minor
        }
    }
    
    Context "When testing version parsing" {
        It "Should handle standard 4-part version" {
            Mock Test-Path { $true }
            Mock Get-Item {
                return [PSCustomObject]@{
                    VersionInfo = @{
                        ProductVersion = "1.2.3.4"
                        CompanyName    = "Test Company"
                    }
                }
            }
            Mock Get-FileHash {
                return @{ Hash = "ABC123" * 10 + "ABCD" }  # 64 chars
            }
            
            $result = Get-FileVersion -executableFileName "test.exe"
            
            $result.major | Should -Be 1
            $result.minor | Should -Be 2
            $result.build | Should -Be 3
            $result.revision | Should -Be 4
        }
        
        It "Should handle 3-part version" {
            Mock Test-Path { $true }
            Mock Get-Item {
                return [PSCustomObject]@{
                    VersionInfo = @{
                        ProductVersion = "5.6.7"
                        CompanyName    = "Test Co"
                    }
                }
            }
            Mock Get-FileHash {
                return @{ Hash = "DEF456" * 10 + "DEFG" }
            }
            
            $result = Get-FileVersion -executableFileName "app.exe"
            
            $result.major | Should -Be 5
            $result.minor | Should -Be 6
            $result.build | Should -Be 7
        }
    }
    
    Context "When testing logging behavior" {
        It "Should log verbose messages during execution" {
            Mock Test-Path { $true }
            Mock Get-Item {
                return [PSCustomObject]@{
                    VersionInfo = @{
                        ProductVersion = "1.0.0.0"
                        CompanyName    = "Test"
                    }
                }
            }
            Mock Get-FileHash {
                return @{ Hash = "A" * 64 }
            }
            Mock Write-Log {} -ParameterFilter { $LogLevel -eq "Verbose" }
            
            $result = Get-FileVersion -executableFileName "test.exe"
            
            # Should log multiple verbose messages throughout execution
            Should -Invoke Write-Log -ParameterFilter { $LogLevel -eq "Verbose" } -Times 9 -Exactly
        }
        
        It "Should log final information message with version" {
            Mock Test-Path { $true }
            Mock Get-Item {
                return [PSCustomObject]@{
                    VersionInfo = @{
                        ProductVersion = "2.0.0.0"
                        CompanyName    = "Test"
                    }
                }
            }
            Mock Get-FileHash {
                return @{ Hash = "B" * 64 }
            }
            Mock Write-Log {} -ParameterFilter { $LogLevel -eq "Information" }
            
            $result = Get-FileVersion -executableFileName "app.exe"
            
            Should -Invoke Write-Log -ParameterFilter { $LogLevel -eq "Information" } -Times 1
        }
    }
    
    Context "When testing file path validation" {
        It "Should handle absolute Windows path" {
            Mock Test-Path { $false }
            
            $result = Get-FileVersion -executableFileName "C:\Program Files\App\program.exe"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle relative path" {
            Mock Test-Path { $false }
            
            $result = Get-FileVersion -executableFileName ".\bin\app.exe"
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle UNC path" {
            Mock Test-Path { $false }
            
            $result = Get-FileVersion -executableFileName "\\server\share\program.exe"
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    AfterAll {
        # Clean up TestDrive to prevent GUID folder remnants
        if (Test-Path "TestDrive:\")
        {
            Get-ChildItem "TestDrive:\" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
