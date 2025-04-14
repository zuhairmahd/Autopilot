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


$filter = "serialNumber eq '$serialNumber'"
$autopilotFilter = "contains(serialNumber,'$serialNumber')"
$global:autopilotDevice = CallGraphAPI -accessToken $accessToken -ResourcePath $autoPilotDeviceURI -filter $autopilotFilter -verbose
$global:managedDevice = CallGraphAPI -accessToken $accessToken -ResourcePath $deviceManagementUri -filter $filter -verbose 