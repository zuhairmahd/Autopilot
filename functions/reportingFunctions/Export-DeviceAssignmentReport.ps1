function Export-DeviceAssignmentReport()
{
    <#
    .SYNOPSIS
    Exports comprehensive device assignment report to CSV file.

    .DESCRIPTION
    This function generates a detailed report of device assignments including profile assignments,
    group memberships, and configuration policies. Exports data to CSV format for analysis and
    reporting purposes.

    .PARAMETER accessToken
    Microsoft Graph API access token. This parameter is mandatory.

    .PARAMETER outputPath
    Directory path where CSV report will be saved. This parameter is mandatory.

    .PARAMETER reportType
    Type of report to generate: 'Assigned', 'Unassigned', 'Preprovisioned', or 'All'. This parameter is mandatory.

    .PARAMETER fileMode
    Specifies whether to 'Append' to or 'Overwrite' the existing CSV file. Default is 'Overwrite'.

    .PARAMETER lastContactDateTime
    Optional datetime filter to include only devices that last contacted on or before this date/time.

    .PARAMETER RefreshCache
    Switch to force refresh of cached device data.

    .PARAMETER CacheExpirationMinutes
    Specifies the cache expiration time in minutes. Default is 15 minutes.

    .OUTPUTS
    System.String
    Returns path to generated CSV file, or error message if export fails.

    .EXAMPLE
    Export-DeviceAssignmentReport -accessToken $token -outputPath "C:\Reports"
    Exports assigned device report to C:\Reports with default settings.

    .EXAMPLE
    Export-DeviceAssignmentReport -accessToken $token -outputPath "C:\Reports" -reportType "Assigned" -fileMode "Append"
    Exports assigned device report to C:\Reports, appending to existing file if present.

    .EXAMPLE
    Export-DeviceAssignmentReport -accessToken $token -outputPath "C:\Reports" -reportType "Unassigned" -lastContactDateTime (Get-Date).AddDays(-30)
    Exports unassigned device report for devices that last contacted more than 30 days ago.

    .NOTES
    Queries device assignments, profiles, and group memberships.
    Creates timestamped CSV file in output directory.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$outputPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Assigned', 'Unassigned', 'Preprovisioned', 'All')]
        [string]$reportType,
        [ValidateSet('Append', 'Overwrite')]
        [string]$fileMode = 'overwrite',
        [datetime]$lastContactDateTime,
        [switch]$RefreshCache,
        [int]$CacheExpirationMinutes = 15
    )

    #region Define variables.
    $functionName = $MyInvocation.MyCommand
    $currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
    $outputFile = "$outputPath\$reportType-DeviceList-$currentDateTime.csv"
    $CSVObject = [System.Collections.ArrayList]@()
    $returnObject = @{
        ReportType          = $reportType
        OutputFile          = $outputFile
        totalDeviceCount    = $null
        filteredDeviceCount = $null
        deviceCount         = $null  # Kept for backward compatibility
        success             = $false
        message             = ''
    }
    #endregion

    #region Fetch device data using Get-DeviceData
    $autopilotDevices = Get-DeviceData -AccessToken $accessToken -DeviceType 'autopilot' -RefreshCache:$RefreshCache -CacheExpirationMinutes $CacheExpirationMinutes
    $managedDevices = Get-DeviceData -AccessToken $accessToken -DeviceType 'managed' -RefreshCache:$RefreshCache -CacheExpirationMinutes $CacheExpirationMinutes

    # Diagnostic logging - check what we actually received
    if ($null -eq $autopilotDevices -or $null -eq $autopilotDevices.value)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "WARNING: No autopilot devices retrieved from API!" -LogLevel "Warning"
        Write-Verbose "[    $functionName] WARNING: No autopilot devices retrieved!"
    }
    if ($null -eq $managedDevices -or $null -eq $managedDevices.value)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "WARNING: No managed devices retrieved from API!" -LogLevel "Warning"
        Write-Verbose "[    $functionName] WARNING: No managed devices retrieved!"
    }
    #endregion

    #region Build combined device objects from autopilot and managed device data
    # Create a hashtable for quick managed device lookup by serial number
    $managedDeviceLookup = @{}
    if ($managedDevices.value)
    {
        write-log -LogFile $LogFile -Module "$functionName" -Message "Building managed device lookup table for $($managedDevices.value.Count) devices..." -LogLevel "Information"
        foreach ($device in $managedDevices.value)
        {
            if (-not [string]::IsNullOrWhiteSpace($device.serialNumber))
            {
                # Normalize serial number by trimming and removing all spaces
                $normalizedSerial = $device.serialNumber.Trim() -replace '\s+', ''
                $managedDeviceLookup[$normalizedSerial] = $device
            }
        }
    }

    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Building combined device objects from $($autopilotDevices.value.Count) autopilot and $($managedDevices.value.Count) managed devices..." -LogLevel "Information"
    Write-Verbose "[    $functionName] Building combined device objects..."

    # Build combined device objects - merge autopilot and managed device properties
    $combinedDevices = foreach ($autopilotDevice in $autopilotDevices.value)
    {
        # Look up matching managed device by serial number (normalize by trimming and removing spaces)
        $normalizedAutopilotSerial = if (-not [string]::IsNullOrWhiteSpace($autopilotDevice.serialNumber))
        {
            $autopilotDevice.serialNumber.Trim() -replace '\s+', ''
        }
        else
        {
            ''
        }
        $matchingManagedDevice = $managedDeviceLookup[$normalizedAutopilotSerial]

        # Determine user assignment status
        $hasUserPrincipal = $false
        $hasDisplayName = $false
        $lastSyncDateTimeParsed = $null

        if ($matchingManagedDevice)
        {
            $hasUserPrincipal = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userPrincipalName)
            $hasDisplayName = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userDisplayName)

            if (-not [string]::IsNullOrWhiteSpace($matchingManagedDevice.lastSyncDateTime))
            {
                try
                {
                    $lastSyncDateTimeParsed = [datetime]::Parse($matchingManagedDevice.lastSyncDateTime)
                }
                catch
                {
                    $lastSyncDateTimeParsed = $null
                }
            }
        }

        # Create combined device object with properties from both sources
        # Autopilot-specific properties: id (autopilotId), groupTag, purchaseOrderIdentifier, serialNumber,
        #   productKey, manufacturer, model, enrollmentState, lastContactedDateTime, addressableUserName,
        #   userPrincipalName (autopilot), resourceName, skuNumber, systemFamily, azureActiveDirectoryDeviceId,
        #   managedDeviceId, displayName
        # Managed device-specific properties: id (managedDeviceId), userId, deviceName, managedDeviceOwnerType,
        #   enrolledDateTime, lastSyncDateTime, operatingSystem, complianceState, osVersion, azureADRegistered,
        #   deviceEnrollmentType, userPrincipalName, userDisplayName, wiFiMacAddress, emailAddress, etc.
        [PSCustomObject]@{
            # Identifiers
            AutopilotId              = $autopilotDevice.id
            ManagedDeviceId          = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.id
            }
            else
            {
                $autopilotDevice.managedDeviceId
            }
            AzureADDeviceId          = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.azureADDeviceId
            }
            else
            {
                $autopilotDevice.azureActiveDirectoryDeviceId
            }
            SerialNumber             = $autopilotDevice.serialNumber

            # Device hardware info (prefer autopilot as source of truth for hardware)
            Manufacturer             = if ($autopilotDevice.manufacturer)
            {
                $autopilotDevice.manufacturer
            }
            else
            {
                if ($matchingManagedDevice)
                {
                    $matchingManagedDevice.manufacturer
                }
                else
                {
                    ''
                }
            }
            Model                    = if ($autopilotDevice.model)
            {
                $autopilotDevice.model
            }
            else
            {
                if ($matchingManagedDevice)
                {
                    $matchingManagedDevice.model
                }
                else
                {
                    ''
                }
            }
            SystemFamily             = if ($autopilotDevice.systemFamily)
            {
                $autopilotDevice.systemFamily
            }
            else
            {
                if ($matchingManagedDevice)
                {
                    $matchingManagedDevice.systemFamily
                }
                else
                {
                    ''
                }
            }
            SkuNumber                = $autopilotDevice.skuNumber
            ProductKey               = $autopilotDevice.productKey

            # Device naming and organization
            DeviceName               = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.deviceName
            }
            else
            {
                $autopilotDevice.displayName
            }
            GroupTag                 = $autopilotDevice.groupTag
            PurchaseOrderIdentifier  = $autopilotDevice.purchaseOrderIdentifier
            ResourceName             = $autopilotDevice.resourceName

            # Enrollment and management state
            EnrollmentState          = $autopilotDevice.enrollmentState
            DeviceEnrollmentType     = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.deviceEnrollmentType
            }
            else
            {
                ''
            }
            AzureADRegistered        = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.azureADRegistered
            }
            else
            {
                ''
            }
            DeviceRegistrationState  = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.deviceRegistrationState
            }
            else
            {
                ''
            }

            # OS and compliance info (from managed device)
            OperatingSystem          = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.operatingSystem
            }
            else
            {
                ''
            }
            OSVersion                = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.osVersion
            }
            else
            {
                ''
            }
            ComplianceState          = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.complianceState
            }
            else
            {
                ''
            }
            IsEncrypted              = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.isEncrypted
            }
            else
            {
                ''
            }
            IsSupervised             = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.isSupervised
            }
            else
            {
                ''
            }

            # Ownership and management
            OwnerType                = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.managedDeviceOwnerType
            }
            else
            {
                ''
            }
            ManagementAgent          = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.managementAgent
            }
            else
            {
                ''
            }

            # User assignment info (from managed device - authoritative source for user assignment)
            UserPrincipalName        = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.userPrincipalName
            }
            else
            {
                ''
            }
            UserDisplayName          = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.userDisplayName
            }
            else
            {
                ''
            }
            UserId                   = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.userId
            }
            else
            {
                ''
            }
            EmailAddress             = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.emailAddress
            }
            else
            {
                ''
            }
            AddressableUserName      = $autopilotDevice.addressableUserName

            # Timestamps
            EnrolledDateTime         = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.enrolledDateTime
            }
            else
            {
                ''
            }
            LastSyncDateTime         = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.lastSyncDateTime
            }
            else
            {
                ''
            }
            LastContactedDateTime    = $autopilotDevice.lastContactedDateTime
            LastSyncDateTimeParsed   = $lastSyncDateTimeParsed

            # Network info
            WiFiMacAddress           = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.wiFiMacAddress
            }
            else
            {
                ''
            }
            EthernetMacAddress       = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.ethernetMacAddress
            }
            else
            {
                ''
            }

            # Storage info
            TotalStorageSpaceInBytes = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.totalStorageSpaceInBytes
            }
            else
            {
                ''
            }
            FreeStorageSpaceInBytes  = if ($matchingManagedDevice)
            {
                $matchingManagedDevice.freeStorageSpaceInBytes
            }
            else
            {
                ''
            }

            # Calculated assignment status flags
            HasUserPrincipal         = $hasUserPrincipal
            HasUserDisplayName       = $hasDisplayName
            IsAssigned               = ($hasUserPrincipal -and $hasDisplayName)
            HasManagedDevice         = ($null -ne $matchingManagedDevice)
        }
    }

    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Built $($combinedDevices.Count) combined device objects." -LogLevel "Information"
    Write-Verbose "[    $functionName] Built $($combinedDevices.Count) combined device objects."
    #endregion

    switch ($reportType)
    {
        'Assigned'
        {
            # Get devices with assigned users (both userPrincipalName and userDisplayName are populated)
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering for assigned devices (with user assignment)..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Filtering for assigned devices..."

            # Filter combined devices for assigned status
            $filteredDevices = $combinedDevices | Where-Object {
                $_.IsAssigned -eq $true -and $_.HasManagedDevice -eq $true
            }

            # Apply lastContactDateTime filter if specified
            if ($PSBoundParameters.ContainsKey('lastContactDateTime'))
            {
                $filteredDevices = $filteredDevices | Where-Object {
                    $null -ne $_.LastSyncDateTimeParsed -and $_.LastSyncDateTimeParsed -le $lastContactDateTime
                }
            }

            $CSVObject = foreach ($device in $filteredDevices)
            {
                [PSCustomObject]@{
                    SerialNumber         = $device.SerialNumber
                    GroupTag             = $device.GroupTag
                    DeviceName           = $device.DeviceName
                    Manufacturer         = $device.Manufacturer
                    Model                = $device.Model
                    SystemFamily         = $device.SystemFamily
                    OSVersion            = $device.OSVersion
                    EnrollmentState      = $device.EnrollmentState
                    DeviceEnrollmentType = $device.DeviceEnrollmentType
                    AzureADRegistered    = $device.AzureADRegistered
                    EnrolledDateTime     = if ([string]::IsNullOrWhiteSpace($device.EnrolledDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.EnrolledDateTime | FormatDateWithTimeZone
                    }
                    LastSyncDateTime     = if ([string]::IsNullOrWhiteSpace($device.LastSyncDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.LastSyncDateTime | FormatDateWithTimeZone
                    }
                    ComplianceState      = $device.ComplianceState
                    OwnerType            = $device.OwnerType
                    UserPrincipalName    = $device.UserPrincipalName
                    UserDisplayName      = $device.UserDisplayName
                    UserId               = $device.UserId
                }
            }

            $returnObject.totalDeviceCount = $combinedDevices.Count
            $returnObject.filteredDeviceCount = @($CSVObject).Count
            $returnObject.deviceCount = $returnObject.filteredDeviceCount  # Backward compatibility
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($returnObject.filteredDeviceCount) assigned devices from $($returnObject.totalDeviceCount) total devices." -LogLevel "Information"
            Write-Verbose "[    $functionName] Found $($returnObject.filteredDeviceCount) assigned devices."
        }
        'Unassigned'
        {
            # Get devices without assigned users (autopilot devices that are not assigned)
            # Unassigned = all autopilot devices minus those with assigned userPrincipalName AND userDisplayName
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering for unassigned devices (missing user assignment)..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Filtering for unassigned devices..."

            # Filter combined devices for unassigned status
            # Device is unassigned if: no managed device match OR missing userPrincipalName OR missing userDisplayName
            $filteredDevices = $combinedDevices | Where-Object {
                $_.IsAssigned -eq $false
            }

            # Apply lastContactDateTime filter if specified (only for devices with managed device data)
            if ($PSBoundParameters.ContainsKey('lastContactDateTime'))
            {
                $filteredDevices = $filteredDevices | Where-Object {
                    # Include devices without managed device (no sync date) OR devices that meet the date filter
                    $_.HasManagedDevice -eq $false -or
                    ($null -ne $_.LastSyncDateTimeParsed -and $_.LastSyncDateTimeParsed -le $lastContactDateTime)
                }
            }

            $CSVObject = foreach ($device in $filteredDevices)
            {
                [PSCustomObject]@{
                    SerialNumber         = $device.SerialNumber
                    GroupTag             = $device.GroupTag
                    DeviceName           = $device.DeviceName
                    Manufacturer         = $device.Manufacturer
                    Model                = $device.Model
                    SystemFamily         = $device.SystemFamily
                    OSVersion            = $device.OSVersion
                    EnrollmentState      = $device.EnrollmentState
                    DeviceEnrollmentType = $device.DeviceEnrollmentType
                    AzureADRegistered    = $device.AzureADRegistered
                    EnrolledDateTime     = if ([string]::IsNullOrWhiteSpace($device.EnrolledDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.EnrolledDateTime | FormatDateWithTimeZone
                    }
                    LastSyncDateTime     = if ([string]::IsNullOrWhiteSpace($device.LastSyncDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.LastSyncDateTime | FormatDateWithTimeZone
                    }
                    ComplianceState      = $device.ComplianceState
                    OwnerType            = $device.OwnerType
                    UserPrincipalName    = $device.UserPrincipalName
                    UserDisplayName      = $device.UserDisplayName
                    UserId               = $device.UserId
                }
            }

            $returnObject.totalDeviceCount = $combinedDevices.Count
            $returnObject.filteredDeviceCount = @($CSVObject).Count
            $returnObject.deviceCount = $returnObject.filteredDeviceCount  # Backward compatibility
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($returnObject.filteredDeviceCount) unassigned devices from $($returnObject.totalDeviceCount) total devices." -LogLevel "Information"
            Write-Verbose "[    $functionName] Found $($returnObject.filteredDeviceCount) unassigned devices."
        }
        'Preprovisioned'
        {
            # Get devices that are enrolled but not yet assigned to users
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering for preprovisioned devices (enrolled without user)..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Filtering for preprovisioned devices..."

            # Filter combined devices for preprovisioned status:
            # - Must be enrolled (enrollmentState -eq 'enrolled')
            # - Must have a managed device record
            # - Must NOT have user assignment (both userPrincipalName AND userDisplayName must be empty)
            $filteredDevices = $combinedDevices | Where-Object {
                $_.EnrollmentState -eq 'enrolled' -and
                $_.HasManagedDevice -eq $true -and
                $_.HasUserPrincipal -eq $false -and
                $_.HasUserDisplayName -eq $false
            }

            # Apply lastContactDateTime filter if specified
            if ($PSBoundParameters.ContainsKey('lastContactDateTime'))
            {
                $filteredDevices = $filteredDevices | Where-Object {
                    $null -ne $_.LastSyncDateTimeParsed -and $_.LastSyncDateTimeParsed -le $lastContactDateTime
                }
            }

            $CSVObject = foreach ($device in $filteredDevices)
            {
                [PSCustomObject]@{
                    SerialNumber         = $device.SerialNumber
                    GroupTag             = $device.GroupTag
                    DeviceName           = $device.DeviceName
                    Manufacturer         = $device.Manufacturer
                    Model                = $device.Model
                    SystemFamily         = $device.SystemFamily
                    OSVersion            = $device.OSVersion
                    EnrollmentState      = $device.EnrollmentState
                    DeviceEnrollmentType = $device.DeviceEnrollmentType
                    AzureADRegistered    = $device.AzureADRegistered
                    EnrolledDateTime     = if ([string]::IsNullOrWhiteSpace($device.EnrolledDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.EnrolledDateTime | FormatDateWithTimeZone
                    }
                    LastSyncDateTime     = if ([string]::IsNullOrWhiteSpace($device.LastSyncDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.LastSyncDateTime | FormatDateWithTimeZone
                    }
                    ComplianceState      = $device.ComplianceState
                    OwnerType            = $device.OwnerType
                    UserPrincipalName    = $device.UserPrincipalName
                    UserDisplayName      = $device.UserDisplayName
                    UserId               = $device.UserId
                }
            }

            $returnObject.totalDeviceCount = $combinedDevices.Count
            $returnObject.filteredDeviceCount = @($CSVObject).Count
            $returnObject.deviceCount = $returnObject.filteredDeviceCount  # Backward compatibility
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found $($returnObject.filteredDeviceCount) preprovisioned devices from $($returnObject.totalDeviceCount) total devices." -LogLevel "Information"
            Write-Verbose "[    $functionName] Found $($returnObject.filteredDeviceCount) preprovisioned devices."
        }
        'All'
        {
            # Get all autopilot devices with their assignment status
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting all autopilot devices..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Exporting all autopilot devices..."

            # Start with all combined devices
            $filteredDevices = $combinedDevices

            # Apply lastContactDateTime filter if specified
            # When date filter is specified, only include devices that have managed device data and meet the date criteria
            # Devices without managed device matches are excluded when filtering by date
            if ($PSBoundParameters.ContainsKey('lastContactDateTime'))
            {
                $filteredDevices = $filteredDevices | Where-Object {
                    $_.HasManagedDevice -eq $true -and
                    $null -ne $_.LastSyncDateTimeParsed -and
                    $_.LastSyncDateTimeParsed -le $lastContactDateTime
                }
            }

            $CSVObject = foreach ($device in $filteredDevices)
            {
                [PSCustomObject]@{
                    SerialNumber         = $device.SerialNumber
                    GroupTag             = $device.GroupTag
                    DeviceName           = $device.DeviceName
                    Manufacturer         = $device.Manufacturer
                    Model                = $device.Model
                    SystemFamily         = $device.SystemFamily
                    OSVersion            = $device.OSVersion
                    EnrollmentState      = $device.EnrollmentState
                    DeviceEnrollmentType = $device.DeviceEnrollmentType
                    AzureADRegistered    = $device.AzureADRegistered
                    EnrolledDateTime     = if ([string]::IsNullOrWhiteSpace($device.EnrolledDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.EnrolledDateTime | FormatDateWithTimeZone
                    }
                    LastSyncDateTime     = if ([string]::IsNullOrWhiteSpace($device.LastSyncDateTime))
                    {
                        ''
                    }
                    else
                    {
                        $device.LastSyncDateTime | FormatDateWithTimeZone
                    }
                    ComplianceState      = $device.ComplianceState
                    OwnerType            = $device.OwnerType
                    UserPrincipalName    = $device.UserPrincipalName
                    UserDisplayName      = $device.UserDisplayName
                    UserId               = $device.UserId
                }
            }

            $matchedCount = ($combinedDevices | Where-Object { $_.HasManagedDevice -eq $true }).Count
            $unmatchedCount = ($combinedDevices | Where-Object { $_.HasManagedDevice -eq $false }).Count

            $returnObject.totalDeviceCount = $combinedDevices.Count
            $returnObject.filteredDeviceCount = @($CSVObject).Count
            $returnObject.deviceCount = $returnObject.filteredDeviceCount  # Backward compatibility
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exported $($returnObject.filteredDeviceCount) devices from $($returnObject.totalDeviceCount) total ($matchedCount matched with managed devices, $unmatchedCount unmatched)." -LogLevel "Information"
            Write-Verbose "[    $functionName] Exported $($returnObject.filteredDeviceCount) devices ($matchedCount matched, $unmatchedCount unmatched)."
        }
    }
    #export the csv object.
    try
    {
        # Validate that we have data to export
        if ($null -eq $CSVObject -or $CSVObject.Count -eq 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No devices found matching report type '$reportType'. No file created." -LogLevel "Warning"
            Write-Verbose "[    $functionName] No devices found matching report type '$reportType'."
            $returnObject.message = "No devices found matching report type '$reportType'. No file created."
            $returnObject.OutputFile = $null
            $returnObject.success = $true
            Write-Verbose "[    $functionName] Export-DeviceAssignmentReport completed successfully. Returning $($returnObject | ConvertTo-Json -Compress)"
            return $returnObject
        }

        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting $($CSVObject.Count) devices to report." -LogLevel "Information"
        Write-Verbose "[    $functionName] Exporting $($CSVObject.Count) devices to report."
        if ($fileMode -eq 'Append' -and (Test-Path -Path $outputFile))
        {
            $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Append
        }
        else
        {
            $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation
        }
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Device assignment report exported to $outputFile ($($CSVObject.Count) devices)" -LogLevel "Information"
        Write-Verbose "[    $functionName] Device assignment report exported to $outputFile ($($CSVObject.Count) devices)"
        $returnObject.success = $true
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to export device assignment report to $outputFile. Error: $_" -LogLevel "Error"
        Write-Verbose "[    $functionName] Failed to export device assignment report to $outputFile. Error: $_"
        $returnObject.success = $false
        $returnObject.OutputFile = $null
        $returnObject.message = "Failed to export device assignment report to $outputFile. Error: $_"
    }
    Write-Verbose "[    $functionName] Export-DeviceAssignmentReport completed successfully. Returning $($returnObject | ConvertTo-Json -Compress)"
    return $returnObject
}

