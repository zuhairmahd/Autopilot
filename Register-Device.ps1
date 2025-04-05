#region help
<#PSScriptInfo
.VERSION 2.2.0
.GUID c5b2b9ce-7269-4fe5-a126-3c84a5053d37
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Intune device deployment script
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES, Microsoft.Graph.Authentication, Microsoft.Graph.Groups', Microsoft.Graph.Identity.DirectoryManagement, WindowsAutoPilotIntune
.SYNOPSIS
Registers one or more devices into Intune and checks for profiles and module requirements.  
.DESCRIPTION
    Registers one or more devices into Intune.  The script will check for the required modules, permissions, and import the device into Intune.  The script will check if the device is already in Intune and if it is assigned to a deployment profile.  If the device is not in Intune, the script will import the device and wait until it is recognized.  If the device is in Intune but not assigned to a deployment profile, the script will prompt the user to check the Intune portal.  If the device is assigned to a deployment profile, the script will prompt the user to restart the device.
.PARAMETER configFile
    The path to the configuration file.  The default value is '.\.secrets\config.json'.
.PARAMETER Name
    The name of the device to register.  The default value is 'localhost'.
.PARAMETER GroupTag
    The group tag for the device.  The default value is 'MSB01'.
.PARAMETER AssignedUser
    The assigned user for the device.  The default value is null.
.PARAMETER check
    A switch to only check the device assignment status.  If used, no devices will be imported. The default value is false.
.PARAMETER NoModuleCheck
    A switch to skip the required module check.  The default value is false.
.PARAMETER NoUpdateCheck
.PARAMETER UpdateOnly
    A switch to only update the scripts.  The default value is false.  Cannot be used with NoUpdateCheck
    A switch to skip the script update check.  The default value is false.
.PARAMETER NoAdminCheck
    A switch to skip the administrator check.  The default value is false.
.PARAMETER NoSignatureVerify
    A switch to skip the code signature verification.  The default value is false.
    .PARAMETER NoHashVerify
    A switch to skip the hash verification.  The default value is false.
    

.PARAMETER GetDeviceHash
    A switch to get the device hash.  The default value is false.
.PARAMETER Redeploy
    A switch to redeploy the device.  The default value is false.
.PARAMETER SerialNumber
    The serial number of the device to verify deployment or prepare for redeployment.  If no serial number is provided, the script will use the serial number of the local device.
.PARAMETER Repo
    The repository to use for script updates.  The default value is 'github'.  The options are 'github' or 'gitlab'.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01'
    Registers the device with the name 'localhost' into Intune.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD'
    Registers the device with the name 'localhost' into Intune and assigns the user 'JohnD'.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -check
    Checks the device assignment status for the device with the name 'localhost'.  The device will not be imported.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoModuleCheck
    Registers the device with the name 'localhost' into Intune and skips the required module check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoUpdateCheck
    Registers the device with the name 'localhost' into Intune and skips the script update check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoAdminCheck
    Registers the device with the name 'localhost' into Intune and skips the administrator check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoSignatureVerify
    Registers the device with the name 'localhost' into Intune and skips the code signature verification.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoHashVerify
    Registers the device with the name 'localhost' into Intune and skips the hash verification.
.NOTES
  1. Optionally update scripts if newer versions are available.  
  2. Check whether the script is running with admin rights.  
  3. Verify required modules are installed.  
  4. Connect to Microsoft Graph.  
  5. Gather device info (serial, hardware hash, manufacturer, etc.).  
  6. Check if the device is already in Intune.  
  7. If needed, import the device into Intune and wait until it’s recognized.  
  8. Check deployment profile assignment and display status.  
  9. If the device is assigned, prompt for restart. Otherwise, advise the user to check the Intune portal.
#>
#endregion help

[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    [string]$configFile = '.\.secrets\config.json',
    [string]$Configuration = 'vars.json',
    [Parameter(Mandatory = $False)] [String] $GroupTag = 'MSB01',
    [Parameter(Mandatory = $False)] [String] $AssignedUser = '',
    [Parameter(Mandatory = $False)] [switch]$check,
    [Parameter(Mandatory = $False)] [switch]$NoModuleCheck,
    [Parameter(Mandatory = $False)] [switch]$NoAdminCheck,
    [Parameter(Mandatory = $False)] [switch]$NoSignatureVerify,
    [Parameter(Mandatory = $False)] [switch]$NoHashVerify,
    [Parameter(Mandatory = $False)] [switch]$GetDeviceHash,
    [Parameter(Mandatory = $False)] [switch]$Reconfigure,
    [Parameter(Mandatory = $False, ParameterSetName = 'NoUpdateCheckSet')] [switch]$NoUpdateCheck,
    [Parameter(Mandatory = $False, ParameterSetName = 'UpdateOnlySet')] [switch]$UpdateOnly,
    [Parameter(ParameterSetName = 'UpdateOnlySet')][ValidateSet('github', 'gitlab')][string]$Repo = 'github',
    [Parameter(ParameterSetName = 'UpdateOnlySet')]
    [Parameter(Mandatory = $False, ParameterSetName = 'github')]
    [Parameter(Mandatory = $False, ParameterSetName = 'gitlab')]
    [ValidateSet('auto', 'main')][string]$Release = 'main'
)

#region Load parameters from the configuration file if it exists
if (Test-Path -Path $Configuration)
{
    Write-Host " Loading configuration values from $Configuration."
    $configData = Get-Content -Path $Configuration -Raw | ConvertFrom-Json
    Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $configData.PSObject.Properties.Name)
    {
        Write-Verbose "Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $configData.$key)
        {
            Write-Verbose "Read parameter $key from the configuration file as $($configData.$key)"
            Write-Verbose "Setting $key to $($configData.$key)"
            if ($configData.$key -in ('true', 'false'))
            {
                Write-Verbose "Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($configData.$key)
                Write-Verbose "Setting the value of $key to the boolean value ($keybooleanValue)."
                Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "Setting the value of $key to the string value ($($configData.$key))."
                Set-Variable -Name $key -Value $configData.$key
            }
        }
        else
        {
            Write-Verbose "Read parameter $key from the commandline as $($PSBoundParameters[$key])"
        }
    }
}
else
{
    Write-Host "Configuration file $Configuration not found. Using default values."
}
#endregion Load parameters from the configuration file if it exists

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
#endregion import functions.

#region Define static and dynamic variables
if ($repo -eq 'github')
{
    $baseSourceURL = 'https://raw.githubusercontent.com'
    $repoPath = 'zuhairmahd'
    $repoName = 'autopilot'
    if ($release -eq 'auto')
    {
        $latestRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
        if ($latestRelease)
        {
            Write-Host "The latest release is $latestRelease"
        }
        else
        {
            Write-Host 'Failed to retrieve the latest release information from GitHub.' -ForegroundColor Red
            Write-Host 'Defaulting to main branch.'
            $latestRelease = 'main'
        }
    }
    else
    {
        $latestRelease = $Release
    }
}
elseif ($repo -eq 'gitlab')
{
    $baseSourceURL = 'https://git.gao.gov'
    $repoPath = 'mahmoudz'
    $repoName = 'autopilot-deployment'
    $repoId = '1031'
    $latestRelease = GetLatestGitlabRelease -RepositoryId $repoId
}
else
{
    Write-Host 'Invalid repository specified.'
    Write-Host 'Defaulting to the main branch from GitHub.'
    $latestRelease = 'main'
}
$accessToken = GetGraphAccessToken -configFile $configFile
if ($null -eq $accessToken)
{
    Write-Host 'Failed to retrieve access token.' -ForegroundColor Red
    Write-Host 'Functions that require direct access to the API will not work.' -ForegroundColor Red
}
$Name = @('localhost')
$maxWaitTime = 30
$timeInSeconds = 60
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
$localManifest = Get-Content -Path "$PSScriptRoot\manifest.json" -Raw | ConvertFrom-Json
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/manifest.json"
$modulesFolder = "$PWD\pwsh\modules"
$exclusions = GetExclusions -ExclusionsFile "$PSScriptRoot\exclusions.json"
$modulesToInstall = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.DirectoryManagement',
    'Microsoft.Graph.DeviceManagement',
    'Microsoft.Graph.Beta.Groups',
    'Microsoft.Graph.Beta.Identity.DirectoryManagement',
    'Microsoft.Graph.Beta.DeviceManagement'
    # 'PackageManagement',
    # 'PowerShellGet',
    'WindowsAutoPilotIntune'
)
#endregion Define static and dynamic variables

#region logging
#print a verbose log of all received variables
Write-Verbose "Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Verbose "The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Verbose "Configuration file: $configFile"
Write-Verbose "Initial values file: $initialValues"
Write-Verbose "Computer name: $Name"
Write-Verbose "Group tag: $GroupTag"
Write-Verbose "Assigned user: $AssignedUser"
Write-Verbose "Check: $check"
Write-Verbose "No module check: $NoModuleCheck"
Write-Verbose "No update check: $NoUpdateCheck"
Write-Verbose "Update only: $UpdateOnly"
Write-Verbose "No admin check: $NoAdminCheck"
Write-Verbose "No signature verify: $NoSignatureVerify"
Write-Verbose "No hash verify: $NoHashVerify"
Write-Verbose "Get device hash: $GetDeviceHash"
Write-Verbose "Redeploy: $Redeploy"
Write-Verbose "Reconfigure: $Reconfigure"
Write-Verbose "Serial number: $SerialNumber"
Write-Verbose "Repository: $Repo"
Write-Verbose "Release: $Release"
#endregion logging

#region Perform checks
if ($Reconfigure)
{
    Write-Host 'Reconfiguring the script...'
    if (CreateFullConfiguration -DestinationFolder $PSScriptRoot -RootFolder $PSScriptRoot)
    {
        Write-Host 'The script has been reconfigured.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to reconfigure the script.' -ForegroundColor Red
        exit 1
    }
    exit 0
}   

if (-not($NoSignatureVerify))
{
    Write-Host 'Verifying code signature.'
    $codeAuthenticity = GetSignatureStatus -scriptFolders @("$PSScriptRoot", "$functionsFolder") -exclusions $exclusions
    if ($codeAuthenticity.count -gt 0)
    {
        Write-Host "$($codeAuthenticity.count) scripts failed the signature check." -ForegroundColor Red
        foreach ($Script in $codeAuthenticity.keys)
        {
            Write-Host "The script $script is $($codeAuthenticity[$script].status)."
            Write-Verbose "The reason is $($codeAuthenticity[$script].reason)."
        }
        Write-Host 'You may not run this script because the code signature verification failed.' -ForegroundColor Red
        Write-Host 'Exiting script.' -ForegroundColor Red
        exit 1
    }
    else
    {
        Write-Host 'All scripts are signed.' -ForegroundColor Green
    }
}
else
{
    Write-Host 'Skipping signature verification check.'
}

if (-not($NoHashVerify))
{
    Write-Host 'Verifying file integrity.'
    $fileIntegrity = GetScriptIntegrity -scriptFolders @("$PSScriptRoot", "$functionsFolder") -RootFolder $PSScriptRoot -exclusions $exclusions
    Write-Verbose "The file integrity check returned $($fileIntegrity.count) scripts."
    if (-not $fileIntegrity)
    {
        Write-Host 'You may not run this script because the integrity check failed.' -ForegroundColor Red
        Write-Host 'Exiting script.' -ForegroundColor Red
        exit 1
    }
    else
    {
        Write-Host 'All scripts passed integrity verification.' -ForegroundColor Green
    }
}
else
{
    Write-Host 'Skipping integrity verification check.'
}

if (-not($NoUpdateCheck))
{
    Write-Host 'Checking for script updates.'
    $remoteManifest = CheckForScriptUpdates -RemoteManifestPath $remoteVersionURL -LocalManifestContent $localManifest
    if ($remoteManifest.functions.count -gt 0 -or $remoteManifest.scripts.count -gt 0 -or $remoteManifest.cmds.count -gt 0)
    {
        Write-Host "$($remoteManifest.functions.count) functions, $($remoteManifest.scripts.count) scripts, and $($remoteManifest.cmds.count) cmds have an update available."
        Write-Host 'Would you like to download the latest version of the scripts? (Y/N)' -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq 'Y')
        {
            Write-Host 'Downloading the latest version of the script.'
            if (DownloadScriptUpdates -scriptsToUpdate $remoteManifest -scriptURI $updateURL -ScriptRoot $PSScriptRoot)
            {
                Write-Host 'All scripts have been updated.' -ForegroundColor Green
            }
            else
            {
                Write-Host 'Failed to update scripts.' -ForegroundColor Red
            }
        }
        else
        {
            Write-Host 'Updates will not be downloaded.' -ForegroundColor Red
        }
    }
    else
    {
        Write-Host 'All scripts are up to date.' -ForegroundColor Green
    }
}
else
{
    Write-Host 'Skipping script update check.'
}

if ($UpdateOnly)
{
    Write-Host 'Update check complete.'
    exit 0
}

if (-not($NoAdminCheck -or $UpdateOnly -or $Redeploy -or $Reconfigure))
{
    Write-Host 'Checking whether the script has sufficient permissions to run.'
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Warning 'You do not have sufficient permissions to run this script. Please run this script as an administrator.'
        exit 1
    }
    else
    {
        Write-Host 'The script has sufficient permissions. Continuing.'
    }
}
else
{
    Write-Host 'Skipping administrator check.'
}

if (-not($NoModuleCheck))
{
    Write-Host 'Checkin for installed modules.'
    $module = GetRequiredModules -moduleNames $modulesToInstall -ModulesFolder $modulesFolder
    if ($module -eq 0)
    {
        Write-Host 'All required modules are installed.' -ForegroundColor Green
    }
    else
    {
        Write-Host "$($module.InstalledModulesCount) modules were installed."
        Write-Host "$($module.PreviouslyInstalledModulesCount) modules were already installed."
    }
}
else
{
    Write-Host 'Skipping module check.'
}
#endregion Perform checks

#region Gather device information.
$deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
$serial = $deviceObject.serialNumber
Write-Verbose "The serial number is $serial"
$hash = $deviceObject.hardwareHash
Write-Verbose "The hardware hash is $hash"
$make = $deviceObject.manufacturer
Write-Verbose "The manufacturer is $make"
$model = $deviceObject.model
Write-Verbose "The model is $model"
$parentDir = (Get-Item -Path $PWD).Parent.FullName
Write-Verbose "The parent directory is $parentDir"
$outputFile = "$parentDir\device_$serial.csv"
Write-Verbose "The output file is $outputFile"
Write-Host "Processing device with serial number $serial, manufacturer $make, and model $model."
if ($GetDeviceHash)
{
    GetDeviceHash -Device $deviceObject -OutputFile $outputFile
    exit 0
}
#endregion Gather device information.

#region Connect to Microsoft Graph
if (connectToTenant($configFile))
{
    Write-Verbose 'Successfully connected to Microsoft Graph.' 
}
else
{
    Write-Host 'Failed to connect to Microsoft Graph.' -ForegroundColor Red
    exit 1
}
$scopes = Get-MgContext | Select-Object -ExpandProperty Scopes | Sort-Object
if ($scopes)
{
    Write-Verbose "The following $($scopes.Count) scopes are available:"
    $scopes | ForEach-Object { Write-Verbose $_ }
}
else
{
    Get-MgContext | Format-List
}
#endregion Connect to Microsoft Graph

#region check if the device has already been imported.
Write-Host "Checking whether the device with serial number $serial is already in Intune."
$assignment = Get-AutopilotDevice -serial $serial
if ($assignment)
{
    Write-Host 'The device is already in Intune.' -ForegroundColor Yellow
    Write-Host 'Checking profile assignment'
    if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState')
    {
        $assignedProfileName = GetAutopilotProfileAssignment -serialNumber $serial
        Write-Host "The device is assigned to the $assignedProfileName deployment profile and ready for enrollment." -ForegroundColor Green
        if ($reminderMessage.Length -gt 0)
        {
            Write-Host $reminderMessage
            Write-Host 'Script complete.'
        }
        else 
        {
            RestartDevice
        }
        exit 0
    }
    else
    {
        Write-Host 'The device is imported but not assigned to a deployment profile.' -ForegroundColor Yellow
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        exit 1
    }
}
#endregion check if the device has already been imported.

#region Add the device to Intune.
$importStart = Get-Date
if (-not($check))
{
    $imported = Add-AutopilotImportedDevice -serialNumber $serial -hardwareIdentifier $hash -groupTag $GroupTag -assignedUser $AssignedUser
    #wait for the device to be imported
    Write-Host "Waiting for device with device ID $($imported.id) to be imported."
    $device = Get-AutopilotImportedDevice -id $imported.id
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
        Write-Host "Pass $index of $maxWaitTime"
        Start-Sleep -Seconds $timeInSeconds
        $device = Get-AutopilotImportedDevice -id $imported.id
        $index++
    }
    Write-Host "The device import status is $($device.state.deviceImportStatus)"
    Write-Verbose "The index count is $index."
    if (($device.state.deviceImportStatus -eq 'unknown') -and ($index -gt $maxWaitTime))
    {
        Write-Host "The import is taking too long (over $maxWaitTime minutes)." 
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        GetDeviceHash -Device $deviceObject -OutputFile $outputFile
        exit 1
    }
}
if (($device.state.deviceImportStatus -eq 'complete') -or ($check))
{
    Write-Host 'Checking device assignment.'
    Start-Sleep -Seconds ($timeInSeconds / 12)
    $assignment = Get-AutopilotDevice -serial $serial
    if ($assignment)
    {
        Write-Verbose "The assignment details are: $($assignment | ConvertTo-Json)"
        $index = 0
        while ($index -lt $maxWaitTime)
        {
            Write-Verbose "The device assignment status is $($assignment.deploymentProfileAssignmentStatus)"
            Write-Verbose "The device assignment date is $($assignment.deploymentProfileAssignedDateTime)"
            if (($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState') -or ($index -gt $maxWaitTime))
            {
                break
            }
            Write-Host "The device assignment status is $($assignment.deploymentProfileAssignmentStatus)"
            Write-Host 'Waiting for device to be assigned to a deployment profile.'
            Write-Host "Will check again in $timeInSeconds seconds"
            Start-Sleep -Seconds $timeInSeconds
            $assignment = Get-AutopilotDevice -serial $serial
            $index++
            Write-Host "Pass $index of $maxWaitTime"
            Write-Verbose "The assignment details are: $($assignment | ConvertTo-Json)"
        }
        Write-Host "The device assignment status is $($assignment.deploymentProfileAssignmentStatus)"
        Write-Host "The device assignment date is $($assignment.deploymentProfileAssignedDateTime)"
        if ((($assignment.deploymentProfileAssignmentStatus -ne 'assignedUnkownSyncState') -or -not($assignment.deploymentProfileAssignedDateTime)) -and ($index -gt $maxWaitTime))
        {
            Write-Host "The device assignment is taking too long (over $maxWaitTime minutes)."
            Write-Host 'Please check the Intune portal or contact an Intune administrator.'
            GetDeviceHash -Device $deviceObject -OutputFile $outputFile
            exit 1
        }
        elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState')
        {
            $assignedProfileName = GetAutopilotProfileAssignment -serialNumber $serial
            Write-Host 'Congratulations!!! ' -ForegroundColor Magenta
            Write-Host "The device is successfully assigned to the deployment profile." -ForegroundColor Green
            $importDuration = (Get-Date) - $importStart
            $importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
            Write-Host "Elapsed time to complete: $importSeconds seconds"
            RestartDevice
            exit 0
        }
    }
    else
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
        GetDeviceHash -Device $deviceObject -OutputFile $outputFile
        exit 1
    }
}
elseif ($device.state.deviceImportStatus -eq 'error')
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
    GetDeviceHash -Device $deviceObject -OutputFile $outputFile
    exit 1
}
else
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host "$($device.state.deviceImportStatus)" -ForegroundColor Red
    GetDeviceHash -Device $deviceObject -OutputFile $outputFile
    exit 1
}
#endregion Add the device to Intune.

# SIG # Begin signature block
# MII94wYJKoZIhvcNAQcCoII91DCCPdACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBk7mEjhYLZj29A
# jkVG1/mpr/aCVq5ivGhupBHlKeHBw6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAJTLw6Q
# AbyxO+trAAAAAlMvMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwNDA1MDYwNDE3WhcNMjUwNDA4
# MDYwNDE3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# pDL9ztepCuGvrQ+Az3uc39Dg/xRxogU5K4uFHTyEsHpkYagTj3v9DMlra4cxPS5N
# tifxD9lU64xOdcm3cDYyXsQVF7Upj3HoIcQk7vCms3wrTFuoa3RA+HyD9OfQduaE
# kAJ6YsqDGbg2ugwy2mcNjDFYUeAXyuwUp7RtE6ebwrF0CCLuB2GUUVCbuxXJ+NI4
# D+nWKImxvmQ9ox+gEn8tzFuTLjKFqohO6qz/ZGsHbv4yG02uNzwkS3Ed1p5JpiKk
# g8B+qxZ5VKsiyN/6YRGRqLk9q+OYxaz+vR7B+6IAw+GVNMtGJ4j1hC0xJ9ZSUM2w
# bBjha7rgsjqG3iMZkLLRxeaqZMDAhBLwXXn6Xao4wJ0yA1W9F3O2FLXfjEOyaW6j
# YkzRctspNO1Lhwg6vyXlRpVByHQcpIkeIpi6MPzJ1PKrBFPn0L+qu1xog3KIbTQ5
# 47kJmxrfLTG5huoFSCTERBY1V9Cd7mUq8rHiweLuuqEjorbGTsnyNq2ITaLezrT5
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFAJlnZta3B1lqFS+1XvKFjbfJEbAMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAABThEUkCudwAUfJ
# vSWcK6gVjV4rszARFHl+2xl4e0QOwAVgm8rKZ2uP6ulsDQ3/XA1k/9vV980zluoz
# 2RoVD1e0q8nYZvUCUFVyZyKESPGKqoY5fiBmJ4FpVNUj1+8Na1SLLuNPe3/Ir6yY
# XtuRnIO27kRmOTolF/kMoWZshyQJ/ybUH+gbFgTtcmsKL5TN4teEAKQkSaG+oUzh
# RsPKf3cqwE4R5wzD5Ws7D5CJZW0Bzju7pcdm1yLin68Mj1TgDoGE+WUAdAolJxUl
# e8MvhvqbzL0Rln3TBMvVV1yYet/b+mMvmx5vRX/ncfgOI+wxUD5z+S8hx2p+HlYs
# yqNO99t4w3qKSVta7MJi9Ybcg4+Z4X9WrN1Gh5xPeuiz3leZixi1R3zNjEaR9Rie
# V/oRgPFfbqQ6rrkLD39Me/bW+n7hT4ap8Rmko6wVDyhbX2WTGjY4Un1Sf8fuDkCF
# nizuavx+8qP8mhqw6WLHdgV1XF5AoKXkX6j63KiWXirsBbMaxxl61FujW24+AkCt
# eWnxjCFdF8ZxC4OjLXvIvdaCIGK4VzD6bEPP2yzyAqWbPbTC1y6sJTPAx/MZysI6
# qivU7kvdsiQsju69gTNdohYdEx3N2wwt6SDsQvh8+1yp1NuaDGnPhkRSFDRy4642
# MDc3EsT9r8vkn6YS5hapslnEVmZJMIIG5zCCBM+gAwIBAgITMwACUy8OkAG8sTvr
# awAAAAJTLzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDQwNTA2MDQxN1oXDTI1MDQwODA2MDQx
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAKQy/c7X
# qQrhr60PgM97nN/Q4P8UcaIFOSuLhR08hLB6ZGGoE497/QzJa2uHMT0uTbYn8Q/Z
# VOuMTnXJt3A2Ml7EFRe1KY9x6CHEJO7wprN8K0xbqGt0QPh8g/Tn0HbmhJACemLK
# gxm4NroMMtpnDYwxWFHgF8rsFKe0bROnm8KxdAgi7gdhlFFQm7sVyfjSOA/p1iiJ
# sb5kPaMfoBJ/Lcxbky4yhaqITuqs/2RrB27+MhtNrjc8JEtxHdaeSaYipIPAfqsW
# eVSrIsjf+mERkai5PavjmMWs/r0ewfuiAMPhlTTLRieI9YQtMSfWUlDNsGwY4Wu6
# 4LI6ht4jGZCy0cXmqmTAwIQS8F15+l2qOMCdMgNVvRdzthS134xDsmluo2JM0XLb
# KTTtS4cIOr8l5UaVQch0HKSJHiKYujD8ydTyqwRT59C/qrtcaINyiG00OeO5CZsa
# 3y0xuYbqBUgkxEQWNVfQne5lKvKx4sHi7rqhI6K2xk7J8jatiE2i3s60+QIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQCZZ2bWtwdZahUvtV7yhY23yRGwDAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQAAU4RFJArncAFHyb0lnCuo
# FY1eK7MwERR5ftsZeHtEDsAFYJvKymdrj+rpbA0N/1wNZP/b1ffNM5bqM9kaFQ9X
# tKvJ2Gb1AlBVcmcihEjxiqqGOX4gZieBaVTVI9fvDWtUiy7jT3t/yK+smF7bkZyD
# tu5EZjk6JRf5DKFmbIckCf8m1B/oGxYE7XJrCi+UzeLXhACkJEmhvqFM4UbDyn93
# KsBOEecMw+VrOw+QiWVtAc47u6XHZtci4p+vDI9U4A6BhPllAHQKJScVJXvDL4b6
# m8y9EZZ90wTL1VdcmHrf2/pjL5seb0V/53H4DiPsMVA+c/kvIcdqfh5WLMqjTvfb
# eMN6iklbWuzCYvWG3IOPmeF/VqzdRoecT3ros95XmYsYtUd8zYxGkfUYnlf6EYDx
# X26kOq65Cw9/THv21vp+4U+GqfEZpKOsFQ8oW19lkxo2OFJ9Un/H7g5AhZ4s7mr8
# fvKj/JoasOlix3YFdVxeQKCl5F+o+tyoll4q7AWzGscZetRbo1tuPgJArXlp8Ywh
# XRfGcQuDoy17yL3WgiBiuFcw+mxDz9ss8gKlmz20wtcurCUzwMfzGcrCOqor1O5L
# 3bIkLI7uvYEzXaIWHRMdzdsMLekg7EL4fPtcqdTbmgxpz4ZEUhQ0cuOuNjA3NxLE
# /a/L5J+mEuYWqbJZxFZmSTCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
# AAYwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDH48g/9CHdxhnAu8XL
# q64nh9OneWfsaqzuzyVNXJ+A4lY/VoAHCTb+jF1WN9IdSrgxM9eKUvnuqL98ftid
# 0Qrgqd3e7lx50XCvZodJOnq+X88vV0Av2x+gO82l0bQ39HzgCFg2kFBOGk7j8GrG
# YKCXeIhF+GHagVU66JOINVa9cGDvptyOcecQS1fO8BbAm7RsFTuhFGpB53hVcm0g
# JW35mgpRKOpjnBSWEB3AeH7fUGekE8LMW0pWIunrMS1HI7FF6BqAVT7IuBe++Z3T
# sgM3RLZMti6JmNPD6Rxg62g2AqvuTQLoT1Z/cfiMdq+TYzGoWm2B8vSAv7NtJv5U
# E0qJVPSarNckgmZaarDQr4Pcwp+YJ6vd7cJus/4XlG0JvRdoTS5Fwk9kmNbByIMH
# EEhuQ0XgYvXaGXm/J2AUybNBw26h0rJf//eUsnWrbaugdVLVyC2wuCmNZhmUGWEJ
# Nxcl5nfG5om9dkH2twsJfXk6BcvbW1RTAkIsTbtXkAZnGQ7eLniaBIKzC06ZZTgA
# p38H97cq1e/pcFREq4C157PUSmCWhpnBB6P2Xl031SHxbX0FmD0iUuX7EdFfi8OI
# xYBR//sA17gyhL3wXjmvvogYnSELTYQy4xnEASvBmPSWfRovncTOUxrkkKJE5tvR
# Sgsd8ZJ00mwyDS6PcMBAN1VZMQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBR2nDZ0E9GQfWFfswLrgPSZS6U+
# hTBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGov
# CZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogqMTfZD
# ozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmzYLVZ
# SP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8wbIH
# Qf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUiQT
# nPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCcn
# 6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuB
# XXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KR
# zUmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF
# I912w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40
# fLpMEydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4Z
# GMfnP6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
# nTiOL60cPqfny+Fq8UiuZzGCGpMwghqPAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACUy8OkAG8sTvrawAAAAJTLzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCUroTUF0gFRPc9mv7B0WpQF8Oi
# BB5Md6IWND5rzGWgGTANBgkqhkiG9w0BAQEFAASCAYBQOh1OGH6yUy2zxszAlXzV
# g/F3GfHtpB9BchR+TeNEvq1QxoVCyV/GazUBRNPO/ZBwtchB10R0x6aevtA/Lfft
# mb5RBvkA7OVQihVmOFck57t2uUEtbi+8eRCynU4h/AgRy3WAy67y225wjWu2mvGq
# X+H7SVaI+KzPrZILs+4SJ0ekZZ/V8W1gzxAJrEz8WYBsQ1OrLl6OiUgmEN9osuqF
# /boMToBkyxtToihjrBuYvhaykOghC5Yq+cB67Vjs3hn4PVY8908/i2sKtvRDYn3J
# fJEKK/4VxYA9+QL2v9IgljUTe24l1e58YzZInJHilh/DmLSICbNdTR6yRdXi/laQ
# TN530xeP1T7sa6s8os/CGtINox5I/3liFuw/80kue+7qQauSFd6gRvQ3vEZRV0a1
# 9u/LHAOAyrTDPHp7/Sc7ERxj0O/od41GSwOTEoWRbhhlxI6lXH/4SWBdabPjlgKp
# VnpLPFpj+U18Y7JQgz8vI1atYx6zWeY8agoOYbHsncmhghgTMIIYDwYKKwYBBAGC
# NwMDATGCF/8wghf7BgkqhkiG9w0BBwKgghfsMIIX6AIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgC/KRF0bBZSc3LDQ0Njnm941diBf1muPhdD687750
# euACBmfnvg/RthgSMjAyNTA0MDUyMjMwMTQuOTZaMASAAgH0oIHhpIHeMIHbMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBF
# U046N0EwMC0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPITCCB4IwggVqoAMCAQICEzMAAAAF
# 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0
# IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz
# 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5
# i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx
# qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk
# X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2
# 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB
# nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd
# Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg
# juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae
# wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc
# 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD
# v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3
# oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl
# JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr
# BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC
# AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm
# +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd
# 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T
# bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3
# he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y
# 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0
# Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4
# fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6
# ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j
# UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5cwggV/oAMCAQIC
# EzMAAABH45ULN6Fg3ccAAAAAAEcwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODUwWhcNMjUxMTE5MTg0ODUwWjCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjdBMDAtMDVFMC1EOTQ3MTUw
# MwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhv
# cml0eTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOhwum733P/414hm
# ZHfYYmDZVP+N33qlguy82eB4fipfArWpWYVpdeSRVvFvV85Aky6RiRtrdYRzr1b9
# ngGzMC7GC5OENWVj2yThliQYyDGirVnmKdQ++PhCHzFW+WGIBLo5/+4vAOxuwqWD
# Z8ama/O2I9I4v0/XmTTQjhuyXW+WZFK63a03AlDmxemhPsYj/ZPYDQadZsUQIpEL
# IZb2uyfL2jQs0hSXg1gB3hrAZKzo4jMo+kgrUl8r3TBce9pfAYlw30/xA9Ekgcq4
# WhUbMhQb8LSNALitDrbJMa9zaxngDFNDB+V9UEFqIeryCf9gMelmKV4aQHYhBrNk
# SIRzk6vld6v2ZQNT7YUR7rrDx7ZaQtdqerFoPn5lyj4T5B3BxNgajvyMXE8O82tp
# OvlACAhNzh1j88ELdxgXNyAPJTHbE5UIG+BpuonGPuteuPgGF3ZL9lNg5UeGLxwN
# YFp58zwmCI7wYIghG+U1aeDwUoW3T1l83GaxJ0ImVbDes0DCwFjXGnymaa/2vYz2
# s0hGRn6yHTF3ca4BJazZs6uoGLRpPOBj1vcLFj7+b5FT5ROKbkmSakkz8Ag/rz9L
# 7U3AWpcrnLFMkEgieGgSB0QeL5rYlHZKVXcCSklrT8HqxlqgRr7OCyEh8VrrpcGa
# eezJ1Xi4btbUg2ho1XDEEoN2ao1HAgMBAAGjggHLMIIBxzAdBgNVHQ4EFgQU5FR2
# WCA6Pu9PubZe8WFIRbyG3WgwHwYDVR0jBBgwFoAUa2koOjUvSGNAz3vYr0npPtk9
# 2yEwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljcm9zb2Z0JTIwUHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5n
# JTIwQ0ElMjAyMDIwLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKGXWh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIw
# UHVibGljJTIwUlNBJTIwVGltZXN0YW1waW5nJTIwQ0ElMjAyMDIwLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w
# CAYGZ4EMAQQCMA0GCSqGSIb3DQEBDAUAA4ICAQANIlRD1dqYOHSCQLVe+uFXPoAz
# AZUq4okD62SUnMFrhRVg/dj2vVEtTTxFgkiM8SSnCLANaK0rnyCxnHA2Hg1zh8WJ
# CtlQln0Eid+eh2/xY47zfNjxhB0kxymAHN5hVeI0J526aoUpePSYwy5ZoHKe/vDC
# fsWccnDMuu7iO3hUt55/4HJydjA+gxrvksX/3Fmj/RMnfvWq0Fh1uxx4qY2FBRMP
# a8i+8+QdM8f80DYiQuxDUCbnWfOHnZYQPNEKhd6V3r78oKWd+wQHX+99Hqlg/HBl
# O9Nnu6HvLwPqDiEOkRyMix6zvnhbZpGnFM+u7qf7PYTOS8cXvQH+DmgCh2ZVNQFv
# 6nGm7vtQebROtpWh2N9ckk2z6HVGOcK70yKS7YqE+akGuxKd7fXLeBey2bm9y2nW
# 0WjH1qZNa+EhXzyXUQgLfJf4E31wYq0vrlESX/LzKprY8hbaLXwkxEivhPuWId9f
# QDqx0+yXsa50vIRUcBaxbw0VXO3+93JGHMxSmzGE8vWoZCAPjlD7duBOV6XkxaVa
# Bgb5v4stRdHm6LJtsizCc5FNT+MPJw0DHy7hzn7Xix6fn9+apytBrfXqXtapxDqs
# 5yjEMXKbuTZFW4SFk1Dhc1cIojuRvw8ytG0xuhtXSavJ3RSVtBRs+wm432dQTYAO
# aCc7dtAbIRG+ml50ITGCB0YwggdCAgEBMHgwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABH45ULN6Fg3ccAAAAA
# AEcwDQYJYIZIAWUDBAIBBQCgggSfMBEGCyqGSIb3DQEJEAIPMQIFADAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDQwNTIyMzAx
# NFowLwYJKoZIhvcNAQkEMSIEIAsZfa5pVGaD/pldIsNLB70UKxo5wW6+vULihx8y
# 3hbQMIG5BgsqhkiG9w0BCRACLzGBqTCBpjCBozCBoAQgk2bzlnKFAAYZ71A+F3f7
# G+YwoK9+MeF/y2XqZEgKzKcwfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABH45ULN6Fg3ccAAAAAAEcw
# ggNhBgsqhkiG9w0BCRACEjGCA1AwggNMoYIDSDCCA0QwggIsAgEBMIIBCaGB4aSB
# 3jCB2zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjdBMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaIjCgEBMAcGBSsOAwIaAxUA
# IAXT2b4gvIw3J1lPs/eU4s1UXN2gZzBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwDQYJKoZIhvcNAQELBQACBQDr
# nB+xMCIYDzIwMjUwNDA1MjEzMTI5WhgPMjAyNTA0MDYyMTMxMjlaMHcwPQYKKwYB
# BAGEWQoEATEvMC0wCgIFAOucH7ECAQAwCgIBAAICD2gCAf8wBwIBAAICErAwCgIF
# AOudcTECAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQAC
# AwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAUNtJrHYQe4ljJ8od
# Yb2xpEYaIPFQIDkK5dzCR4u/+ocdox0PqGgEDwfAlL7J9n+hc1+ftjg8Xe5p1A8p
# fbVOTaA5SoMJl49sYpS2nwUazlvKUUYIpcgN4CbCEAiYCQLylBBIPbgSWO27dmCb
# 8/wyAmwnm/9jtaLGJhrsL1wUzhi9sngNaO/7MdGGgX/0AUHkzUgCkOGTmeHAb1sK
# FxdUN/Xf+A+taK64cCpHt0mWaxM/w/oxJZNF6PSr9X5iJBDNwIrwAKAKmVqI+Wi5
# f4ui3oRHLqekgsX9qm9iHK4F3JmWr/SGCUyziMrQoFRzpcOKYgjyYFC+Gk4ghqR0
# KEPkKjANBgkqhkiG9w0BAQEFAASCAgCCrdinRLyO1RmVSh7ynXO/IKayECwCXlFx
# 8z5AjDAn4ZBc234dpB6mC602lsV0W566JExsOc5hC9HB0jHXpyIOcDKKLYfjKwVq
# iz+m6xk+A6UAxQ+7Q1NSKbAoMXGXn7lYzVXCJ5uFTV3RlMjGGZYQg3AK2n+28rmX
# o8TOmZS52CLy/XRE9J1aBQKc1bpiUIhqZ+j2j4bWRHsBxWLxL25ALWM+Lb/H6MVE
# aNYkhb2VVrmR39iwQXXasYSFidfblCZZzOWRYqpbmmuFcYhShHHnWOz8+eyrs7gk
# g9YchDvzTL/jgxZ3qn7KQlEXncErriP0X6zi9MYOBoOXr5xO19EXaIOFHQ2rrq9m
# 7Juzl9EEfy0yV0A/zQYBQWfntwF8ELeMx/yYEitfxoSRaT75lp0J4y17YHbqRZD1
# gmdJjeHv92W0noAF0Fk8OL+mfnUJwbi/2cceMaAfWF/83VAcldkLRsEQHT82+40T
# 3x3a7jILNoHjaZtAaDg/KcJqK84dU8z6xq6K4vOhf0D+Cn0DA1+O2z60ydfLHwbQ
# w3+iLc2zONqcwm3OigllSTCDkw/RdCCL4cKm0ibfBmYu6yXctJogxvu0DtCpXUWx
# 3wi04ytsNnja6rRvKo+wyKi5Bdw82e1ERe0HwvtsyvWrRxZPvkpTcyGDSZhg5BoP
# jPaZOKmK3w==
# SIG # End signature block
