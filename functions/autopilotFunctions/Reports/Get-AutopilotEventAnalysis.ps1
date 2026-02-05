function Get-AutopilotEventAnalysis()
{
    <#
    .SYNOPSIS
        Gathers and analyzes autopilot event data.

    .DESCRIPTION
        Retrieves autopilot events from Graph API and performs comprehensive analysis
        including success/failure counts, durations, user patterns, and device information.

    .PARAMETER Events
        Array of autopilot events to analyze. If not provided, will fetch from Graph API.

    .PARAMETER AccessToken
        Access token for Graph API calls (required if Events not provided).

    .PARAMETER StartDate
        Optional start date to filter events.

    .PARAMETER EndDate
        Optional end date to filter events.

    .PARAMETER UserPrincipalName
        Optional user principal name to filter events.

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token -StartDate "2025-01-01"

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token -UserPrincipalName "user@contoso.com"

    .OUTPUTS
        PSCustomObject with analyzed autopilot event data
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [array]$Events,
        [Parameter()]
        [string]$AccessToken,
        [Parameter()]
        [DateTime]$StartDate,
        [Parameter()]
        [DateTime]$EndDate,
        [Parameter()]
        [string]$UserPrincipalName
    )

    $functionName = $MyInvocation.MyCommand.Name
    $filterMsg = "Starting autopilot event analysis"
    if ($UserPrincipalName)
    {
        $filterMsg += " for user: $UserPrincipalName"
    }
    Write-Verbose "[$functionName] $filterMsg"
    Write-Log -LogFile $LogFile -Module $functionName -Message $filterMsg -LogLevel "Information"

    # Fetch events if not provided
    if (-not $Events)
    {
        if (-not $AccessToken)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "AccessToken is required when Events are not provided" -LogLevel "Error"
            throw "AccessToken is required when Events are not provided"
        }

        Write-Verbose "[$functionName] Fetching autopilot events from Graph API"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fetching autopilot events from Graph API" -LogLevel "Information"
        $autopilotEventsURI = "deviceManagement/autopilotEvents"
        $extraparameters = "top=999&count=true"
        $Events = (CallGraphAPI -ResourcePath $autopilotEventsURI -accessToken $AccessToken -consistencyLevel -extraParameters $extraparameters).value
        Write-Verbose "[$functionName] Retrieved $($Events.Count) events"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieved $($Events.Count) events from Graph API" -LogLevel "Information"
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using provided events array with $($Events.Count) events" -LogLevel "Verbose"
    }

    # Filter events by date range if specified
    $filteredEvents = $Events
    if ($StartDate -or $EndDate)
    {
        $dateRangeMsg = "Filtering events"
        if ($StartDate)
        {
            $dateRangeMsg += " from $($StartDate.ToString('yyyy-MM-dd'))"
        }
        if ($EndDate)
        {
            $dateRangeMsg += " to $($EndDate.ToString('yyyy-MM-dd'))"
        }
        Write-Log -LogFile $LogFile -Module $functionName -Message $dateRangeMsg -LogLevel "Information"

        $filteredEvents = $Events | Where-Object {
            $eventDate = $null
            try
            {
                $eventDate = [DateTime]$_.eventDateTime
            }
            catch
            {
                return $false
            }

            $afterStart = (-not $StartDate) -or ($eventDate -ge $StartDate)
            $beforeEnd = (-not $EndDate) -or ($eventDate -le $EndDate)

            return ($afterStart -and $beforeEnd)
        }
        Write-Verbose "[$functionName] Filtered to $($filteredEvents.Count) events from $($Events.Count) total"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered to $($filteredEvents.Count) events from $($Events.Count) total" -LogLevel "Information"
    }
    else
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "No date filtering applied, analyzing all $($Events.Count) events" -LogLevel "Verbose"
    }

    # Filter events by UserPrincipalName if specified
    if ($UserPrincipalName)
    {
        $beforeUserFilter = $filteredEvents.Count
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filtering events by UserPrincipalName: $UserPrincipalName" -LogLevel "Information"
        $filteredEvents = $filteredEvents | Where-Object {
            $_.userPrincipalName -eq $UserPrincipalName
        }
        Write-Verbose "[$functionName] Filtered to $($filteredEvents.Count) events from $beforeUserFilter for user $UserPrincipalName"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Filtered to $($filteredEvents.Count) events from $beforeUserFilter for user $UserPrincipalName" -LogLevel "Information"
    }

    # Helper function to convert ISO 8601 duration to TimeSpan
    function ConvertFrom-ISO8601Duration
    {
        param([string]$Duration)

        if ([string]::IsNullOrWhiteSpace($Duration))
        {
            return $null
        }

        try
        {
            return [System.Xml.XmlConvert]::ToTimeSpan($Duration)
        }
        catch
        {
            Write-Verbose "[$functionName] Failed to parse duration: $Duration"
            return $null
        }
    }

    # 1. Earliest event date
    $earliestEvent = $filteredEvents |
        Where-Object { $_.eventDateTime -and $null -ne $_.deploymentState } |
        Sort-Object eventDateTime |
        Select-Object -First 1

    $earliestDate = if ($earliestEvent)
    {
        [DateTime]$earliestEvent.eventDateTime
    }
    else
    {
        $null
    }

    # 2. Total number of events
    $totalEvents = $filteredEvents.Count

    # 3 & 4. Successful and failed events
    $successfulEvents = @($filteredEvents | Where-Object { $_.deploymentState -eq 'success' })
    $failedEvents = @($filteredEvents | Where-Object { $_.deploymentState -ne 'success' -and $null -ne $_.deploymentState })

    # 5. Average duration of successful deployments
    $successDurations = @($successfulEvents | ForEach-Object {
            $duration = ConvertFrom-ISO8601Duration -Duration $_.deploymentTotalDuration
            if ($duration)
            {
                $duration
            }
        })

    $avgSuccessDuration = if ($successDurations.Count -gt 0)
    {
        $totalTicks = ($successDurations | Measure-Object -Property Ticks -Sum).Sum
        New-Object TimeSpan($totalTicks / $successDurations.Count)
    }
    else
    {
        $null
    }

    # 6. Average duration of failed deployments
    $failureDurations = @($failedEvents | ForEach-Object {
            $duration = ConvertFrom-ISO8601Duration -Duration $_.deploymentTotalDuration
            if ($duration)
            {
                $duration
            }
        })

    $avgFailureDuration = if ($failureDurations.Count -gt 0)
    {
        $totalTicks = ($failureDurations | Measure-Object -Property Ticks -Sum).Sum
        New-Object TimeSpan($totalTicks / $failureDurations.Count)
    }
    else
    {
        $null
    }

    # 7. Categorize failures into mutually exclusive groups
    # Device phase only: Device failed, account not started or success
    $devicePhaseOnlyFailures = @($failedEvents | Where-Object {
            $deviceFailed = $_.deviceSetupStatus -and
            $_.deviceSetupStatus -ne 'success' -and
            $_.deviceSetupStatus -ne 'notStarted'
            $accountNotFailed = (-not $_.accountSetupStatus) -or
            $_.accountSetupStatus -eq 'success' -or
            $_.accountSetupStatus -eq 'notStarted'
            $deviceFailed -and $accountNotFailed
        })

    # User/Account phase only: Device succeeded, account failed
    $userPhaseOnlyFailures = @($failedEvents | Where-Object {
            $deviceSuccess = $_.deviceSetupStatus -eq 'success'
            $accountFailed = $_.accountSetupStatus -and
            $_.accountSetupStatus -ne 'success' -and
            $_.accountSetupStatus -ne 'notStarted'
            $deviceSuccess -and $accountFailed
        })

    # Both phases failed: Both device and account show failure
    $bothPhasesFailures = @($failedEvents | Where-Object {
            $deviceFailed = $_.deviceSetupStatus -and
            $_.deviceSetupStatus -ne 'success' -and
            $_.deviceSetupStatus -ne 'notStarted'
            $accountFailed = $_.accountSetupStatus -and
            $_.accountSetupStatus -ne 'success' -and
            $_.accountSetupStatus -ne 'notStarted'
            $deviceFailed -and $accountFailed
        })

    # Unknown/Other: Failures that don't clearly fall into above categories
    $unknownPhaseFailures = @($failedEvents | Where-Object {
            $deviceFailed = $_.deviceSetupStatus -and
            $_.deviceSetupStatus -ne 'success' -and
            $_.deviceSetupStatus -ne 'notStarted'
            $accountFailed = $_.accountSetupStatus -and
            $_.accountSetupStatus -ne 'success' -and
            $_.accountSetupStatus -ne 'notStarted'
            $deviceSuccess = $_.deviceSetupStatus -eq 'success'
            $accountNotFailed = (-not $_.accountSetupStatus) -or
            $_.accountSetupStatus -eq 'success' -or
            $_.accountSetupStatus -eq 'notStarted'

            # Not in any of the three categories above
            -not (($deviceFailed -and $accountNotFailed) -or
                ($deviceSuccess -and $accountFailed) -or
                ($deviceFailed -and $accountFailed))
        })

    # 8. Users with multiple enrollment failures
    $userFailureGroups = $failedEvents |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.userPrincipalName) } |
        Group-Object -Property userPrincipalName |
        Where-Object { $_.Count -gt 1 } |
        Sort-Object -Property Count -Descending

    $usersWithMultipleFailures = @()
    foreach ($userGroup in $userFailureGroups)
    {
        # Check for eventual success
        $userSuccesses = $successfulEvents |
            Where-Object { $_.userPrincipalName -eq $userGroup.Name } |
            Sort-Object eventDateTime

        $lastFailureDate = ($userGroup.Group | Sort-Object eventDateTime -Descending | Select-Object -First 1).eventDateTime

        $firstSuccessAfterFailures = $userSuccesses |
            Where-Object {
                if ($lastFailureDate)
                {
                    ([DateTime]$_.eventDateTime) -gt ([DateTime]$lastFailureDate)
                }
                else
                {
                    $true
                }
            } |
            Select-Object -First 1

        $usersWithMultipleFailures += [PSCustomObject]@{
            UserPrincipalName = $userGroup.Name
            FailureCount      = $userGroup.Count
            FailedDevices     = @($userGroup.Group | Sort-Object eventDateTime)
            EventualSuccess   = $null -ne $firstSuccessAfterFailures
            SuccessDevice     = $firstSuccessAfterFailures
            LastFailureDate   = $lastFailureDate
        }
    }

    # 8b. Users with single failure followed by success
    $singleFailureUsers = $failedEvents |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.userPrincipalName) } |
        Group-Object -Property userPrincipalName |
        Where-Object { $_.Count -eq 1 }

    $singleFailureWithSuccess = @()
    foreach ($userGroup in $singleFailureUsers)
    {
        $userSuccesses = $successfulEvents | Where-Object { $_.userPrincipalName -eq $userGroup.Name }

        if ($userSuccesses)
        {
            $failureDate = $userGroup.Group[0].eventDateTime
            $successAfter = $userSuccesses |
                Where-Object {
                    if ($failureDate)
                    {
                        ([DateTime]$_.eventDateTime) -gt ([DateTime]$failureDate)
                    }
                    else
                    {
                        $false
                    }
                } |
                Sort-Object eventDateTime |
                Select-Object -First 1

            if ($successAfter)
            {
                $singleFailureWithSuccess += [PSCustomObject]@{
                    UserPrincipalName = $userGroup.Name
                    FailureDate       = $failureDate
                    FailureDevice     = $userGroup.Group[0]
                    SuccessDate       = $successAfter.eventDateTime
                    SuccessDevice     = $successAfter
                }
            }
        }
    }

    # 9. Failed devices sorted chronologically
    $failedDevicesSorted = $failedEvents |
        Where-Object { $_.deviceSerialNumber } |
        Sort-Object eventDateTime

    Write-Log -LogFile $LogFile -Module $functionName -Message "Analysis complete: $totalEvents total events, $($successfulEvents.Count) successful, $($failedEvents.Count) failed" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Failure breakdown: Device only=$($devicePhaseOnlyFailures.Count), User only=$($userPhaseOnlyFailures.Count), Both=$($bothPhasesFailures.Count), Unknown=$($unknownPhaseFailures.Count)" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Users with multiple failures: $($usersWithMultipleFailures.Count), Single failure with success: $($singleFailureWithSuccess.Count)" -LogLevel "Verbose"

    # Build result object
    $result = [PSCustomObject]@{
        TotalEvents                 = $totalEvents
        TotalEventsBeforeFilter     = $Events.Count
        StartDate                   = $StartDate
        EndDate                     = $EndDate
        UserPrincipalName           = $UserPrincipalName
        EarliestEventDate           = $earliestDate
        SuccessfulEvents            = $successfulEvents
        SuccessCount                = $successfulEvents.Count
        FailedEvents                = $failedEvents
        FailureCount                = $failedEvents.Count
        AverageSuccessDuration      = $avgSuccessDuration
        AverageFailureDuration      = $avgFailureDuration
        DevicePhaseOnlyFailures     = $devicePhaseOnlyFailures
        DevicePhaseOnlyFailureCount = $devicePhaseOnlyFailures.Count
        UserPhaseOnlyFailures       = $userPhaseOnlyFailures
        UserPhaseOnlyFailureCount   = $userPhaseOnlyFailures.Count
        BothPhasesFailures          = $bothPhasesFailures
        BothPhasesFailureCount      = $bothPhasesFailures.Count
        UnknownPhaseFailures        = $unknownPhaseFailures
        UnknownPhaseFailureCount    = $unknownPhaseFailures.Count
        UsersWithMultipleFailures   = $usersWithMultipleFailures
        SingleFailureWithSuccess    = $singleFailureWithSuccess
        FailedDevicesChronological  = $failedDevicesSorted
        AllFilteredEvents           = $filteredEvents
        AllEvents                   = $Events
    }

    Write-Verbose "[$functionName] Analysis complete"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Autopilot event analysis completed successfully" -LogLevel "Information"
    return $result
}

