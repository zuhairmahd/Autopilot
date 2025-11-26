function AssessDeviceState() 
{
    <#
    .SYNOPSIS
    Assesses the current state and readiness of an Autopilot device for next user.

    .DESCRIPTION
    This function evaluates a device's enrollment state and determines readiness for next user assignment.
    It checks enrollment status, management state, profile assignment, contact dates, and pending actions
    to provide comprehensive assessment with specific recommendations.

    .PARAMETER enrollmentState
    Enrollment state object containing device status information. This parameter is mandatory.

    .PARAMETER AssessmentType
    Type of assessment: 'NextUserReadiness' (default) or other assessment types.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns assessment object with readiness status, issues, and recommendations.

    .EXAMPLE
    $assessment = AssessDeviceState -enrollmentState $state -AssessmentType 'NextUserReadiness'

    .NOTES
    Evaluates enrollment, management, profile assignment, contact dates, and pending actions.
    Provides actionable recommendations for device readiness.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $enrollmentState,
        $settings = $settings,
        [Parameter(Mandatory = $true)]
        [ValidateSet('PropperEnrollmentVerification', 'NextUserReadiness', 'TroubleShooting')]
        [string]$AssessmentType
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region Write verbose log of received parameters.
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Received parameters:" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Enrollment state: $($enrollmentState | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Assessment type: $AssessmentType" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Settings: $($settings | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Information"
    $returnValue = [ordered] @{}
    $readinessState = $null
    $action = $null
    $device = $null
    #endregion

    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Type of assessment: $AssessmentType" -LogLevel "Information"
    switch ($AssessmentType)
    {
        'PropperEnrollmentVerification'
        {
            Write-Host "Place holder text..."
            Write-Host "Checking if the device is properly enrolled..."
        }
        'NextUserReadiness'
        {
            Write-Host "Checking if the device is ready for the next user..."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking if the device is registered in Autopilot..." -LogLevel "Verbose"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "In Autopilot: $($enrollmentState.inAutopilot)" -LogLevel "Information"
            if ($enrollmentState.inAutopilot)
            {
                $autopilotReadiness = GetAutopilotDeviceRelevantProperties -enrollmentState $enrollmentState
                
                # Initialize variables to avoid null reference errors
                $managedDeviceReadiness = $null
                $deviceLastContactDate = $null
                
                if ($enrollmentState.autopilot.device.enrollmentState -ne 'notContacted')
                {   
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting managed device properties." -LogLevel "Information"
                    $managedDeviceReadiness = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState -settings $settings
                    $deviceLastContactDate = GetLastDeviceContactDate -accessToken $accessToken -enrollmentState $enrollmentState
                    if ($deviceLastContactDate.withinThreshold)
                    {
                        Write-Host "The device last contacted Intune on $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone), $($deviceLastContactDate.numberOfDaysSinceLastContact) days ago."
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device last contact date: $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone)" -LogLevel "Information"
                    }
                    else
                    {
                        Write-Host "The device has not contacted Intune in $($deviceLastContactDate.numberOfDaysSinceLastContact) days. Last contact date: $($deviceLastContactDate.lastContactDate | FormatDateWithTimeZone)."
                        Write-Host "Please check the device's network connectivity and ensure it can reach Intune."
                    }    
                    $memoryMessage = "`n"
                    Write-Verbose "[$functionName] Managed device readiness good: $($managedDeviceReadiness.ReadyForNextUser)"
                    Write-Verbose "[$functionName] within threshold: $($deviceLastContactDate.withinThreshold)"
                }
                else 
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device enrollment state is 'notContacted', skipping managed device readiness check." -LogLevel "Information"
                    $memoryMessage = "We could not determine whether the device has the required $($settings.MinimumDevicePhysicalMemoryInGB ) GB of RAM. `n Please manually verify that the device has $($settings.MinimumDevicePhysicalMemoryInGB ) GB of RAM before proceeding."
                }
                Write-Verbose "Autopilot assignment good: $($autopilotReadiness.AutopilotAssignmentGood)"
                
                # Determine readiness - handle notContacted devices separately to avoid null reference errors
                $isNotContactedReady = $autopilotReadiness.AutopilotAssignmentGood -and 
                $enrollmentState.autopilot.device.enrollmentState -eq 'notContacted' -and 
                $enrollmentState.managed -eq $false
                
                $isEnrolledReady = $settings.includeEnrolledDevicesInNextUserReadiness -and 
                $autopilotReadiness.AutopilotAssignmentGood -and 
                $null -ne $managedDeviceReadiness -and
                $managedDeviceReadiness.ReadyForNextUser -and 
                ($settings.includeEnrolledDevicesInNextUserReadiness -and $enrollmentState.autopilot.device.enrollmentState -ne 'notContacted') -and 
                $null -ne $deviceLastContactDate -and
                $deviceLastContactDate.withinThreshold

                # Check for pending actions using getDevicePendingActions
                $pendingActionsResult = getDevicePendingActions -enrollmentState $enrollmentState
                $isPendingActions = $pendingActionsResult.IsPendingAction

                Write-Verbose "[$functionName] isNotContactedReady: $isNotContactedReady"
                Write-Verbose "[$functionName] isEnrolledReady: $isEnrolledReady"
                Write-Verbose "[$functionName] isPendingActions: $isPendingActions"
                Write-Log -logFile $LogFile -Module "$functionName" -Message "Device readiness for next user - isEnrolledReady: $isEnrolledReady, isNotContactedReady: $isNotContactedReady, isPendingActions: $isPendingActions" -LogLevel "Information"
                
                # Device is only ready if it passes readiness checks AND has no pending actions
                if (($isEnrolledReady -or $isNotContactedReady) -and -not $isPendingActions)
                {
                    Write-Host "`n=== Device Readiness Assessment ===" -ForegroundColor Cyan
                    Write-Host "Status: " -NoNewline
                    Write-Host "READY" -ForegroundColor Green
                    Write-Host "The device is ready for the next user." -ForegroundColor Green
                    Write-Host $memoryMessage
                    Write-Host "===================================`n" -ForegroundColor Cyan
                    $readinessState = $deviceStates.ready 
                    $action = $deviceActions.none
                    $device = if ($enrollmentState.managedDevice -and $enrollmentState.managedDevice.device.id)
                    { 
                        $enrollmentState.managedDevice.device.id 
                    }
                    elseif ($enrollmentState.autopilot -and $enrollmentState.autopilot.device.id)
                    { 
                        $enrollmentState.autopilot.device.id 
                    }
                    else
                    { 
                        $null 
                    }
                    $allIssues = @()  # No issues when ready
                    $allActions = @($deviceActions.none)
                }
                else
                {
                    Write-Host "`n=== Device Readiness Assessment ===" -ForegroundColor Cyan
                    Write-Host "Status: " -NoNewline
                    Write-Host "NOT READY" -ForegroundColor Red
                    Write-Host "The device is not ready for the next user." -ForegroundColor Red
                    Write-Host "See below for more information.`n" -ForegroundColor Yellow
                    
                    # Initialize arrays to collect all issues and actions
                    $allIssues = @()
                    $allActions = @()
                    $actionsPriority = @{}  # To track action priorities
                    
                    # Set base readiness state and device ID
                    $readinessState = $deviceStates.notReady
                    $device = if ($enrollmentState.managedDevice -and $enrollmentState.managedDevice.device.id)
                    { 
                        $enrollmentState.managedDevice.device.id 
                    }
                    elseif ($enrollmentState.autopilot -and $enrollmentState.autopilot.device.id)
                    { 
                        $enrollmentState.autopilot.device.id 
                    }
                    else
                    { 
                        $null 
                    }
                    
                    # Check for pending actions first (highest priority issue)
                    if ($isPendingActions)
                    {
                        $issue = $returnValues.devicePendingActionsMessage
                        Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                        Write-Host $issue -ForegroundColor Yellow
                        $allIssues += $issue
                        
                        # Display specific pending actions if available
                        if ($pendingActionsResult.PendingActions)
                        {
                            Write-Host "      Pending Actions:" -ForegroundColor Yellow
                            if ($pendingActionsResult.PendingActions -is [array])
                            {
                                foreach ($pendingAction in $pendingActionsResult.PendingActions)
                                {
                                    Write-Host "      - $($pendingAction.ActionName): $($pendingAction.ActionStatus)" -ForegroundColor Cyan
                                }
                            }
                            else
                            {
                                Write-Host "      - $($pendingActionsResult.PendingActions.ActionName): $($pendingActionsResult.PendingActions.ActionStatus)" -ForegroundColor Cyan
                            }
                        }
                        $actionsPriority[$deviceActions.turnOnDevice] = 1  # Highest priority
                    }
                    
                    # Check all other possible issues and collect them
                    if ($autopilotReadiness.CorrectProfile -eq $false)
                    {
                        $issue = "The device is not assigned to the correct autopilot profile."
                        Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                        Write-Host $issue -ForegroundColor Red
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($autopilotReadiness.ProfileAssigned -eq $false)
                    {
                        $issue = "The device is not assigned to an autopilot profile."
                        Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                        Write-Host $issue -ForegroundColor Red
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($autopilotReadiness.RemediationStateGood -eq $false)
                    {
                        $issue = "The device has a remediation state that is not valid."
                        Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                        Write-Host $issue -ForegroundColor Red
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($autopilotReadiness.EnrollmentStateGood -eq $false)
                    {
                        $issue = "The device failed enrollment."
                        Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                        Write-Host $issue -ForegroundColor Red
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($settings.includeEnrolledDevicesInNextUserReadiness -and $enrollmentState.Managed -and $null -ne $managedDeviceReadiness)
                    {
                        if ($managedDeviceReadiness.OrphanDevice -eq $true)
                        {
                            $issue = "The device is an orphan device."
                            Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                            Write-Host $issue -ForegroundColor Red
                            $allIssues += $issue
                            $actionsPriority[$deviceActions.contactAdmin] = 3
                        }
                        if ($managedDeviceReadiness.CorrectRam -eq $false)
                        {
                            $issue = "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                            Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                            Write-Host $issue -ForegroundColor Red
                            Write-Host "      " -NoNewline
                            Write-Host "Contact Hardware and Logistics." -ForegroundColor Cyan
                            $allIssues += $issue
                            $actionsPriority[$deviceActions.contactAdmin] = 3
                        }
                        if ($managedDeviceReadiness.HasUser)
                        {
                            $issue = "The managed device is associated with a user."
                            Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                            Write-Host $issue -ForegroundColor Red
                            Write-Host "      " -NoNewline
                            Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device." -ForegroundColor Cyan
                            $allIssues += $issue
                            $actionsPriority[$deviceActions.WipeOrClean] = 2  # Higher priority action
                        }
                        if ($managedDeviceReadiness.ValidUser -eq $false)
                        {
                            $issue = "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                            Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                            Write-Host $issue -ForegroundColor Red
                            Write-Host "      " -NoNewline
                            Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device." -ForegroundColor Cyan
                            $allIssues += $issue
                            $actionsPriority[$deviceActions.WipeOrClean] = 2  # Higher priority action
                        }
                        if ($deviceLastContactDate.withinThreshold -eq $false -and -not ($enrollmentState.autopilot.device.enrollmentState -eq 'notContacted'))
                        {
                            $issue = "The device has not contacted Intune in $($deviceLastContactDate.numberOfDaysSinceLastContact) days."
                            Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                            Write-Host $issue -ForegroundColor Red
                            Write-Host "      " -NoNewline
                            Write-Host "Please check the device's network connectivity and ensure it can reach Intune." -ForegroundColor Cyan
                            $allIssues += $issue
                            $actionsPriority[$deviceActions.connectToNetwork] = 2  # Priority 2 - fix connectivity
                        }
                    }
                    elseif (-not $settings.includeEnrolledDevicesInNextUserReadiness -and $enrollmentState.Managed)
                    {
                        $issue = "The device appears to have already been enrolled. Devices must not be enrolled to be considered ready for the next user."
                        Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
                        Write-Host $issue -ForegroundColor Red
                        $allIssues += $issue                            
                        $actionsPriority[$deviceActions.WipeOrClean] = 2
                    }                           

                    # Determine the primary action based on priority (lower number = higher priority)
                    if ($actionsPriority.Count -gt 0)
                    {
                        $action = ($actionsPriority.GetEnumerator() | Sort-Object Value)[0].Key
                        $allActions = @($actionsPriority.Keys)  # Force array with @()
                    }
                    else
                    {
                        $action = $deviceActions.none
                        $allActions = @($deviceActions.none)
                    }
                    
                    # Display recommended actions summary
                    Write-Host "`nRecommended Actions:" -ForegroundColor Yellow
                    Write-Host "  Primary: " -NoNewline
                    Write-Host $action -ForegroundColor Cyan
                    if ($allActions.Count -gt 1)
                    {
                        Write-Host "  All Actions:" -ForegroundColor Yellow
                        $allActions | ForEach-Object {
                            Write-Host "    - $_" -ForegroundColor Cyan
                        }
                    }
                    
                    # Provide specific guidance based on primary action
                    Write-Host "`nGuidance:" -ForegroundColor Yellow
                    switch ($action)
                    {
                        $deviceActions.turnOnDevice
                        {
                            Write-Host "  Turn on the device and allow it to complete pending actions." -ForegroundColor Cyan
                            Write-Host "  This may take several minutes. Check the device status in Intune portal." -ForegroundColor Cyan
                        }
                        $deviceActions.contactAdmin
                        {
                            Write-Host "  Contact your Intune administrator for assistance." -ForegroundColor Cyan
                        }
                        $deviceActions.WipeOrClean
                        {
                            Write-Host "  Wipe or clean the device before assigning to the next user." -ForegroundColor Cyan
                        }
                        $deviceActions.connectToNetwork
                        {
                            Write-Host "  Connect the device to the network and allow it to sync with Intune." -ForegroundColor Cyan
                        }
                        $deviceActions.none
                        {
                            Write-Host "  No specific guidance available for this device state." -ForegroundColor DarkGray
                        }
                    }
                    Write-Host "===================================`n" -ForegroundColor Cyan
                }
            }
            else
            {
                Write-Host "The device is not registered in Autopilot."
                Write-Host "You may want to contact an Intune admin."
                $readinessState = $deviceStates.notReady
                $action = $deviceActions.contactAdmin
                $device = if ($enrollmentState.managedDevice -and $enrollmentState.managedDevice.device.id)
                { 
                    $enrollmentState.managedDevice.device.id 
                }
                else
                { 
                    $null 
                }
                $allIssues = @("The device is not registered in Autopilot.")
                $allActions = @($deviceActions.contactAdmin)
            }
        }
        'TroubleShooting'
        {
            Write-Host "Place holder text..."
            Write-Host "Troubleshooting the device..."
        }
    }        
    # Ensure variables are initialized for all code paths
    if (-not $allIssues)
    {
        $allIssues = @() 
    }
    if (-not $allActions)
    {
        $allActions = @($action) 
    }
    
    # Build comprehensive return object (maintains backward compatibility)
    $returnValue.Add('ReadinessState', $readinessState)
    $returnValue.Add('Action', $action)  # Primary action (backward compatibility)
    $returnValue.Add('Device', $device)
    
    # Enhanced information for comprehensive issue reporting
    $returnValue.Add('AllIssues', $allIssues)  # Array of all issues found
    $returnValue.Add('AllActions', $allActions)  # Array of all recommended actions
    $returnValue.Add('IssueCount', $allIssues.Count)  # Number of issues found
    $returnValue.Add('IsReady', ($readinessState -eq $deviceStates.ready))  # Boolean readiness check
    
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning readiness state: $readinessState" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning primary action: $action" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning device: $device" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($allIssues.Count) issues: $($allIssues -join '; ')" -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "All actions needed: $($allActions -join '; ')" -LogLevel "Information"
    return $returnValue
}
