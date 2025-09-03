function ShowDeviceReport()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'EnrollmentState')]
        $enrollmentState,
        [Parameter(Mandatory = $true, ParameterSetName = 'HashTable')]
        [hashtable]$report,
        [Parameter(Mandatory = $false)]
        [string[]]$PrefixList = @('Intune', 'Autopilot'),
        [string]$DeviceName,
        [Parameter(Mandatory = $false)]
        [string]$SerialNumber
    )
    #region usage info
    # Use with enrollment state (original ShowDeviceReport functionality)
    #ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber
    # Use with hashtable (original DisplayReport functionality)
    #Show-DeviceReport -report $myHashtable -PrefixList @('Custom', 'Prefix')
    # Direct export without prompting
    #Show-DeviceReport -enrollmentState $state -Export -ExportFormat "CSV"   
    #endregion usage info
    $functionName = $MyInvocation.MyCommand.Name
    #region write verbose log of received parameters
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Starting device report generation" -LogLevel "Verbose"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Parameter Set: $($PSCmdlet.ParameterSetName)" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Export: $Export" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "ExportFormat: $ExportFormat" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "OutputFile: $OutputFile" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "PrefixList: $($PrefixList -join ', ')" -LogLevel "Information"
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Enrollment state provided" -LogLevel "Information"
    }
    else
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Report hashtable provided with $($report.Keys.Count) properties" -LogLevel "Information"
    }
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "DeviceName: $DeviceName" -LogLevel "Information"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "SerialNumber: $SerialNumber" -LogLevel "Information"
    #endregion write verbose log of received parameters
    #region Build report data
    $output = [ordered]@{}
    
    if ($PSCmdlet.ParameterSetName -eq 'EnrollmentState')
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Building report from enrollment state" -LogLevel "Information"
        
        # Get latest autopilot event
        if ($enrollmentState.autopilot.events -and $enrollmentState.autopilot.events.Count -gt 0)
        {
            $latestAutopilotEvent = $enrollmentState.autopilot.events | Select-Object -First 1
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($enrollmentState.autopilot.events.Count) autopilot events" -LogLevel "Verbose"
        }
        else
        {
            $latestAutopilotEvent = $null
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No autopilot events found" -LogLevel "Verbose"
        }
        
        $output = [ordered] @{
            InputIdentifier               = $SerialNumber
            IntuneDeviceName              = $enrollmentState.managedDevice.device.deviceName
            IntuneSerialNumber            = $enrollmentState.managedDevice.device.serialNumber
            IntuneDeviceMemory            = "$($enrollmentState.managedDevice.memory) GB"
            IntuneManagedDeviceId         = $enrollmentState.managedDevice.device.Id
            IntuneEnrollmentDate          = if ($enrollmentState.managedDevice.device.enrolledDateTime)
            {
                $enrollmentState.managedDevice.device.enrolledDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneLastSync                = if ($enrollmentState.managedDevice.device.lastSyncDateTime)
            {
                $enrollmentState.managedDevice.device.lastSyncDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneEnrollmentProfile       = $enrollmentState.managedDevice.device.enrollmentProfileName
            IntunePrimaryUPN              = $enrollmentState.managedDevice.device.userPrincipalName
            IntuneAzureUser               = $enrollmentState.managedDevice.users.AzureUser
            IntuneUserDisplayName         = $enrollmentState.managedDevice.users.userDisplayName
            IntuneReportedUserDisplayName = $enrollmentState.managedDevice.device.userDisplayName
            IntuneLastLogon               = if ($enrollmentState.managedDevice.users.lastLogOnDateTime)
            {
                $enrollmentState.managedDevice.users.lastLogOnDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneActionResults           = $enrollmentState.managedDevice.device.deviceActionResults
            IntuneCertExpiration          = if ($enrollmentState.managedDevice.device.managementCertificateExpirationDate)
            {
                $enrollmentState.managedDevice.device.managementCertificateExpirationDate | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneComplianceExpiry        = if ($enrollmentState.managedDevice.device.complianceGracePeriodExpirationDateTime)
            {
                $enrollmentState.managedDevice.device.complianceGracePeriodExpirationDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            IntuneAutopilotEnrolled       = $enrollmentState.managedDevice.device.autopilotEnrolled
            IntuneRegistrationState       = $enrollmentState.managedDevice.device.deviceRegistrationState
            IntuneIsEncrypted             = $enrollmentState.managedDevice.device.isEncrypted
            IntuneEnrollmentType          = $enrollmentState.managedDevice.device.deviceEnrollmentType
            IntunesVersion                = $enrollmentState.managedDevice.device.sVersion
            IntuneComplianceState         = $enrollmentState.managedDevice.device.complianceState
            IntuneManagementState         = $enrollmentState.managedDevice.device.managementState
            IntuneOwnerType               = $enrollmentState.managedDevice.device.managedDeviceOwnerType
            AutopilotDeviceId             = $enrollmentState.autopilot.device.id
            AutopilotState                = $enrollmentState.autopilot.device.enrollmentState
            AutopilotProfileAssigned      = $enrollmentState.autopilot.device.deploymentProfileAssignmentStatus
            AutopilotProfileAssignedDate  = if ($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime)
            {
                $enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotProfileName          = $enrollmentState.autopilot.device.deploymentProfile.displayName
            AutopilotAssignedUser         = $enrollmentState.autopilot.device.userPrincipalName
            AutopilotLastContacted        = if ($enrollmentState.autopilot.device.lastContactedDateTime)
            {
                $enrollmentState.autopilot.device.lastContactedDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotLatestEventTime      = if ($latestAutopilotEvent -and $latestAutopilotEvent.eventDateTime)
            {
                $latestAutopilotEvent.eventDateTime | FormatDateWithTimeZone 
            }
            else
            {
                $null 
            }
            AutopilotLatestProfile        = $latestAutopilotEvent.windowsAutopilotDeploymentProfileDisplayName
            AutopilotLatestStatus         = $latestAutopilotEvent.deploymentState
            AutopilotLatestError          = $latestAutopilotEvent.enrollmentFailureDetails
        }
        
        # Set device name for export if not provided
        if (-not $DeviceName)
        {
            $DeviceName = $enrollmentState.managedDevice.device.deviceName
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Using provided report hashtable" -LogLevel "Information"
        $output = $report
    }
    #endregion Build report data
    
    #region Format property names and display report
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Formatting output for display" -LogLevel "Information"
    $formattedOutput = [System.Collections.Specialized.OrderedDictionary]::new()
    
    foreach ($key in $output.Keys)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing property: $key" -LogLevel "Verbose"
        
        # Format the property name to be more readable
        $readableKey = $key
        $matchedPrefix = $null
        
        # Check for prefix matches
        foreach ($prefix in $PrefixList)
        {
            if ($key -match "^($prefix)(.+)$")
            {
                $matchedPrefix = $prefix
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found prefix '$prefix' for key '$key'" -LogLevel "Verbose"
                break
            }
        }
        
        if ($matchedPrefix)
        {
            $prefix = $matches[1]
            $remainder = $matches[2]
            # Insert spaces before capital letters in the remainder
            $formattedRemainder = [regex]::Replace($remainder, '(?<=[a-z])(?=[A-Z])', ' ')
            $readableKey = "$prefix $formattedRemainder"
        }
        else
        {
            # Insert spaces before capital letters
            $readableKey = [regex]::Replace($key, '(?<=[a-z])(?=[A-Z])', ' ')
        }
        
        # Format the value based on type
        $formattedValue = $output[$key]
        if ($output[$key] -is [DateTime])
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Formatting DateTime value for key '$key'" -LogLevel "Information"
            $formattedValue = FormatDateWithTimeZone -DateTime $output[$key]
        }
        elseif ($null -eq $output[$key])
        {
            $formattedValue = "N/A"
        }
        
        $formattedOutput[$readableKey] = $formattedValue
        
        # Display each property and value
        Write-Host "$readableKey`: $formattedValue"
    }
    Write-Verbose "[$functionName] Formatted $($formattedOutput.Keys.Count) properties for display"    #endregion Format property names and display report
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Formatted $($formattedOutput.Keys.Count) properties for display"    #endregion Format property names and display report" -LogLevel "Information"
    #endregion Display report
    
    #region Handle export decision
    $HTMLAction = {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected HTML export" -LogLevel "Information"
        $exportResult = ExportDeviceReport -formattedOutput $formattedOutput -ExportFormat "HTML"
        if ($exportResult)
        {
            Write-Host "Report exported to HTML successfully."
        }
        else
        {
            Write-Host "Failed to export report to HTML."
        }
        return $exportResult 
    } 
    $CSVAction = {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected CSV export" -LogLevel "Information"
        $exportResult = ExportDeviceReport -formattedOutput $formattedOutput -ExportFormat "CSV"
        if ($exportResult)
        {
            Write-Host "Report exported to CSV successfully."
        }
        else
        {
            Write-Host "Failed to export report to CSV."
        }
        return $exportResult 
    } 
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Prompting user for export decision" -LogLevel "Information"
    # Create report export menu from configuration
    $reportExportMenu = NewMenu -MenuName "reportExportMenu"
    if (-not $reportExportMenu) {
        # Fallback to manual creation if config not found
        $reportExportMenu = NewMenu -Title "Export report" -Description "Select the format to which you would like to export the report"
    }
    $reportExportMenu = AddMenuItem -Menu $reportExportMenu -Name "Export to HTML" -Action $HTMLAction -ReturnsValue
    $reportExportMenu = AddMenuItem -Menu $reportExportMenu -Name "Export to CSV" -Action $CSVAction -ReturnsValue
    $selection = ShowMenu -Menu $reportExportMenu -CalledBy 'Action'

    if ($null -ne $selection )
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned: '$selection' (Type: $($selection.GetType().Name))" -LogLevel "Information"
        # Validate that we got a proper selection, not a navigation option
        if ($selection -eq "Back" -or $selection -eq "Main Menu" -or $selection -eq 0 -or $selection -eq "0")
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned navigation option: '$selection', treating as navigation" -LogLevel "Information"
            return $selection
        }
    }
    else
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "No export selected. Exiting." -LogLevel "Information"
        return $null
    }
    #endregion Handle export decision
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device report generation completed" -LogLevel "Information"
    return $true
}

