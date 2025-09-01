function AssessDeviceState() 
{
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
                if (-not ($enrollmentState.autopilot.device.enrollmentState -eq 'notContacted'))
                {   
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting managed device properties." -LogLevel "Information"
                    $managedDeviceReadiness = GetManagedDeviceRelevantProperties -enrollmentState $enrollmentState
                    $memoryMessage = "`n"
                }
                else 
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device enrollment state is 'notContacted', skipping managed device readiness check." -LogLevel "Information"
                    $memoryMessage = "We could not determine whether the device has the required $($settings.MinimumDevicePhysicalMemoryInGB ) GB of RAM. `n Please manually verify that the device has $($settings.MinimumDevicePhysicalMemoryInGB ) GB of RAM before proceeding."
                }
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
                Write-Verbose "Autopilot assignment good: $($autopilotReadiness.AutopilotAssignmentGood)"
                Write-Verbose "Managed device readiness good: $($managedDeviceReadiness.ReadyForNextUser)"
                Write-Host "Within threshold: $($deviceLastContactDate.withinThreshold)"
                if (($autopilotReadiness.AutopilotAssignmentGood -and $managedDeviceReadiness.ReadyForNextUser) -or ($autopilotReadiness.AutopilotAssignmentGood -and $enrollmentState.autopilot.device.enrollmentState -eq 'notContacted' -and $enrollmentState.managed -eq $false) -and $deviceLastContactDate.withinThreshold)
                {
                    Write-Host "The device is ready for the next user."
                    Write-Host $memoryMessage
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
                    Write-Host "The device is not ready for the next user."
                    Write-Host "See below for more information."
                    
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
                    
                    # Check all possible issues and collect them
                    if ($autopilotReadiness.CorrectProfile -eq $false)
                    {
                        $issue = "The device is not assigned to the correct autopilot profile."
                        Write-Host $issue
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($autopilotReadiness.ProfileAssigned -eq $false)
                    {
                        $issue = "The device is not assigned to an autopilot profile."
                        Write-Host $issue
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($autopilotReadiness.RemediationStateGood -eq $false)
                    {
                        $issue = "The device has a remediation state that is not valid."
                        Write-Host $issue
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($autopilotReadiness.EnrollmentStateGood -eq $false)
                    {
                        $issue = "The device failed enrollment."
                        Write-Host $issue
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($managedDeviceReadiness.OrphanDevice -eq $true)
                    {
                        $issue = "The device is an orphan device."
                        Write-Host $issue
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($managedDeviceReadiness.CorrectRam -eq $false)
                    {
                        $issue = "The device has only $($enrollmentState.managedDevice.memory)GB of RAM, which is below the $($settings.MinimumDevicePhysicalMemoryInGB)GB desired requirement."
                        Write-Host $issue
                        Write-Host "Contact Hardware and Logistics."
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.contactAdmin] = 3
                    }
                    if ($managedDeviceReadiness.HasUser)
                    {
                        $issue = "The managed device is associated with a user."
                        Write-Host $issue
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.WipeOrClean] = 2  # Higher priority action
                    }
                    if ($managedDeviceReadiness.ValidUser -eq $false)
                    {
                        $issue = "The device appears to be associated with an SPN or a user that no longer exists in Azure AD."
                        Write-Host $issue
                        Write-Host "It is advisable to remove the managed device from Intune prior to having the user enroll the device."
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.WipeOrClean] = 2  # Higher priority action
                    }
                    if ($deviceLastContactDate.withinThreshold -eq $false)
                    {
                        $issue = "The device has not contacted Intune in $($deviceLastContactDate.numberOfDaysSinceLastContact) days."
                        Write-Host $issue
                        Write-Host "Please check the device's network connectivity and ensure it can reach Intune."
                        $allIssues += $issue
                        $actionsPriority[$deviceActions.connectToNetwork] = 1  # Highest priority - fix connectivity first
                    }
                    
                    # Determine the primary action based on priority (lower number = higher priority)
                    if ($actionsPriority.Count -gt 0)
                    {
                        $action = ($actionsPriority.GetEnumerator() | Sort-Object Value)[0].Key
                        $allActions = $actionsPriority.Keys
                    }
                    else
                    {
                        $action = $deviceActions.none
                        $allActions = @($deviceActions.none)
                    }
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
