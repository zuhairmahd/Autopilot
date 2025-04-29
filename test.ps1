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
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $unmanagedDeviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $accessToken = GetGraphAccessToken -configFile $configFile -deligated -scopes $scopes
# $accessToken = GetGraphAccessToken -configFile $configFile
# $autopilotDevices = (CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken).value
# $managedDevices = (CallGraphApi -ResourcePath $managedDeviceUri -accessToken $accessToken).value
# $importedDevices = (CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken).value
# $unmanagedDevices = (CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken).value
# $global:enrollments = [ordered] @{
# "autopilot" = $autopilotDevices
# "managed"   = $managedDevices
# "imported"  = $importedDevices
# "unmanaged" = $unmanagedDevices
# }
#endregion variables


for ($i = 0; $i -lt $enrollments.autopilot.count - 1; $i++)
{
    if ($enrollments.autopilot[$i].enrollmentState -ne 'enrolled' -and $enrollments.autopilot[$i].enrollmentState -ne 'notContacted')
    {
        Write-Host "Serial number $($enrollments.autopilot[$i].serialNumber) is $($enrollments.autopilot[$i].enrollmentState)"
    }
}