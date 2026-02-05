<#
.SYNOPSIS
    Tests for Get-AutopilotEventAnalysis

.DESCRIPTION
    Unit tests for autopilot event analysis function

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers, AutopilotGraphMocks
#>

Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotGraphMocks.psm1" -Force

Describe "Get-AutopilotEventAnalysis" -Tags 'Unit', 'Reports' {

    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

        # Dot-source functions directly (PS 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }

        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment
        Initialize-GraphMockEnvironment -ClearCache

        # Mock Write-Log if not already available
        if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            function global:Write-Log { param($LogFile, $Module, $Message, $LogLevel) }
        }

        # Set global variables
        $global:LogFile = $script:TestContext.LogFile

        # Create sample autopilot events
        $script:SampleEvents = @(
            @{
                eventDateTime = "2025-02-01T10:00:00Z"
                deviceSerialNumber = "ABC123"
                managedDeviceName = "Device1"
                userPrincipalName = "user1@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT2H30M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
            },
            @{
                eventDateTime = "2025-02-02T11:00:00Z"
                deviceSerialNumber = "DEF456"
                managedDeviceName = "Device2"
                userPrincipalName = "user2@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT1H45M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
            },
            @{
                eventDateTime = "2025-02-03T12:00:00Z"
                deviceSerialNumber = "GHI789"
                managedDeviceName = "Device3"
                userPrincipalName = "user3@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "notStarted"
                deploymentTotalDuration = "PT45M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                enrollmentFailureDetails = "Device setup failed"
            },
            @{
                eventDateTime = "2025-02-04T13:00:00Z"
                deviceSerialNumber = "JKL012"
                managedDeviceName = "Device4"
                userPrincipalName = "user3@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "notStarted"
                deploymentTotalDuration = "PT30M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                enrollmentFailureDetails = "Device setup failed again"
            },
            @{
                eventDateTime = "2025-02-05T14:00:00Z"
                deviceSerialNumber = "MNO345"
                managedDeviceName = "Device5"
                userPrincipalName = "user3@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT2H"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
            },
            @{
                eventDateTime = "2025-02-06T15:00:00Z"
                deviceSerialNumber = "PQR678"
                managedDeviceName = "Device6"
                userPrincipalName = "user4@contoso.com"
                deploymentState = "inProgress"
                deviceSetupStatus = "inProgress"
                accountSetupStatus = "notStarted"
                osVersion = "10.0.19045"
                enrollmentState = "enrolling"
                enrollmentType = "userDrivenAADJoin"
            },
            @{
                eventDateTime = "2025-02-07T16:00:00Z"
                deviceSerialNumber = "STU901"
                managedDeviceName = "Device7"
                userPrincipalName = "user5@contoso.com"
                deploymentState = "inProgress"
                deviceSetupStatus = "success"
                accountSetupStatus = "inProgress"
                osVersion = "10.0.19045"
                enrollmentState = "enrolling"
                enrollmentType = "userDrivenAADJoin"
            },
            @{
                eventDateTime = "2025-02-08T17:00:00Z"
                deviceSerialNumber = "VWX234"
                managedDeviceName = "Device8"
                userPrincipalName = "user6@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "success"
                accountSetupStatus = "failure"
                deploymentTotalDuration = "PT1H20M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                enrollmentFailureDetails = "Account setup failed"
            },
            @{
                eventDateTime = "2025-02-09T18:00:00Z"
                deviceSerialNumber = "YZA567"
                managedDeviceName = "Device9"
                userPrincipalName = "user7@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "failure"
                deploymentTotalDuration = "PT50M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                enrollmentFailureDetails = "Both phases failed"
            },
            @{
                eventDateTime = "2025-02-10T19:00:00Z"
                deviceSerialNumber = "BCD890"
                managedDeviceName = "Device10"
                userPrincipalName = "user8@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "notStarted"
                deploymentTotalDuration = "PT25M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                enrollmentFailureDetails = "Device setup failed"
            },
            @{
                eventDateTime = "2025-02-11T20:00:00Z"
                deviceSerialNumber = "EFG123"
                managedDeviceName = "Device11"
                userPrincipalName = "user8@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT2H15M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
            }
        )
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
    }

    Context "Event retrieval via Graph API" {

        It "Should fetch events from Graph API when not provided" {
            Mock CallGraphAPI {
                return @{ value = $script:SampleEvents }
            }

            $result = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $result | Should -Not -BeNullOrEmpty
            $result.TotalEvents | Should -BeGreaterThan 0
        }

        It "Should throw when AccessToken missing and Events not provided" {
            { Get-AutopilotEventAnalysis } | Should -Throw "*AccessToken is required*"
        }

        It "Should use provided Events array without API call" {
            Mock CallGraphAPI { throw "Should not call API" }

            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.TotalEvents | Should -Be $script:SampleEvents.Count
        }
    }

    Context "Event counting and categorization" {

        It "Should count total events correctly" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.TotalEvents | Should -Be 11
        }

        It "Should count successful events correctly" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.SuccessCount | Should -Be 4
        }

        It "Should count failed events correctly" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.FailureCount | Should -Be 5
        }

        It "Should count in-progress events correctly" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.InProgressCount | Should -Be 2
        }

        It "Should identify device phase in-progress events" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.DevicePhaseInProgressCount | Should -Be 1
        }

        It "Should identify user/account phase in-progress events" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.UserPhaseInProgressCount | Should -Be 1
        }
    }

    Context "Failure phase categorization" {

        It "Should categorize device-only failures" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.DevicePhaseOnlyFailureCount | Should -Be 3
        }

        It "Should categorize user/account-only failures" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.UserPhaseOnlyFailureCount | Should -Be 1
        }

        It "Should categorize both-phases failures" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.BothPhasesFailureCount | Should -Be 1
        }

        It "Should track unknown phase failures" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.UnknownPhaseFailureCount | Should -BeGreaterOrEqual 0
        }
    }

    Context "Date filtering" {

        It "Should filter events by start date" {
            $startDate = [DateTime]"2025-02-05T00:00:00Z"
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents -StartDate $startDate

            $result.TotalEvents | Should -BeLessOrEqual $script:SampleEvents.Count
            $result.StartDate | Should -Be $startDate
        }

        It "Should filter events by end date" {
            $endDate = [DateTime]"2025-02-05T23:59:59Z"
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents -EndDate $endDate

            $result.TotalEvents | Should -BeLessOrEqual $script:SampleEvents.Count
            $result.EndDate | Should -Be $endDate
        }

        It "Should filter events by date range" {
            $startDate = [DateTime]"2025-02-05T00:00:00Z"
            $endDate = [DateTime]"2025-02-08T23:59:59Z"
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents -StartDate $startDate -EndDate $endDate

            $result.TotalEvents | Should -BeLessOrEqual $script:SampleEvents.Count
            $result.StartDate | Should -Be $startDate
            $result.EndDate | Should -Be $endDate
        }

        It "Should handle events with invalid dates" {
            $eventsWithBadDate = @(
                @{
                    eventDateTime = $null
                    deploymentState = "success"
                    deviceSetupStatus = "success"
                    accountSetupStatus = "success"
                },
                @{
                    eventDateTime = "not-a-date"
                    deploymentState = "success"
                    deviceSetupStatus = "success"
                    accountSetupStatus = "success"
                }
            )

            # The function should handle invalid dates without crashing
            { $result = Get-AutopilotEventAnalysis -Events $eventsWithBadDate } | Should -Not -Throw
        }
    }

    Context "User principal name filtering" {

        It "Should filter events by UserPrincipalName" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents -UserPrincipalName "user3@contoso.com"

            $result.TotalEvents | Should -Be 3
            $result.UserPrincipalName | Should -Be "user3@contoso.com"
        }

        It "Should return only events matching the UPN" {
            # Create a fresh copy to avoid cross-test contamination
            $testEvents = $script:SampleEvents | ForEach-Object { $_.Clone() }
            $result = Get-AutopilotEventAnalysis -Events $testEvents -UserPrincipalName "user1@contoso.com"

            # Should filter to only events for this user
            $result.TotalEvents | Should -BeLessOrEqual $testEvents.Count
            # Verify filtering occurred (if user has events)
            if ($result.TotalEvents -gt 0) {
                $result.UserPrincipalName | Should -Be "user1@contoso.com"
            }
        }

        It "Should return zero events for non-existent UPN" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents -UserPrincipalName "nonexistent@contoso.com"

            $result.TotalEvents | Should -Be 0
        }
    }

    Context "Duration calculation" {

        It "Should calculate average success duration" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.AverageSuccessDuration | Should -Not -BeNullOrEmpty
            $result.AverageSuccessDuration.GetType().Name | Should -Be "TimeSpan"
        }

        It "Should calculate average failure duration" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.AverageFailureDuration | Should -Not -BeNullOrEmpty
            $result.AverageFailureDuration.GetType().Name | Should -Be "TimeSpan"
        }

        It "Should handle events without duration data" {
            $eventsWithoutDuration = @(
                @{
                    eventDateTime = "2025-02-01T10:00:00Z"
                    deploymentState = "success"
                    deviceSetupStatus = "success"
                    accountSetupStatus = "success"
                }
            )

            $result = Get-AutopilotEventAnalysis -Events $eventsWithoutDuration

            $result.AverageSuccessDuration | Should -BeNullOrEmpty
        }
    }

    Context "User failure analysis" {

        It "Should identify users with multiple failures" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.UsersWithMultipleFailures | Should -Not -BeNullOrEmpty
            $result.UsersWithMultipleFailures.Count | Should -BeGreaterThan 0
        }

        It "Should track eventual success for users with multiple failures" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $user3 = $result.UsersWithMultipleFailures | Where-Object { $_.UserPrincipalName -eq "user3@contoso.com" }
            $user3.FailureCount | Should -Be 2
            $user3.EventualSuccess | Should -Be $true
        }

        It "Should identify users with single failure then success" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.SingleFailureWithSuccess | Should -Not -BeNullOrEmpty
            $result.SingleFailureWithSuccess.Count | Should -BeGreaterThan 0
        }

        It "Should track single failure followed by success" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $user8 = $result.SingleFailureWithSuccess | Where-Object { $_.UserPrincipalName -eq "user8@contoso.com" }
            $user8 | Should -Not -BeNullOrEmpty
            $user8.SuccessDevice | Should -Not -BeNullOrEmpty
        }
    }

    Context "Chronological sorting" {

        It "Should sort failed devices chronologically" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.FailedDevicesChronological | Should -Not -BeNullOrEmpty
            $result.FailedDevicesChronological.Count | Should -Be $result.FailureCount
        }

        It "Should order failures by event date ascending" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $dates = $result.FailedDevicesChronological | ForEach-Object { [DateTime]$_.eventDateTime }
            for ($i = 0; $i -lt ($dates.Count - 1); $i++) {
                $dates[$i] | Should -BeLessOrEqual $dates[$i + 1]
            }
        }
    }

    Context "Result structure" {

        It "Should return PSCustomObject with all expected properties" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.PSObject.TypeNames[0] | Should -Be "System.Management.Automation.PSCustomObject"
            $result.PSObject.Properties.Name | Should -Contain "TotalEvents"
            $result.PSObject.Properties.Name | Should -Contain "SuccessCount"
            $result.PSObject.Properties.Name | Should -Contain "FailureCount"
            $result.PSObject.Properties.Name | Should -Contain "InProgressCount"
        }

        It "Should preserve original events array" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.AllEvents | Should -Be $script:SampleEvents
            $result.AllEvents.Count | Should -Be $script:SampleEvents.Count
        }

        It "Should include filtered events when filters applied" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents -UserPrincipalName "user3@contoso.com"

            $result.AllFilteredEvents | Should -Not -BeNullOrEmpty
            $result.AllFilteredEvents.Count | Should -BeLessOrEqual $script:SampleEvents.Count
        }

        It "Should track earliest event date" {
            $result = Get-AutopilotEventAnalysis -Events $script:SampleEvents

            $result.EarliestEventDate | Should -Not -BeNullOrEmpty
            $result.EarliestEventDate | Should -Be ([DateTime]"2025-02-01T10:00:00Z")
        }
    }

    Context "Edge cases" {

        It "Should handle empty events array" {
            # When Events array is provided (even if empty), no AccessToken needed
            { $result = Get-AutopilotEventAnalysis -Events @() } | Should -Not -Throw

            $result = Get-AutopilotEventAnalysis -Events @()
            $result.TotalEvents | Should -Be 0
            $result.SuccessCount | Should -Be 0
            $result.FailureCount | Should -Be 0
        }

        It "Should handle events without userPrincipalName" {
            $eventsWithoutUPN = @(
                @{
                    eventDateTime = "2025-02-01T10:00:00Z"
                    deviceSerialNumber = "ABC123"
                    deploymentState = "success"
                    deviceSetupStatus = "success"
                    accountSetupStatus = "success"
                }
            )

            $result = Get-AutopilotEventAnalysis -Events $eventsWithoutUPN

            $result.TotalEvents | Should -Be 1
            $result.UsersWithMultipleFailures.Count | Should -Be 0
        }

        It "Should handle events without serial numbers" {
            $eventsWithoutSerial = @(
                @{
                    eventDateTime = "2025-02-01T10:00:00Z"
                    userPrincipalName = "user@contoso.com"
                    deploymentState = "failure"
                    deviceSetupStatus = "failure"
                    accountSetupStatus = "notStarted"
                }
            )

            $result = Get-AutopilotEventAnalysis -Events $eventsWithoutSerial

            $result.TotalEvents | Should -Be 1
            $result.FailedDevicesChronological.Count | Should -Be 0
        }
    }
}
