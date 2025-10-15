<#
.SYNOPSIS
    Integration tests for Autopilot profile assignments.

.DESCRIPTION
    Tests the application's ability to correctly identify Autopilot profiles
    assigned to groups by testing the GetGroupDirectAssignments function against
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

        # Load the function to be tested
        . (Join-Path $script:RepoRoot "functions/UserAndGroupFunctions/GetGroupDirectAssignments.ps1")

        Initialize-GraphMockEnvironment -ClearCache

        # Add mock data for tests
        Add-MockAutopilotProfile -DisplayName "Test-Profile-1" -Id "profile-test-01"
        Add-MockGroup -DisplayName "Test-Group-1" -Id "group-test-01"

        # Mock the global CallGraphAPI function to use our enhanced mock
        function global:CallGraphAPI {
            param($accessToken, $ResourcePath, $Filter, $ExtraParameters, [switch]$consistencyLevel, [string]$Method = 'GET', $Body = $null, [string]$apiVersion = 'v1.0')
            
            return Invoke-MockGraphAPI -accessToken $accessToken -ResourcePath $ResourcePath `
                -Filter $Filter -ExtraParameters $ExtraParameters -consistencyLevel:$consistencyLevel `
                -Method $Method -Body $Body -apiVersion $apiVersion
        }

        $script:token = New-MockAuthToken
        $script:testGroup = @{ 
            id = "group-test-01"
            displayName = "Test-Group-1"
        }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
    }

    BeforeEach {
        # Clear assignment state before each test
        Clear-MockProfileAssignments
    }

    Context "With Profile Assignment" {
        It "Should find a profile assigned to a group" {
            # Arrange
            Add-MockProfileAssignment -ProfileId "profile-test-01" -TargetId "group-test-01"

            # Act
            # The function under test requires the -IncludeBeta switch for Autopilot profiles
            $result = GetGroupDirectAssignments -AccessToken $script:token -GroupName $script:testGroup -IncludeBeta

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
            $result = GetGroupDirectAssignments -AccessToken $script:token -GroupName $script:testGroup -IncludeBeta

            # Assert
            $result | Should -Not -BeNull
            $result.AutopilotAssignments | Should -HaveCount 0
        }

        It "Should return no assignments if profile is assigned to a different group" {
            # Arrange
            Add-MockProfileAssignment -ProfileId "profile-test-01" -TargetId "some-other-group"

            # Act
            $result = GetGroupDirectAssignments -AccessToken $script:token -GroupName $script:testGroup -IncludeBeta

            # Assert
            $result | Should -Not -BeNull
            $result.AutopilotAssignments | Should -HaveCount 0
        }
    }
}
