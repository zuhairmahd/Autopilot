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
$serialNumber = 'BTSB25000BCR'
$ManagedDeviceId = "bb2c0930-36e1-4515-80af-df4266d3cdb5"
$deviceManagementUri = "deviceManagement/managedDevices/$ManagedDeviceId"
$global:action = callGraphApi -AccessToken $accessToken -ResourcePath $deviceManagementUri -apiVersion 'v1.0' -ExtraParameters "select=deviceActionResults"
Write-Host "Action: $global:action"
