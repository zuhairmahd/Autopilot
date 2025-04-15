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



# $filter = "deviceSerialNumber eq 'C4N8054'"
# $extraParameters = "orderby=createdDateTime"
# $serialNumber = [uri]::EscapeDataString('C4N8054')
# $filter = "deviceSerialNumber eq '$serialNumber'"
$serialNumber = 'C4N8054' # Define the serial number
#encode the serialnumber
$serialNumber = [uri]::EscapeDataString($serialNumber)
$uri = "https://graph.microsoft.com/beta/deviceManagement/autopilotEvents?`$filter=deviceSerialNumber eq '$serialNumber'&`$orderby=createdDateTime desc&`$top=5"

$headers = @{
    Authorization    = "Bearer $accessToken"
    'Content-Type'   = 'application/json'
    ConsistencyLevel = 'Eventual'
}

Write-Host "Calling Graph API with the following parameters:" -ForegroundColor Green
Write-Host "URI: $uri" -ForegroundColor Green
Invoke-RestMethod -Uri $uri -Headers $headers -UseBasicParsing -Debug
# $extraParameters = "top=5"
# $global:result = callGraphApi -ResourcePath $uri -accessToken $accessToken -APIVersion 'beta' -filter $filter -extraparameters $extraParameters -verbose


