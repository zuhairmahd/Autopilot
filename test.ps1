[CmdletBinding()]
param
(
    [parameter(helpMessage = 'Please enter the serial number of the device you want to verify.', Position = 0)]$serialNumber = '5R3SBZ3'
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
$importedAutopilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities'
$deviceUri = "https://graph.microsoft.com/beta/devices"
$deviceManagementUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
$autoPilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities'
$configFile = "$pwd\.secrets\config.json"
$accessToken = GetGraphAccessToken -configFile $configFile
$global:ac = $accessToken
#endregion variables


$Uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"

$global:myDevice = CallGraphAPI -accessToken $accessToken -uri $Uri -filter "serialNumber eq $serialNumber" -verbose 
