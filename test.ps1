[CmdletBinding()]
param
(
    $configFile = "$pwd\.secrets\config.json",
    $outputFile = "$pwd\deviceMemory-export.csv"
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
# $logfile = "mylog.log"
# $domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
# $serialNumber = '0F3CFP724223KV'
# $serialNumber = 'BTSB25000BCR'
# $serialNumber = '5R3SBZ3'
# $userUri = "users"
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $importedAutopilotDeviceExtraParameters = "select=serialNumber,importId,groupTag,state"
# $unmanagedDeviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $autopilotExtraParameters = "select=serialNumber,groupTag,manufacturer,model,systemFamily,enrollmentState,deploymentProfileAssignmentStatus&top=9999&skip=0&count=true"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $managedDeviceFilter = "startswith(deviceName,'w11-')"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $deviceConfigurationUri = "deviceManagement/deviceConfigurations"
# $autopilotCsv = [System.Collections.ArrayList]@()
# $importedCsv = [System.Collections.ArrayList]@()
# $accessToken = GetGraphAccessToken -configFile $configFile -deligated -scope $scopes -AuthType 'PublicAuthFlow' 
# $accessToken = GetGraphAccessToken -configFile $configFile
# $autopilotDevices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken -extraParameters $autopilotExtraParameters -consistencyLevel -verbose
# $importedDevices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -consistencyLevel -extraParameters $importedAutopilotDeviceExtraParameters -verbose
# $unmanagedDevices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken
# $global:enrollments = [ordered] @{
# "autopilot" = $autopilotDevices
# "managed" = $managedDevices
# "imported"  = $importedDevices
# "unmanaged" = $unmanagedDevices
# }
#endregion variables

$invocation = $MyInvocation
#print all the content of $myinvocation.
Write-Host "Script name: $($invocation.MyCommand.Name)"
Write-Host "Script path: $($invocation.MyCommand.Path)"
Write-Host "Script line number: $($invocation.ScriptLineNumber)"
Write-Host "Script command type: $($invocation.MyCommand.CommandType)"
Write-Host "Script arguments: $($invocation.MyCommand.Parameters | Out-String)"
Write-Host "$($invocation.MyCommand.Name) started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "Command type: $($invocation.MyCommand.CommandType)"
Write-Host "Command name: $($invocation.MyCommand.Name)"
Write-Host "Command path: $($invocation.MyCommand.Path)"
Write-Host "Command line number: $($invocation.ScriptLineNumber)"
Write-Host "Command arguments: $($invocation.MyCommand.Parameters | Out-String)"    

if ($invocation.MyCommand.CommandType -eq "ExternalScript")
{
    Write-Host "Running as an external script."
    $ScriptPath = Split-Path -Parent -Path $invocation.MyCommand.Definition
    Write-Host "Script path: $ScriptPath"
}
else
{
    Write-Host "Running as a script block."
    $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    Write-Host "Script path: $ScriptPath"
    if (!$ScriptPath)
    {
        Write-Host "Script path is not set. Defaulting to current directory."
        $ScriptPath = "."
    }
}

Write-Host "Script name: $($invocation.MyCommand.Name)"
Write-Host "Script path: $($invocation.MyCommand.Path)"
Write-Host "Script line number: $($invocation.ScriptLineNumber)"
Write-Host "Script command type: $($invocation.MyCommand.CommandType)"
Write-Host "Script arguments: $($invocation.MyCommand.Parameters | Out-String)"
Write-Host "$($invocation.MyCommand.Name) started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "Command type: $($invocation.MyCommand.CommandType)"
Write-Host "Command name: $($invocation.MyCommand.Name)"
Write-Host "Command path: $($invocation.MyCommand.Path)"
Write-Host "Command line number: $($invocation.ScriptLineNumber)"
Write-Host "Command arguments: $($invocation.MyCommand.Parameters | Out-String)"    

