<#
.SYNOPSIS
    Integration tests for Autopilot Event Analysis workflow

.DESCRIPTION
    End-to-end integration tests for the complete autopilot reports workflow

.NOTES
    Test Category: Integration
    Template Compliance: Full
    Uses: AutopilotTestHelpers, AutopilotGraphMocks
#>

Import-Module "$PSScriptRoot\..\Helpers\AutopilotTestHelpers.psm1" -Force
Import-Module "$PSScriptRoot\..\Helpers\AutopilotGraphMocks.psm1" -Force

Describe "Autopilot Event Analysis Workflow" -Tags 'Integration', 'Reports' {

    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

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

        # Create comprehensive sample autopilot events
        $script:SampleAutopilotEvents = @(
            # Successful enrollments
            @{
                id = "event-001"
                eventDateTime = "2025-02-01T10:00:00Z"
                deviceSerialNumber = "SN-SUCCESS-001"
                managedDeviceName = "LAPTOP-SUCCESS-001"
                userPrincipalName = "success.user@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT2H30M"
                deploymentDuration = "PT2H"
                deviceSetupDuration = "PT1H30M"
                accountSetupDuration = "PT30M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
                deviceId = "device-001"
                userId = "user-001"
                deviceRegisteredDateTime = "2025-02-01T08:00:00Z"
                enrollmentStartDateTime = "2025-02-01T09:00:00Z"
                deploymentStartDateTime = "2025-02-01T09:30:00Z"
                deploymentEndDateTime = "2025-02-01T12:00:00Z"
            },
            @{
                id = "event-002"
                eventDateTime = "2025-02-02T11:00:00Z"
                deviceSerialNumber = "SN-SUCCESS-002"
                managedDeviceName = "LAPTOP-SUCCESS-002"
                userPrincipalName = "another.user@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT1H45M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
            },
            # Multiple failures then success (same user)
            @{
                id = "event-003"
                eventDateTime = "2025-02-03T12:00:00Z"
                deviceSerialNumber = "SN-FAIL-001"
                managedDeviceName = "LAPTOP-RETRY-001"
                userPrincipalName = "retry.user@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "notStarted"
                deploymentTotalDuration = "PT45M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
                enrollmentFailureDetails = "Device setup failed - network timeout"
            },
            @{
                id = "event-004"
                eventDateTime = "2025-02-04T13:00:00Z"
                deviceSerialNumber = "SN-FAIL-002"
                managedDeviceName = "LAPTOP-RETRY-002"
                userPrincipalName = "retry.user@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "notStarted"
                deploymentTotalDuration = "PT30M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
                enrollmentFailureDetails = "Device setup failed - DNS resolution"
            },
            @{
                id = "event-005"
                eventDateTime = "2025-02-05T14:00:00Z"
                deviceSerialNumber = "SN-SUCCESS-003"
                managedDeviceName = "LAPTOP-SUCCESS-003"
                userPrincipalName = "retry.user@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT2H"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
            },
            # Single failure then success (different user)
            @{
                id = "event-006"
                eventDateTime = "2025-02-06T15:00:00Z"
                deviceSerialNumber = "SN-FAIL-003"
                managedDeviceName = "LAPTOP-SINGLEFAIL-001"
                userPrincipalName = "singlefail.user@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "notStarted"
                deploymentTotalDuration = "PT25M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
                enrollmentFailureDetails = "Device setup failed - TPM issue"
            },
            @{
                id = "event-007"
                eventDateTime = "2025-02-07T16:00:00Z"
                deviceSerialNumber = "SN-SUCCESS-004"
                managedDeviceName = "LAPTOP-SUCCESS-004"
                userPrincipalName = "singlefail.user@contoso.com"
                deploymentState = "success"
                deviceSetupStatus = "success"
                accountSetupStatus = "success"
                deploymentTotalDuration = "PT2H15M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
            },
            # In-progress devices
            @{
                id = "event-008"
                eventDateTime = "2025-02-08T17:00:00Z"
                deviceSerialNumber = "SN-INPROG-001"
                managedDeviceName = "LAPTOP-INPROG-001"
                userPrincipalName = "inprogress.user@contoso.com"
                deploymentState = "inProgress"
                deviceSetupStatus = "inProgress"
                accountSetupStatus = "notStarted"
                osVersion = "10.0.19045"
                enrollmentState = "enrolling"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
            },
            @{
                id = "event-009"
                eventDateTime = "2025-02-09T18:00:00Z"
                deviceSerialNumber = "SN-INPROG-002"
                managedDeviceName = "LAPTOP-INPROG-002"
                userPrincipalName = "inprogress2.user@contoso.com"
                deploymentState = "inProgress"
                deviceSetupStatus = "success"
                accountSetupStatus = "inProgress"
                osVersion = "10.0.19045"
                enrollmentState = "enrolling"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
            },
            # Different failure types
            @{
                id = "event-010"
                eventDateTime = "2025-02-10T19:00:00Z"
                deviceSerialNumber = "SN-FAIL-ACCOUNT"
                managedDeviceName = "LAPTOP-ACCOUNTFAIL"
                userPrincipalName = "accountfail.user@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "success"
                accountSetupStatus = "failure"
                deploymentTotalDuration = "PT1H20M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
                enrollmentFailureDetails = "Account setup failed - Azure AD sync issue"
            },
            @{
                id = "event-011"
                eventDateTime = "2025-02-11T20:00:00Z"
                deviceSerialNumber = "SN-FAIL-BOTH"
                managedDeviceName = "LAPTOP-BOTHFAIL"
                userPrincipalName = "bothfail.user@contoso.com"
                deploymentState = "failure"
                deviceSetupStatus = "failure"
                accountSetupStatus = "failure"
                deploymentTotalDuration = "PT50M"
                osVersion = "10.0.19045"
                enrollmentState = "enrolled"
                enrollmentType = "userDrivenAADJoin"
                windowsAutopilotDeploymentProfileDisplayName = "Standard Profile"
                enrollmentFailureDetails = "Both device and account setup failed"
            }
        )

        # Mock CallGraphAPI to return sample events
        Mock CallGraphAPI {
            return @{ value = $script:SampleAutopilotEvents }
        }

        # Mock FormatDateWithTimeZone
        Mock FormatDateWithTimeZone {
            param($DateTime)
            if ($DateTime) {
                return $DateTime.ToString("yyyy-MM-dd HH:mm:ss zzz")
            }
            return "N/A"
        }

        # Mock Show-PagedContent to avoid interactive prompts
        Mock Show-PagedContent {
            param($Items, $PageSize, $DisplayScript, $SectionTitle)
            foreach ($item in $Items) {
                & $DisplayScript $item
            }
        }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
        Clear-GraphMockEnvironment
    }

    Context "Complete workflow without filters" {

        It "Should fetch and analyze events successfully" {
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $analysis | Should -Not -BeNullOrEmpty
            $analysis.TotalEvents | Should -Be 11
            $analysis.SuccessCount | Should -Be 4
            $analysis.FailureCount | Should -Be 5
            $analysis.InProgressCount | Should -Be 2
        }

        It "Should identify all failure categories" {
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $analysis.DevicePhaseOnlyFailureCount | Should -BeGreaterThan 0
            $analysis.UserPhaseOnlyFailureCount | Should -BeGreaterThan 0
            $analysis.BothPhasesFailureCount | Should -BeGreaterThan 0
        }

        It "Should identify users with multiple failures" {
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $analysis.UsersWithMultipleFailures | Should -Not -BeNullOrEmpty
            $retryUser = $analysis.UsersWithMultipleFailures | Where-Object { $_.UserPrincipalName -eq "retry.user@contoso.com" }
            $retryUser | Should -Not -BeNullOrEmpty
            $retryUser.FailureCount | Should -Be 2
            $retryUser.EventualSuccess | Should -Be $true
        }

        It "Should identify users with single failure then success" {
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $analysis.SingleFailureWithSuccess | Should -Not -BeNullOrEmpty
            $singleFailUser = $analysis.SingleFailureWithSuccess | Where-Object { $_.UserPrincipalName -eq "singlefail.user@contoso.com" }
            $singleFailUser | Should -Not -BeNullOrEmpty
        }

        It "Should display analysis successfully" {
            Mock Write-Host { }

            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            {
                Show-AutopilotEventAnalysis -AnalysisData $analysis `
                    -ShowSummary `
                    -ShowMultipleFailures `
                    -ShowSingleFailures `
                    -ShowChronologicalFailures `
                    -ShowInProgress
            } | Should -Not -Throw
        }

        It "Should export analysis successfully" {
            Mock Write-Host { }
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestContext.TestFolder }
                return ""
            }

            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"
            $exportResult = Export-AutopilotEventAnalysis -AnalysisData $analysis

            $exportResult.Success | Should -Be $true
            $exportResult.FileCount | Should -BeGreaterThan 0
        }
    }

    Context "Workflow with date filters" {

        It "Should filter by start date" {
            $startDate = [DateTime]"2025-02-05T00:00:00Z"
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" -StartDate $startDate

            $analysis.TotalEvents | Should -BeLessOrEqual 7
            $analysis.StartDate | Should -Be $startDate
        }

        It "Should filter by date range" {
            $startDate = [DateTime]"2025-02-03T00:00:00Z"
            $endDate = [DateTime]"2025-02-07T23:59:59Z"
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" -StartDate $startDate -EndDate $endDate

            $analysis.TotalEvents | Should -BeLessOrEqual 5
            $analysis.StartDate | Should -Be $startDate
            $analysis.EndDate | Should -Be $endDate
        }

        It "Should display filtered results correctly" {
            Mock Write-Host { }

            $startDate = [DateTime]"2025-02-05T00:00:00Z"
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" -StartDate $startDate

            { Show-AutopilotEventAnalysis -AnalysisData $analysis -ShowSummary } | Should -Not -Throw
        }
    }

    Context "Workflow with user filter" {

        It "Should filter by UserPrincipalName" {
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "retry.user@contoso.com"

            $analysis.TotalEvents | Should -Be 3
            $analysis.FailureCount | Should -Be 2
            $analysis.SuccessCount | Should -Be 1
        }

        It "Should show user journey in filtered results" {
            Mock Write-Host { }

            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "retry.user@contoso.com"

            { Show-AutopilotEventAnalysis -AnalysisData $analysis -ShowSummary -ShowChronologicalFailures } | Should -Not -Throw
        }

        It "Should export filtered user data" {
            Mock Write-Host { }
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestContext.TestFolder }
                return ""
            }

            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" -UserPrincipalName "retry.user@contoso.com"
            $exportResult = Export-AutopilotEventAnalysis -AnalysisData $analysis

            $exportResult.Success | Should -Be $true
        }
    }

    Context "Workflow with input gathering" {

        It "Should gather input and apply filters" {
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*Start Date*") { return "2025-02-05" }
                if ($Prompt -like "*End Date*") { return "" }
                if ($Prompt -like "*User Principal Name*") { return "" }
                return ""
            }
            Mock Write-Host { }

            $inputParams = Get-AutopilotEnrollmentReportInput -NoConfirmation
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" @inputParams

            $analysis.StartDate | Should -Not -BeNullOrEmpty
            $analysis.TotalEvents | Should -BeLessOrEqual 7
        }

        It "Should complete full workflow with interactive input" {
            Mock Read-Host {
                param($Prompt)
                # Input gathering
                if ($Prompt -like "*Start Date*") { return "2025-02-01" }
                if ($Prompt -like "*End Date*") { return "2025-02-11" }
                if ($Prompt -like "*User Principal Name*") { return "" }
                # Export prompts
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestContext.TestFolder }
                return ""
            }
            Mock Write-Host { }

            # Gather input
            $inputParams = Get-AutopilotEnrollmentReportInput -NoConfirmation

            # Analyze
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token" @inputParams

            # Display
            Show-AutopilotEventAnalysis -AnalysisData $analysis -ShowSummary

            # Export
            $exportResult = Export-AutopilotEventAnalysis -AnalysisData $analysis

            $exportResult.Success | Should -Be $true
            $exportResult.FileCount | Should -BeGreaterThan 0
        }
    }

    Context "Workflow with provided events" {

        It "Should analyze provided events without API call" {
            Mock CallGraphAPI { throw "Should not call API" }

            $analysis = Get-AutopilotEventAnalysis -Events $script:SampleAutopilotEvents

            $analysis.TotalEvents | Should -Be 11
        }

        It "Should complete workflow with pipeline" {
            Mock Write-Host { }

            $analysis = $script:SampleAutopilotEvents | Get-AutopilotEventAnalysis

            { $analysis | Show-AutopilotEventAnalysis -ShowSummary } | Should -Not -Throw
        }

        It "Should export piped analysis" {
            Mock Write-Host { }
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "1" }
                if ($Prompt -like "*output path*") { return $script:TestContext.TestFolder }
                return ""
            }

            $exportResult = $script:SampleAutopilotEvents | Get-AutopilotEventAnalysis | Export-AutopilotEventAnalysis

            $exportResult.Success | Should -Be $true
        }
    }

    Context "Data consistency across workflow" {

        It "Should maintain consistent counts throughout workflow" {
            Mock Write-Host { }
            Mock Read-Host {
                param($Prompt)
                if ($Prompt -like "*export option*") { return "2" }
                if ($Prompt -like "*output path*") { return $script:TestContext.TestFolder }
                return ""
            }

            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"
            Show-AutopilotEventAnalysis -AnalysisData $analysis -ShowSummary
            $exportResult = Export-AutopilotEventAnalysis -AnalysisData $analysis

            # Verify counts are consistent
            $analysis.SuccessCount + $analysis.FailureCount + $analysis.InProgressCount | Should -Be $analysis.TotalEvents

            # Verify export succeeded
            $exportResult.Success | Should -Be $true
        }

        It "Should maintain event data integrity" {
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $analysis.AllEvents.Count | Should -Be $script:SampleAutopilotEvents.Count
            $analysis.AllFilteredEvents.Count | Should -Be $analysis.TotalEvents
        }

        It "Should calculate durations correctly" {
            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $analysis.AverageSuccessDuration | Should -Not -BeNullOrEmpty
            $analysis.AverageSuccessDuration.TotalMinutes | Should -BeGreaterThan 0
        }
    }

    Context "Error handling in workflow" {

        It "Should handle API errors gracefully" {
            Mock CallGraphAPI { throw "API error" }

            { Get-AutopilotEventAnalysis -AccessToken "test-token" } | Should -Throw
        }

        It "Should handle empty event sets" {
            Mock CallGraphAPI { return @{ value = @() } }
            Mock Write-Host { }

            $analysis = Get-AutopilotEventAnalysis -AccessToken "test-token"

            $analysis.TotalEvents | Should -Be 0

            { Show-AutopilotEventAnalysis -AnalysisData $analysis -ShowSummary } | Should -Not -Throw
        }

        It "Should handle malformed event data" {
            $badEvents = @(
                @{ eventDateTime = "invalid-date"; deploymentState = "success" },
                @{ deviceSerialNumber = "SN001" }  # Missing required fields
            )

            { Get-AutopilotEventAnalysis -Events $badEvents } | Should -Not -Throw
        }
    }

    Context "Performance with large datasets" {

        It "Should handle 100+ events efficiently" {
            # Create large dataset
            $largeEventSet = 1..120 | ForEach-Object {
                @{
                    id = "event-$_"
                    eventDateTime = (Get-Date).AddDays(-$_).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    deviceSerialNumber = "SN-$_"
                    managedDeviceName = "Device-$_"
                    userPrincipalName = "user$_@contoso.com"
                    deploymentState = if ($_ % 3 -eq 0) { "failure" } elseif ($_ % 7 -eq 0) { "inProgress" } else { "success" }
                    deviceSetupStatus = if ($_ % 3 -eq 0) { "failure" } else { "success" }
                    accountSetupStatus = if ($_ % 3 -eq 0) { "notStarted" } else { "success" }
                    osVersion = "10.0.19045"
                    enrollmentState = "enrolled"
                    enrollmentType = "userDrivenAADJoin"
                }
            }

            $analysis = Get-AutopilotEventAnalysis -Events $largeEventSet

            $analysis.TotalEvents | Should -Be 120
            $analysis.SuccessCount + $analysis.FailureCount + $analysis.InProgressCount | Should -Be 120
        }
    }
}
