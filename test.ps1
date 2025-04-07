[CmdletBinding()]
param
(
)

$importedAutopilotDeviceURI = "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities"
$deviceManagementUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
$autoPilotDeviceURI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
$configFile = "$pwd\.secrets\config.json"
# $serialNumber = 'VMware-564d734181a15091-8cab81424cc39146'

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

# if (connectToTenant -configFile '.\.secrets\config.json')
# {
#     Write-Verbose 'Connected to tenant'
# }
# else
# {
#     Write-Host 'Failed to connect to tenant' -ForegroundColor Red
#     exit 1
# }


$accessToken = GetGraphAccessToken -configFile $configFile

$global:devices = CallGraphAPI -AccessToken $accessToken -Uri $deviceManagementUri
$global:imported = CallGraphAPI -AccessToken $accessToken -Uri $importedAutopilotDeviceURI -Method GET
$global:autopilot = CallGraphAPI -AccessToken $accessToken -Uri $autoPilotDeviceURI -Method GET