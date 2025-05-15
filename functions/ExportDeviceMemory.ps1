function ExportDeviceMemory()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )
    $functionName = $MyInvocation.MyCommand.Name
    $managedDeviceUri = "deviceManagement/managedDevices"
    $success = $false
    Write-Verbose "[$functionName] - Getting device list from Graph API"
    $DeviceList = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken -Filter $managedDeviceFilter -consistencyLevel
    Write-Verbose "[$functionName] - Retrieved $($DeviceList.value.count) devices"
    if ($null -eq $DeviceList -or $DeviceList.value.count -eq 0)
    {
        Write-Host "[$functionName] - No devices found. Exiting script." -ForegroundColor Red
        return $false
    }
    $CSVObject = [System.Collections.ArrayList]@()
    for ($i = 0; $i -lt $DeviceList.value.count ; $i++)
    {
        Write-Verbose "[$functionName] - Processing device $i of $($DeviceList.value.count)"
        $device = $deviceList.value[$i]
        $deviceId = $device.id
        if ($null -eq $deviceId)
        {
            Write-Verbose "[$functionName] - Device ID is null. Skipping device."
            continue
        }
        else
        {
            Write-Verbose "[$functionName] - Device ID: $deviceId"
        }
        $deviceName = $device.deviceName
        Write-Verbose "[$functionName] - Device name: $deviceName"
        $serialNumber = $device.serialNumber
        Write-Verbose "[$functionName] - Serial number: $serialNumber"
        $manufacturer = $device.manufacturer
        Write-Verbose "[$functionName] - Manufacturer: $manufacturer"
        $model = $device.model
        Write-Verbose "[$functionName] - Model: $model"
        $systemFamily = $device.systemFamily
        Write-Verbose "[$functionName] - System family: $systemFamily"
        $hardwareResourcePath = "$managedDeviceUri/$deviceId" 
        $deviceHardwareExtraparameters = "select=hardwareInformation,physicalMemoryInBytes"
        Write-Verbose "[$functionName] - Getting hardware information for device $deviceId"
        Write-Verbose "[$functionName] Calling Graph API with resource path: $hardwareResourcePath and extra parameters: $deviceHardwareExtraparameters"
        $hardwareObject = CallGraphApi -accessToken $accessToken -ResourcePath $hardwareResourcePath -extraParameters $deviceHardwareExtraparameters
        if ($null -eq $hardwareObject)
        {
            Write-Verbose "[$functionName] - Hardware object is null. Skipping device."
            continue
        }
        else
        {
            Write-Verbose "[$functionName] - Hardware object retrieved successfully."
        }
        $memory = ((($global:hardwareObject.physicalMemoryInBytes / 1024) / 1024) / 1024)
        Write-Verbose "[$functionName] - Memory: $memory GB"
        Write-Verbose "[$functionName] Preparing export object for device $deviceId"
        $ExportObject = [pscustomobject]@{
            deviceId          = $deviceId
            serialNumber      = $serialNumber
            deviceName        = $deviceName
            manufacturer      = $manufacturer
            model             = $model
            systemFamily      = $systemFamily
            userPrincipalName = $device.userPrincipalName
            userDisplayName   = $device.userDisplayName
            memory            = $memory
        }
        Write-Verbose "[$functionName] - Adding device $deviceId to CSV object"
        $CsvObject.Add($ExportObject) | Out-Null
    }
    Write-Verbose "[$functionName] - Exporting CSV object to file $OutputFile"
    try
    {
        $CsvObject | Export-Csv -Path $OutputFile -NoTypeInformation -Force
        Write-Host "[$functionName] - Exported CSV object to file $OutputFile" -ForegroundColor Green
        $success = $true
    }
    catch
    {
        Write-Host "[$functionName] - Error exporting CSV object to file $OutputFile" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
    return $success
}