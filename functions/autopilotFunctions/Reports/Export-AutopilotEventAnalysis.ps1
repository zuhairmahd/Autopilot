function Export-AutopilotEventAnalysis()
{
    <#
    .SYNOPSIS
        Exports autopilot event analysis to CSV files with interactive prompts.

    .DESCRIPTION
        Provides an interactive interface for exporting autopilot event analysis data to CSV files.
        Users can choose from predefined export options or customize which data to export.
        Returns a structured object with success status and exported file information.

    .PARAMETER AnalysisData
        The analysis data object returned from Get-AutopilotEventAnalysis containing event data to export.

    .PARAMETER noConfirmation
        Reserved for future use to skip interactive prompts.

    .OUTPUTS
        PSCustomObject with the following properties:
        - Success: Boolean indicating if export completed successfully
        - ExportedFiles: Array of full file paths that were created
        - OutputPath: Resolved full path to the output directory
        - FileCount: Number of files successfully exported
        - Error: Error message if Success is false

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token
        $result = Export-AutopilotEventAnalysis -AnalysisData $analysis
        if ($result.Success) {
            Write-Host "Exported $($result.FileCount) files to $($result.OutputPath)"
        }

    .EXAMPLE
        $analysis | Export-AutopilotEventAnalysis

    .NOTES
        The function provides three export modes:
        1. Default - Summary, failures, and user analysis
        2. Everything - All available data including successes and raw events
        3. Custom - User selects specific data sets to export
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$AnalysisData,
        [switch]$noConfirmation
    )

    function Export-EventAnalysis()
    {
        <#
    .SYNOPSIS
        Exports autopilot event analysis to CSV.

    .DESCRIPTION
        Exports autopilot event analysis data to one or more CSV files.

    .PARAMETER AnalysisData
        The analysis data object returned from Get-AutopilotEventAnalysis.

    .PARAMETER OutputPath
        Base path for output files (default: current directory).

    .PARAMETER FilePrefix
        Prefix for output file names (default: "AutopilotEvents").

    .PARAMETER ExportSummary
        Export summary statistics to CSV.

    .PARAMETER ExportFailures
        Export detailed failure information.

    .PARAMETER ExportSuccesses
        Export successful enrollments.

    .PARAMETER ExportInProgress
        Export devices currently in progress.

    .PARAMETER ExportAllEvents
        Export all events with human-readable formatting.

    .PARAMETER ExportUserAnalysis
        Export user-based failure analysis.

    .PARAMETER ExportLocationAnalysis
        Export location-based analysis from sign-in data.

    .EXAMPLE
        $analysis = Get-AutopilotEventAnalysis -AccessToken $token
        Export-AutopilotEventAnalysis -AnalysisData $analysis -OutputPath "C:\Reports"

    .EXAMPLE
        $analysis | Export-AutopilotEventAnalysis -ExportAllEvents -FilePrefix "Autopilot_$(Get-Date -Format 'yyyyMMdd')"
    #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [PSCustomObject]$AnalysisData,
            [Parameter()]
            [string]$OutputPath = ".",
            [Parameter()]
            [string]$FilePrefix = "AutopilotEvents",
            [Parameter()]
            [switch]$ExportSummary,
            [Parameter()]
            [switch]$ExportFailures,
            [Parameter()]
            [switch]$ExportSuccesses,
            [Parameter()]
            [switch]$ExportInProgress,
            [Parameter()]
            [switch]$ExportAllEvents,
            [Parameter()]
            [switch]$ExportUserAnalysis,
            [Parameter()]
            [switch]$ExportLocationAnalysis
        )

        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Starting export to: $OutputPath"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Starting autopilot event analysis export to: $OutputPath" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Export options: Summary=$ExportSummary, Failures=$ExportFailures, Successes=$ExportSuccesses, InProgress=$ExportInProgress, AllEvents=$ExportAllEvents, UserAnalysis=$ExportUserAnalysis, LocationAnalysis=$ExportLocationAnalysis" -LogLevel "Verbose"

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $exportedFiles = @()

        # Export Summary
        if ($ExportSummary)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting summary data" -LogLevel "Verbose"
            $summaryFile = Join-Path $OutputPath "$FilePrefix`_Summary_$timestamp.csv"
            $summaryData = @(
                [PSCustomObject]@{
                    Metric = "Total Events"
                    Value  = $AnalysisData.TotalEvents
                },
                [PSCustomObject]@{
                    Metric = "Successful Events"
                    Value  = $AnalysisData.SuccessCount
                },
                [PSCustomObject]@{
                    Metric = "In-Progress Events"
                    Value  = $AnalysisData.InProgressCount
                },
                [PSCustomObject]@{
                    Metric = "In-Progress - Device Phase"
                    Value  = $AnalysisData.DevicePhaseInProgressCount
                },
                [PSCustomObject]@{
                    Metric = "In-Progress - User/Account Phase"
                    Value  = $AnalysisData.UserPhaseInProgressCount
                },
                [PSCustomObject]@{
                    Metric = "Failed Events"
                    Value  = $AnalysisData.FailureCount
                },
                [PSCustomObject]@{
                    Metric = "Average Success Duration"
                    Value  = if ($AnalysisData.AverageSuccessDuration)
                    {
                        "{0:hh\:mm\:ss}" -f $AnalysisData.AverageSuccessDuration
                    }
                    else
                    {
                        "N/A"
                    }
                },
                [PSCustomObject]@{
                    Metric = "Average Failure Duration"
                    Value  = if ($AnalysisData.AverageFailureDuration)
                    {
                        "{0:hh\:mm\:ss}" -f $AnalysisData.AverageFailureDuration
                    }
                    else
                    {
                        "N/A"
                    }
                },
                [PSCustomObject]@{
                    Metric = "Device Phase Only Failures"
                    Value  = $AnalysisData.DevicePhaseOnlyFailureCount
                },
                [PSCustomObject]@{
                    Metric = "User/Account Phase Only Failures"
                    Value  = $AnalysisData.UserPhaseOnlyFailureCount
                },
                [PSCustomObject]@{
                    Metric = "Both Phases Failures"
                    Value  = $AnalysisData.BothPhasesFailureCount
                },
                [PSCustomObject]@{
                    Metric = "Unknown Phase Failures"
                    Value  = $AnalysisData.UnknownPhaseFailureCount
                },
                [PSCustomObject]@{
                    Metric = "Earliest Event Date"
                    Value  = if ($AnalysisData.EarliestEventDate)
                    {
                        $AnalysisData.EarliestEventDate.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    else
                    {
                        "N/A"
                    }
                },
                [PSCustomObject]@{
                    Metric = "Filter - Start Date"
                    Value  = if ($AnalysisData.StartDate)
                    {
                        $AnalysisData.StartDate.ToString("yyyy-MM-dd")
                    }
                    else
                    {
                        "N/A"
                    }
                },
                [PSCustomObject]@{
                    Metric = "Filter - End Date"
                    Value  = if ($AnalysisData.EndDate)
                    {
                        $AnalysisData.EndDate.ToString("yyyy-MM-dd")
                    }
                    else
                    {
                        "N/A"
                    }
                },
                [PSCustomObject]@{
                    Metric = "Filter - User Principal Name"
                    Value  = if ($AnalysisData.UserPrincipalName)
                    {
                        $AnalysisData.UserPrincipalName
                    }
                    else
                    {
                        "N/A"
                    }
                }
            )
            $summaryData | Export-Csv -Path $summaryFile -NoTypeInformation
            $exportedFiles += $summaryFile
            Write-Host "Exported summary to: $summaryFile" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Summary exported successfully to: $summaryFile" -LogLevel "Information"
        }

        # Export Failures
        if ($ExportFailures -and $AnalysisData.FailureCount -gt 0)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting failure data ($($AnalysisData.FailureCount) failures)" -LogLevel "Verbose"
            $failuresFile = Join-Path $OutputPath "$FilePrefix`_Failures_$timestamp.csv"
            $AnalysisData.FailedEvents |
                Select-Object @{N = "EventDate"; E = { if ($_.eventDateTime)
                        {
                            ([DateTime]$_.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                deviceSerialNumber,
                managedDeviceName,
                userPrincipalName,
                deploymentState,
                deviceSetupStatus,
                accountSetupStatus,
                osVersion,
                enrollmentState,
                enrollmentType,
                windowsAutopilotDeploymentProfileDisplayName,
                @{N = "DeploymentDuration"; E = { $_.deploymentDuration } },
                @{N = "DeploymentTotalDuration"; E = { $_.deploymentTotalDuration } },
                enrollmentFailureDetails,
                @{N = "SignIn_Location"; E = { "$($_.SignIn_Location_City), $($_.SignIn_Location_State), $($_.SignIn_Location_Country)" -replace '^, |, $' } },
                SignIn_IPAddress,
                SignIn_Status,
                SignIn_FailureReason,
                @{N = "SignIn_ConfidenceScore"; E = { $_.SignIn_ConfidenceScore } },
                @{N = "SignIn_MatchedOn"; E = { $_.SignIn_MatchedOn } } |
                Export-Csv -Path $failuresFile -NoTypeInformation
            $exportedFiles += $failuresFile
            Write-Host "Exported failures to: $failuresFile" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failures exported successfully to: $failuresFile" -LogLevel "Information"
        }

        # Export Successes
        if ($ExportSuccesses -and $AnalysisData.SuccessCount -gt 0)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting success data ($($AnalysisData.SuccessCount) successes)" -LogLevel "Verbose"
            $successesFile = Join-Path $OutputPath "$FilePrefix`_Successes_$timestamp.csv"
            $AnalysisData.SuccessfulEvents |
                Select-Object @{N = "EventDate"; E = { if ($_.eventDateTime)
                        {
                            ([DateTime]$_.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                deviceSerialNumber,
                managedDeviceName,
                userPrincipalName,
                deploymentState,
                deviceSetupStatus,
                accountSetupStatus,
                osVersion,
                enrollmentState,
                enrollmentType,
                windowsAutopilotDeploymentProfileDisplayName,
                @{N = "DeploymentDuration"; E = { $_.deploymentDuration } },
                @{N = "DeploymentTotalDuration"; E = { $_.deploymentTotalDuration } },
                @{N = "SignIn_Location"; E = { "$($_.SignIn_Location_City), $($_.SignIn_Location_State), $($_.SignIn_Location_Country)" -replace '^, |, $' } },
                SignIn_IPAddress,
                SignIn_Status,
                @{N = "SignIn_ConfidenceScore"; E = { $_.SignIn_ConfidenceScore } },
                @{N = "SignIn_MatchedOn"; E = { $_.SignIn_MatchedOn } } |
                Export-Csv -Path $successesFile -NoTypeInformation
            $exportedFiles += $successesFile
            Write-Host "Exported successes to: $successesFile" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successes exported successfully to: $successesFile" -LogLevel "Information"
        }

        # Export In-Progress
        if ($ExportInProgress -and $AnalysisData.InProgressCount -gt 0)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting in-progress data ($($AnalysisData.InProgressCount) in progress)" -LogLevel "Verbose"
            $inProgressFile = Join-Path $OutputPath "$FilePrefix`_InProgress_$timestamp.csv"
            $AnalysisData.InProgressEvents |
                Select-Object @{N = "EventDate"; E = { if ($_.eventDateTime)
                        {
                            ([DateTime]$_.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                deviceSerialNumber,
                managedDeviceName,
                userPrincipalName,
                deploymentState,
                deviceSetupStatus,
                accountSetupStatus,
                @{N = "InProgressPhase"; E = {
                        if ($_.deviceSetupStatus -eq 'inProgress')
                        {
                            "Device"
                        }
                        elseif ($_.accountSetupStatus -eq 'inProgress')
                        {
                            "User/Account"
                        }
                        else
                        {
                            "Unknown"
                        }
                    }
                },
                osVersion,
                enrollmentState,
                enrollmentType,
                windowsAutopilotDeploymentProfileDisplayName,
                @{N = "DeploymentDuration"; E = { $_.deploymentDuration } },
                @{N = "DeploymentTotalDuration"; E = { $_.deploymentTotalDuration } },
                @{N = "SignIn_Location"; E = { "$($_.SignIn_Location_City), $($_.SignIn_Location_State), $($_.SignIn_Location_Country)" -replace '^, |, $' } },
                SignIn_IPAddress,
                SignIn_Status,
                @{N = "SignIn_ConfidenceScore"; E = { $_.SignIn_ConfidenceScore } },
                @{N = "SignIn_MatchedOn"; E = { $_.SignIn_MatchedOn } } |
                Export-Csv -Path $inProgressFile -NoTypeInformation
            $exportedFiles += $inProgressFile
            Write-Host "Exported in-progress devices to: $inProgressFile" -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module $functionName -Message "In-progress devices exported successfully to: $inProgressFile" -LogLevel "Information"
        }

        # Export User Analysis
        if ($ExportUserAnalysis)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting user analysis data" -LogLevel "Verbose"
            # Multiple failures
            if ($AnalysisData.UsersWithMultipleFailures.Count -gt 0)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting users with multiple failures ($($AnalysisData.UsersWithMultipleFailures.Count) users)" -LogLevel "Verbose"
                $userMultipleFile = Join-Path $OutputPath "$FilePrefix`_UsersMultipleFailures_$timestamp.csv"
                $userData = @()
                foreach ($user in $AnalysisData.UsersWithMultipleFailures)
                {
                    $userData += [PSCustomObject]@{
                        UserPrincipalName   = $user.UserPrincipalName
                        FailureCount        = $user.FailureCount
                        EventualSuccess     = $user.EventualSuccess
                        SuccessDevice       = if ($user.SuccessDevice)
                        {
                            $user.SuccessDevice.deviceSerialNumber
                        }
                        else
                        {
                            "N/A"
                        }
                        SuccessDate         = if ($user.SuccessDevice)
                        {
                            ([DateTime]$user.SuccessDevice.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        }
                        FailedDeviceSerials = ($user.FailedDevices.deviceSerialNumber -join "; ")
                        LastFailureDate     = if ($user.LastFailureDate)
                        {
                            ([DateTime]$user.LastFailureDate).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        }
                    }
                }
                $userData | Export-Csv -Path $userMultipleFile -NoTypeInformation
                $exportedFiles += $userMultipleFile
                Write-Host "Exported users with multiple failures to: $userMultipleFile" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module $functionName -Message "Users with multiple failures exported to: $userMultipleFile" -LogLevel "Information"
            }

            # Single failure with success
            if ($AnalysisData.SingleFailureWithSuccess.Count -gt 0)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting users with single failure ($($AnalysisData.SingleFailureWithSuccess.Count) users)" -LogLevel "Verbose"
                $userSingleFile = Join-Path $OutputPath "$FilePrefix`_UsersSingleFailure_$timestamp.csv"
                $AnalysisData.SingleFailureWithSuccess |
                    Select-Object UserPrincipalName,
                    @{N = "FailureDate"; E = { if ($_.FailureDate)
                            {
                                ([DateTime]$_.FailureDate).ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            else
                            {
                                "N/A"
                            } }
                    },
                    @{N = "FailureDeviceSerial"; E = { $_.FailureDevice.deviceSerialNumber } },
                    @{N = "SuccessDate"; E = { if ($_.SuccessDate)
                            {
                                ([DateTime]$_.SuccessDate).ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            else
                            {
                                "N/A"
                            } }
                    },
                    @{N = "SuccessDeviceSerial"; E = { $_.SuccessDevice.deviceSerialNumber } } |
                    Export-Csv -Path $userSingleFile -NoTypeInformation
                $exportedFiles += $userSingleFile
                Write-Host "Exported users with single failure to: $userSingleFile" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module $functionName -Message "Users with single failure exported to: $userSingleFile" -LogLevel "Information"
            }
        }

        # Export All Events
        if ($ExportAllEvents)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting all events ($($AnalysisData.AllFilteredEvents.Count) events)" -LogLevel "Verbose"
            $allEventsFile = Join-Path $OutputPath "$FilePrefix`_AllEvents_$timestamp.csv"
            $AnalysisData.AllFilteredEvents |
                Select-Object @{N = "EventDate"; E = { if ($_.eventDateTime)
                        {
                            ([DateTime]$_.eventDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                @{N = "RegisteredDate"; E = { if ($_.deviceRegisteredDateTime)
                        {
                            ([DateTime]$_.deviceRegisteredDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                @{N = "EnrollmentStartDate"; E = { if ($_.enrollmentStartDateTime)
                        {
                            ([DateTime]$_.enrollmentStartDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                @{N = "DeploymentStartDate"; E = { if ($_.deploymentStartDateTime)
                        {
                            ([DateTime]$_.deploymentStartDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                @{N = "DeploymentEndDate"; E = { if ($_.deploymentEndDateTime)
                        {
                            ([DateTime]$_.deploymentEndDateTime).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                deviceId,
                userId,
                deviceSerialNumber,
                managedDeviceName,
                userPrincipalName,
                windowsAutopilotDeploymentProfileDisplayName,
                enrollmentState,
                enrollmentType,
                windows10EnrollmentCompletionPageConfigurationDisplayName,
                deploymentState,
                deviceSetupStatus,
                accountSetupStatus,
                osVersion,
                deploymentDuration,
                deploymentTotalDuration,
                deviceSetupDuration,
                accountSetupDuration,
                enrollmentFailureDetails,
                SignIn_MatchFound,
                @{N = "SignIn_ConfidenceScore"; E = { $_.SignIn_ConfidenceScore } },
                @{N = "SignIn_MatchedOn"; E = { $_.SignIn_MatchedOn } },
                SignIn_Location_City,
                SignIn_Location_State,
                SignIn_Location_Country,
                SignIn_IPAddress,
                SignIn_Status,
                SignIn_FailureReason,
                SignIn_ErrorCode |
                Export-Csv -Path $allEventsFile -NoTypeInformation
            $exportedFiles += $allEventsFile
            Write-Host "Exported all events to: $allEventsFile" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "All events exported to: $allEventsFile" -LogLevel "Information"
        }

        # Export Location Analysis
        if ($ExportLocationAnalysis -and $AnalysisData.LocationAnalysisCount -gt 0)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting location analysis ($($AnalysisData.LocationAnalysisCount) locations)" -LogLevel "Verbose"
            $locationFile = Join-Path $OutputPath "$FilePrefix`_LocationAnalysis_$timestamp.csv"
            $AnalysisData.LocationAnalysis |
                Select-Object Location,
                TotalEvents,
                SuccessfulEvents,
                FailedEvents,
                InProgressEvents,
                @{N = "SuccessRate"; E = { if ($_.TotalEvents -gt 0)
                        {
                            "{0:P2}" -f $_.SuccessRate
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                @{N = "FailureRate"; E = { if ($_.TotalEvents -gt 0)
                        {
                            "{0:P2}" -f $_.FailureRate
                        }
                        else
                        {
                            "N/A"
                        } }
                },
                Country,
                State,
                City,
                @{N = "UniqueUsers"; E = { $_.UniqueUsers } },
                @{N = "UniqueDevices"; E = { $_.UniqueDevices } } |
                Export-Csv -Path $locationFile -NoTypeInformation
            $exportedFiles += $locationFile
            Write-Host "Exported location analysis to: $locationFile" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Location analysis exported to: $locationFile" -LogLevel "Information"
        }

        Write-Host "`nExport complete. $($exportedFiles.Count) file(s) created." -ForegroundColor Cyan
        Write-Log -LogFile $LogFile -Module $functionName -Message "Export completed successfully. Created $($exportedFiles.Count) file(s)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Exported files: $($exportedFiles -join ', ')" -LogLevel "Verbose"
        # Use comma operator to prevent PowerShell from unrolling single-element arrays
        , $exportedFiles
    }

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting autopilot event analysis export"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting autopilot event analysis export" -LogLevel "Information"

    # Scaffold return object with default values
    $result = [PSCustomObject]@{
        Success       = $false
        ExportedFiles = @()
        OutputPath    = $null
        FileCount     = 0
        Error         = $null
    }

    try
    {
        Write-Host "\nExport Options:" -ForegroundColor Cyan
        Write-Host "1. Export summary and failures only (default)" -ForegroundColor Gray
        Write-Host "2. Export everything including all events" -ForegroundColor Gray
        Write-Host "3. Export custom selection" -ForegroundColor Gray

        Write-Verbose "[$functionName] Prompting user for export option"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting user for export option" -LogLevel "Verbose"
        $exportOption = Read-Host "Choose export option (1-3)"
        Write-Verbose "[$functionName] User selected export option: $exportOption"
        Write-Log -LogFile $LogFile -Module $functionName -Message "User selected export option: $exportOption" -LogLevel "Information"
        $exportPath = Read-Host "Enter output path (leave blank for current directory)"
        if ([string]::IsNullOrWhiteSpace($exportPath))
        {
            $exportPath = "."
        }
        else
        {
            if (-not (Test-Path -Path $exportPath -PathType Container))
            {
                Write-Host "Output path does not exist. Creating directory: $exportPath" -ForegroundColor Yellow
                Write-Log -LogFile $LogFile -Module $functionName -Message "Output path does not exist. Creating directory: $exportPath" -LogLevel "Warning"
                New-Item -Path $exportPath -ItemType Directory | Out-Null
            }
        }
        Write-Verbose "[$functionName] Export path set to: $exportPath"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Export path set to: $exportPath" -LogLevel "Verbose"

        # Store the path in result object
        $result.OutputPath = $exportPath
        try
        {
            switch ($exportOption)
            {
                "2"
                {
                    Write-Verbose "[$functionName] Exporting all data (summary, failures, successes, in-progress, user analysis, location analysis, all events)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Exporting all data (summary, failures, successes, in-progress, user analysis, location analysis, all events)" -LogLevel "Information"
                    $exportedFiles = Export-EventAnalysis -AnalysisData $AnalysisData -OutputPath $exportPath -ExportSummary -ExportFailures -ExportUserAnalysis -ExportLocationAnalysis -ExportAllEvents -ExportSuccesses -ExportInProgress
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Export completed successfully" -LogLevel "Information"
                    $result.Success = $true
                    $result.ExportedFiles = @($exportedFiles)
                    $result.OutputPath = (Resolve-Path $exportPath).Path
                    $result.FileCount = $exportedFiles.Count
                }
                "3"
                {
                    Write-Verbose "[$functionName] Custom export selection mode"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Custom export selection mode" -LogLevel "Information"
                    Write-Host "`nExport Summary? (Y/N): " -NoNewline
                    $expSum = Read-Host
                    Write-Host "Export Failures? (Y/N): " -NoNewline
                    $expFail = Read-Host
                    Write-Host "Export Successes? (Y/N): " -NoNewline
                    $expSucc = Read-Host
                    Write-Host "Export In-Progress Devices? (Y/N): " -NoNewline
                    $expInProg = Read-Host
                    Write-Host "Export All Events? (Y/N): " -NoNewline
                    $expAll = Read-Host
                    Write-Host "Export User Analysis? (Y/N): " -NoNewline
                    $expUser = Read-Host
                    Write-Host "Export Location Analysis? (Y/N): " -NoNewline
                    $expLocation = Read-Host
                    $exportParams = @{
                        AnalysisData = $AnalysisData
                        OutputPath   = $exportPath
                    }
                    if ($expSum -eq 'Y' -or $expSum -eq 'y')
                    {
                        $exportParams['ExportSummary'] = $true
                    }
                    if ($expFail -eq 'Y' -or $expFail -eq 'y')
                    {
                        $exportParams['ExportFailures'] = $true
                    }
                    if ($expSucc -eq 'Y' -or $expSucc -eq 'y')
                    {
                        $exportParams['ExportSuccesses'] = $true
                    }
                    if ($expInProg -eq 'Y' -or $expInProg -eq 'y')
                    {
                        $exportParams['ExportInProgress'] = $true
                    }
                    if ($expAll -eq 'Y' -or $expAll -eq 'y')
                    {
                        $exportParams['ExportAllEvents'] = $true
                    }
                    if ($expUser -eq 'Y' -or $expUser -eq 'y')
                    {
                        $exportParams['ExportUserAnalysis'] = $true
                    }
                    if ($expLocation -eq 'Y' -or $expLocation -eq 'y')
                    {
                        $exportParams['ExportLocationAnalysis'] = $true
                    }

                    Write-Verbose "[$functionName] Custom selections: Summary=$($expSum), Failures=$($expFail), Successes=$($expSucc), InProgress=$($expInProg), AllEvents=$($expAll), UserAnalysis=$($expUser), LocationAnalysis=$($expLocation)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Custom selections: Summary=$($expSum), Failures=$($expFail), Successes=$($expSucc), InProgress=$($expInProg), AllEvents=$($expAll), UserAnalysis=$($expUser), LocationAnalysis=$($expLocation)" -LogLevel "Verbose"
                    $exportedFiles = Export-EventAnalysis @exportParams
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Custom export completed successfully" -LogLevel "Information"
                    $result.Success = $true
                    $result.ExportedFiles = @($exportedFiles)
                    $result.OutputPath = (Resolve-Path $exportPath).Path
                    $result.FileCount = $exportedFiles.Count
                }
                default
                {
                    Write-Verbose "[$functionName] Default export (summary, failures, user analysis)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Default export (summary, failures, user analysis)" -LogLevel "Information"
                    $exportedFiles = Export-EventAnalysis -AnalysisData $AnalysisData -OutputPath $exportPath -ExportSummary -ExportFailures -ExportUserAnalysis
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Default export completed successfully" -LogLevel "Information"
                    $result.Success = $true
                    $result.ExportedFiles = @($exportedFiles)
                    $result.OutputPath = (Resolve-Path $exportPath).Path
                    $result.FileCount = $exportedFiles.Count
                }
            }
        }
        catch
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Export failed: $_" -LogLevel "Error"
            $result.Error = $_.Exception.Message
            throw
        }
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Fatal error during export: $_" -LogLevel "Error"
        if (-not $result.Error)
        {
            $result.Error = $_.Exception.Message
        }
    }

    Write-Verbose "[$functionName] Export operation completed with status: Success=$($result.Success)"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Export operation completed with status: Success=$($result.Success), FileCount=$($result.FileCount)" -LogLevel "Information"

    return $result
}