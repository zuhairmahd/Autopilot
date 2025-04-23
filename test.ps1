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
$managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $configFile = "$pwd\.secrets\config.json"
# $accessToken = GetGraphAccessToken -configFile $configFile
#endregion variables

$enrollmentState.autopilot.device.lastContactedDateTime | FormatDateWithTimeZone



exit 0
$extraparameters = "select=deviceName,manufacturer,model,serialNumber,userPrincipalName,userDisplayName&orderby=userDisplayName"
$filter = "userPrincipalName ne null and userPrincipalName ne '' and contains(userPrincipalName, 'mahmoudz@gao.gov') and startswith(deviceName,'w11-')"
$global:response = CallGraphAPI -accessToken $accessToken -ResourcePath $managedDeviceUri -Filter $filter -extraParameters $extraparameters -consistencyLevel

# Process and display the sorted results
# if ($global:response -and $global:response.value)
# {
# Write-Host "Processing response data..." -ForegroundColor Green
    
# Sort the response data by userDisplayName (in case API sorting didn't work properly)
# $sortedDevices = $global:response.value | Sort-Object -Property userDisplayName

# Display the sorted results
# Write-Host "`nDevices sorted by userDisplayName:" -ForegroundColor Cyan
# $sortedDevices | Format-Table -Property deviceName, userDisplayName, model, serialNumber -AutoSize
    
# Export to CSV if needed
# $sortedDevices | ConvertTo-Csv -NoTypeInformation -Delimiter ',' | Out-File -FilePath "$pwd\devices.csv" -Encoding UTF8 -Force
# Write-Host "Exported sorted results to $pwd\devices.csv" -ForegroundColor Green
# }
# else
# {
# Write-Host "No response data was received or the response did not contain any values." -ForegroundColor Red
# }