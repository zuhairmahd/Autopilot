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
    $CSVObject = [System.Collections.ArrayList]@()
    $success = $false
    #endregion

    #region Fetch devices using Get-DeviceData
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetching $deviceType devices." -LogLevel "Information"
    $devices = Get-DeviceData -AccessToken $AccessToken -DeviceType $deviceType
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Fetched $($devices.value.Count) $deviceType devices." -LogLevel "Information"
    #endregion
    
    #region Process devices for export
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
    
    try
    {
        if ($CSVObject.Count -gt 0)
        {
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "exporting $($CSVObject.Count) $deviceType devices to $outputFile." -LogLevel "Information"
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No devices found for export." -LogLevel "Verbose"
        }
        write-log -logFile $LogFile -Module "$functionName" -Message "Device list export completed successfully." -LogLevel "Information"
        $success = $true
    }
    catch
    {
        $success = $false
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error occurred while exporting device list: $_" -LogLevel "Error"
    }
    
    return $success, $outputFile
}
