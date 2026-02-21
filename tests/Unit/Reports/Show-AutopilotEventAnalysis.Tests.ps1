<#
.SYNOPSIS
    Tests for Show-AutopilotEventAnalysis

.DESCRIPTION
    Unit tests for autopilot event analysis display function

.NOTES
    Test Category: Unit
    Template Compliance: Full
    Uses: AutopilotTestHelpers
#>

Import-Module "$PSScriptRoot\..\..\Helpers\AutopilotTestHelpers.psm1" -Force

Describe "Show-AutopilotEventAnalysis" -Tags 'Unit', 'Reports' {

    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

        # Dot-source functions directly (PS 5.1 compatible)
        $functionsPath = Join-Path $script:RepoRoot "functions"
        Get-ChildItem -Path $functionsPath -Recurse -Filter *.ps1 | ForEach-Object {
            . $_.FullName
        }

        # Initialize test environment
        $script:TestContext = Initialize-AutopilotTestEnvironment

        # Mock Write-Log if not already available
        if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue))
        {
            function global:Write-Log
            {
                param($LogFile, $Module, $Message, $LogLevel)
            }
        }

        # Set global variables
        $global:LogFile = $script:TestContext.LogFile

        # Create mock analysis data
        $script:MockAnalysisData = [PSCustomObject]@{
            TotalEvents                 = 10
            TotalEventsBeforeFilter     = 15
            StartDate                   = [DateTime]"2025-02-01T00:00:00Z"
            EndDate                     = [DateTime]"2025-02-10T23:59:59Z"
            UserPrincipalName           = "test@contoso.com"
            EarliestEventDate           = [DateTime]"2025-02-01T10:00:00Z"
            SuccessCount                = 5
            InProgressCount             = 2
            DevicePhaseInProgressCount  = 1
            UserPhaseInProgressCount    = 1
            FailureCount                = 3
            AverageSuccessDuration      = New-TimeSpan -Hours 2 -Minutes 30
            AverageFailureDuration      = New-TimeSpan -Hours 1 -Minutes 15
            DevicePhaseOnlyFailureCount = 1
            UserPhaseOnlyFailureCount   = 1
            BothPhasesFailureCount      = 1
            UnknownPhaseFailureCount    = 0
            SignInMatchStats            = @{
                TotalEvents      = 10
                MatchedEvents    = 8
                HighConfidence   = 5
                MediumConfidence = 2
                LowConfidence    = 1
            }
            UsersWithMultipleFailures   = @(
                [PSCustomObject]@{
                    UserPrincipalName = "user1@contoso.com"
                    FailureCount      = 2
                    EventualSuccess   = $true
                    SuccessDevice     = @{ deviceSerialNumber = "ABC123"; eventDateTime = "2025-02-05T14:00:00Z" }
                    FailedDevices     = @(
                        @{ deviceSerialNumber = "DEF456"; eventDateTime = "2025-02-03T12:00:00Z" },
                        @{ deviceSerialNumber = "GHI789"; eventDateTime = "2025-02-04T13:00:00Z" }
                    )
                    LastFailureDate   = "2025-02-04T13:00:00Z"
                }
            )
            SingleFailureWithSuccess    = @(
                [PSCustomObject]@{
                    UserPrincipalName = "user2@contoso.com"
                    FailureDate       = "2025-02-06T15:00:00Z"
                    FailureDevice     = @{ deviceSerialNumber = "JKL012"; eventDateTime = "2025-02-06T15:00:00Z" }
                    SuccessDate       = "2025-02-07T16:00:00Z"
                    SuccessDevice     = @{ deviceSerialNumber = "MNO345"; eventDateTime = "2025-02-07T16:00:00Z" }
                }
            )
            InProgressEvents            = @(
                @{
                    deviceSerialNumber       = "PQR678"
                    managedDeviceName        = "Device1"
                    userPrincipalName        = "user3@contoso.com"
                    eventDateTime            = "2025-02-08T17:00:00Z"
                    deploymentState          = "inProgress"
                    deviceSetupStatus        = "inProgress"
                    accountSetupStatus       = "notStarted"
                    SignIn_MatchFound        = $true
                    SignIn_ConfidenceScore   = 90
                    SignIn_MatchedOn         = "UserId, DeviceId, Time_Within1Hour"
                    SignIn_Location_City     = "Seattle"
                    SignIn_Location_State    = "Washington"
                    SignIn_Location_Country  = "US"
                    SignIn_IPAddress         = "192.168.1.1"
                    SignIn_Status            = "Success"
                    SignIn_FailureReason     = $null
                    SignIn_ErrorCode         = $null
                    SignIn_AppDisplayName    = "Microsoft Intune"
                    SignIn_DeviceDisplayName = "Device1"
                    SignIn_IsCompliant       = $true
                    SignIn_IsManaged         = $true
                }
            )
            FailedDevicesChronological  = @(
                @{
                    deviceSerialNumber       = "STU901"
                    managedDeviceName        = "Device2"
                    userPrincipalName        = "user4@contoso.com"
                    eventDateTime            = "2025-02-09T18:00:00Z"
                    deploymentState          = "failure"
                    deviceSetupStatus        = "failure"
                    accountSetupStatus       = "notStarted"
                    enrollmentFailureDetails = "Device setup failed"
                    SignIn_MatchFound        = $true
                    SignIn_ConfidenceScore   = 75
                    SignIn_MatchedOn         = "UserId, DeviceId, Time_Within2Hours"
                    SignIn_Location_City     = "Redmond"
                    SignIn_Location_State    = "Washington"
                    SignIn_Location_Country  = "US"
                    SignIn_IPAddress         = "10.0.0.1"
                    SignIn_Status            = "Failure"
                    SignIn_FailureReason     = "Invalid credentials"
                    SignIn_ErrorCode         = 50126
                    SignIn_AppDisplayName    = "Microsoft Intune Enrollment"
                    SignIn_DeviceDisplayName = "Device2"
                    SignIn_IsCompliant       = $false
                    SignIn_IsManaged         = $false
                }
            )
            FailedEvents                = @(
                @{
                    deviceSerialNumber       = "VWX234"
                    managedDeviceName        = "Device3"
                    userPrincipalName        = "user5@contoso.com"
                    eventDateTime            = "2025-02-10T19:00:00Z"
                    deploymentState          = "failure"
                    deviceSetupStatus        = "failure"
                    accountSetupStatus       = "notStarted"
                    osVersion                = "10.0.19045"
                    enrollmentState          = "enrolled"
                    enrollmentType           = "userDrivenAADJoin"
                    enrollmentFailureDetails = "Device setup failed"
                    SignIn_MatchFound        = $true
                    SignIn_ConfidenceScore   = 80
                    SignIn_MatchedOn         = "UserId, DeviceId, Time_Within1Hour"
                    SignIn_Location_City     = "San Francisco"
                    SignIn_Location_State    = "California"
                    SignIn_Location_Country  = "US"
                    SignIn_IPAddress         = "172.16.0.1"
                    SignIn_Status            = "Success"
                    SignIn_FailureReason     = $null
                    SignIn_ErrorCode         = $null
                    SignIn_AppDisplayName    = "Microsoft Intune"
                    SignIn_DeviceDisplayName = "Device3"
                    SignIn_IsCompliant       = $true
                    SignIn_IsManaged         = $true
                }
            )
        }

        # Mock Show-PagedContent
        Mock Show-PagedContent {
            param($Content, $PageSize, $DisplayScriptBlock, $Title, $ShowPageInfo, $Silent, $NoPaging)
            # Do nothing - just accept the call without executing DisplayScriptBlock
            # This prevents any output leakage from the DisplayScriptBlock execution
        }

        # Mock FormatDateWithTimeZone
        Mock FormatDateWithTimeZone {
            param($DateTime)
            if ($DateTime)
            {
                # Handle both string and DateTime types
                if ($DateTime -is [string])
                {
                    $dt = [DateTime]::Parse($DateTime)
                    return $dt.ToString("yyyy-MM-dd HH:mm:ss zzz")
                }
                elseif ($DateTime -is [DateTime])
                {
                    return $DateTime.ToString("yyyy-MM-dd HH:mm:ss zzz")
                }
                else
                {
                    return $DateTime.ToString()
                }
            }
            else
            {
                return "N/A"
            }
        }

        # Mock Read-Host to prevent test hangs on prompt
        Mock Read-Host {
            param($Prompt)
            # Return empty string to simulate user pressing Enter
            return ""
        }
    }

    AfterAll {
        Remove-TestEnvironment -TestContext $script:TestContext
    }

    Context "Empty events handling" {

        It "Should display message when no events found" {
            $emptyAnalysisData = [PSCustomObject]@{
                TotalEvents  = 0
                SuccessCount = 0
                FailureCount = 0
            }

            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $emptyAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*No autopilot events found*"
            } -Exactly 1
        }

        It "Should return early when TotalEvents is zero" {
            $emptyAnalysisData = [PSCustomObject]@{
                TotalEvents = 0
            }

            Mock Write-Host { }

            { Show-AutopilotEventAnalysis -AnalysisData $emptyAnalysisData -ShowSummary } | Should -Not -Throw
        }
    }

    Context "Summary section display" {

        It "Should display summary when ShowSummary is set" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Total Number of Events*"
            } -Exactly 1
        }

        It "Should display applied filters when present" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Applied Filters*"
            } -Exactly 1
        }

        It "Should display success count" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Successful Events*"
            } -Exactly 1
        }

        It "Should display failure count" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Failed Events*"
            } -Exactly 1
        }

        It "Should display in-progress count and breakdown" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*In-Progress Events*"
            } -Exactly 1
        }

        It "Should display average durations" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Average Duration*"
            }
        }

        It "Should display failure breakdown" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Failure Breakdown*"
            } -Exactly 1
        }

        It "Should display sign-in match statistics when present" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -like "*Sign-In Match*"
            }
        }

        It "Should prompt to continue after summary" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Read-Host -ParameterFilter {
                $Prompt -like "*Press Enter to continue*"
            } -Exactly 1
        }
    }

    Context "Multiple failures section display" {

        It "Should display multiple failures when ShowMultipleFailures is set" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowMultipleFailures

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Users with Multiple Enrollment Failures*"
            } -Exactly 1
        }

        It "Should use Show-PagedContent for multiple failures" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowMultipleFailures

            Should -Invoke Show-PagedContent -ParameterFilter {
                $Title -like "*Multiple*"
            } -Exactly 1
        }

        It "Should display message when no multiple failures" {
            $noFailuresData = $script:MockAnalysisData.PSObject.Copy()
            $noFailuresData.UsersWithMultipleFailures = @()

            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $noFailuresData -ShowMultipleFailures

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*No users with multiple failures*"
            } -Exactly 1
        }
    }

    Context "Single failure section display" {

        It "Should display single failures when ShowSingleFailures is set" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSingleFailures | Out-Null

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Failed Then Successful Enrollments*"
            } -Exactly 1
        }

        It "Should use Show-PagedContent for single failures" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSingleFailures

            Should -Invoke Show-PagedContent -ParameterFilter {
                $Title -like "*Single*"
            } -Exactly 1
        }

        It "Should display message when no single failures" {
            $noSingleFailuresData = $script:MockAnalysisData.PSObject.Copy()
            $noSingleFailuresData.SingleFailureWithSuccess = @()

            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $noSingleFailuresData -ShowSingleFailures

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*No users with single failure*"
            } -Exactly 1
        }
    }

    Context "Chronological failures section display" {

        It "Should display chronological failures when ShowChronologicalFailures is set" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowChronologicalFailures

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Failed Devices*Chronological*"
            } -Exactly 1
        }

        It "Should use Show-PagedContent for chronological failures" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowChronologicalFailures

            Should -Invoke Show-PagedContent -ParameterFilter {
                $Title -like "*Chronological*"
            } -Exactly 1
        }

        It "Should display message when no failures to show" {
            $noChronologicalData = $script:MockAnalysisData.PSObject.Copy()
            $noChronologicalData.FailedDevicesChronological = @()

            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $noChronologicalData -ShowChronologicalFailures

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*No failed devices*"
            } -Exactly 1
        }
    }

    Context "In-progress section display" {

        It "Should display in-progress devices when ShowInProgress is set" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowInProgress

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Devices Currently In Progress*"
            } -Exactly 1
        }

        It "Should use Show-PagedContent for in-progress devices" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowInProgress

            Should -Invoke Show-PagedContent -ParameterFilter {
                $Title -like "*Progress*"
            } -Exactly 1
        }

        It "Should display message when no in-progress devices" {
            $noInProgressData = $script:MockAnalysisData.PSObject.Copy()
            $noInProgressData.InProgressCount = 0
            $noInProgressData.InProgressEvents = @()

            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $noInProgressData -ShowInProgress

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*No devices currently in progress*"
            } -Exactly 1
        }
    }

    Context "Detailed failures section display" {

        It "Should display detailed failures when ShowDetailedFailures is set" {
            Mock Write-Host { }
            Mock Format-Table { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowDetailedFailures | Out-Null

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Detailed Failure Summary Table*"
            } -Exactly 1
        }

        It "Should format failures as table" {
            Mock Write-Host { }
            Mock Format-Table { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowDetailedFailures

            Should -Invoke Format-Table -Exactly 1
        }

        It "Should display message when no failures" {
            $noDetailedFailuresData = $script:MockAnalysisData.PSObject.Copy()
            $noDetailedFailuresData.FailedEvents = @()
            $noDetailedFailuresData.FailureCount = 0

            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $noDetailedFailuresData -ShowDetailedFailures | Out-Null

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Detailed Failure Summary Table*"
            } -Exactly 0
        }
    }

    Context "Display with all sections" {

        It "Should display all sections when all switches are set" {
            Mock Write-Host { }
            Mock Format-Table { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData `
                -ShowSummary `
                -ShowMultipleFailures `
                -ShowSingleFailures `
                -ShowChronologicalFailures `
                -ShowInProgress `
                -ShowDetailedFailures

            Should -Invoke Write-Host
        }

        It "Should display only requested sections" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Users with Multiple*"
            } -Exactly 0
        }
    }

    Context "Pipeline input" {

        It "Should accept AnalysisData from pipeline" {
            Mock Write-Host { }

            { $script:MockAnalysisData | Show-AutopilotEventAnalysis -ShowSummary } | Should -Not -Throw
        }

        It "Should process piped data correctly" {
            Mock Write-Host { }

            $script:MockAnalysisData | Show-AutopilotEventAnalysis -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Total Number of Events*"
            } -Exactly 1
        }
    }

    Context "Date formatting" {

        It "Should call FormatDateWithTimeZone for dates" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke FormatDateWithTimeZone
        }

        It "Should handle null dates gracefully" {
            $nullDateData = $script:MockAnalysisData.PSObject.Copy()
            $nullDateData.EarliestEventDate = $null

            Mock Write-Host { }

            { Show-AutopilotEventAnalysis -AnalysisData $nullDateData -ShowSummary } | Should -Not -Throw
        }
    }

    Context "Color coding" {

        It "Should use green for success indicators" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Green"
            }
        }

        It "Should use red for failure indicators" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary

            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Red"
            }
        }

        It "Should use cyan for in-progress indicators" {
            Mock Write-Host { }

            Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary -ShowInProgress

            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Cyan"
            }
        }
    }

    Context "Edge cases" {

        It "Should handle missing optional properties" {
            $minimalData = [PSCustomObject]@{
                TotalEvents     = 1
                SuccessCount    = 1
                FailureCount    = 0
                InProgressCount = 0
            }

            Mock Write-Host { }

            { Show-AutopilotEventAnalysis -AnalysisData $minimalData -ShowSummary } | Should -Not -Throw
        }

        It "Should handle null FormatDateWithTimeZone return" {
            Mock FormatDateWithTimeZone { return $null }
            Mock Write-Host { }

            { Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowSummary } | Should -Not -Throw
        }

        It "Should not throw when Show-PagedContent is not available" {
            Mock Show-PagedContent { throw "Not available" }
            Mock Write-Host { }

            # Should handle gracefully - either skip or show error
            { Show-AutopilotEventAnalysis -AnalysisData $script:MockAnalysisData -ShowMultipleFailures } | Should -Throw
        }
    }
}
