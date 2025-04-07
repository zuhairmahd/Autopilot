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

$importedAutopilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities'
$deviceManagementUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
$autoPilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities'
$configFile = "$pwd\.secrets\config.json"
$accessToken = GetGraphAccessToken -configFile $configFile

$global:enrollmentState = VerifyEnrollmentStatus -serialNumber $serialNumber -accessToken $accessToken
Write-Host "Enrollment State: $($global:enrollmentState |ConvertTo-Json)" -ForegroundColor Green

# $global:devices = CallGraphAPI -AccessToken $accessToken -Uri $deviceManagementUri
# $global:imported = CallGraphAPI -AccessToken $accessToken -Uri $importedAutopilotDeviceURI -Method GET
# $global:autopilot = CallGraphAPI -AccessToken $accessToken -Uri $autoPilotDeviceURI -Method GET