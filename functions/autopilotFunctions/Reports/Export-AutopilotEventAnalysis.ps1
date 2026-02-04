function Export-AutopilotEventAnalysis()
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
        Export summary statistics to CSV (default: true).

    .PARAMETER ExportFailures
        Export detailed failure information (default: true).

    .PARAMETER ExportSuccesses
        Export successful enrollments (default: false).

    .PARAMETER ExportAllEvents
        Export all events with human-readable formatting (default: false).

    .PARAMETER ExportUserAnalysis
        Export user-based failure analysis (default: true).

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
        [switch]$ExportAllEvents,
        [Parameter()]
        [switch]$ExportUserAnalysis
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting export to: $OutputPath"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting autopilot event analysis export to: $OutputPath" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Export options: Summary=$ExportSummary, Failures=$ExportFailures, Successes=$ExportSuccesses, AllEvents=$ExportAllEvents, UserAnalysis=$ExportUserAnalysis" -LogLevel "Verbose"

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
                Metric = "Device Phase Failures"
                Value  = $AnalysisData.DevicePhaseFailureCount
            },
            [PSCustomObject]@{
                Metric = "User Phase Failures"
                Value  = $AnalysisData.UserPhaseFailureCount
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
            enrollmentFailureDetails |
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
            @{N = "DeploymentTotalDuration"; E = { $_.deploymentTotalDuration } } |
            Export-Csv -Path $successesFile -NoTypeInformation
        $exportedFiles += $successesFile
        Write-Host "Exported successes to: $successesFile" -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $functionName -Message "Successes exported successfully to: $successesFile" -LogLevel "Information"
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
            enrollmentFailureDetails |
            Export-Csv -Path $allEventsFile -NoTypeInformation
        $exportedFiles += $allEventsFile
        Write-Host "Exported all events to: $allEventsFile" -ForegroundColor Green
        Write-Log -LogFile $LogFile -Module $functionName -Message "All events exported to: $allEventsFile" -LogLevel "Information"
    }

    Write-Host "`nExport complete. $($exportedFiles.Count) file(s) created." -ForegroundColor Cyan
    Write-Log -LogFile $LogFile -Module $functionName -Message "Export completed successfully. Created $($exportedFiles.Count) file(s)" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Exported files: $($exportedFiles -join ', ')" -LogLevel "Verbose"
    return $exportedFiles
}
