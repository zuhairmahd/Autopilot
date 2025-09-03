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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Autopilot devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) Autopilot devices." -LogLevel "Information"
        }
        'imported'
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Imported Autopilot devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -extraParameters $importedAutopilotExtraParameters
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) imported Autopilot devices." -LogLevel "Information"
        }
        'unmanaged'
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Unmanaged devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken -filter $unmanagedDeviceFilter -extraParameters $unmanagedDeviceExtraParameters
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) unmanaged devices." -LogLevel "Information"
        }
        'managed'
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "fetching Managed devices." -LogLevel "Information"
            $devices = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken -filter $managedDeviceFilter -extraParameters $managedDeviceExtraParameters
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) managed devices." -LogLevel "Information"
        }
    }
    
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Processing $($devices.value.Count) $deviceType devices for export." -LogLevel "Verbose"
    for ($i = 0; $i -lt $devices.value.count; $i++)
    {
        $device = $devices.value[$i]
        if (-not $device)
        {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Skipping null or invalid $deviceType device at index $i." -LogLevel "Debug"
            continue
        }
        switch ($deviceType)
        {
            'autopilot'
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $deviceType device with serial number $($device.serialNumber) for export." -LogLevel "Information"
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
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $deviceType device with serial number $($device.serialNumber) for export." -LogLevel "Information"
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
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $devicetype device with display name $($device.displayName) for export." -LogLevel "Information"
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
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Preparing $devicetype device object for export." -LogLevel "Information"
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "exporting $($CSVObject.Count) $deviceType devices to $outputFile." -LogLevel "Information"
        #Check if the file exists and ask if the user wants to overwrite.
        if (Test-Path $outputFile)
        {
            if ($fileMode -eq 'Append')
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Appending to existing file $outputFile." -LogLevel "Information"
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Append -Encoding UTF8 -Delimiter ','
            }
            else
            {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "Overwriting existing file $outputFile." -LogLevel "Verbose"
                $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
            }
        }
        else
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Creating new file $outputFile." -LogLevel "Information"
        }
        $CSVObject | Export-Csv -Path $outputFile -NoTypeInformation -Force -Encoding UTF8 -Delimiter ','
    }
    else
    {
Write-Log -LogFile $LogFile -Module "$functionName" -Message "No devices found for export." -LogLevel "Verbose"
    }
    #check if the csv file exists.
    if (Test-Path $outputFile)
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "CSV file $outputFile created successfully." -LogLevel "Information"
        $success = $true
    }
    else
    {
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to create CSV file $outputFile." -LogLevel "Error"
        $success = $false
    }
    return $success, $outputFile
}
