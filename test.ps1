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
$managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $deviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
$accessToken = GetGraphAccessToken -configFile $configFile -forceNewToken

#endregion variables

$global:apps = CallGraphApi -ResourcePath $managedAppUri -accessToken $accessToken -apiVersion 'v1.0'
Write-Host "Found $($apps.value.count) apps in Intune." -ForegroundColor Green
$global:assignmentResults = @()
for ($i = 0; $i -lt $global:apps.value.count; $i++)
{
    Write-Host "Getting target assignment for app: $($global:apps.value[$i].displayName)"
    $appAssignmentURI = "deviceAppManagement/mobileApps/$($global:apps.value[$i].id)/assignments"
    Write-Verbose "Calling appAssignmentURI at $($appAssignmentURI)"
    $assignmentResult = CallGraphApi -ResourcePath $appAssignmentURI -accessToken $accessToken -apiVersion 'v1.0' -consistencyLevel
    if ($assignmentResult)
    {
        Write-Host "Number of groups: $($assignmentResult.value.target.count)"
        $assignmentResult.value | ForEach-Object {
            Write-Host "Group ID: $($_.target.groupId)"
$groupUri = "groups/$($_.target.groupId)" 
$extraparameters = "select=displayName"
Write-Host "Calling the uri $($groupUri)"
$groupResult = CallGraphApi -ResourcePath $groupUri -accessToken $accessToken -apiVersion 'v1.0' -extraparameters $extraparameters
Write-Host "Got $($groupResult.value.count) groups for app: $($global:apps.value[$i].displayName)"
Write-Host "Group display name: $($groupResult.value.displayName)"
            $asignedGroups += $groupResult.value.displayName
        }
        
        Write-Host "Calling the url $($groupUri)"
    $appObject = [ordered] @{
        id = $global:apps.value[$i].id
        displayName = $global:apps.value[$i].displayName
        AssignedGroups = $asignedGroups -join ','
        targetAssignment = $assignmentResult
    }
    $global:assignmentResults += $appObject
    Write-Host "Checking $($global:assignmentResults.value[$i].count) assignment results for app: $($global:apps.value[$i].displayName)"
    }}