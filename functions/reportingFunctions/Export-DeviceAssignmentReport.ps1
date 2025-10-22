function Export-DeviceAssignmentReport()
{
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
        [switch]$RefreshCache,
        [int]$CacheExpirationMinutes = 15
    )

    #region Define variables.
    $functionName = $MyInvocation.MyCommand
    $currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
    $outputFile = "$outputPath\$reportType-DeviceList-$currentDateTime.csv"
    $CSVObject = [System.Collections.ArrayList]@()
    $returnObject = @{
        ReportType  = $reportType
        OutputFile  = $outputFile
        deviceCount = $null
        success     = $false
        message     = ''
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
    
    switch ($reportType)
    {
        'Assigned'
        {
            # Get autopilot devices with assigned users (both userPrincipalName and userDisplayName are populated and not empty)
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering for assigned devices (with user assignment)..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Filtering for assigned devices..."
            
            $processedCount = 0
            $assignedCount = 0
            
            $CSVObject = foreach ($autopilotDevice in $autopilotDevices.value)
            {
                $processedCount++
                
                # Find matching managed device for user assignment information
                $matchingManagedDevice = $managedDevices.value | Where-Object { 
                    $_.serialNumber -eq $autopilotDevice.serialNumber
                }
                
                if ($matchingManagedDevice)
                {
                    # Check if device has a user assigned (both userPrincipalName and userDisplayName must be populated)
                    $hasUserPrincipal = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userPrincipalName)
                    $hasDisplayName = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userDisplayName)
                    
                    if ($hasUserPrincipal -and $hasDisplayName)
                    {
                        $assignedCount++
                        
                        [PSCustomObject]@{
                            SerialNumber         = $autopilotDevice.serialNumber
                            GroupTag             = $autopilotDevice.groupTag
                            DeviceName           = $matchingManagedDevice.deviceName
                            Manufacturer         = $autopilotDevice.manufacturer
                            Model                = $autopilotDevice.model
                            SystemFamily         = $autopilotDevice.systemFamily
                            OSVersion            = $matchingManagedDevice.osVersion
                            EnrollmentState      = $autopilotDevice.enrollmentState
                            DeviceEnrollmentType = $matchingManagedDevice.deviceEnrollmentType
                            AzureADRegistered    = $matchingManagedDevice.azureADRegistered
                            EnrolledDateTime     = $matchingManagedDevice.enrolledDateTime | FormatDateWithTimeZone
                            LastSyncDateTime     = $matchingManagedDevice.lastSyncDateTime | FormatDateWithTimeZone
                            ComplianceState      = $matchingManagedDevice.complianceState
                            OwnerType            = $matchingManagedDevice.managedDeviceOwnerType
                            UserPrincipalName    = $matchingManagedDevice.userPrincipalName
                            UserDisplayName      = $matchingManagedDevice.userDisplayName
                            UserId               = $matchingManagedDevice.userId
                        }
                    }
                }
            }
            $returnObject.deviceCount = $assignedCount
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processed $processedCount autopilot devices, found $assignedCount assigned devices." -LogLevel "Information"
            Write-Verbose "[    $functionName] Processed $processedCount autopilot devices, found $assignedCount assigned devices."
        }
        'Unassigned'
        {
            # Get autopilot devices without assigned users (either userPrincipalName or userDisplayName is missing/empty)
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering for unassigned devices (missing user assignment)..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Filtering for unassigned devices..."
            
            $processedCount = 0
            $unassignedCount = 0
            
            $CSVObject = foreach ($autopilotDevice in $autopilotDevices.value)
            {
                $processedCount++
                
                # Find matching managed device for user assignment information
                $matchingManagedDevice = $managedDevices.value | Where-Object { 
                    $_.serialNumber -eq $autopilotDevice.serialNumber
                }
                
                if ($matchingManagedDevice)
                {
                    # Check if device is missing user assignment (either userPrincipalName or userDisplayName is empty)
                    $hasUserPrincipal = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userPrincipalName)
                    $hasDisplayName = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userDisplayName)
                    
                    if (-not $hasUserPrincipal -or -not $hasDisplayName)
                    {
                        $unassignedCount++
                        
                        [PSCustomObject]@{
                            SerialNumber         = $autopilotDevice.serialNumber
                            GroupTag             = $autopilotDevice.groupTag
                            DeviceName           = $matchingManagedDevice.deviceName
                            Manufacturer         = $autopilotDevice.manufacturer
                            Model                = $autopilotDevice.model
                            SystemFamily         = $autopilotDevice.systemFamily
                            OSVersion            = $matchingManagedDevice.osVersion
                            EnrollmentState      = $autopilotDevice.enrollmentState
                            DeviceEnrollmentType = $matchingManagedDevice.deviceEnrollmentType
                            AzureADRegistered    = $matchingManagedDevice.azureADRegistered
                            EnrolledDateTime     = $matchingManagedDevice.enrolledDateTime | FormatDateWithTimeZone
                            LastSyncDateTime     = $matchingManagedDevice.lastSyncDateTime | FormatDateWithTimeZone
                            ComplianceState      = $matchingManagedDevice.complianceState
                            OwnerType            = $matchingManagedDevice.managedDeviceOwnerType
                            UserPrincipalName    = $matchingManagedDevice.userPrincipalName
                            UserDisplayName      = $matchingManagedDevice.userDisplayName
                            UserId               = $matchingManagedDevice.userId
                        }
                    }
                }
                else
                {
                    # Autopilot device exists but not in managed devices - treat as unassigned
                    $unassignedCount++
                    
                    [PSCustomObject]@{
                        SerialNumber         = $autopilotDevice.serialNumber
                        GroupTag             = $autopilotDevice.groupTag
                        DeviceName           = ''
                        Manufacturer         = $autopilotDevice.manufacturer
                        Model                = $autopilotDevice.model
                        SystemFamily         = $autopilotDevice.systemFamily
                        OSVersion            = ''
                        EnrollmentState      = $autopilotDevice.enrollmentState
                        DeviceEnrollmentType = ''
                        AzureADRegistered    = ''
                        EnrolledDateTime     = ''
                        LastSyncDateTime     = ''
                        ComplianceState      = ''
                        OwnerType            = ''
                        UserPrincipalName    = ''
                        UserDisplayName      = ''
                        UserId               = ''
                    }
                }
            }
            $returnObject.deviceCount = $unassignedCount
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processed $processedCount autopilot devices, found $unassignedCount unassigned devices." -LogLevel "Information"
            Write-Verbose "[    $functionName] Processed $processedCount autopilot devices, found $unassignedCount unassigned devices."
        }
        'Preprovisioned'
        {
            # Get autopilot devices that are enrolled but not yet assigned to users
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Filtering for preprovisioned devices (enrolled without user)..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Filtering for preprovisioned devices..."
            
            $processedCount = 0
            $preprovisionedCount = 0
            
            $CSVObject = foreach ($autopilotDevice in $autopilotDevices.value | Where-Object { $_.enrollmentState -eq 'enrolled' })
            {
                $processedCount++
                
                # Find matching managed device for user assignment information
                $matchingManagedDevice = $managedDevices.value | Where-Object { 
                    $_.serialNumber -eq $autopilotDevice.serialNumber
                }
                
                if ($matchingManagedDevice)
                {
                    # Check if device is enrolled but has no user (both userPrincipalName and userDisplayName must be empty)
                    $hasUserPrincipal = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userPrincipalName)
                    $hasDisplayName = -not [string]::IsNullOrWhiteSpace($matchingManagedDevice.userDisplayName)
                    
                    if (-not $hasUserPrincipal -and -not $hasDisplayName)
                    {
                        $preprovisionedCount++
                        
                        [PSCustomObject]@{
                            SerialNumber         = $autopilotDevice.serialNumber
                            GroupTag             = $autopilotDevice.groupTag
                            DeviceName           = $matchingManagedDevice.deviceName
                            Manufacturer         = $autopilotDevice.manufacturer
                            Model                = $autopilotDevice.model
                            SystemFamily         = $autopilotDevice.systemFamily
                            OSVersion            = $matchingManagedDevice.osVersion
                            EnrollmentState      = $autopilotDevice.enrollmentState
                            DeviceEnrollmentType = $matchingManagedDevice.deviceEnrollmentType
                            AzureADRegistered    = $matchingManagedDevice.azureADRegistered
                            EnrolledDateTime     = $matchingManagedDevice.enrolledDateTime | FormatDateWithTimeZone
                            LastSyncDateTime     = $matchingManagedDevice.lastSyncDateTime | FormatDateWithTimeZone
                            ComplianceState      = $matchingManagedDevice.complianceState
                            OwnerType            = $matchingManagedDevice.managedDeviceOwnerType
                            UserPrincipalName    = $matchingManagedDevice.userPrincipalName
                            UserDisplayName      = $matchingManagedDevice.userDisplayName
                            UserId               = $matchingManagedDevice.userId
                        }
                    }
                }
            }
            $returnObject.deviceCount = $preprovisionedCount
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processed $processedCount enrolled autopilot devices, found $preprovisionedCount preprovisioned devices." -LogLevel "Information"
            Write-Verbose "[    $functionName] Processed $processedCount enrolled autopilot devices, found $preprovisionedCount preprovisioned devices."
        }
        'All'
        {
            # Get all autopilot devices with their assignment status
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exporting all autopilot devices..." -LogLevel "Information"
            Write-Verbose "[    $functionName] Exporting all autopilot devices..."
            
            $matchedCount = 0
            $unmatchedCount = 0
            
            $CSVObject = foreach ($autopilotDevice in $autopilotDevices.value)
            {
                # Find matching managed device for user assignment and additional information
                $matchingManagedDevice = $managedDevices.value | Where-Object { 
                    $_.serialNumber -eq $autopilotDevice.serialNumber
                }
                
                if ($matchingManagedDevice)
                {
                    $matchedCount++
                    
                    [PSCustomObject]@{
                        SerialNumber         = $autopilotDevice.serialNumber
                        GroupTag             = $autopilotDevice.groupTag
                        DeviceName           = $matchingManagedDevice.deviceName
                        Manufacturer         = $autopilotDevice.manufacturer
                        Model                = $autopilotDevice.model
                        SystemFamily         = $autopilotDevice.systemFamily
                        OSVersion            = $matchingManagedDevice.osVersion
                        EnrollmentState      = $autopilotDevice.enrollmentState
                        DeviceEnrollmentType = $matchingManagedDevice.deviceEnrollmentType
                        AzureADRegistered    = $matchingManagedDevice.azureADRegistered
                        EnrolledDateTime     = $matchingManagedDevice.enrolledDateTime | FormatDateWithTimeZone
                        LastSyncDateTime     = $matchingManagedDevice.lastSyncDateTime | FormatDateWithTimeZone
                        ComplianceState      = $matchingManagedDevice.complianceState
                        OwnerType            = $matchingManagedDevice.managedDeviceOwnerType
                        UserPrincipalName    = $matchingManagedDevice.userPrincipalName
                        UserDisplayName      = $matchingManagedDevice.userDisplayName
                        UserId               = $matchingManagedDevice.userId
                    }
                }
                else
                {
                    $unmatchedCount++
                    
                    # Autopilot device without managed device match
                    [PSCustomObject]@{
                        SerialNumber         = $autopilotDevice.serialNumber
                        GroupTag             = $autopilotDevice.groupTag
                        DeviceName           = ''
                        Manufacturer         = $autopilotDevice.manufacturer
                        Model                = $autopilotDevice.model
                        SystemFamily         = $autopilotDevice.systemFamily
                        OSVersion            = ''
                        EnrollmentState      = $autopilotDevice.enrollmentState
                        DeviceEnrollmentType = ''
                        AzureADRegistered    = ''
                        EnrolledDateTime     = ''
                        LastSyncDateTime     = ''
                        ComplianceState      = ''
                        OwnerType            = ''
                        UserPrincipalName    = ''
                        UserDisplayName      = ''
                        UserId               = ''
                    }
                }
            }
            $returnObject.deviceCount = $autopilotDevices.value.Count
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Exported $($autopilotDevices.value.Count) autopilot devices ($matchedCount matched with managed devices, $unmatchedCount unmatched)." -LogLevel "Information"
            Write-Verbose "[    $functionName] Exported $($autopilotDevices.value.Count) autopilot devices ($matchedCount matched, $unmatchedCount unmatched)."
        }
    }
    #export the csv object.
    try
    {
        # Validate that we have data to export
        if ($null -eq $CSVObject -or $CSVObject.Count -eq 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No devices found matching report type '$reportType'. Generated empty report." -LogLevel "Warning"
            Write-Verbose "[    $functionName] No devices found matching report type '$reportType'."
            $returnObject.message = "No devices found matching report type '$reportType'."
            
            # Create empty file with headers for consistency
            $emptyObject = [PSCustomObject]@{
                SerialNumber         = ''
                GroupTag             = ''
                DeviceName           = ''
                Manufacturer         = ''
                Model                = ''
                SystemFamily         = ''
                OSVersion            = ''
                EnrollmentState      = ''
                DeviceEnrollmentType = ''
                AzureADRegistered    = ''
                EnrolledDateTime     = ''
                LastSyncDateTime     = ''
                ComplianceState      = ''
                OwnerType            = ''
                UserPrincipalName    = ''
                UserDisplayName      = ''
                UserId               = ''
            }
            $emptyObject | Export-Csv -Path $outputFile -NoTypeInformation
            $returnObject.success = $true
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
    }

    Write-Verbose "[    $functionName] Export-DeviceAssignmentReport completed successfully. Returning $returnObject."
    return $returnObject
}

