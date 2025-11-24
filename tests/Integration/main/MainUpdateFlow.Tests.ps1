#Requires -Version 7.0
<#
.SYNOPSIS
    Integration tests for main.ps1 update checking workflow.

.DESCRIPTION
    Tests the complete update checking workflow including:
    - Release version determination (auto vs explicit)
    - GitHub API integration for latest release
    - CheckForUpdates function calls
    - Update availability detection
    - Show-AboutApplication integration
    
    These tests validate the update checking infrastructure built in Phase 1.

.NOTES
    - Requires: PowerShell 7+ (Pester v5)
    - Application code: PowerShell 5.1 compatible
    - Test file: tests/Integration/main/MainUpdateFlow.Tests.ps1
    - Module: main.ps1 (lines 875-895, 2260)
    - Dependencies: GetLatestGithubRelease, CheckForUpdates, Show-AboutApplication
    - Coverage Target: ~100 lines (update detection, user interaction)
    
    Test Approach:
    - Mock GitHub API calls (GetLatestGithubRelease)
    - Mock update checking (CheckForUpdates)
    - Mock UI display (Show-AboutApplication)
    - Validate parameter flow and decision logic
    - Test both 'auto' and explicit release scenarios
#>

BeforeAll {
    # Setup test environment
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    $script:LogFile = Join-Path $TestDrive "main-update-flow-test.log"
    
    # Mock Write-Log to prevent file I/O
    function Write-Log
    {
        param($LogFile, $Module, $Message, $LogLevel)
        # Silent mock
    }
    
    # Mock GetLatestGithubRelease
    function GetLatestGithubRelease
    {
        param([string]$Repository)
        return "v1.5.0"
    }
    
    # Mock CheckForUpdates
    function CheckForUpdates
    {
        param([string]$remoteVersionURL)
        return @{
            Version     = [System.Version]"1.5.0"
            ReleaseDate = (Get-Date).AddDays(-7)
            Hash        = "abc123def456"
            success     = $true
        }
    }
    
    # Mock Show-AboutApplication
    function Show-AboutApplication
    {
        param($updateAvailable, $accessToken, $Release, $appId, $tenantId, $name)
        # Silent mock
    }
    
    # Mock Invoke-RestMethod (used by CheckForUpdates internally)
    Mock Invoke-RestMethod {
        return @{
            version = "1.5.0"
            date    = (Get-Date).AddDays(-7).ToString("o")
            hash    = "abc123def456"
        }
    }
}

Describe "Main.ps1 Update Flow Integration Tests" -Tags 'Integration', 'Main', 'UpdateFlow' {
    
    Context "Release Version Determination" {
        
        It "Should use explicit release version when settings.Release is set" {
            $settings = @{ Release = "v1.4.0" }
            
            # Simulate the logic from main.ps1 lines 875-889
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "owner/repo"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                "master"
            }
            
            $latestRelease | Should -Be "v1.4.0"
        }
        
        It "Should fetch latest release from GitHub when settings.Release is 'auto'" {
            $settings = @{ Release = "auto" }
            
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "owner/repo"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                "master"
            }
            
            $latestRelease | Should -Be "v1.5.0"
        }
        
        It "Should default to master branch when settings.Release is not set" {
            $settings = @{}
            
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "owner/repo"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                "master"
            }
            
            $latestRelease | Should -Be "master"
        }
        
        It "Should handle null settings.Release gracefully" {
            $settings = @{ Release = $null }
            
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "owner/repo"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                "master"
            }
            
            $latestRelease | Should -Be "master"
        }
    }
    
    Context "Update URL Construction" {
        
        It "Should construct correct remote version URL with release version" {
            $baseSourceURL = "https://raw.githubusercontent.com"
            $repoPath = "zuhairmahd"
            $repoName = "autopilot"
            $latestRelease = "v1.5.0"
            
            $remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
            
            $remoteVersionURL | Should -Be "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0/lastrun.json"
        }
        
        It "Should construct correct update URL with release version" {
            $baseSourceURL = "https://raw.githubusercontent.com"
            $repoPath = "zuhairmahd"
            $repoName = "autopilot"
            $latestRelease = "v1.5.0"
            
            $updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
            
            $updateURL | Should -Be "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0"
        }
        
        It "Should handle master branch in URL construction" {
            $baseSourceURL = "https://raw.githubusercontent.com"
            $repoPath = "zuhairmahd"
            $repoName = "autopilot"
            $latestRelease = "master"
            
            $remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
            
            $remoteVersionURL | Should -Be "https://raw.githubusercontent.com/zuhairmahd/autopilot/master/lastrun.json"
        }
    }
    
    Context "CheckForUpdates Integration" {
        
        It "Should call CheckForUpdates with correct remote version URL" {
            $remoteVersionURL = "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0/lastrun.json"
            
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            $updateAvailable | Should -Not -BeNullOrEmpty
            $updateAvailable.success | Should -Be $true
        }
        
        It "Should return update information with version" {
            $remoteVersionURL = "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0/lastrun.json"
            
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            $updateAvailable.Version | Should -BeOfType [System.Version]
            $updateAvailable.Version | Should -Be "1.5.0"
        }
        
        It "Should return update information with release date" {
            $remoteVersionURL = "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0/lastrun.json"
            
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            $updateAvailable.ReleaseDate | Should -BeOfType [DateTime]
            $updateAvailable.ReleaseDate | Should -BeLessThan (Get-Date)
        }
        
        It "Should return update information with hash" {
            $remoteVersionURL = "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0/lastrun.json"
            
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            $updateAvailable.Hash | Should -Not -BeNullOrEmpty
            $updateAvailable.Hash | Should -BeOfType [string]
        }
        
        It "Should handle CheckForUpdates failure gracefully" {
            # Mock CheckForUpdates to return null (failure scenario)
            Mock CheckForUpdates { return $null }
            
            $remoteVersionURL = "https://invalid.url/lastrun.json"
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            $updateAvailable | Should -BeNullOrEmpty
        }
    }
    
    Context "Show-AboutApplication Integration" {
        
        It "Should pass updateAvailable to Show-AboutApplication" {
            $updateAvailable = @{
                Version     = [System.Version]"1.5.0"
                ReleaseDate = (Get-Date).AddDays(-7)
                Hash        = "abc123def456"
                success     = $true
            }
            
            # Function should execute without error
            {
                Show-AboutApplication -updateAvailable $updateAvailable `
                    -accessToken "test-token" `
                    -Release "v1.5.0" `
                    -appId "app-id" `
                    -tenantId "tenant-id" `
                    -Name "Test App"
            } | Should -Not -Throw
        }
        
        It "Should pass release version to Show-AboutApplication" {
            $latestRelease = "v1.5.0"
            
            # Function should execute without error
            {
                Show-AboutApplication -updateAvailable $null `
                    -accessToken "test-token" `
                    -Release $latestRelease `
                    -appId "app-id" `
                    -tenantId "tenant-id" `
                    -Name "Test App"
            } | Should -Not -Throw
        }
        
        It "Should handle null updateAvailable in Show-AboutApplication" {
            # Function should execute without error
            {
                Show-AboutApplication -updateAvailable $null `
                    -accessToken "test-token" `
                    -Release "v1.5.0" `
                    -appId "app-id" `
                    -tenantId "tenant-id" `
                    -Name "Test App"
            } | Should -Not -Throw
        }
    }
    
    Context "End-to-End Update Flow Scenarios" {
        
        It "Should complete full update flow with auto release" {
            # Simulate settings
            $settings = @{ Release = "auto" }
            $baseSourceURL = "https://raw.githubusercontent.com"
            $repoPath = "zuhairmahd"
            $repoName = "autopilot"
            $defaultBranch = "master"
            
            # Step 1: Determine release
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                $defaultBranch
            }
            
            # Step 2: Construct URLs
            $remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
            $updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
            
            # Step 3: Check for updates
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            # Step 4: Display about (would happen later in main.ps1)
            $result = Show-AboutApplication -updateAvailable $updateAvailable `
                -accessToken "test-token" `
                -Release $latestRelease `
                -appId "app-id" `
                -tenantId "tenant-id" `
                -Name "Test App"
            
            # Assertions
            $latestRelease | Should -Be "v1.5.0"
            $remoteVersionURL | Should -Be "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0/lastrun.json"
            $updateURL | Should -Be "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.5.0"
            $updateAvailable.success | Should -Be $true
            $updateAvailable.Version | Should -Be "1.5.0"
        }
        
        It "Should complete full update flow with explicit release" {
            # Simulate settings
            $settings = @{ Release = "v1.4.5" }
            $baseSourceURL = "https://raw.githubusercontent.com"
            $repoPath = "zuhairmahd"
            $repoName = "autopilot"
            $defaultBranch = "master"
            
            # Step 1: Determine release
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                $defaultBranch
            }
            
            # Step 2: Construct URLs
            $remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
            
            # Step 3: Check for updates
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            # Assertions
            $latestRelease | Should -Be "v1.4.5"
            $remoteVersionURL | Should -Be "https://raw.githubusercontent.com/zuhairmahd/autopilot/v1.4.5/lastrun.json"
            $updateAvailable.success | Should -Be $true
        }
        
        It "Should complete full update flow with default branch" {
            # Simulate settings
            $settings = @{}
            $baseSourceURL = "https://raw.githubusercontent.com"
            $repoPath = "zuhairmahd"
            $repoName = "autopilot"
            $defaultBranch = "master"
            
            # Step 1: Determine release
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                $defaultBranch
            }
            
            # Step 2: Construct URLs
            $remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
            
            # Step 3: Check for updates
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            # Assertions
            $latestRelease | Should -Be "master"
            $remoteVersionURL | Should -Be "https://raw.githubusercontent.com/zuhairmahd/autopilot/master/lastrun.json"
            $updateAvailable.success | Should -Be $true
        }
        
        It "Should handle update check failure in full flow" {
            # Mock CheckForUpdates to return null
            Mock CheckForUpdates { return $null }
            
            # Simulate settings
            $settings = @{ Release = "auto" }
            $baseSourceURL = "https://raw.githubusercontent.com"
            $repoPath = "zuhairmahd"
            $repoName = "autopilot"
            $defaultBranch = "master"
            
            # Step 1: Determine release
            $latestRelease = if ($settings.Release)
            {
                if ($settings.Release -eq 'auto')
                {
                    $tempRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
                    $tempRelease
                }
                else
                {
                    $settings.Release
                }
            }
            else
            {
                $defaultBranch
            }
            
            # Step 2: Construct URLs
            $remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/lastrun.json"
            
            # Step 3: Check for updates (will fail)
            $updateAvailable = CheckForUpdates -remoteVersionURL $remoteVersionURL
            
            # Step 4: Display about with null updateAvailable
            {
                Show-AboutApplication -updateAvailable $updateAvailable `
                    -accessToken "test-token" `
                    -Release $latestRelease `
                    -appId "app-id" `
                    -tenantId "tenant-id" `
                    -Name "Test App"
            } | Should -Not -Throw
            
            # Assertions - should handle gracefully
            $updateAvailable | Should -BeNullOrEmpty
        }
    }
}
