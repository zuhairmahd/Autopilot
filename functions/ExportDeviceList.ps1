function ExportDeviceList()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$outputPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet('autopilot', 'imported', 'unmanaged', 'managed')]
        [string]$deviceType,
        [ValidateSet('Append', 'Overwrite')]
        [string]$fileMode = 'overwrite'
    )

    #region Define variables.
    $functionName = $MyInvocation.MyCommand
    $currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
    $outputFile = "$outputPath\$deviceType-DeviceList-$currentDateTime.csv"
    $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
    # $autopilotExtraParameters = "select=serialNumber,groupTag,manufacturer,model,systemFamily,enrollmentState,deploymentProfileAssignmentStatus"
    $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
    $importedAutopilotExtraParameters = "select=serialNumber,importId,groupTag,state"
    $unmanagedDeviceUri = "devices"
    $unmanagedDeviceFilter = "operatingSystem eq 'Windows'"
    $unmanagedDeviceExtraParameters = "select=id,displayName,manufacturer,model,operatingSystemVersion,profileType,createdDateTime,registrationDateTime,accountEnabled,approximateLastSignInDateTime,enrollmentProfileName,enrollmentType,isCompliant"
    $managedDeviceUri = "deviceManagement/managedDevices"
    $managedDeviceFilter = "operatingSystem eq Windows"
    $managedDeviceExtraParameters = "select=serialNumber,deviceName,manufacturer,model,osVersion,autopilotEnrolled,enrolledDateTime,lastSyncDateTime,complianceState,userPrincipalName,userDisplayName,usersLoggedOn"
    $CSVObject = [System.Collections.ArrayList]@()
    $success = $false
    #endregion

    #region Prepare export object
    switch ($deviceType )
    {
        'autopilot'
        {
            Write-Verbose "[$functionName] fetching Autopilot devices."
            $devices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) Autopilot devices."
        }
        'imported'
        {
            Write-Verbose "[$functionName] fetching Imported Autopilot devices."
            $devices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -extraParameters $importedAutopilotExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) imported Autopilot devices."
        }
        'unmanaged'
        {
            Write-Verbose "[$functionName] fetching Unmanaged devices."
            $devices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken -filter $unmanagedDeviceFilter -extraParameters $unmanagedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) unmanaged devices."
        }
        'managed'
        {
            Write-Verbose "[$functionName] fetching Managed devices."
            $devices = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken -filter $managedDeviceFilter -extraParameters $managedDeviceExtraParameters
            Write-Verbose "[$functionName] Fetched $($devices.value.Count) managed devices."
        }
    }
    
    Write-Verbose "[$functionName] Processing $($devices.value.Count) $deviceType devices for export."
    for ($i = 0; $i -lt $devices.value.count; $i++)
    {
        $device = $devices.value[$i]
        if (-not $device)
        {
            Write-Verbose "[$functionName] Skipping null or invalid $deviceType device at index $i."
            continue
        }
        switch ($deviceType)
        {
            'autopilot'
            {
                Write-Verbose "[$functionName] Preparing $deviceType device with serial number $($device.serialNumber) for export."
                if ($null -ne $device.lastContactedDateTime)
                {
                    $lastContactedDateTime = $device.lastContactedDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    serialNumber                      = $device.serialNumber
                    groupTag                          = $device.groupTag
                    manufacturer                      = $device.manufacturer
                    model                             = $device.model
                    systemFamily                      = $device.systemFamily
                    enrollmentState                   = $device.enrollmentState
                    deploymentProfileAssignmentStatus = $device.deploymentProfileAssignmentStatus
                    lastContactedDateTime             = $lastContactedDateTime
                }
            }
            'imported'
            {
                Write-Verbose "[$functionName] Preparing $deviceType device with serial number $($device.serialNumber) for export."
                $exportObject = [PSCustomObject] @{
                    serialNumber         = $device.serialNumber
                    importId             = $device.importId
                    groupTag             = $device.groupTag
                    importStatus         = $device.state.deviceImportStatus
                    deviceRegistrationId = $device.state.deviceRegistrationId
                    deviceErrorCode      = $device.state.deviceErrorCode
                    deviceErrorName      = $device.state.deviceErrorName
                }
            }
            'unmanaged'
            {
                Write-Verbose "[$functionName] Preparing $devicetype device with display name $($device.displayName) for export."
                $createdDateTime = $device.createdDateTime
                $registrationDateTime = $device.registrationDateTime
                $approximateLastSignInDateTime = $device.approximateLastSignInDateTime
                if ($null -ne $device.createdDateTime)
                {
                    $createdDateTime = $device.createdDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.registrationDateTime)
                {
                    $registrationDateTime = $device.registrationDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.approximateLastSignInDateTime)
                {
                    $approximateLastSignInDateTime = $device.approximateLastSignInDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    id                            = $device.id
                    displayName                   = $device.displayName
                    manufacturer                  = $device.manufacturer
                    model                         = $device.model
                    operatingSystemVersion        = $device.operatingSystemVersion
                    profileType                   = $device.profileType
                    createdDateTime               = $createdDateTime
                    registrationDateTime          = $registrationDateTime
                    accountEnabled                = $device.accountEnabled
                    approximateLastSignInDateTime = $approximateLastSignInDateTime
                    enrollmentProfileName         = $device.enrollmentProfileName
                    enrollmentType                = $device.enrollmentType
                    isCompliant                   = $device.isCompliant
                }
            }
            'managed'
            {
                Write-Verbose "[$functionName] Preparing $devicetype device object for export."
                $enrollmentDate = $device.enrolledDateTime
                $LastSync = $device.lastSyncDateTime
                $lastLoggedOn = $device.usersLoggedOn.lastLogOnDateTime
                if ($null -ne $device.enrolledDateTime)
                {
                    $enrollmentDate = $device.enrolledDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.lastSyncDateTime)
                {
                    $LastSync = $device.lastSyncDateTime | FormatDateWithTimeZone
                }
                if ($null -ne $device.usersLoggedOn.lastLogOnDateTime)
                {
                    $lastLoggedOn = $device.usersLoggedOn.lastLogOnDateTime | FormatDateWithTimeZone
                }
                $exportObject = [PSCustomObject] @{
                    serialNumber      = $device.serialNumber
                    deviceName        = $device.deviceName
                    manufacturer      = $device.manufacturer
                    model             = $device.model
                    WindowsVersion    = $device.osVersion
                    autopilotEnrolled = $device.autopilotEnrolled
                    enrollmentDate    = $enrollmentDate
                    LastSync          = $LastSync
                    complianceState   = $device.complianceState
                    userPrincipalName = $device.userPrincipalName
                    userDisplayName   = $device.userDisplayName
                    lastLoggedOn      = $lastLoggedOn
                }
            }
        }
        $CSVObject.Add($exportObject) | Out-Null
    }
    #endregion    

    if ($CSVObject.Count -gt 0)
    {
        Write-Verbose "[$functionName] exporting $($CSVObject.Count) $deviceType devices to $outputFile."
        #Check if the file exists and ask if the user wants to overwrite.
        if (Test-Path $outputFile)
        {
            if ($fileMode -eq 'Append')
            {
                Write-Verbose "[$functionName] Appending to existing file $outputFile."
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Append -Encoding UTF8 -Delimiter ','
            }
            else
            {
                Write-Verbose "[$functionName] Overwriting existing file $outputFile."
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
            }
        }
        else
        {
            Write-Verbose "[$functionName] Creating new file $outputFile."
        }
        $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
    }
    else
    {
        Write-Verbose "[$functionName] No devices found for export."
    }
    #check if the csv file exists.
    if (Test-Path $outputFile)
    {
        Write-Verbose "[$functionName] CSV file $outputFile created successfully."
        $success = $true
    }
    else
    {
        Write-Verbose "[$functionName] Failed to create CSV file $outputFile."
        $success = $false
    }
    return $success, $outputFile
}