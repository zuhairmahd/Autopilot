[CmdletBinding()]
param
(
    $configFile = "$pwd\.secrets\config.json"
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
# $scopes = "Device.ReadWrite.All,DeviceLocalCredential.Read.All,DeviceManagementApps.Read.All,DeviceManagementApps.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,DeviceManagementManagedDevices.PrivilegedOperations.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementServiceConfig.ReadWrite.All,Directory.ReadWrite.All,Domain.ReadWrite.All,Group.Read.All,GroupMember.ReadWrite.All,Organization.ReadWrite.All"
$scopes = "DeviceManagementApps.Read.All,DeviceManagementApps.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementServiceConfig.ReadWrite.All"
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $deviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
$accessToken = GetGraphAccessToken -configFile $configFile -deligated -scopes $scopes
#endregion variables


$global:appReport = GetAppAssignmentTypes -accessToken $accessToken -export