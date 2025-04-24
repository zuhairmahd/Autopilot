[CmdletBinding()]
param
(
    [parameter(helpMessage = 'Please enter the object id of the device you want to find.', Position = 0)]$SerialNumber = 'C4N8054'
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
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
$managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
$configFile = "$pwd\.secrets\config.json"
$accessToken = GetGraphAccessToken -configFile $configFile
#endregion variables

$managedDeviceUri = "deviceManagement/managedDevices"
# Write-Host "managed device uri: $managedDeviceUri" -ForegroundColor Green
# Write-Host "managed device filter: $managedDeviceFilter" -ForegroundColor Green
# $extraparameters = "select=userPrincipalName,userDisplayName,lastLogOnDateTime&orderby=userDisplayName"
# Write-Host "extraparameters: $extraparameters" -ForegroundColor Green
# $global:managedDevice = CallGraphAPI -accessToken $accessToken -ResourcePath $managedDeviceUri -filter $managedDeviceFilter -extraparameters $extraparameters -verbose 

$deviceManagementUri = "deviceManagement/managedDevices"
$managedDeviceFilter = "serialNumber eq '$serialNumber'"
$global:ap = (CallGraphAPI -AccessToken $accessToken -ResourcePath $deviceManagementUri -APIVersion 'beta' -Filter $managedDeviceFilter).value
# $extraparameters = "select=deviceName,manufacturer,model,serialNumber,userPrincipalName,userDisplayName&orderby=userDisplayName"
# $filter = "userPrincipalName eq 'mahmoudz@gao.gov'"







