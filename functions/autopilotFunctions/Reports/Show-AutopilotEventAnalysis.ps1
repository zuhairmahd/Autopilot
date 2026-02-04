function Show-AutopilotEventAnalysis()
{
    <#
    .SYNOPSIS
        Displays autopilot event analysis results.

    .DESCRIPTION
        Formats and displays the analyzed autopilot event data with customizable sections.

    .PARAMETER AnalysisData
        The analysis data object returned from Get-AutopilotEventAnalysis.

    .PARAMETER ShowSummary
        Display summary statistics (default: true).

    .PARAMETER ShowMultipleFailures
        Display users with multiple failures (default: true).

    .PARAMETER ShowSingleFailures
        Display users with single failure then success (default: true).

    .PARAMETER ShowChronologicalFailures
        Display failed devices in chronological order (default: true).

    .PARAMETER MaxChronologicalDisplay
        Maximum number of chronological failures to display (default: 20).

    .PARAMETER ShowDetailedFailures
        Show detailed failure table at the end (default: true).

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token
        Show-AutopilotEventAnalysis -AnalysisData $analysis

    .EXAMPLE
        $analysis | Show-AutopilotEventAnalysis -ShowChronologicalFailures:$false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$AnalysisData,
        [Parameter()]
        [switch]$ShowSummary = $true,
        [Parameter()]
        [switch]$ShowMultipleFailures = $true,
        [Parameter()]
        [switch]$ShowSingleFailures = $true,
        [Parameter()]
        [switch]$ShowChronologicalFailures = $true,
        [Parameter()]
        [int]$MaxChronologicalDisplay = 20,
        [Parameter()]
        [switch]$ShowDetailedFailures = $true
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message \"Starting display of autopilot event analysis\" -LogLevel \"Verbose\"

    if ($AnalysisData.TotalEvents -eq 0)
    {
        Write-Host \"`nNo autopilot events found in the specified date range.\" -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $functionName -Message \"No events to display (TotalEvents = 0)\" -LogLevel \"Information\"
        return
    }

    Write-Log -LogFile $LogFile -Module $functionName -Message \"Displaying analysis for $($AnalysisData.TotalEvents) events (Success: $($AnalysisData.SuccessCount), Failed: $($AnalysisData.FailureCount))\" -LogLevel \"Information\"

    Write-Host \"`nAutopilot Events Analysis\" -ForegroundColor Cyan
    Write-Host (\"=\" * 60) -ForegroundColor Cyan

    # Summary Section
    if ($ShowSummary)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message \"Displaying summary section\" -LogLevel \"Verbose\"
        if ($AnalysisData.StartDate -or $AnalysisData.EndDate)
        {
            Write-Host "`nDate Range Filter:" -ForegroundColor Cyan
            if ($AnalysisData.StartDate)
            {
                Write-Host "  Start: $($AnalysisData.StartDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
            }
            if ($AnalysisData.EndDate)
            {
                Write-Host "  End: $($AnalysisData.EndDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
            }
            Write-Host "  Filtered: $($AnalysisData.TotalEvents) of $($AnalysisData.TotalEventsBeforeFilter) events" -ForegroundColor Gray
        }

        Write-Host "`n1. Earliest Event Date: " -NoNewline
        if ($AnalysisData.EarliestEventDate)
        {
            Write-Host $AnalysisData.EarliestEventDate.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Green
        }
        else
        {
            Write-Host "N/A" -ForegroundColor Yellow
        }

        Write-Host "`n2. Total Number of Events: " -NoNewline
        Write-Host $AnalysisData.TotalEvents -ForegroundColor Green

        Write-Host "`n3. Successful Events: " -NoNewline
        Write-Host $AnalysisData.SuccessCount -ForegroundColor Green

        Write-Host "`n4. Failed Events: " -NoNewline
        Write-Host $AnalysisData.FailureCount -ForegroundColor $(if ($AnalysisData.FailureCount -gt 0)
            {
                "Red"
            }
            else
            {
                "Green"
            })

        Write-Host "`n5. Average Duration (Successful): " -NoNewline
        if ($AnalysisData.AverageSuccessDuration)
        {
            Write-Host ("{0:hh\:mm\:ss}" -f $AnalysisData.AverageSuccessDuration) -ForegroundColor Green
        }
        else
        {
            Write-Host "N/A (no successful deployments with duration data)" -ForegroundColor Yellow
        }

        Write-Host "`n6. Average Duration (Failed): " -NoNewline
        if ($AnalysisData.AverageFailureDuration)
        {
            Write-Host ("{0:hh\:mm\:ss}" -f $AnalysisData.AverageFailureDuration) -ForegroundColor Red
        }
        else
        {
            Write-Host "N/A (no failed deployments with duration data)" -ForegroundColor Yellow
        }

        Write-Host "`n7. Failure Breakdown:" -ForegroundColor Cyan
        Write-Host "   - Device Phase Failures: " -NoNewline
        Write-Host $AnalysisData.DevicePhaseFailureCount -ForegroundColor $(if ($AnalysisData.DevicePhaseFailureCount -gt 0)
            {
                "Red"
            }
            else
            {
                "Green"
            })
        Write-Host "   - User Phase Failures: " -NoNewline
        Write-Host $AnalysisData.UserPhaseFailureCount -ForegroundColor $(if ($AnalysisData.UserPhaseFailureCount -gt 0)
            {
                "Red"
            }
            else
            {
                "Green"
            })
    }

    # Users with multiple failures
    if ($ShowMultipleFailures)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message \"Displaying users with multiple failures section ($($AnalysisData.UsersWithMultipleFailures.Count) users)\" -LogLevel \"Verbose\" Write-Host "`n8. Users with Multiple Enrollment Failures:" -ForegroundColor Cyan
        if ($AnalysisData.UsersWithMultipleFailures.Count -gt 0)
        {
            Write-Host "   Found $($AnalysisData.UsersWithMultipleFailures.Count) user(s) with multiple failures:" -ForegroundColor Yellow
            foreach ($user in $AnalysisData.UsersWithMultipleFailures)
            {
                Write-Host "`n   User: " -NoNewline -ForegroundColor White
                Write-Host $user.UserPrincipalName -ForegroundColor Red
                Write-Host "   Failure Count: " -NoNewline -ForegroundColor White
                Write-Host $user.FailureCount -ForegroundColor Red

                Write-Host "   Devices:" -ForegroundColor White
                foreach ($device in $user.FailedDevices)
                {
                    $eventDate = if ($device.eventDateTime)
                    {
                        ([DateTime]$device.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    else
                    {
                        "N/A"
                    }
                    Write-Host "      - Serial: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($device.deviceSerialNumber)" -NoNewline -ForegroundColor Yellow
                    Write-Host " | Device: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($device.managedDeviceName)" -NoNewline -ForegroundColor Yellow
                    Write-Host " | Date: " -NoNewline -ForegroundColor Gray
                    Write-Host "$eventDate" -ForegroundColor Yellow
                }

                if ($user.EventualSuccess)
                {
                    $successDate = ([DateTime]$user.SuccessDevice.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                    Write-Host "`n   [SUCCESS AFTER FAILURES]" -ForegroundColor Green
                    Write-Host "   User had $($user.FailureCount) failed enrollment(s) before successful enrollment" -ForegroundColor Green
                    Write-Host "   Successful Device: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($user.SuccessDevice.managedDeviceName)" -NoNewline -ForegroundColor Green
                    Write-Host " | Serial: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($user.SuccessDevice.deviceSerialNumber)" -ForegroundColor Green
                    Write-Host "   Success Date: " -NoNewline -ForegroundColor Gray
                    Write-Host "$successDate" -ForegroundColor Green
                }
                else
                {
                    Write-Host "`n   [NO SUCCESSFUL ENROLLMENT FOUND]" -ForegroundColor Red
                    Write-Host "   User has not yet completed a successful enrollment in the analyzed period" -ForegroundColor Yellow
                }
            }
        }
        else
        {
            Write-Host "   No users with multiple failures." -ForegroundColor Green
        }
    }

    # Single failure with success
    if ($ShowSingleFailures)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message \"Displaying single failure with success section ($($AnalysisData.SingleFailureWithSuccess.Count) users)\" -LogLevel \"Verbose\" Write-Host "`n8b. Users with Failed Then Successful Enrollments (Single Failure):" -ForegroundColor Cyan
        if ($AnalysisData.SingleFailureWithSuccess.Count -gt 0)
        {
            Write-Host "   Found $($AnalysisData.SingleFailureWithSuccess.Count) user(s) with 1 failure followed by success:" -ForegroundColor Yellow
            foreach ($user in $AnalysisData.SingleFailureWithSuccess)
            {
                $failDate = if ($user.FailureDate)
                {
                    ([DateTime]$user.FailureDate).ToString("yyyy-MM-dd HH:mm:ss")
                }
                else
                {
                    "Unknown"
                }
                $succDate = if ($user.SuccessDate)
                {
                    ([DateTime]$user.SuccessDate).ToString("yyyy-MM-dd HH:mm:ss")
                }
                else
                {
                    "Unknown"
                }

                Write-Host "`n   User: " -NoNewline -ForegroundColor White
                Write-Host $user.UserPrincipalName -ForegroundColor Yellow
                Write-Host "   Had 1 failed enrollment before successful enrollment" -ForegroundColor Green
                Write-Host "   Failed Device: " -NoNewline -ForegroundColor Gray
                Write-Host "$($user.FailureDevice.deviceSerialNumber)" -NoNewline -ForegroundColor Red
                Write-Host " on $failDate" -ForegroundColor Gray
                Write-Host "   Success Device: " -NoNewline -ForegroundColor Gray
                Write-Host "$($user.SuccessDevice.deviceSerialNumber)" -NoNewline -ForegroundColor Green
                Write-Host " on $succDate" -ForegroundColor Gray
            }
        }
        else
        {
            Write-Host "   No users with single failure followed by success." -ForegroundColor Green
        }
    }

    # Chronological failures
    if ($ShowChronologicalFailures)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message \"Displaying chronological failures section ($($AnalysisData.FailedDevicesChronological.Count) devices, max display: $MaxChronologicalDisplay)\" -LogLevel \"Verbose\" Write-Host "`n9. Failed Devices (Chronological Order):" -ForegroundColor Cyan
        if ($AnalysisData.FailedDevicesChronological.Count -gt 0)
        {
            Write-Host "   Total failed devices: " -NoNewline
            Write-Host $AnalysisData.FailedDevicesChronological.Count -ForegroundColor Red
            Write-Host "`n   Failures from oldest to newest:" -ForegroundColor Yellow

            $counter = 1
            foreach ($failure in $AnalysisData.FailedDevicesChronological)
            {
                $eventDate = if ($failure.eventDateTime)
                {
                    ([DateTime]$failure.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                }
                else
                {
                    "Unknown Date"
                }

                Write-Host "`n   [$counter] " -NoNewline -ForegroundColor White
                Write-Host "Serial Number: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.deviceSerialNumber)" -ForegroundColor Yellow

                Write-Host "       Device Name: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.managedDeviceName)" -ForegroundColor Yellow

                Write-Host "       User: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.userPrincipalName)" -ForegroundColor Yellow

                Write-Host "       Date/Time: " -NoNewline -ForegroundColor Gray
                Write-Host "$eventDate" -ForegroundColor Yellow

                Write-Host "       Deployment State: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.deploymentState)" -ForegroundColor Red

                Write-Host "       Device Setup: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.deviceSetupStatus)" -ForegroundColor $(if ($failure.deviceSetupStatus -eq 'success')
                    {
                        "Green"
                    }
                    else
                    {
                        "Red"
                    })

                Write-Host "       Account Setup: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.accountSetupStatus)" -ForegroundColor $(if ($failure.accountSetupStatus -eq 'success')
                    {
                        "Green"
                    }
                    else
                    {
                        "Red"
                    })

                if (-not [string]::IsNullOrWhiteSpace($failure.enrollmentFailureDetails))
                {
                    Write-Host "       Failure Details: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($failure.enrollmentFailureDetails)" -ForegroundColor Red
                }

                $counter++

                if ($counter -gt $MaxChronologicalDisplay -and $AnalysisData.FailedDevicesChronological.Count -gt $MaxChronologicalDisplay)
                {
                    Write-Host "`n   ... and $($AnalysisData.FailedDevicesChronological.Count - $MaxChronologicalDisplay) more failures." -ForegroundColor Yellow
                    Write-Host "   Use Export-AutopilotEventAnalysis for full details." -ForegroundColor Yellow
                    break
                }
            }
        }
        else
        {
            Write-Host "   No failed devices in the selected time period." -ForegroundColor Green
        }
    }

    # Detailed failure table
    if ($ShowDetailedFailures -and $AnalysisData.FailureCount -gt 0)
    {
        Write-Host "`n" -NoNewline
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host "`nDetailed Failure Summary Table:" -ForegroundColor Yellow
        $AnalysisData.FailedEvents |
            Select-Object -First 5 deviceSerialNumber, managedDeviceName, deploymentState, deviceSetupStatus, accountSetupStatus, enrollmentFailureDetails |
            Format-Table -AutoSize

        if ($AnalysisData.FailureCount -gt 5)
        {
            Write-Host "... and $($AnalysisData.FailureCount - 5) more failures." -ForegroundColor Yellow
        }
    }

    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Cyan

    Write-Log -LogFile $LogFile -Module $functionName -Message "Autopilot event analysis display completed" -LogLevel "Information"
}
