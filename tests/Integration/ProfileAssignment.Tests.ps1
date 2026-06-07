<#
.SYNOPSIS
    Integration tests for Autopilot profile assignments.

.DESCRIPTION
    Tests the application's ability to correctly identify Autopilot profiles
    assigned to groups by testing the Get-GroupDirectAssignments function against
    a mock Graph API backend.
    Addresses Phase 3 of the Pester Migration Plan.

.NOTES
    Test Category: Integration
    Template Compliance: Full
    Uses: AutopilotGraphMocks, AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot/../Helpers/AutopilotGraphMocks.psm1" -Force

Describe "Profile Assignment Integration" -Tags 'Integration', 'Profile', 'Assignment' {

    BeforeAll {
        $script:TestContext = Initialize-AutopilotTestEnvironment
        $script:RepoRoot = $TestContext.RootPath

        # Initialize global variables needed by functions
        $global:logFile = Join-Path $script:TestContext.TestFolder "test.log"
        $global:maxJSONDepth = 10

        # Load utility functions first
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Write-Log.ps1")

        # Define mock CallGraphAPI BEFORE loading functions that depend on it
        function global:CallGraphAPI
        {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel, [string]$Method = 'GET', $Body = $null, [string]$apiVersion = 'v1.0')

            return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
                -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel `
                -Method $Method -Body $Body -apiVersion $apiVersion
        }

        # Now load functions that will use the mocked CallGraphAPI
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-GroupDirectAssignments.ps1")
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-GroupIndirectAssignments.ps1")
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/Get-GroupAssignments-Common.ps1")
        . (Join-Path $script:RepoRoot "functions/utilityFunctions/Get-CachedData.ps1")

        Initialize-GraphMockEnvironment -ClearCache

        # Add mock data for tests
        Add-MockAutopilotProfile -DisplayName "Test-Profile-1" -Id "profile-test-01"
        Add-MockGroup -DisplayName "Test-Group-1" -Id "group-test-01"

        $script:token = New-MockAuthToken
        $script:testGroup = @{
            id          = "group-test-01"
            displayName = "Test-Group-1"
        }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
    }

    BeforeEach {
        # Clear assignment state and cache before each test
        Clear-MockProfileAssignments

        # Clear all caches to ensure tests are isolated
        if ($global:DirectoryObjectCache)
        {
            $global:DirectoryObjectCache.Clear()
        }
        if ($global:UnifiedCache)
        {
            if ($global:UnifiedCache.DirectoryObjects)
            {
                $global:UnifiedCache.DirectoryObjects.Clear()
            }
            if ($global:UnifiedCache.Configuration)
            {
                $global:UnifiedCache.Configuration.Clear()
            }
        }
    }

    Context "With Profile Assignment" {
        It "Should find a profile assigned to a group" {
            # Arrange
            Add-MockProfileAssignment -ProfileId "profile-test-01" -TargetId "group-test-01"

            # Act
            # The function under test requires the -IncludeBeta switch for Autopilot profiles
            $result = Get-GroupDirectAssignments -AccessToken $script:token -GroupName $script:testGroup -IncludeBeta

            # Assert
            $result | Should -Not -BeNull
            $result.AutopilotAssignments | Should -HaveCount 1
            $result.AutopilotAssignments[0].Id | Should -Be "profile-test-01"
            $result.AutopilotAssignments[0].Name | Should -Be "Test-Profile-1"
        }
    }

    Context "Without Profile Assignment" {
        It "Should return no assignments when none exist" {
            # Arrange: No assignments are added

            # Act
            $result = Get-GroupDirectAssignments -AccessToken $script:token -GroupName $script:testGroup -IncludeBeta

            # Assert
            $result | Should -Not -BeNull
            $result.AutopilotAssignments | Should -HaveCount 0
        }

        It "Should return no assignments if profile is assigned to a different group" {
            # Arrange
            Add-MockProfileAssignment -ProfileId "profile-test-01" -TargetId "some-other-group"

            # Act
            $result = Get-GroupDirectAssignments -AccessToken $script:token -GroupName $script:testGroup -IncludeBeta

            # Assert
            $result | Should -Not -BeNull
            $result.AutopilotAssignments | Should -HaveCount 0
        }
    }
}
