function ProcessSerialNumber()
{
    <#
    .SYNOPSIS
    Processes and displays comprehensive device information for a given serial number.

    .DESCRIPTION
    This function orchestrates device lookup by serial number, retrieves enrollment status,
    and presents formatted device information including Autopilot status, deployment profile
    assignment, management state, and user readiness assessment. It supports both standard
    device lookup and user readiness checking modes.

    .PARAMETER SerialNumber
    The device serial number to process. This parameter is mandatory.

    .PARAMETER AccessToken
    The Microsoft Graph API access token for authentication.

    .PARAMETER Settings
    Optional settings object containing configuration values. Defaults to script-level $settings.

    .PARAMETER CheckUserReadiness
    When specified, performs user readiness assessment instead of standard device lookup.

    .OUTPUTS
    System.Object
    Returns device information and assessment results. When CheckUserReadiness is specified,
    returns user readiness report. Otherwise displays formatted device information to console
    and returns enrollment state object.

    .EXAMPLE
    ProcessSerialNumber -SerialNumber "ABC123456" -AccessToken $token
    ProcessSerialNumber -SerialNumber "ABC123456" -AccessToken $token -CheckUserReadiness

    .NOTES
    Validates and trims serial number input.
    Uses Get-CachedDeviceEnrollmentStatus for efficient lookups with caching.
    Displays formatted device information including:
    - Autopilot enrollment status
    - Deployment profile assignment
    - Management state
    - Device hardware details
    - Import history
    
    When CheckUserReadiness is specified, delegates to GetNextUserReadinessReport.
    Provides detailed logging throughout the lookup process.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$SerialNumber,
        $AccessToken,
        $Settings = $settings,
        [switch]$CheckUserReadiness
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing device lookup for serial number: $SerialNumber" -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Validating serial number: $SerialNumber" -LogLevel "Verbose"
    if ([string]::IsNullOrWhiteSpace($SerialNumber))
    {
        Write-Host "Serial number cannot be empty or null." -ForegroundColor Red
        return $null # Return null to signal no valid serial number
    }
    $SerialNumber = $SerialNumber.Trim()
    Write-Host "`nLooking up device information for serial number: $SerialNumber" -ForegroundColor Cyan
    $enrollmentState = Get-CachedDeviceEnrollmentStatus -SerialNumber $SerialNumber -AccessToken $AccessToken
    if ($enrollmentState)
    {
        $success = $true
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device lookup successful" -LogLevel "Information"
        # Display basic device information
        Write-Host "`n=== Device Information ===" -ForegroundColor Green
        Write-Host "Serial Number: $SerialNumber"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device is managed: $($enrollmentState.managed)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Has device object: $($enrollmentState.hasDeviceObject)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "In Autopilot: $($enrollmentState.inAutopilot)" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device imported: $($enrollmentState.Imported)" -LogLevel "Information"
        if ($CheckUserReadiness)
        {
            return GetNextUserReadinessReport -enrollmentState $enrollmentState
        }
        
        if ($enrollmentState.inAutopilot)
        {
            Write-Host "This device is enrolled in Autopilot."
            #capture the device information since this is the first place we can get it.
            if (-not $enrollmentState.managed)
            {
                Write-Host "Model: $($enrollmentState.autopilot.device.model)"
                Write-Host "Manufacturer: $($enrollmentState.autopilot.device.manufacturer)"
                Write-Host "System Family: $($enrollmentState.autopilot.device.systemFamily)"
                Write-Host "=============================`n" -ForegroundColor Green
                $DeviceAssessmentState = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness'
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assessment state: $DeviceAssessmentState" -LogLevel "Information"
                Write-Verbose "[$functionName] Device Assessment State: $($DeviceAssessmentState | Out-String)"
                write-log -logfile $LogFile -Module "$functionName" -Message "Device assessment state details: $($DeviceAssessmentState | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Debug"
            }
            Write-Host "Deployment profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
            {
                Write-Host "Deployment profile: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host "Deployment Profile Assignment Date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone)"
            }
            else
            {
                Write-Host "This device is not assigned to a deployment profile." -ForegroundColor Yellow
            }
        }
        else
        {
            Write-Host "This device is not enrolled in Autopilot." -ForegroundColor Yellow
            Write-Host "=============================`n" -ForegroundColor Yellow
        }
        if ($enrollmentState.Imported)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Imported in Autopilot: $($enrollmentState.inAutopilot)" -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Imported count: $($enrollmentState.Imported)" -LogLevel "Information"
            if ($enrollmentState.Imported -gt 1)
            {
                Write-Host "This device was imported into Autopilot $($enrollmentState.Imported) times." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice[$enrollmentState.ImportedAutopilotDevice.Count - 1]
            }
            else
            {
                Write-Host "This device was recently imported into Autopilot." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice
            }
            if (-not $enrollmentState.managed)
            {
                Write-Host "However, this device is not currently managed in Intune."
            }
            Write-Host "Here is the latest known import information:"
            Write-Host "Imported Device ID: $($importedDeviceInfo.id)"
            Write-Host "Last import registration id: $($importedDeviceInfo.state.deviceRegistrationId)"
            Write-Host "Last import status: $($importedDeviceInfo.state.deviceImportStatus)"
            Write-Host "Last import error: $($importedDeviceInfo.state.deviceErrorName)"
            Write-Host "Last import error code: $($importedDeviceInfo.state.deviceErrorCode)"
        }
        else
        {
            Write-Verbose "This device was not recently imported into Autopilot."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "This device was not recently imported into Autopilot." -LogLevel "Warning"
        }
        if ($enrollmentState.managed)
        {
            $deviceName = $enrollmentState.managedDevice.device.deviceName
            $model = $enrollmentState.managedDevice.device.model
            $manufacturer = $enrollmentState.managedDevice.device.manufacturer
            $managedDeviceId = $enrollmentState.managedDevice.device.id
            Write-Host "Device Name: $deviceName"
            Write-Host "Model: $model"
            Write-Host "Manufacturer: $manufacturer"
            Write-Host "Status: Managed by Intune" -ForegroundColor Green
            Write-Host "=============================`n" -ForegroundColor Green
            $deviceLastContactDate = GetLastDeviceContactDate -accessToken $accessToken -enrollmentState $enrollmentState
            # Calculate actual calendar days difference based on midnight boundaries
            $today = (Get-Date).Date
            $yesterday = $today.AddDays(-1)
            $dayBeforeYesterday = $today.AddDays(-2)
            if ($null -ne $deviceLastContactDate.latestContactDate)
            {
                $lastContactDate = [DateTime]::Parse($deviceLastContactDate.latestContactDate).Date
            }
            else
            {
                $lastContactDate = $null
            }
            if ($null -ne $lastContactDate)
            {
                if ($lastContactDate -eq $today)
                {
                    $contactMessage = "The device contacted Intune today."
                }
                elseif ($lastContactDate -eq $yesterday)
                {
                    $contactMessage = "The device contacted Intune yesterday."
                }
                elseif ($lastContactDate -eq $dayBeforeYesterday)
                {
                    $contactMessage = "The device contacted Intune the day before yesterday."
                }
                else
                {
                    $contactMessage = "The device contacted Intune $($deviceLastContactDate.numberOfDaysSinceLastContact) days ago."
                }
                if (-not ($deviceLastContactDate.withinThreshold))
                {
                    Write-Host "It has been more than $($deviceLastContactDate.numberOfDaysSinceLastContact) days  since the device has contacted Intune, which is more than $($Settings.deviceContactThresholdInDays) days." -ForegroundColor Red
                    Write-Host "Please connect the device to the Internet overnight to ensure it can receive updates and policies." -ForegroundColor Red
                    Write-Host "Last contact date: $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last contact date: $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone)" -LogLevel "Information"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Number of days since last contact: $($deviceLastContactDate.numberOfDaysSinceLastContact)" -LogLevel "Information"
                    Write-Host "Press any key to continue"
                    $null = Read-Host
                }
                elseif ($deviceLastContactDate.withinThreshold)
                {
                    Write-Host $contactMessage -ForegroundColor Green
                    Write-Host "Last contact date: $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Last contact date: $($deviceLastContactDate.latestContactDate | FormatDateWithTimeZone)" -LogLevel "Information"
                }
                else
                {
                    Write-Host "The last contact date could not be determined."
                }
            }       
            $pendingActions = getDevicePendingActions -enrollmentState $enrollmentState
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Pending actions: $($pendingActions | ConvertTo-Json -Depth $maxJSONDepth)" -LogLevel "Information"
            if ($pendingActions.isPendingAction)
            {
                Write-Host "This device has pending actions:"
                foreach ($action in $pendingActions.pendingActions)
                {
                    Write-Host "- Action name: $($action.actionName)" -ForegroundColor Yellow
                    Write-Host "- Action status: $($action.status)" -ForegroundColor Yellow
                }
                return $returnValues.deviceActionPendingMessage
            }
            else
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "No pending actions for this device." -LogLevel "Information"
            }
            # Create and show device actions menu using main.ps1 menu structure
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting device actions menu loop" -LogLevel "Debug"
            $deviceActionsMenu = NewMenu -MenuName "deviceActionsMenu"
            # Update the title to include the actual device name
            $deviceActionsMenu.Title = $deviceActionsMenu.Title -replace '\$deviceName', $deviceName
            
            #region Check device capabilities and remove unavailable menu items
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking device capabilities to determine available actions" -LogLevel "Verbose"
            
            # Check LAPS credentials availability
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking if device has LAPS credentials." -LogLevel "Verbose"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "LAPS credentials count: $($enrollmentState.managedDevice.laps.credentials.count)" -LogLevel "Information"
            if (-not ($enrollmentState.managedDevice.laps.credentials.count -gt 0))
            {
                Write-Verbose "[$functionName] No LAPS credentials available - removing menu item"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "LAPS Password menu item excluded - no credentials available" -LogLevel "Information"
                $deviceActionsMenu = Remove-MenuItem -Menu $deviceActionsMenu -ItemName "Get LAPS Password"
            }
            
            # Check BitLocker keys availability
            Write-Verbose "[$functionName] Checking if we have bitlocker keys for this device."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "BitLocker recovery key count: $($enrollmentState.managedDevice.bitLocker.value.count)" -LogLevel "Information"
            if ($null -eq $enrollmentState.managedDevice.latestBitlockerKey)
            {
                Write-Verbose "[$functionName] No BitLocker recovery keys available - removing menu item"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "BitLocker Recovery Key menu item excluded - no keys available" -LogLevel "Information"
                $deviceActionsMenu = Remove-MenuItem -Menu $deviceActionsMenu -ItemName "Get BitLocker Recovery Key"
            }
            
            # Check Hardware Password Details availability
            Write-Log -logFile $LogFile -Module "$functionName" -Message "Checking if device has hardware password details." -LogLevel "Verbose"
            if ($null -eq $enrollmentState.managedDevice.hardwarePassword -or $enrollmentState.managedDevice.hardwarePassword.count -eq 0)
            {
                Write-Verbose "[$functionName] No hardware password details available - removing menu item"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Hardware Password Details menu item excluded - no details available" -LogLevel "Information"
                $deviceActionsMenu = Remove-MenuItem -Menu $deviceActionsMenu -ItemName "Get Hardware Password Details"
            }
            #endregion
            
            #region Assign actions to remaining menu items
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Assigning actions to available menu items" -LogLevel "Information"
            
            # Always available actions
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Wipe Device" -Action {
                Write-Host "`nInitiating device wipe for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'wipe' | Out-Null
            }
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action assigned for 'Wipe Device'" -LogLevel "Debug"
            
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Clean Device" -Action {
                Write-Host "`nInitiating device clean for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'clean' -MonitorAction
            }
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action assigned for 'Clean Device'" -LogLevel "Debug"
            
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Sync Device" -Action {
                Write-Host "`nSyncing device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'sync'
            }
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action assigned for 'Sync Device'" -LogLevel "Debug"
            
            # Conditionally available actions - only assign if menu item still exists
            if ($enrollmentState.managedDevice.laps.credentials.count -gt 0)
            {
                $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Get LAPS Password" -Action {
                    GetDeviceLAPSCredentials -enrollmentState $enrollmentState
                    try
                    {
                        Set-Clipboard -Value ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($enrollmentState.managedDevice.LAPS.credentials[0].passwordBase64)))
                        Write-Host "`n LAPS password copied to clipboard." -ForegroundColor Green
                    }
                    catch
                    {
                        Write-Host "`nFailed to copy LAPS password to clipboard. Please check your permissions." -ForegroundColor Red
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to copy LAPS password to clipboard. Error: $_" -LogLevel "Error"
                    }
                }
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "LAPS Password action assigned - credentials available" -LogLevel "Debug"
            }
            
            if ($null -ne $enrollmentState.managedDevice.latestBitlockerKey)
            {
                $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Get BitLocker Recovery Key" -Action {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Sending value of $($enrollmentState.managedDevice.latestBitlockerKey) to GetBitLockerRecoveryKey function." -LogLevel "Information"
                    $bitlockerKey = GetBitLockerRecoveryKey -key $enrollmentState.managedDevice.latestBitlockerKey -accessToken $AccessToken
                    if ($bitlockerKey -ne "`n")
                    {
                        try
                        {
                            Set-Clipboard -Value $bitlockerKey
                            Write-Host "`nBitlocker key copied to clipboard." -ForegroundColor Green
                        }
                        catch
                        {
                            Write-Host "`nFailed to copy Bitlocker key to clipboard. Please check your permissions." -ForegroundColor Red
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to copy Bitlocker key to clipboard. Error: $_" -LogLevel "Error"
                        }
                    }
                }
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "BitLocker Recovery Key action assigned - keys available" -LogLevel "Debug"
            }
            
            if ($null -ne $enrollmentState.managedDevice.hardwarePassword -and $enrollmentState.managedDevice.hardwarePassword.count -gt 0)
            {
                $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Get Hardware Password Details" -Action {
                    Write-Host "`nHardware password details retrieved successfully." -ForegroundColor Green
                    if ($null -ne $enrollmentState.managedDevice.HardwarePassword.currentPassword)
                    {
                        Write-Host "Current hardware password: $($enrollmentState.managedDevice.HardwarePassword.currentPassword)"
                        Set-Clipboard -Value $enrollmentState.managedDevice.HardwarePassword.currentPassword
                        Write-Host "Current hardware password copied to clipboard." -ForegroundColor Green
                    }
                    elseif ($null -ne $enrollmentState.managedDevice.HardwarePassword.previousPasswords -and $enrollmentState.managedDevice.HardwarePassword.previousPasswords.Count -gt 0)
                    {
                        Write-Host "Previous hardware passwords:"
                        foreach ($password in $enrollmentState.managedDevice.HardwarePassword.previousPasswords)
                        {
                            Write-Host " - $password"
                        }
                    }   
                    else 
                    {
                        Write-Host "No hardware password details found."
                    }
                }
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Hardware Password Details action assigned - details available" -LogLevel "Debug"
            }
            
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Restart Device" -Action {
                Write-Host "`nRestarting device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'restart' | Out-Null
            }
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action assigned for 'Restart Device'" -LogLevel "Debug"
            
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Show Device Health Status" -Action {
                $deviceReport = ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device report: $deviceReport" -LogLevel "Information"
                # Handle navigation responses from ShowReport
                if ($deviceReport -eq "Back" -or $deviceReport -eq "back")
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected Back from device selection, returning to previous menu" -LogLevel "Information"
                    return $returnValues.backoutText
                }
                elseif ($deviceReport -eq "Main Menu" -or $deviceReport -eq "main menu")
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected Main Menu from device selection" -LogLevel "Information"
                    return "EXIT_APPLICATION"
                }
                elseif ([string]::IsNullOrWhiteSpace($deviceReport) -or $null -eq $deviceReport)
                {
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "User requested application exit from device selection." -LogLevel "Information"
                    return "EXIT_APPLICATION"
                }        
                elseif ($deviceReport -ne '0' -and $null -ne $deviceReport -and $deviceReport -ne "Back" -and $deviceReport -ne "Main Menu")
                {
                    if ($deviceReport -eq $true -or $deviceReport -in ("Export to HTML", "Export to CSV"))
                    {
                        Write-Host "`nDevice health status displayed successfully." -ForegroundColor Green
                    }
                    else
                    {
                        Write-Host "`nDevice health status could not be displayed." -ForegroundColor Red
                    }
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowDeviceReport returned: $deviceReport" -LogLevel "Information"
                }
                return $returnValues.backoutText
            }
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action assigned for 'Show Device Health Status'" -LogLevel "Debug"
            
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Check next user readiness state" -Action {
                return (GetNextUserReadinessReport -enrollmentState $enrollmentState).ReadinessState
            }
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action assigned for 'Check next user readiness state'" -LogLevel "Debug"
            #endregion
            
            # Show the device actions menu with navigation context
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Showing device actions menu with Depth: $depth, History count: $($History.Count), MenuHistory count: $($MenuHistory.Count)" -LogLevel "Information"
            $result = ShowMenu -Menu $deviceActionsMenu -CalledBy 'Action'
            #endregion Process devices
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device actions menu returned result: $result" -LogLevel "Information"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returning from device actions menu with result: $result" -LogLevel "Information"
            return $result
        }

        else
        {
            Write-Host "This device is not managed in Intune." -ForegroundColor Yellow
            Write-Host "This is normal for a device that has not had a user login yet." -ForegroundColor Gray
        }
        if ($enrollmentState.hasDeviceObject)

        {
            Write-Host "`nDevice object found in Intune." -ForegroundColor Green
            Write-Host "Device ID: $($enrollmentState.device.id)"
            Write-Host "Device Name: $($enrollmentState.device.deviceName)"
            Write-Host "Model: $($enrollmentState.device.model)"
        }
        else
        {
            Write-Host "This device does not have an associated object in Intune." -ForegroundColor Red
        }
    }
    else
    {
        # Explicitly return $null if no enrollmentState
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device lookup failed or no enrollment state found" -LogLevel "Verbose"
        return $null
    }
    
    # Return success status for calling functions
    return $success
}

