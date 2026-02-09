function Show-AutopilotEventAnalysis()
{
    <#
    .SYNOPSIS
        Displays autopilot event analysis results.

    .DESCRIPTION
        Formats and displays the analyzed autopilot event data with customizable sections.
        Uses paging for large result sets and timezone-aware date formatting.

        Dependencies:
        - Show-PagedContent: For paged display of multi-item sections
        - FormatDateWithTimeZone: For timezone-aware date/time formatting

    .PARAMETER AnalysisData
        The analysis data object returned from Get-AutopilotEventAnalysis.

    .PARAMETER ShowSummary
        Display summary statistics.

    .PARAMETER ShowMultipleFailures
        Display users with multiple failures.
        Uses paging with 5 items per page.

    .PARAMETER ShowSingleFailures
        Display users with single failure then success.
        Uses paging with 5 items per page.

    .PARAMETER ShowChronologicalFailures
        Display failed devices in chronological order.
        Uses paging with 5 items per page.

    .PARAMETER ShowInProgress
        Display devices currently in progress and which phase they are in.
        Uses paging with 5 items per page.

    .PARAMETER ShowLocationAnalysis
        Display location-based analysis from sign-in data showing success/failure rates by location.
        Uses paging with 5   items per page.

    .PARAMETER MaxChronologicalDisplay
        DEPRECATED: No longer used due to paging implementation.
        Previously limited chronological failures to display (default: 20).

    .PARAMETER ShowDetailedFailures
        Show detailed failure table at the end.

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token
        Show-AutopilotEventAnalysis -AnalysisData $analysis

    .EXAMPLE
        $analysis | Show-AutopilotEventAnalysis -ShowChronologicalFailures:$false

    .NOTES
        All dates are displayed in local timezone with timezone abbreviation.
        Large result sets use interactive paging (n/p/q for navigation).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$AnalysisData,
        [Parameter()]
        [switch]$ShowSummary,
        [Parameter()]
        [switch]$ShowMultipleFailures,
        [Parameter()]
        [switch]$ShowSingleFailures,
        [Parameter()]
        [switch]$ShowChronologicalFailures,
        [Parameter()]
        [switch]$ShowInProgress,
        [Parameter()]
        [switch]$ShowLocationAnalysis,
        [Parameter()]
        [int]$MaxChronologicalDisplay = 20,
        [Parameter()]
        [switch]$ShowDetailedFailures
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting display of autopilot event analysis" -LogLevel "Verbose"

    if ($AnalysisData.TotalEvents -eq 0)
    {
        Write-Host "`nNo autopilot events found in the specified date range." -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $functionName -Message "No events to display (TotalEvents = 0)" -LogLevel "Information"
        return
    }

    Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying analysis for $($AnalysisData.TotalEvents) events (Success: $($AnalysisData.SuccessCount), Failed: $($AnalysisData.FailureCount))" -LogLevel "Information"

    Write-Host "`nAutopilot Enrollment Report" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan

    # Summary Section
    if ($ShowSummary)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying summary section" -LogLevel "Verbose"
        if ($AnalysisData.StartDate -or $AnalysisData.EndDate -or $AnalysisData.UserPrincipalName)
        {
            Write-Host "`nApplied Filters:" -ForegroundColor Cyan
            if ($AnalysisData.StartDate)
            {
                Write-Host "  Start Date: $(FormatDateWithTimeZone -DateTime $AnalysisData.StartDate)" -ForegroundColor Gray
            }
            if ($AnalysisData.EndDate)
            {
                Write-Host "  End Date: $(FormatDateWithTimeZone -DateTime $AnalysisData.EndDate)" -ForegroundColor Gray
            }
            if ($AnalysisData.UserPrincipalName)
            {
                Write-Host "  User: $($AnalysisData.UserPrincipalName)" -ForegroundColor Gray
            }
            Write-Host "  Filtered: $($AnalysisData.TotalEvents) of $($AnalysisData.TotalEventsBeforeFilter) events" -ForegroundColor Gray
        }

        Write-Host "`n1. Earliest Event Date: " -NoNewline
        if ($AnalysisData.EarliestEventDate)
        {
            $formattedDate = FormatDateWithTimeZone -DateTime $AnalysisData.EarliestEventDate
            Write-Host $formattedDate -ForegroundColor Green
        }
        else
        {
            Write-Host "N/A" -ForegroundColor Yellow
        }

        Write-Host "`n2. Total Number of Events: " -NoNewline
        Write-Host $AnalysisData.TotalEvents -ForegroundColor Green

        Write-Host "`n3. Successful Events: " -NoNewline
        Write-Host $AnalysisData.SuccessCount -ForegroundColor Green

        Write-Host "`n4. In-Progress Events: " -NoNewline
        Write-Host $AnalysisData.InProgressCount -ForegroundColor $(if ($AnalysisData.InProgressCount -gt 0)
            {
                "Cyan"
            }
            else
            {
                "Green"
            })

        if ($AnalysisData.InProgressCount -gt 0)
        {
            Write-Host "   - Device Phase: " -NoNewline -ForegroundColor Gray
            Write-Host $AnalysisData.DevicePhaseInProgressCount -ForegroundColor Cyan
            Write-Host "   - User/Account Phase: " -NoNewline -ForegroundColor Gray
            Write-Host $AnalysisData.UserPhaseInProgressCount -ForegroundColor Cyan
        }

        Write-Host "`n5. Failed Events: " -NoNewline
        Write-Host $AnalysisData.FailureCount -ForegroundColor $(if ($AnalysisData.FailureCount -gt 0)
            {
                "Red"
            }
            else
            {
                "Green"
            })

        Write-Host "`n6. Average Duration (Successful): " -NoNewline
        if ($AnalysisData.AverageSuccessDuration)
        {
            Write-Host ("{0:hh\:mm\:ss}" -f $AnalysisData.AverageSuccessDuration) -ForegroundColor Green
        }
        else
        {
            Write-Host "N/A (no successful deployments with duration data)" -ForegroundColor Yellow
        }

        Write-Host "`n7. Average Duration (Failed): " -NoNewline
        if ($AnalysisData.AverageFailureDuration)
        {
            Write-Host ("{0:hh\:mm\:ss}" -f $AnalysisData.AverageFailureDuration) -ForegroundColor Red
        }
        else
        {
            Write-Host "N/A (no failed deployments with duration data)" -ForegroundColor Yellow
        }

        Write-Host "`n8. Failure Breakdown (Mutually Exclusive):" -ForegroundColor Cyan
        Write-Host "   - Device Phase Only: " -NoNewline
        Write-Host $AnalysisData.DevicePhaseOnlyFailureCount -NoNewline -ForegroundColor $(if ($AnalysisData.DevicePhaseOnlyFailureCount -gt 0)
            {
                "Red"
            }
            else
            {
                "Green"
            })
        Write-Host " (device setup failed, account not started or succeeded)" -ForegroundColor Gray

        Write-Host "   - User/Account Phase Only: " -NoNewline
        Write-Host $AnalysisData.UserPhaseOnlyFailureCount -NoNewline -ForegroundColor $(if ($AnalysisData.UserPhaseOnlyFailureCount -gt 0)
            {
                "Red"
            }
            else
            {
                "Green"
            })
        Write-Host " (device setup succeeded, account setup failed)" -ForegroundColor Gray

        Write-Host "   - Both Phases Failed: " -NoNewline
        Write-Host $AnalysisData.BothPhasesFailureCount -NoNewline -ForegroundColor $(if ($AnalysisData.BothPhasesFailureCount -gt 0)
            {
                "Red"
            }
            else
            {
                "Green"
            })
        Write-Host " (both device and account setup failed)" -ForegroundColor Gray

        if ($AnalysisData.UnknownPhaseFailureCount -gt 0)
        {
            Write-Host "   - Unknown/Other: " -NoNewline
            Write-Host $AnalysisData.UnknownPhaseFailureCount -NoNewline -ForegroundColor Yellow
            Write-Host " (failure stage unclear)" -ForegroundColor Gray
        }

        # Display sign-in match statistics if available
        if ($AnalysisData.SignInMatchStats -and $AnalysisData.SignInMatchStats.TotalEvents -gt 0)
        {
            Write-Host "`n9. Sign-In Match Statistics:" -ForegroundColor Cyan
            Write-Host "   Total Events: " -NoNewline
            Write-Host "$($AnalysisData.SignInMatchStats.TotalEvents)" -ForegroundColor White
            Write-Host "   Matched Events: " -NoNewline
            Write-Host "$($AnalysisData.SignInMatchStats.MatchedEvents)" -ForegroundColor Green

            if ($AnalysisData.SignInMatchStats.HighConfidence -and $AnalysisData.SignInMatchStats.HighConfidence -gt 0)
            {
                Write-Host "   High Confidence: " -NoNewline
                Write-Host "$($AnalysisData.SignInMatchStats.HighConfidence)" -ForegroundColor Green
            }
            if ($AnalysisData.SignInMatchStats.MediumConfidence -and $AnalysisData.SignInMatchStats.MediumConfidence -gt 0)
            {
                Write-Host "   Medium Confidence: " -NoNewline
                Write-Host "$($AnalysisData.SignInMatchStats.MediumConfidence)" -ForegroundColor Yellow
            }
            if ($AnalysisData.SignInMatchStats.LowConfidence -and $AnalysisData.SignInMatchStats.LowConfidence -gt 0)
            {
                Write-Host "   Low Confidence: " -NoNewline
                Write-Host "$($AnalysisData.SignInMatchStats.LowConfidence)" -ForegroundColor Red
            }
        }

        # Pause after summary to allow user to review before showing detailed sections
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor Cyan
        $null = Read-Host -Prompt "Press Enter to continue to detailed results..."
    }

    # In-progress devices
    if ($ShowInProgress)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying in-progress devices section ($($AnalysisData.InProgressCount) devices)" -LogLevel "Verbose"
        Write-Host "`n9. Devices Currently In Progress:" -ForegroundColor Cyan
        if ($AnalysisData.InProgressCount -gt 0)
        {
            Write-Host "   Total in-progress devices: " -NoNewline
            Write-Host $AnalysisData.InProgressCount -ForegroundColor Cyan
            Write-Host ""

            # Use paged display for in-progress devices
            $displayScript = {
                param($device)
                $eventDate = if ($device.eventDateTime)
                {
                    FormatDateWithTimeZone -DateTime $device.eventDateTime
                }
                else
                {
                    "Unknown Date"
                }

                Write-Host "   Serial Number: " -NoNewline -ForegroundColor Gray
                Write-Host "$($device.deviceSerialNumber)" -ForegroundColor Cyan

                Write-Host "   Device Name: " -NoNewline -ForegroundColor Gray
                Write-Host "$($device.managedDeviceName)" -ForegroundColor Cyan

                Write-Host "   User: " -NoNewline -ForegroundColor Gray
                Write-Host "$($device.userPrincipalName)" -ForegroundColor Cyan

                Write-Host "   Date/Time: " -NoNewline -ForegroundColor Gray
                Write-Host "$eventDate" -ForegroundColor Cyan

                Write-Host "   Deployment State: " -NoNewline -ForegroundColor Gray
                Write-Host "$($device.deploymentState)" -ForegroundColor Cyan

                Write-Host "   Device Setup: " -NoNewline -ForegroundColor Gray
                $deviceColor = switch ($device.deviceSetupStatus)
                {
                    'inProgress'
                    {
                        'Cyan'
                    }
                    'success'
                    {
                        'Green'
                    }
                    default
                    {
                        'Yellow'
                    }
                }
                Write-Host "$($device.deviceSetupStatus)" -ForegroundColor $deviceColor

                Write-Host "   Account Setup: " -NoNewline -ForegroundColor Gray
                $accountColor = switch ($device.accountSetupStatus)
                {
                    'inProgress'
                    {
                        'Cyan'
                    }
                    'success'
                    {
                        'Green'
                    }
                    default
                    {
                        'Yellow'
                    }
                }
                Write-Host "$($device.accountSetupStatus)" -ForegroundColor $accountColor

                # Display location and IP if available from sign-in matching
                if ($device.SignIn_Location_City -or $device.SignIn_Location_State -or $device.SignIn_Location_Country)
                {
                    $location = @($device.SignIn_Location_City, $device.SignIn_Location_State, $device.SignIn_Location_Country) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
                    Write-Host "   Location: " -NoNewline -ForegroundColor Gray
                    Write-Host ($location -join ", ") -ForegroundColor Cyan
                }
                if ($device.SignIn_IPAddress)
                {
                    Write-Host "   IP Address: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($device.SignIn_IPAddress)" -ForegroundColor Cyan
                }

                # Indicate which phase is in progress
                if ($device.deviceSetupStatus -eq 'inProgress')
                {
                    Write-Host "   [DEVICE PHASE IN PROGRESS]" -ForegroundColor Cyan
                }
                elseif ($device.accountSetupStatus -eq 'inProgress')
                {
                    Write-Host "   [USER/ACCOUNT PHASE IN PROGRESS]" -ForegroundColor Cyan
                }
                Write-Host ""
            }

            Show-PagedContent -Content $AnalysisData.InProgressEvents -DisplayScriptBlock $displayScript -PageSize 2 -Title "Devices In Progress" -ShowPageInfo $true
        }
        else
        {
            Write-Host "   No devices currently in progress." -ForegroundColor Green
        }
    }

    # Location-based analysis
    if ($ShowLocationAnalysis)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying location analysis section ($($AnalysisData.LocationAnalysis.Count) locations)" -LogLevel "Verbose"
        Write-Host "`n9b. Sign-In Enrollment Analysis by Location:" -ForegroundColor Cyan
        if ($AnalysisData.LocationAnalysis -and $AnalysisData.LocationAnalysis.Count -gt 0)
        {
            Write-Host "   Found enrollment activity in $($AnalysisData.LocationAnalysis.Count) location(s):" -ForegroundColor Yellow
            Write-Host ""

            # Use paged display for location analysis
            $displayScript = {
                param($location)

                # Format location display
                $locationDisplay = if ([string]::IsNullOrWhiteSpace($location.Location))
                {
                    "Unknown Location"
                }
                else
                {
                    $location.Location
                }

                Write-Host "   Location: " -NoNewline -ForegroundColor White
                Write-Host $locationDisplay -ForegroundColor Cyan

                Write-Host "   Total Events: " -NoNewline -ForegroundColor Gray
                Write-Host $location.TotalEvents -ForegroundColor White

                # Show breakdown by outcome
                if ($location.SuccessfulEvents -gt 0)
                {
                    Write-Host "      Successful: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($location.SuccessfulEvents)" -NoNewline -ForegroundColor Green
                    Write-Host " ($($location.SuccessRate)%)" -ForegroundColor Green
                }

                if ($location.FailedEvents -gt 0)
                {
                    Write-Host "      Failed: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($location.FailedEvents)" -NoNewline -ForegroundColor Red
                    Write-Host " ($($location.FailureRate)%)" -ForegroundColor Red
                }

                if ($location.InProgressEvents -gt 0)
                {
                    Write-Host "      In Progress: " -NoNewline -ForegroundColor Gray
                    Write-Host $location.InProgressEvents -ForegroundColor Cyan
                }

                # Show unique users and devices
                Write-Host "   Unique Users: " -NoNewline -ForegroundColor Gray
                Write-Host $location.UniqueUsers -ForegroundColor Yellow
                Write-Host "   Unique Devices: " -NoNewline -ForegroundColor Gray
                Write-Host $location.UniqueDevices -ForegroundColor Yellow

                # Show detailed location info if available
                if (-not [string]::IsNullOrWhiteSpace($location.City) -or
                    -not [string]::IsNullOrWhiteSpace($location.State) -or
                    -not [string]::IsNullOrWhiteSpace($location.Country))
                {
                    Write-Host "   Details: " -NoNewline -ForegroundColor Gray
                    $detailParts = @()
                    if (-not [string]::IsNullOrWhiteSpace($location.City))
                    {
                        $detailParts += $location.City
                    }
                    if (-not [string]::IsNullOrWhiteSpace($location.State))
                    {
                        $detailParts += $location.State
                    }
                    if (-not [string]::IsNullOrWhiteSpace($location.Country))
                    {
                        $detailParts += $location.Country
                    }
                    Write-Host ($detailParts -join ", ") -ForegroundColor Cyan
                }

                # Show users and their devices for this location
                if ($location.Events -and $location.Events.Count -gt 0)
                {
                    Write-Host "`n   Users and Devices:" -ForegroundColor Cyan

                    # Group events by user
                    $eventsByUser = $location.Events | Group-Object -Property userPrincipalName

                    foreach ($userGroup in $eventsByUser)
                    {
                        $userName = if ([string]::IsNullOrWhiteSpace($userGroup.Name))
                        {
                            "Unknown User"
                        }
                        else
                        {
                            $userGroup.Name
                        }

                        Write-Host "      User: " -NoNewline -ForegroundColor Gray
                        Write-Host $userName -ForegroundColor White

                        # Show each device for this user
                        foreach ($evt in $userGroup.Group)
                        {
                            $deviceName = if ([string]::IsNullOrWhiteSpace($evt.managedDeviceName))
                            {
                                "Unknown"
                            }
                            else
                            {
                                $evt.managedDeviceName
                            }

                            $serialNumber = if ([string]::IsNullOrWhiteSpace($evt.deviceSerialNumber))
                            {
                                "Unknown"
                            }
                            else
                            {
                                $evt.deviceSerialNumber
                            }

                            # Color code by deployment state
                            $statusColor = switch ($evt.deploymentState)
                            {
                                'success'
                                {
                                    "Green"
                                }
                                'inProgress'
                                {
                                    "Cyan"
                                }
                                default
                                {
                                    "Red"
                                }
                            }

                            Write-Host "         - Device: " -NoNewline -ForegroundColor Gray
                            Write-Host $deviceName -NoNewline -ForegroundColor White
                            Write-Host " | Serial: " -NoNewline -ForegroundColor Gray
                            Write-Host $serialNumber -NoNewline -ForegroundColor White
                            Write-Host " | Status: " -NoNewline -ForegroundColor Gray
                            Write-Host $evt.deploymentState -ForegroundColor $statusColor
                        }
                    }
                }

                Write-Host ""
            }

            Show-PagedContent -Content $AnalysisData.LocationAnalysis -DisplayScriptBlock $displayScript -PageSize 5 -Title "Enrollment Activity by Location" -ShowPageInfo $true
        }
        else
        {
            Write-Host "   No location data available from sign-in logs." -ForegroundColor Yellow
            Write-Host "   Location information comes from matched sign-in events." -ForegroundColor Gray
        }
    }

    # Users with multiple failures
    if ($ShowMultipleFailures)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying users with multiple failures section ($($AnalysisData.UsersWithMultipleFailures.Count) users)" -LogLevel "Verbose"
        Write-Host "`n10. Users with Multiple Enrollment Failures:" -ForegroundColor Cyan
        if ($AnalysisData.UsersWithMultipleFailures.Count -gt 0)
        {
            Write-Host "   Found $($AnalysisData.UsersWithMultipleFailures.Count) user(s) with multiple failures:" -ForegroundColor Yellow
            Write-Host ""

            # Use paged display for multiple failure users
            $displayScript = {
                param($user)
                Write-Host "   User: " -NoNewline -ForegroundColor White
                Write-Host $user.UserPrincipalName -ForegroundColor Red
                Write-Host "   Failure Count: " -NoNewline -ForegroundColor White
                Write-Host $user.FailureCount -ForegroundColor Red

                Write-Host "   Devices:" -ForegroundColor White
                foreach ($device in $user.FailedDevices)
                {
                    $eventDate = if ($device.eventDateTime)
                    {
                        FormatDateWithTimeZone -DateTime $device.eventDateTime
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

                    # Display location and IP if available
                    if ($device.SignIn_Location_City -or $device.SignIn_Location_State -or $device.SignIn_Location_Country)
                    {
                        $location = @($device.SignIn_Location_City, $device.SignIn_Location_State, $device.SignIn_Location_Country) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
                        Write-Host "        Location: " -NoNewline -ForegroundColor Gray
                        Write-Host ($location -join ", ") -ForegroundColor Yellow
                    }
                    if ($device.SignIn_IPAddress)
                    {
                        Write-Host "        IP: " -NoNewline -ForegroundColor Gray
                        Write-Host "$($device.SignIn_IPAddress)" -ForegroundColor Yellow
                    }
                }

                if ($user.EventualSuccess)
                {
                    $successDate = FormatDateWithTimeZone -DateTime $user.SuccessDevice.eventDateTime
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
                Write-Host ""
            }

            Show-PagedContent -Content $AnalysisData.UsersWithMultipleFailures -DisplayScriptBlock $displayScript -PageSize 3 -Title "Users with Multiple Enrollment Failures" -ShowPageInfo $true
        }
        else
        {
            Write-Host "   No users with multiple failures." -ForegroundColor Green
        }
    }

    # Single failure with success
    if ($ShowSingleFailures)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying single failure with success section ($($AnalysisData.SingleFailureWithSuccess.Count) users)" -LogLevel "Verbose"
        Write-Host "`n10b. Users with Failed Then Successful Enrollments (Single Failure):" -ForegroundColor Cyan
        if ($AnalysisData.SingleFailureWithSuccess.Count -gt 0)
        {
            Write-Host "   Found $($AnalysisData.SingleFailureWithSuccess.Count) user(s) with 1 failure followed by success:" -ForegroundColor Yellow
            Write-Host ""

            # Use paged display for single failure users
            $displayScript = {
                param($user)
                $failDate = if ($user.FailureDate)
                {
                    FormatDateWithTimeZone -DateTime $user.FailureDate
                }
                else
                {
                    "Unknown"
                }
                $succDate = if ($user.SuccessDate)
                {
                    FormatDateWithTimeZone -DateTime $user.SuccessDate
                }
                else
                {
                    "Unknown"
                }

                Write-Host "   User: " -NoNewline -ForegroundColor White
                Write-Host $user.UserPrincipalName -ForegroundColor Yellow
                Write-Host "   Had 1 failed enrollment before successful enrollment" -ForegroundColor Green
                Write-Host "   Failed Device: " -NoNewline -ForegroundColor Gray
                Write-Host "$($user.FailureDevice.deviceSerialNumber)" -NoNewline -ForegroundColor Red
                Write-Host " on $failDate" -ForegroundColor Gray

                # Display location and IP for failed device if available
                if ($user.FailureDevice.SignIn_Location_City -or $user.FailureDevice.SignIn_Location_State -or $user.FailureDevice.SignIn_Location_Country)
                {
                    $location = @($user.FailureDevice.SignIn_Location_City, $user.FailureDevice.SignIn_Location_State, $user.FailureDevice.SignIn_Location_Country) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
                    Write-Host "      Location: " -NoNewline -ForegroundColor Gray
                    Write-Host ($location -join ", ") -ForegroundColor Yellow
                }
                if ($user.FailureDevice.SignIn_IPAddress)
                {
                    Write-Host "      IP: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($user.FailureDevice.SignIn_IPAddress)" -ForegroundColor Yellow
                }

                Write-Host "   Success Device: " -NoNewline -ForegroundColor Gray
                Write-Host "$($user.SuccessDevice.deviceSerialNumber)" -NoNewline -ForegroundColor Green
                Write-Host " on $succDate" -ForegroundColor Gray

                # Display location and IP for success device if available
                if ($user.SuccessDevice.SignIn_Location_City -or $user.SuccessDevice.SignIn_Location_State -or $user.SuccessDevice.SignIn_Location_Country)
                {
                    $location = @($user.SuccessDevice.SignIn_Location_City, $user.SuccessDevice.SignIn_Location_State, $user.SuccessDevice.SignIn_Location_Country) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
                    Write-Host "      Location: " -NoNewline -ForegroundColor Gray
                    Write-Host ($location -join ", ") -ForegroundColor Yellow
                }
                if ($user.SuccessDevice.SignIn_IPAddress)
                {
                    Write-Host "      IP: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($user.SuccessDevice.SignIn_IPAddress)" -ForegroundColor Yellow
                }
                Write-Host ""
            }

            Show-PagedContent -Content $AnalysisData.SingleFailureWithSuccess -DisplayScriptBlock $displayScript -PageSize 3 -Title "Users with Single Failure Then Success" -ShowPageInfo $true
        }
        else
        {
            Write-Host "   No users with single failure followed by success." -ForegroundColor Green
        }
    }

    # Chronological failures
    if ($ShowChronologicalFailures)
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Displaying chronological failures section ($($AnalysisData.FailedDevicesChronological.Count) devices, max display: $MaxChronologicalDisplay)" -LogLevel "Verbose"
        Write-Host "`n11. Failed Devices (Chronological Order):" -ForegroundColor Cyan
        if ($AnalysisData.FailedDevicesChronological.Count -gt 0)
        {
            Write-Host "   Total failed devices: " -NoNewline
            Write-Host $AnalysisData.FailedDevicesChronological.Count -ForegroundColor Red
            Write-Host "`n   Failures from oldest to newest:" -ForegroundColor Yellow
            Write-Host ""

            # Use paged display for chronological failures
            $displayScript = {
                param($failure)
                $eventDate = if ($failure.eventDateTime)
                {
                    FormatDateWithTimeZone -DateTime $failure.eventDateTime
                }
                else
                {
                    "Unknown Date"
                }

                Write-Host "   Serial Number: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.deviceSerialNumber)" -ForegroundColor Yellow

                Write-Host "   Device Name: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.managedDeviceName)" -ForegroundColor Yellow

                Write-Host "   User: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.userPrincipalName)" -ForegroundColor Yellow

                Write-Host "   Date/Time: " -NoNewline -ForegroundColor Gray
                Write-Host "$eventDate" -ForegroundColor Yellow

                Write-Host "   Deployment State: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.deploymentState)" -ForegroundColor Red

                Write-Host "   Device Setup: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.deviceSetupStatus)" -ForegroundColor $(if ($failure.deviceSetupStatus -eq 'success')
                    {
                        "Green"
                    }
                    else
                    {
                        "Red"
                    })

                Write-Host "   Account Setup: " -NoNewline -ForegroundColor Gray
                Write-Host "$($failure.accountSetupStatus)" -ForegroundColor $(if ($failure.accountSetupStatus -eq 'success')
                    {
                        "Green"
                    }
                    else
                    {
                        "Red"
                    })

                # Display location and IP if available
                if ($failure.SignIn_Location_City -or $failure.SignIn_Location_State -or $failure.SignIn_Location_Country)
                {
                    $location = @($failure.SignIn_Location_City, $failure.SignIn_Location_State, $failure.SignIn_Location_Country) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
                    Write-Host "   Location: " -NoNewline -ForegroundColor Gray
                    Write-Host ($location -join ", ") -ForegroundColor Yellow
                }
                if ($failure.SignIn_IPAddress)
                {
                    Write-Host "   IP Address: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($failure.SignIn_IPAddress)" -ForegroundColor Yellow
                }

                if (-not [string]::IsNullOrWhiteSpace($failure.enrollmentFailureDetails))
                {
                    Write-Host "   Failure Details: " -NoNewline -ForegroundColor Gray
                    Write-Host "$($failure.enrollmentFailureDetails)" -ForegroundColor Red
                }
                Write-Host ""
            }

            Show-PagedContent -Content $AnalysisData.FailedDevicesChronological -DisplayScriptBlock $displayScript -PageSize 3 -Title "Failed Devices (Chronological)" -ShowPageInfo $true
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
            Format-Table -AutoSize |
            Out-Host

        if ($AnalysisData.FailureCount -gt 5)
        {
            Write-Host "... and $($AnalysisData.FailureCount - 5) more failures." -ForegroundColor Yellow
        }
    }

    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Cyan

    Write-Log -LogFile $LogFile -Module $functionName -Message "Autopilot event analysis display completed" -LogLevel "Information"
}
