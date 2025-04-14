[CmdletBinding()]
param
(
    [parameter(helpMessage = 'Please enter the serial number of the device you want to verify.', Position = 0)]$serialNumber = '5R3SBZ3'
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
$importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
$deviceUri = "devices"
$deviceManagementUri = "deviceManagement/managedDevices"
$autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
$configFile = "$pwd\.secrets\config.json"
$accessToken = GetGraphAccessToken -configFile $configFile -cacheType 'File'
#endregion variables


$managedDeviceFilter = "serialNumber eq '$serialNumber'"
$autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
$importedDeviceFilter = "serialNumber eq '$serialNumber'"
Write-Verbose "Getting autopilot devices"
$global:autopilotDevice = CallGraphAPI -accessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotDeviceFilter
Write-Host "Getting managed devices"
$global:managedDevice = CallGraphAPI -accessToken $accessToken -ResourcePath $deviceManagementUri -filter $managedDeviceFilter
Write-Host "Getting imported devices"
$global:importedDevice = CallGraphAPI -accessToken $accessToken -ResourcePath $importedAutopilotDeviceURI -filter $importedDeviceFilter
