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
# $scopes = "offline_access Device.ReadWrite.All DeviceLocalCredential.Read.All DeviceManagementApps.Read.All DeviceManagementApps.ReadWrite.All DeviceManagementConfiguration.ReadWrite.All DeviceManagementManagedDevices.PrivilegedOperations.All DeviceManagementManagedDevices.ReadWrite.All DeviceManagementServiceConfig.ReadWrite.All Directory.ReadWrite.All Domain.ReadWrite.All Group.Read.All GroupMember.ReadWrite.All Organization.ReadWrite.All"
# $serialNumber = '0F3CFP724223KV'
# $serialNumber = 'BTSB25000BCR'
# $serialNumber = '5R3SBZ3'
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $unmanagedDeviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $managedDeviceFilter = "startswith(deviceName,'w11-')"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $accessToken = GetGraphAccessToken -configFile $configFile -deligated -scopes $scopes
$accessToken = GetGraphAccessToken -configFile $configFile
# $autopilotDevices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken
# $managedDevices = CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken 
# $importedDevices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken
# $unmanagedDevices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken
# $global:enrollments = [ordered] @{
#     "autopilot" = $autopilotDevices
#     "managed"   = $managedDevices
#     "imported"  = $importedDevices
#     "unmanaged" = $unmanagedDevices
# }
#endregion variables


$groupUri = "users/mahmoudz@gao.gov/memberOf/microsoft.graph.group"
$global:myGroups = CallGraphAPI -ResourcePath $groupUri -accessToken $accessToken -extraparameters "count=true"