function Get-AutopilotEnrollmentReportInput()
{
    <#
    .SYNOPSIS
        Gathers user input for autopilot event analysis parameters.

    .DESCRIPTION
        Prompts user for start date, end date, and user principal name filters.
        Provides convenient date shortcuts (today, yesterday, week-to-date) and default values.

    .PARAMETER NoConfirmation
        Skip the confirmation prompt and return values immediately.

    .EXAMPLE
        $params = Get-EnrollmentReportInput
        $analysis = Get-AutopilotEventAnalysis @params -AccessToken $token

    .EXAMPLE
        $params = Get-EnrollmentReportInput -NoConfirmation
        $analysis = Get-AutopilotEventAnalysis @params -AccessToken $token

    .OUTPUTS
        Hashtable with StartDate, EndDate, and UserPrincipalName parameters ready for splatting
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$NoConfirmation
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting enrollment report input collection"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting enrollment report input collection" -LogLevel "Information"

    # Helper function to parse date input
    function ConvertTo-DateFilter()
    {
        param(
            [string]$InputString,
            [bool]$IsEndDate = $false
        )
        $functionName = $MyInvocation.MyCommand.Name
        if ([string]::IsNullOrWhiteSpace($InputString))
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Empty date input string" -LogLevel "Warning"
            return $null
        }

        $result = $null
        $today = Get-Date
        switch -Regex ($InputString.Trim().ToLower())
        {
            '^today$'
            {
                $result = Get-Date -Hour 0 -Minute 0 -Second 0
                Write-Verbose "[$functionName] Interpreted '$InputString' as today: $($result.ToString('yyyy-MM-dd'))"
                Write-Log -logFile $LogFile -Module $functionName -Message "Interpreted '$InputString' as today: $($result.ToString('yyyy-MM-dd'))"
            }
            '^yesterday$'
            {
                $result = (Get-Date).AddDays(-1).Date
                Write-Verbose "[$functionName] Interpreted '$InputString' as yesterday: $($result.ToString('yyyy-MM-dd'))"
                Write-Log -logFile $LogFile -Module $functionName -Message "Interpreted '$InputString' as yesterday: $($result.ToString('yyyy-MM-dd'))"
            }
            '^(wtd|week|weektodate|week-to-date)$'
            {
                $daysToMonday = ([int]$today.DayOfWeek + 6) % 7
                $result = $today.AddDays(-$daysToMonday).Date
                Write-Verbose "[$functionName] Interpreted '$InputString' as week-to-date: $($result.ToString('yyyy-MM-dd'))"
                Write-Log -logFile $LogFile -Module $functionName -Message "Interpreted '$InputString' as week-to-date: $($result.ToString('yyyy-MM-dd'))"
            }
            '^(mtd|month|monthtodate|month-to-date)$'
            {
                $result = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
                Write-Verbose "[$functionName] Interpreted '$InputString' as month-to-date: $($result.ToString('yyyy-MM-dd'))"
                Write-Log -logFile $LogFile -Module $functionName -Message "Interpreted '$InputString' as month-to-date: $($result.ToString('yyyy-MM-dd'))"
            }
            default
            {
                try
                {
                    $result = [DateTime]::Parse($InputString)
                    Write-Verbose "[$functionName] Parsed date input: $($result.ToString('yyyy-MM-dd'))"
                    Write-Log -logFile $LogFile -Module $functionName -Message "Parsed date input: $($result.ToString('yyyy-MM-dd'))"
                }
                catch
                {
                    Write-Log -logFile $LogFile -Module $functionName -Message "Failed to parse date input: $InputString" -LogLevel "ERROR"
                    Write-Verbose "[$functionName] Failed to parse date input: $InputString"
                    return $null
                }
            }
        }

        if ($result -and $IsEndDate)
        {
            $result = $result.AddDays(1).AddTicks(-1)
            Write-Verbose "[$functionName] Adjusted end date to end of day: $($result.ToString('yyyy-MM-dd HH:mm:ss'))"
            Write-Log -logFile $LogFile -Module $functionName -Message "Adjusted end date to end of day: $($result.ToString('yyyy-MM-dd HH:mm:ss'))"
        }
        Write-Log -logFile $LogFile -Module $functionName -Message "Returning date filter: $($result.ToString('yyyy-MM-dd HH:mm:ss'))" -LogLevel "Verbose"
        return $result
    }

    # Display header
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "Autopilot Enrollment Report - Filter Configuration" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan

    # Start Date Input
    Write-Host "`nStart Date Filter:" -ForegroundColor Cyan
    Write-Host "  Options:" -ForegroundColor Gray
    Write-Host "    - Press Enter for default $((Get-Date).AddDays(-30).ToString('yyyy-MM-dd'))" -ForegroundColor Gray
    Write-Host "    - Type: today, yesterday, wtd (week-to-date), mtd (month-to-date)" -ForegroundColor Gray
    Write-Host "    - Or enter date: yyyy-MM-dd or MM/dd/yyyy" -ForegroundColor Gray
    $startDateInput = Read-Host "`nStart Date [default: $((Get-Date).AddDays(-30).ToString('yyyy-MM-dd'))]"

    $startDate = $null
    if ([string]::IsNullOrWhiteSpace($startDateInput))
    {
        #set the start date to 30 days ago if no input is provided
        $startDate = (Get-Date).AddDays(-30)
        Write-Verbose "[$functionName] Using default start date: $($startDate.ToString('yyyy-MM-dd'))"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected default start date: $($startDate.ToString('yyyy-MM-dd'))" -LogLevel "Information"
        Write-Host "Using default: $($startDate.ToString('yyyy-MM-dd'))                     " -ForegroundColor Yellow
    }
    else
    {
        $startDate = ConvertTo-DateFilter -InputString $startDateInput -IsEndDate $false
        if ($startDate)
        {
            Write-Host "Start date set to: $($startDate.ToString('yyyy-MM-dd'))" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Start date set to: $($startDate.ToString('yyyy-MM-dd'))" -LogLevel "Information"
        }
        else
        {
            Write-Host "Invalid date format. No start date filter will be applied." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid start date input: $startDateInput" -LogLevel "Warning"
        }
    }

    # End Date Input
    Write-Host "`nEnd Date Filter:" -ForegroundColor Cyan
    Write-Host "  Options:" -ForegroundColor Gray
    Write-Host "    - Press Enter for default (today's date)" -ForegroundColor Gray
    Write-Host "    - Type: today, yesterday, wtd (week-to-date), mtd (month-to-date)" -ForegroundColor Gray
    Write-Host "    - Or enter date: yyyy-MM-dd or MM/dd/yyyy" -ForegroundColor Gray
    $endDateInput = Read-Host "`nEnd Date [default: Today's date]"

    $endDate = $null
    if ([string]::IsNullOrWhiteSpace($endDateInput))
    {
        Write-Verbose "[$functionName] Using default end date: today's date (end-of-day filter)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected default end date (today's date, end-of-day filter)" -LogLevel "Verbose"
        Write-Host "Using default: $((Get-Date).ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
        #if we have a null string, then endDate will be today's date at 11:59:59 PM
        $endDate = ConvertTo-DateFilter -InputString "today" -IsEndDate $true
    }
    else
    {
        $endDate = ConvertTo-DateFilter -InputString $endDateInput -IsEndDate $true
        if ($endDate)
        {
            Write-Host "End date set to: $($endDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "End date set to: $($endDate.ToString('yyyy-MM-dd HH:mm:ss'))" -LogLevel "Information"
        }
        else
        {
            Write-Host "Invalid date format. No end date filter will be applied." -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid end date input: $endDateInput" -LogLevel "Warning"
        }
    }

    # User Principal Name Input
    Write-Host "`nUser Principal Name Filter:" -ForegroundColor Cyan
    Write-Host "  Options:" -ForegroundColor Gray
    Write-Host "    - Press Enter to skip (analyze all users)" -ForegroundColor Gray
    Write-Host "    - Enter UPN: user@contoso.com" -ForegroundColor Gray
    $upnInput = Read-Host "`nUser Principal Name [default: all users]"

    $userPrincipalName = $null
    if (-not [string]::IsNullOrWhiteSpace($upnInput))
    {
        $userPrincipalName = $upnInput.Trim()
        Write-Host "Filtering by user: $userPrincipalName" -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $functionName -Message "User filter set to: $userPrincipalName" -LogLevel "Information"
        Write-Verbose "[$functionName] User principal name filter: $userPrincipalName"
    }
    else
    {
        Write-Host "No user filter (analyzing all users)" -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $functionName -Message "No user principal name filter applied" -LogLevel "Verbose"
        Write-Verbose "[$functionName] No user principal name filter"
    }
    # User Prompt for location data
    Write-Host "`nLocation data:" -ForegroundColor Cyan
    Write-Host "`nWould you like to use a location filter for the report?" -ForegroundColor Gray
    Write-Host "Please note this may take a long time with a large dataset." -ForegroundColor Yellow
    $useLocationFilter = Read-Host "Use location filter? (Y/N) [default: N]"
    while ($useLocationFilter -notin @("Y", "N", "y", "n", ""))
    {
        Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red
        try { [console]::Beep(1000, 500) } catch { <# Beep not supported on this platform #> }
        $useLocationFilter = Read-Host "Use location filter? (Y/N) [default: N]"
    }

    if ($useLocationFilter -in @("Y", "y"))
    {
        Write-Host "Location filter will be applied." -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $functionName -Message "User opted to use location filter" -LogLevel "Information"
        Write-Verbose "[$functionName] User opted to use location filter"
        $useLocationFilter = $true
    }
    else
    {
        Write-Host "No location filter will be applied." -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module $functionName -Message "User opted not to use location filter" -LogLevel "Information"
        Write-Verbose "[$functionName] User opted not to use location filter"
        $useLocationFilter = $false
    }

    # Build result hashtable
    $result = @{}
    if ($startDate)
    {
        $result['StartDate'] = $startDate
    }
    if ($endDate)
    {
        $result['EndDate'] = $endDate
    }
    if ($userPrincipalName)
    {
        $result['UserPrincipalName'] = $userPrincipalName
    }
    if ($useLocationFilter)
    {
        $result['UseLocationFilter'] = $true
    }
    Write-Verbose "[$functionName] Collected input parameters: $($result.Keys -join ', ')"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Collected input parameters: $($result.Keys -join ', ')" -LogLevel "Verbose"
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "Filter Summary:" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  Start Date: " -NoNewline -ForegroundColor Gray
    Write-Host $(if ($startDate)
        {
            $startDate.ToString('yyyy-MM-dd')
        }
        else
        {
            "None"
        }) -ForegroundColor $(if ($startDate)
        {
            "Green"
        }
        else
        {
            "Yellow"
        })
    Write-Host "  End Date:   " -NoNewline -ForegroundColor Gray
    Write-Host $(if ($endDate)
        {
            $endDate.ToString('yyyy-MM-dd HH:mm:ss')
        }
        else
        {
            "None"
        }) -ForegroundColor $(if ($endDate)
        {
            "Green"
        }
        else
        {
            "Yellow"
        })
    Write-Host "  User:       " -NoNewline -ForegroundColor Gray
    Write-Host $(if ($userPrincipalName)
        {
            $userPrincipalName
        }
        else
        {
            "All users"
        }) -ForegroundColor $(if ($userPrincipalName)
        {
            "Green"
        }
        else
        {
            "Yellow"
        })
    Write-Host "  Location Filter: " -NoNewline -ForegroundColor Gray
    Write-Host $(if ($useLocationFilter)
        {
            "Enabled"
        }
        else
        {
            "Disabled"
        }) -ForegroundColor $(if ($useLocationFilter)
        {
            "Green"
        }
        else
        {
            "Yellow"
        })
    Write-Host ("=" * 60) -ForegroundColor Cyan

    # Confirmation and edit loop
    if (-not $NoConfirmation)
    {
        Write-Host ""
        $confirmed = Read-Host "Are these filters correct? (Y/N) [Y]"
        while ($confirmed -and $confirmed -notmatch '^[YyNn]?$')
        {
            Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red
            [console]::beep(300, 100)
            $confirmed = Read-Host "Are these filters correct? (Y/N) [Y]"
        }

        if ($confirmed -eq '' -or $confirmed -match '^[Yy]')
        {
            Write-Verbose "[$functionName] User confirmed filter selection"
            Write-Log -LogFile $LogFile -Module $functionName -Message "User confirmed filter selection" -LogLevel "Information"
        }
        else
        {
            Write-Host "`nRestarting filter configuration..." -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "User requested to reconfigure filters" -LogLevel "Information"
            return Get-AutopilotEnrollmentReportInput
        }
    }
    else
    {
        Write-Verbose "[$functionName] Skipping confirmation (NoConfirmation switch)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Skipping confirmation due to NoConfirmation switch" -LogLevel "Verbose"
    }

    Write-Verbose "[$functionName] Input collection complete. Filters: StartDate=$($null -ne $startDate), EndDate=$($null -ne $endDate), UserPrincipalName=$($null -ne $userPrincipalName)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Input collection complete. Returning $($result.Count) filter parameter(s)" -LogLevel "Information"

    return $result
}