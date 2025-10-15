<#
.SYNOPSIS
    Unit tests for GetLatestGithubRelease function
.DESCRIPTION
    Tests GitHub API interaction, release parsing, and error handling
    Compatible with PowerShell 5.1 and Pester 5.x
.NOTES
    Part of Week 2 Phase 1 coverage improvement initiative
    Tests use mocked Invoke-RestMethod to avoid actual GitHub API calls
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: GetLatestGithubRelease" -Tags 'Unit', 'UpdateFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        . "$script:RepoRoot/functions/updateFunctions/GetLatestGithubRelease.ps1"
    }
    
    Context "When retrieving latest release successfully" {
        It "Should return tag_name from GitHub API response" {
            Mock Invoke-RestMethod {
                return @{
                    tag_name = "v1.2.3"
                    name     = "Release 1.2.3"
                }
            }
            
            $result = GetLatestGithubRelease -Repository "owner/repo"
            
            $result | Should -Be "v1.2.3"
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
        
        It "Should construct correct GitHub API URL" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Be "https://api.github.com/repos/test/project/releases/latest"
                return @{ tag_name = "v2.0.0" }
            }
            
            $result = GetLatestGithubRelease -Repository "test/project"
            $result | Should -Be "v2.0.0"
        }
        
        It "Should handle version tags without 'v' prefix" {
            Mock Invoke-RestMethod {
                return @{ tag_name = "1.0.0" }
            }
            
            $result = GetLatestGithubRelease -Repository "owner/repo"
            $result | Should -Be "1.0.0"
        }
        
        It "Should handle pre-release version tags" {
            Mock Invoke-RestMethod {
                return @{ tag_name = "v2.0.0-beta.1" }
            }
            
            $result = GetLatestGithubRelease -Repository "owner/repo"
            $result | Should -Be "v2.0.0-beta.1"
        }
    }
    
    Context "When GitHub API returns null response" {
        It "Should return null and display error message" {
            Mock Invoke-RestMethod { return $null }
            Mock Write-Host {}
            
            $result = GetLatestGithubRelease -Repository "owner/repo"
            
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Host -Times 1
        }
    }
    
    Context "When GitHub API returns response without tag_name" {
        It "Should return null when tag_name is missing" {
            Mock Invoke-RestMethod {
                return @{
                    name = "Some Release"
                    id   = 12345
                }
            }
            Mock Write-Host {}
            
            $result = GetLatestGithubRelease -Repository "owner/repo"
            
            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Host -Times 1
        }
        
        It "Should return null when tag_name is null" {
            Mock Invoke-RestMethod {
                return @{
                    tag_name = $null
                    name     = "Release"
                }
            }
            Mock Write-Host {}
            
            $result = GetLatestGithubRelease -Repository "owner/repo"
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "When GitHub API call fails" {
        It "Should throw exception for network errors" {
            Mock Invoke-RestMethod {
                throw "Connection timeout"
            }
            
            { GetLatestGithubRelease -Repository "owner/repo" } | Should -Throw
        }
        
        It "Should throw exception for 404 Not Found" {
            Mock Invoke-RestMethod {
                throw "Response status code does not indicate success: 404 (Not Found)"
            }
            
            { GetLatestGithubRelease -Repository "owner/repo" } | Should -Throw
        }
        
        It "Should throw exception for 403 API rate limit" {
            Mock Invoke-RestMethod {
                throw "API rate limit exceeded"
            }
            
            { GetLatestGithubRelease -Repository "owner/repo" } | Should -Throw
        }
        
        It "Should throw exception for invalid repository format" {
            Mock Invoke-RestMethod {
                throw "Invalid repository format"
            }
            
            { GetLatestGithubRelease -Repository "invalid-format" } | Should -Throw
        }
    }
    
    Context "When testing with different repository formats" {
        It "Should handle repository with numbers" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Be "https://api.github.com/repos/user123/project456/releases/latest"
                return @{ tag_name = "v1.0.0" }
            }
            
            $result = GetLatestGithubRelease -Repository "user123/project456"
            $result | Should -Be "v1.0.0"
        }
        
        It "Should handle repository with hyphens and underscores" {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Be "https://api.github.com/repos/my-org/my_project/releases/latest"
                return @{ tag_name = "v2.3.4" }
            }
            
            $result = GetLatestGithubRelease -Repository "my-org/my_project"
            $result | Should -Be "v2.3.4"
        }
    }
    
    Context "When testing verbose output" {
        It "Should write verbose messages when -Verbose is used" {
            Mock Invoke-RestMethod {
                return @{ tag_name = "v1.0.0" }
            }
            Mock Write-Verbose {}
            
            $result = GetLatestGithubRelease -Repository "owner/repo" -Verbose
            
            # Verify verbose messages were called
            Should -Invoke Write-Verbose -Times 3 -Exactly
        }
    }
    
    Context "When testing parameter validation" {
        It "Should accept empty repository parameter" {
            Mock Invoke-RestMethod {
                return @{ tag_name = "v1.0.0" }
            }
            
            # Should not throw - parameter is not mandatory
            { GetLatestGithubRelease -Repository "" } | Should -Not -Throw
        }
    }
}
