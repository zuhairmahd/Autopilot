function ImportAutopilotDevice() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [object]$DeviceObject
    )
    $uri = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities"
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
  "groupTag": "MSB01",
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
  "assignedUserPrincipalName": ""
}    
"@
    $responce = Invoke-RestMethod -Uri $uri -Authentication Bearer -Token $AccessToken -Method POST -Body $json 
    return $responce
}