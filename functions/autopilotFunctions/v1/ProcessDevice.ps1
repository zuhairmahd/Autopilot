function ProcessDevice()
{
    <#
    .SYNOPSIS
    Processes a single device for Autopilot import including all workflow steps.

    .DESCRIPTION
    This function orchestrates the complete device processing workflow including preparation,
    import execution, result validation, and status reporting. It serves as the main entry
    point for processing individual devices through the Autopilot import pipeline.

    .PARAMETER device
    Device object containing hardware hash and metadata. This parameter is mandatory.

    .PARAMETER accessToken
    Microsoft Graph API access token. This parameter is mandatory.

    .PARAMETER settings
    Settings object with configuration values.

    .PARAMETER returnValues
    Return values object for status messages.

    .PARAMETER domain
    Optional domain for operations.

    .OUTPUTS
    System.String
    Returns workflow status message indicating import outcome.

    .EXAMPLE
    $result = ProcessDevice -device $deviceObj -accessToken $token -settings $config -returnValues $rv

    .NOTES
    Coordinates preparation, import, and result processing.
    Comprehensive error handling throughout workflow.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $DeviceObject,
        [Parameter(Mandatory = $true)]
        [ValidateSet('import', 'check', 'delete')]
        [string]$action,
        [switch]$CustomImport
    )
    
    #region check and initialize variables
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking access token..."
        
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking access token..." -LogLevel "Verbose"
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token provided." -LogLevel "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Access token not provided. Returning Null."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token not provided. Returning Null." -LogLevel "Information"
        return $null
    }
    Write-Verbose "[$functionName] Processing serial number: $($deviceObject.SerialNumber)."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing serial number: $($deviceObject.SerialNumber)." -LogLevel "Verbose"
    Write-Verbose "[$functionName] Action: $action"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action: $action" -LogLevel "Information"
    Write-Verbose "[$functionName] Custom import: $CustomImport"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Custom import: $CustomImport" -LogLevel "Information"
    $serialNumber = $deviceObject.serialNumber
    Write-Verbose "[$functionName] The serial number is $serialNumber."
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The serial number is $serialNumber." -LogLevel "Information"
    $make = $deviceObject.manufacturer
    Write-Verbose "[$functionName] The manufacturer is $make"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The manufacturer is $make" -LogLevel "Information"
    $model = $deviceObject.model
    Write-Verbose "[$functionName] The model is $model"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "The model is $model" -LogLevel "Information"
    #endregion check and initialize variables
    
    switch ($action)
    {
        'import'
        {
            Write-Verbose "[$functionName] Importing device with serial number $serialNumber."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Importing device with serial number $serialNumber." -LogLevel "Information"
            Write-Host "Checking to make sure the device hash is not already in Intune..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            Write-Verbose "[$functionName] Device assignment check returned: $deviceAssignment"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assignment check returned: $deviceAssignment" -LogLevel "Information"
            if ($null -ne $deviceAssignment -and $deviceAssignment -notin $returnValues.values)
            {
                $assignmentStatusObject = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment 
                Write-Verbose "[$functionName] Device assignment object: $($assignmentStatusObject | ConvertTo-Json -Depth 4)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assignment object IsAssigned=$($assignmentStatusObject.IsAssigned) Status=$($assignmentStatusObject.AssignmentStatus) Category=$($assignmentStatusObject.StatusCategory)" -LogLevel "Information"
                if ($assignmentStatusObject.IsAssigned)
                {
                    return $returnValues.deviceAssignedMessage
                }
                else
                {
                    switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                    {
                        'unassigned'
                        {
                            return $returnValues.deviceNotAssignedMessage
                        }
                        'pending'
                        {
                            return $returnValues.deviceAssignmentPendingMessage
                        }
                    }
                    Write-Host "The device is in Intune but not assigned to a profile." 
                }
                return $returnValues.deviceIsInIntuneMessage 
            }
            else
            {
                Write-Host "The device is not in Intune." 
            }
            
            #region Add the device to Intune
            Write-Host "This will import the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) into Autopilot."
            $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            while ($choice -notin @('yes', 'no'))
            {
                Write-Host "Invalid choice. Please enter 'yes' or 'no'."
                #beep
                $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            }
            if ($choice -eq 'no')
            {
                Write-Host "Import canceled..."
                return $returnValues.backoutText
            }
            $importStart = Get-Date
            $device = ImportAutopilotDevice -DeviceObject $deviceObject -AccessToken $accessToken -GroupTag $settings.GroupTag -AssignedUser $settings.AssignedUser -TimeInSeconds $settings.timeInSeconds -maxWaitTime $settings.maxWaitTime -CustomImport $CustomImport
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "ImportAutopilotDevice function returned: $device" -LogLevel "Information"
            if ($device -eq $returnValues.backoutText)
            {
                Write-Verbose "[$functionName] The import function returned $device."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "The import function returned $device." -LogLevel "Information"
                return $returnValues.backoutText
            }
            $importResult = ProcessImportResult -device $device -returnValues $returnValues
            if ($importResult -ne $returnValues.deviceImportSuccessMessage)
            {
                return $importResult
            }
            Write-Host "Waiting for $($settings.timeInSeconds) seconds to allow for profile assignment."
            Start-Sleep -Seconds $settings.timeInSeconds
            $assignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -WaitForAssignment -waitTimeInSeconds $settings.timeInSeconds -maxWaitTime $settings.maxWaitTime
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "CheckDeviceAssignment function returned: $assignment" -LogLevel "Information"
            return ProcessAssignmentResult -assignment $assignment -importStart $importStart -returnValues $returnValues
            #endregion Add the device to Intune.
        }
        'check'
        {
            Write-Host "Checking device with serial number $serialNumber..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            if ($null -ne $deviceAssignment -and $deviceAssignment -notin $returnValues.values)
            {
                $assignmentStatusObject = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment 
                if ($assignmentStatusObject.IsAssigned)
                {
                    return HandleDeviceEnrollmentState -deviceAssignment $deviceAssignment -serialNumber $serialNumber -accessToken $accessToken -returnValues $returnValues -domain $domain
                }
                else
                {
                    # Handle unassigned devices
                    switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                    {
                        'unassigned'
                        {
                            return $returnValues.deviceNotAssignedMessage
                        }
                        'pending'
                        {
                            return $returnValues.deviceAssignmentPendingMessage
                        }
                    }
                    # Show options for problem devices
                    Write-Host "What would you like to do?"
                    # Create device wait menu from configuration
                    $deviceWaitMenu = NewMenu -MenuName "deviceWaitMenu"
                    if (-not $deviceWaitMenu)
                    {
                        # Fallback to manual creation if config not found
                        $deviceWaitMenu = NewMenu -Title "Options for Device With Serial Number $serialNumber" -Description "Choose what you would like to do with this device:"
                    }
                    else
                    {
                        # Update title with actual serial number
                        $deviceWaitMenu.Title = $deviceWaitMenu.Title -replace '\$serialNumber', $serialNumber
                    }
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Restart the device" -Action {
                        Write-Host "Restarting the device..."
                        Write-Verbose "[$functionName] User chose to restart the device."

                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User chose to restart the device." -LogLevel "Information"
                        if (-not (RestartDevice))
                        {
                            Write-Verbose "[$functionName] RestartDevice function returned false."
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "RestartDevice function returned false." -LogLevel "Information"
                            return $returnValues.noRestartMessage 
                        }
                    }
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Continue to wait for profile assignment" -Action {
                        Write-Host "Continuing to wait for profile assignment..."
                        $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -waitforAssignment -waitTimeInSeconds $settings.timeInSeconds -maxWaitTime $settings.maxWaitTime
                        return $deviceAssignment
                    }
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Delete the device from Autopilot" -Action {
                        Write-Host "Deleting the device from Autopilot..."
                        if (DeleteAutopilotDevice -DeviceIdentifyer $deviceAssignment.id -IdentifyerType 'DeviceId')
                        {
                            Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                            return $returnValues.deviceDeleteSuccessMessage
                        }
                        else
                        {
                            Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                            return $returnValues.deviceDeleteFailedMessage
                        }
                    }
                    $result = ShowMenu -Menu $deviceWaitMenu -CalledBy 'Action'
                    Write-Verbose "[$functionName] Result from device wait menu: $result"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Result from device wait menu: $result" -LogLevel "Information"
                    if ($result -eq $returnValues.backoutText)
                    {
                        Write-Verbose "[$functionName] User selected Back from device wait menu."
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected Back from device wait menu." -LogLevel "Information"
                        return $returnValues.backoutText
                    }
                    elseif ($result -eq "EXIT_APPLICATION")
                    {
                        Write-Verbose "[$functionName] User selected to exit the application."
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected to exit the application." -LogLevel "Information"
                        return "EXIT_APPLICATION"
                    }
                    else 
                    {
                        return $result
                    }
                }
            }
            else
            {
                Write-Host 'The device is not in Autopilot.'
                return $deviceAssignment
            }
        }
        'delete'
        {
            Write-Host "Checking whether the device is in Autopilot..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            if ($deviceAssignment)
            {
                Write-Host "Deleting device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) from Autopilot."
                if (DeleteAutopilotDevice -DeviceIdentifyer $serialNumber -IdentifyerType 'serialNumber')
                {
                    Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                    return $returnValues.deviceDeleteSuccessMessage
                }
                else
                {
                    Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                    return $returnValues.deviceDeleteFailedMessage
                }
            }
            else
            {
                Write-Host "The device with serial number $serialNumber is not in Autopilot." -ForegroundColor Yellow
                Write-Host "No action taken." -ForegroundColor Yellow
                return $returnValues.deviceNotInIntuneMessage 
            }
        }
        default
        {
            Write-Verbose "[$functionName] Invalid action: $action"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invalid action: $action" -LogLevel "Error"
            return $returnValues.unknownErrorMessage
        }
    }
}
