function ImportAutopilotDevice() 
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$AccessToken,
    [Parameter(Mandatory = $true)]
    [object]$DeviceObject,
    [Parameter(Mandatory = $false)]
    [string]$GroupTag = '',
    [Parameter(Mandatory = $false)]
    [string]$AssignedUser = '',
    [Parameter(Mandatory = $false)]
    [int]$maxWaitTime = 30,
    [Parameter(Mandatory = $false)]
    [int]$timeInSeconds = 60
  )

  #region print verbose log of the parameters and define variables
  if ($accessToken)
  {
    Write-Verbose "AccessToken provided."
  }
  else
  {
    Write-Verbose "AccessToken not provided."
    return $false
  }
  Write-Verbose "DeviceObject: $DeviceObject"
  Write-Verbose "GroupTag: $GroupTag"
  Write-Verbose "AssignedUser: $AssignedUser"
  Write-Verbose "MaxWaitTime: $maxWaitTime"
  Write-Verbose "TimeInSeconds: $timeInSeconds"
  $uri = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
  $serialNumber = $DeviceObject.serialNumber
  Write-Verbose "Serial Number: $serialNumber"
  $make = $DeviceObject.manufacturer
  Write-Verbose "Make: $make"
  $model = $DeviceObject.model
  Write-Verbose "Model: $model"
  $hash = $DeviceObject.hardwareHash
  $json = @"
{
  "@odata.type": "#microsoft.graph.importedWindowsAutopilotDeviceIdentity",
  "groupTag": "$groupTag",
  "serialNumber": "$serialNumber",
  "productKey": "",
  "importId": "",
  "hardwareIdentifier": "$hash",
  "state": {
    "@odata.type": "microsoft.graph.importedWindowsAutopilotDeviceIdentityState",
    "deviceImportStatus": "pending",
    "deviceRegistrationId": "",
    "deviceErrorCode": 15,
    "deviceErrorName": ""
  },
  "assignedUserPrincipalName": "$AssignedUser",
}    
"@
  #endregion
  
  $imported = callGraphApi -AccessToken $AccessToken -ResourcePath $uri -Method POST -Body $json
  if ($null -eq $imported)
  {
    Write-Host "The device import failed."
    Write-Host "Please check the Intune portal or contact an Intune administrator."
    return $null
  }
  Write-Host "The device import was successful."
  Write-Host "The imported device ID is $($imported.id)."
  #wait for the device to be imported
  Write-Host "Waiting for device with device ID $($imported.id) to be imported."
  $device = callGraphApi -AccessToken $AccessToken -ResourcePath "$uri/$($imported.id)" -Method GET
  $index = 0
  while ($index -lt $maxWaitTime)
  {
    Write-Verbose "The device import status is $($device.state.deviceImportStatus)"
    if (($device.state.deviceImportStatus -ne 'unknown') -or ($index -gt $maxWaitTime))
    {
      break
    }
    Write-Host "The import status is $($device.state.deviceImportStatus)."
    Write-Host "Will check again in $timeInSeconds seconds."
    $index++
    Write-Host "Pass $index of $maxWaitTime"
    Start-Sleep -Seconds $timeInSeconds
    $device = callGraphApi -AccessToken $AccessToken -ResourcePath "$uri/$($imported.id)" -Method GET
  }
  Write-Host "The device import status is $($device.state.deviceImportStatus)"
  Write-Verbose "The index count is $index."
  if (($device.state.deviceImportStatus -eq 'unknown') -and ($index -gt $maxWaitTime))
  {
    Write-Host "The import is taking too long (over $maxWaitTime minutes)." 
    Write-Host 'Please check the Intune portal or contact an Intune administrator.'
    return $null
  }
  else
  {
    Write-Verbose "The device import state is $($device.state.deviceImportStatus)"
    return $device
  }
}
