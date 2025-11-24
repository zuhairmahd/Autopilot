function ShowDeviceReport()
{
    <#
    .SYNOPSIS
    Displays formatted device report to console and optionally exports to file.

    .DESCRIPTION
    This function presents device information in a formatted, user-friendly display including
    enrollment status, hardware details, assignments, and compliance state. Supports both
    console output and optional file export.

    .PARAMETER enrollmentState
    Enrollment state object with device information. This parameter is mandatory.

    .PARAMETER export
    When specified, exports report to file in addition to console display.

    .PARAMETER outputPath
    Directory path for report export when export switch is used.

    .OUTPUTS
    None. Displays report to console and optionally exports to file.

    .EXAMPLE
    ShowDeviceReport -enrollmentState $state
    ShowDeviceReport -enrollmentState $state -export -outputPath "C:\Reports"

    .NOTES
    Formatted console output with color coding.
    Optional export to text or CSV file.
    Comprehensive device information display.
    Compatible with PowerShell 5.1.
    #>
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
    }
    
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Formatted $($formattedOutput.Keys.Count) properties for display" -LogLevel "Information"
    
    # Use the generic paging function to display the report
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invoking Show-PagedContent for device report with $($formattedOutput.Count) properties" -LogLevel "Verbose"
    Write-Verbose "[$functionName] Invoking Show-PagedContent for device report with $($formattedOutput.Count) properties"
    
    # Convert ordered dictionary to array of key-value pairs for paging
    $reportItems = @()
    foreach ($key in $formattedOutput.Keys)
    {
        $reportItems += [PSCustomObject]@{
            Property = $key
            Value    = $formattedOutput[$key]
        }
    }
    
    # Build title string to avoid nested quote issues
    $reportTitle = "Device Report"
    if ($DeviceName)
    {
        $reportTitle += " - $DeviceName"
    }
    elseif ($SerialNumber)
    {
        $reportTitle += " - $SerialNumber"
    }
    #endregion Format property names and display report
    
    #region Handle menu decision
    $displayAction = {
        write-log -logFile $LogFile -Module "$functionName" -Message "User selected to display report on screen" -LogLevel "Information"
        $pagingResult = Show-PagedContent `
            -Content $reportItems `
            -PageSize 15 `
            -DisplayScriptBlock { param($item); Write-Host "$($item.Property): $($item.Value)" } `
            -Title $reportTitle `
            -ShowPageInfo $false
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Show-PagedContent completed with result: $pagingResult" -LogLevel "Verbose"
        Write-Verbose "[$functionName] Show-PagedContent completed with result: $pagingResult"
        if ($pagingResult -in @('completed', 'quit'))
        {
            Write-Host "Returning to Device Health Menu: $pagingResult" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "Returning to Device Health Menu due to an error: $pagingResult" -ForegroundColor Yellow
        }
        return $pagingResult                
    } 
    $HTMLAction = {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected HTML export" -LogLevel "Information"
        $exportResult = Export-DeviceReport -formattedOutput $formattedOutput -ExportFormat "HTML"
        if ($exportResult.success)
        {
            Write-Host $exportResult.message -ForegroundColor Green
        }
        else
        {
            Write-Host $exportResult.message -ForegroundColor Red
        }
        return $exportResult 
    } 
    $CSVAction = {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "User selected CSV export" -LogLevel "Information"
        $exportResult = Export-DeviceReport -formattedOutput $formattedOutput -ExportFormat "CSV"
        if ($exportResult.success)
        {
            Write-Host $exportResult.message -ForegroundColor Green                 
        }
        else
        {
            Write-Host $exportResult.message -ForegroundColor Red
        }
        return $exportResult 
    } 
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Prompting user for export decision" -LogLevel "Information"
    # Create report menu from configuration
    $reportExportMenu = NewMenu -MenuName "reportExportMenu"
    if (-not $reportExportMenu)
    {
        # Fallback to manual creation if config not found
        $reportExportMenu = NewMenu -Title "Export report" -Description "Select the format to which you would like to export the report"
    }
    $reportExportMenu = AddMenuItem -Menu $reportExportMenu -Name "Display on Screen" -Action $displayAction -ReturnsValue
    $reportExportMenu = AddMenuItem -Menu $reportExportMenu -Name "Export to HTML" -Action $HTMLAction -ReturnsValue
    $reportExportMenu = AddMenuItem -Menu $reportExportMenu -Name "Export to CSV" -Action $CSVAction -ReturnsValue
    
    # Loop to keep showing the menu until user chooses to navigate away
    # Similar approach to ShowGroupAssignments function
    while ($true)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "=== LOOP ITERATION START ===" -LogLevel "Debug"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "About to call ShowMenu with CalledBy 'Custom_DeviceHealthSubmenu' and StackOperation 'Push'" -LogLevel "Debug"
        
        # Use custom CalledBy context with explicit Push to enable auto-pop after action
        # This ensures the menu stays on the stack during loop but pops after each action completes
        $selection = ShowMenu -Menu $reportExportMenu -CalledBy 'Custom_DeviceHealthSubmenu' -StackOperation 'Push'
        
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned. Selection value: '$selection', Type: $(if ($null -eq $selection) { 'null' } else { $selection.GetType().Name })" -LogLevel "Debug"

        # Validate that we got a proper selection, not a navigation option
        if ($selection -eq "Back" -or $selection -eq "Main Menu" -or $selection -eq 0 -or $selection -eq "0")
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned navigation option: '$selection', treating as navigation" -LogLevel "Information"
            return $selection
        }
        
        # If selection is null, user may have navigated away
        if ($null -eq $selection)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "ShowMenu returned null, user may have navigated away" -LogLevel "Information"
            return $null
        }
        
        # If action completed successfully, continue loop to show menu again
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Action completed, returning to Device Health Menu" -LogLevel "Information"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "=== LOOP ITERATION END - continuing ===" -LogLevel "Debug"
    }
    #endregion Handle menu decision
}

