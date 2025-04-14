[CmdletBinding()]
param
(
    [parameter(mandatory, helpMessage = 'Please enter the object id of the device you want to find.', Position = 0)]$ObjectId
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
$managedDeviceFilter = "serialNumber eq '$serialNumber'"
$autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
$importedDeviceFilter = "serialNumber eq '$serialNumber'"
$configFile = "$pwd\.secrets\config.json"
$accessToken = GetGraphAccessToken -configFile $configFile
#endregion variables

$uri = "$deviceUri/$($ObjectId)"
$global:result = callGraphApi -ResourcePath $uri -accessToken $accessToken -method GET
