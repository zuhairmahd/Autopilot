[CmdletBinding()]
param
(
    [parameter(helpMessage = 'Please enter the object id of the device you want to find.', Position = 0)]$ObjectId = 'C4N8054'
)


#region import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}
#endregion

#region variables
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $deviceUri = "devices"
# $deviceManagementUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
$configFile = "$pwd\.secrets\config.json"
$accessToken = GetGraphAccessToken -configFile $configFile
#endregion variables
$autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $deviceManagementUri = "deviceManagement/managedDevices"
$autopilotDevices = (CallGraphAPI -ResourcePath $autoPilotDeviceURI -accessToken $accessToken -apiVersion 'v1.0').value
Write-Host "Found $($autopilotDevices.count) autopilot devices."
foreach ($autopilotDevice in $autopilotDevices)
{
    Write-Host "Assigning variables for autopilot device with serial number $($autopilotDevice.serialNumber)"
    $variables = [ordered] @{
        'id'                           = $autopilotDevice.id
        'azureActiveDirectoryDeviceId' = $autopilotDevice.azureActiveDirectoryDeviceId
        # 'azureAdDeviceId'              = $autopilotDevice.azureAdDeviceId
        'managedDeviceId'              = $autopilotDevice.managedDeviceId
    }
    foreach ($key in $variables.Keys)
    {
        $originalValue = $($variables[$key])
        Write-Host "Looking for a match for key: $key"
        Write-Host "The value of $key is $originalValue"
        Write-Host "Checking managed devices."
        foreach ($device in $enrollmentState.ManagedDevice.Device.GetEnumerator())
        {
            foreach ($property in $device.PSObject.Properties)
            {
                $newValue = $property.Value
                if ($originalValue -eq $newValue)
                {
                    Write-Host "The value of $key matches with the value of $($property.Name)"
                }
                else 
                {
                    Write-Verbose "No match."
                }
            }
        }
        Write-Host "Checking unmanaged devices."
        foreach ($device in $enrollmentState.Device.GetEnumerator())
        {
            foreach ($property in $device.PSObject.Properties)
            {
                $newValue = $property.Value
                if ($originalValue -eq $newValue)
                {
                    Write-Host "The value of $key matches with the value of $($property.Name)"
                }
                else 
                {
                    Write-Verbose "No match."
                }
            }
        }
    }
}
exit 0 
$autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $deviceManagementUri = "deviceManagement/managedDevices"
$autopilotDevices = (CallGraphAPI -ResourcePath $autoPilotDeviceURI -accessToken $accessToken -apiVersion 'v1.0').value
#Get the serial numbers of each device.
$devices = @()
foreach ($device in $autopilotDevices)
{
    $serialNumber = $device.serialNumber
    $devices += $serialNumber
}
Write-Host "Found $($devices.count) serial numbers in the autopilot devices."
foreach ($device in $devices)
{
    $deviceObject = GetDeviceEnrollmentStatus -accessToken $accessToken -serialNumber $device
    $deviceId = $deviceObject.autopilot.device.azureActiveDirectoryDeviceId
    $managedDeviceId = $deviceObject.autopilot.device.managedDeviceId
    if ($managedDeviceId -ne '00000000-0000-0000-0000-000000000000')
    {
        $managedDeviceFilter = "azureADDeviceId eq '$deviceId'"
        $deviceManagementUri = "deviceManagement/managedDevices"
        Write-Host "Looking up managed device for device with id $managedDeviceId"
        (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -APIVersion 'beta' -filter $managedDeviceFilter).value
    }
    Write-Host "Attempting a lookup for device $deviceId"
    $resourcePath = "devices"   
    $filter = "deviceId eq '$deviceId'"
    (CallGraphAPI -ResourcePath $resourcePath -accessToken $accessToken -apiVersion 'v1.0' -filter $filter).value
}