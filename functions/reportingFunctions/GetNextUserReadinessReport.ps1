function GetNextUserReadinessReport()
{
    <#
    .SYNOPSIS
    Generates readiness report for device assignment to next user.

    .DESCRIPTION
    This function assesses whether a device is ready for next user assignment by evaluating
    enrollment state, management status, profile assignment, contact dates, and pending actions.
    Provides detailed readiness assessment with actionable recommendations.

    .PARAMETER enrollmentState
    Enrollment state object with device information. This parameter is mandatory.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns readiness report with assessment, issues, recommendations, and device details.

    .EXAMPLE
    $report = GetNextUserReadinessReport -enrollmentState $state

    .NOTES
    Delegates to AssessDeviceState for comprehensive evaluation.
    Provides user-friendly readiness determination.
    Includes specific recommendations for remediation.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $enrollmentState
    )

    $functionName = $MyInvocation.MyCommand.Name
    # Input validation
    if (-not $enrollmentState)
    {
        Write-Host "Error: No enrollment state provided" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No enrollment state provided" -LogLevel "Error"
        return @{
            ReadinessState = 'Error'
            Action         = $deviceActions.contactAdmin
            Device         = $null
            AllIssues      = @("No enrollment state provided")
            AllActions     = @($deviceActions.contactAdmin)
            IssueCount     = 1
            IsReady        = $false
        }
    }
    
    # Extract device information from enrollment state with error handling
    try
    {
        $deviceName = if ($enrollmentState.managedDevice -and $enrollmentState.managedDevice.device.deviceName)
        { 
            $enrollmentState.managedDevice.device.deviceName 
        }
        elseif ($enrollmentState.autopilot -and $enrollmentState.autopilot.device.displayName)
        { 
            $enrollmentState.autopilot.device.displayName 
        }
        else
        { 
            "Device name not available" 
        }
        
        $serialNumber = if ($enrollmentState.autopilot -and $enrollmentState.autopilot.device.serialNumber)
        { 
            $enrollmentState.autopilot.device.serialNumber 
        }
        elseif ($enrollmentState.managedDevice -and $enrollmentState.managedDevice.device.serialNumber)
        { 
            $enrollmentState.managedDevice.device.serialNumber 
        }
        else
        { 
            "Unknown Serial" 
        }
    }
    catch
    {
        Write-Host "Warning: Could not extract device information from enrollment state" -ForegroundColor Yellow
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Could not extract device information: $($_.Exception.Message)" -LogLevel "Warning"
        $deviceName = "Unknown Device"
        $serialNumber = "Unknown Serial"
    }
    
    Write-Host "`nChecking next user readiness state for: $deviceName ($serialNumber)" -ForegroundColor Yellow
    
    # Call AssessDeviceState with error handling
    try
    {
        $DeviceAssessmentState = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness'
        if (-not $DeviceAssessmentState)
        {
            throw "AssessDeviceState returned null or empty result"
        }
    }
    catch
    {
        Write-Host "Error during device assessment: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error during device assessment: $($_.Exception.Message)" -LogLevel "Error"
        
        return @{
            ReadinessState = 'Error'
            Action         = $deviceActions.contactAdmin
            Device         = $null
            AllIssues      = @("Error during device assessment: $($_.Exception.Message)")
            AllActions     = @($deviceActions.contactAdmin)
            IssueCount     = 1
            IsReady        = $false
        }
    }
    
    Write-Verbose "[$functionName] Device assessment state completed successfully"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assessment state completed" -LogLevel "Information"
    
    # Display comprehensive readiness information
    if ($DeviceAssessmentState.ReadinessState -eq $deviceStates.ready)
    {
        Write-Host "`n" -ForegroundColor Green -NoNewline
        Write-Host $deviceStates.ready -ForegroundColor Green
        Write-Host "Primary Action: " -NoNewline
        Write-Host $DeviceAssessmentState.Action -ForegroundColor Green
        return $DeviceAssessmentState
    }
    elseif ($DeviceAssessmentState.ReadinessState -eq $deviceStates.notReady)
    {
        Write-Host "`n" -ForegroundColor Red -NoNewline
        Write-Host $deviceStates.notReady -ForegroundColor Red
        
        # Display all issues found
        if ($DeviceAssessmentState.AllIssues -and $DeviceAssessmentState.AllIssues.Count -gt 0)
        {
            Write-Host "`nIssues Found ($($DeviceAssessmentState.IssueCount)):" -ForegroundColor Yellow
            for ($i = 0; $i -lt $DeviceAssessmentState.AllIssues.Count; $i++)
            {
                Write-Host "  $($i + 1). $($DeviceAssessmentState.AllIssues[$i])" -ForegroundColor Red
            }
        }
        
        # Display primary recommended action
        Write-Host "`nPrimary Action Required:" -ForegroundColor Yellow
        Write-Host "  $($DeviceAssessmentState.Action)" -ForegroundColor Cyan
        
        # Display all recommended actions if multiple
        if ($DeviceAssessmentState.AllActions -and $DeviceAssessmentState.AllActions.Count -gt 1)
        {
            Write-Host "`nAll Actions Needed:" -ForegroundColor Yellow
            $DeviceAssessmentState.AllActions | ForEach-Object {
                Write-Host "  • $_" -ForegroundColor Cyan
            }
        }
        
        # Provide specific guidance based on primary action
        switch ($DeviceAssessmentState.Action)
        {
            $deviceActions.contactAdmin
            {
                Write-Host "`nGuidance: " -ForegroundColor Yellow -NoNewline
                Write-Host "Please contact your Intune administrator for assistance." -ForegroundColor Red
            }
            $deviceActions.WipeOrClean
            {
                Write-Host "`nGuidance: " -ForegroundColor Yellow -NoNewline
                Write-Host "You may need to wipe or clean the device before it can be used by the next user." -ForegroundColor Red
            }
            $deviceActions.connectToNetwork
            {
                Write-Host "`nGuidance: " -ForegroundColor Yellow -NoNewline
                Write-Host "Connect the device to the network overnight and allow it to sync with Intune." -ForegroundColor Red
            }
            $deviceActions.none
            {
                Write-Host "`nGuidance: " -ForegroundColor Yellow -NoNewline
                Write-Host "No action required at this time." -ForegroundColor Green
            }
        }
        return $DeviceAssessmentState
    }
    else
    {
        Write-Host "`n⚠ " -ForegroundColor Yellow -NoNewline
        Write-Host ("An unexpected readiness state was encountered: {0}" -f $DeviceAssessmentState.ReadinessState) -ForegroundColor Red
        Write-Verbose ("[{0}] Unexpected readiness state encountered. Assessment state: {1}" -f $functionName, ($DeviceAssessmentState | ConvertTo-Json -Depth $maxJSONDepth))
        Write-Log -LogFile $LogFile -Module $functionName -Message ("Unexpected readiness state: {0}" -f $DeviceAssessmentState.ReadinessState) -LogLevel "Error"

        # PowerShell 5.1 workaround: avoid string interpolation in variable assignment
        # Return a proper error object instead of null for better error handling
        return @{
            ReadinessState = 'Error'
            Action         = $deviceActions.contactAdmin
            Device         = $null
            AllIssues      = @("Unexpected readiness state encountered: $($DeviceAssessmentState.ReadinessState)")
            AllActions     = @($deviceActions.contactAdmin)
            IssueCount     = 1
            IsReady        = $false
        }
    }
}
