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

[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    [string]$configFile = '.\.secrets\config.json',
    [Parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)][alias('DNSHostName', 'ComputerName', 'Computer')] [String[]] $Name = @('localhost'),
    [Parameter(Mandatory = $False)] [String] $GroupTag = 'MSB01',
    [Parameter(Mandatory = $False)] [String] $AssignedUser = '',
    [Parameter(Mandatory = $False)] [switch]$check,
    [Parameter(Mandatory = $False)] [switch]$NoModuleCheck,
    [Parameter(Mandatory = $False, ParameterSetName = 'NoUpdateCheckSet')] [switch]$NoUpdateCheck,
    [Parameter(Mandatory = $False, ParameterSetName = 'UpdateOnlySet')] [switch]$UpdateOnly,
    [Parameter(Mandatory = $False)] [switch]$NoAdminCheck,
    [Parameter(Mandatory = $False)] [switch]$NoSignatureVerify,
    [Parameter(Mandatory = $False)] [switch]$NoHashVerify,
    [Parameter(Mandatory = $False)] [switch]$GetDeviceHash,
    [Parameter(Mandatory = $False)] [switch]$Redeploy,
    [Parameter(Mandatory = $False)] [string]$SerialNumber = '',
    [Parameter(Mandatory = $False, ParameterSetName = 'UpdateOnlySet')][ValidateSet('github', 'gitlab')][string]$Repo = 'github',
    [Parameter(Mandatory = $False, ParameterSetName = 'UpdateOnlySet')]
    [Parameter(Mandatory = $False, ParameterSetName = 'github')][ValidateSet('auto', 'main')][string]$Release = 'main'
)

#import functions.
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
            Write-Host "Defaulting to main branch."
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
    # $baseSourceURL = 'https://git.gao.gov'
    # $baseRepoURL = 'https://git.gao.gov'
    # $repoPath = 'mahmoudz'
    # $repoName = 'autopilot-deployment'
}
else
{
    Write-Host 'Invalid repository specified.'
    Write-Host 'Defaulting to the main branch from GitHub.'
    $latestRelease = 'main'
}

#Define variables.
$maxWaitTime = 30
$timeInSeconds = 60
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
$localManifest = Get-Content -Path "$PSScriptRoot\manifest.json" -Raw | ConvertFrom-Json
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/manifest.json"
$modulesFolder = "$PWD\pwsh\modules"
$modulesToInstall = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.DirectoryManagement',
    'Microsoft.Graph.DeviceManagement',
    'PackageManagement',
    'PowerShellGet',
    'WindowsAutoPilotIntune'
)

if (-not($NoSignatureVerify))
{
    Write-Host 'Verifying code signature.'
    $codeAuthenticity = GetSignatureStatus -scriptFolders @("$PSScriptRoot", "$functionsFolder")
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
    $fileIntegrity = GetScriptIntegrity -scriptFolders @("$PSScriptRoot", "$functionsFolder") -RootFolder $PSScriptRoot
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
            Write-Host 'Failed to update scripts.' -ForegroundColor Red
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
else
{
    Write-Host 'Skipping script update check.'
}

if (-not($NoAdminCheck))
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

$deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
$serial = $deviceObject.serialNumber
$hash = $deviceObject.hardwareHash
$make = $deviceObject.manufacturer
$model = $deviceObject.model
$parentDir = (Get-Item -Path $PWD).Parent.FullName
$outputFile = "$parentDir\device_$serial.csv"
if (($Redeploy) -and ($SerialNumber -ne ''))
{
    Write-Host "Checking redeployment status for device with serial number $serialNumber"
}
else
{
    Write-Host "Processing device with serial number $serial, manufacturer $make, and model $model."
}
if ($GetDeviceHash)
{
    GetDeviceHash -Device $deviceObject -OutputFile $outputFile
    exit 0
}


if (connectToTenant($configFile))
{
    Write-Host 'Successfully connected to Microsoft Graph.' -ForegroundColor Green
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

if ($Redeploy)
{
    if ($SerialNumber -eq '')
    {
        Write-Host "Checking redeployment status for this device, serial number $serial."
        $SerialNumber = $serial
    }
    else
    {
        $reminderMessage = 'Remember to reboot the device after the script completes.'
    }
    $enrollmentState = VerifyEnrollmentStatus -serialNumber $SerialNumber
    Write-Verbose "The enrollment state is $enrollmentState"
    if (($enrollmentState.imported -eq $false) -and ($enrollmentState.enrolled -eq $false))
    {
        Write-Host "The device with serial number $SerialNumber is not imported or enrolled." -ForegroundColor Yellow
        Write-Host 'Continue to import the device.' -ForegroundColor Yellow
    }
    elseif (($enrollmentState.imported -eq $true) -and ($enrollmentState.enrolled -eq $false))
    {
        Write-Host 'The device is imported in Intune but is not enrolled.' -ForegroundColor Yellow
        Write-Host 'Continue to check assignment.' -ForegroundColor Yellow
    }
    elseif (($enrollmentState.imported -eq $false) -and ($enrollmentState.enrolled -eq $true))
    {
        Write-Host 'This is not an Autopilot device' -ForegroundColor Red
        Write-Host 'Please contact an Intune administrator.' -ForegroundColor Red
    }
    elseif (($enrollmentState.imported -eq $true) -and ($enrollmentState.enrolled -eq $true))
    {
        Write-Host 'The device is enrolled and is registered to a user.'
        if ($enrollmentState.userName -ne 'unknown')
        {
            Write-Host "The registered user is $($enrollmentState.username)"
            Write-Host 'You must wipe the device to get it ready for another user'
            Write-Host 'Wiping a device is a distructive command.  Make sure you are wiping the correct device.'
            Write-Host "Device id: $($enrollmentState.id)"
            Write-Host "Device serial number: $SerialNumber"
            Write-Host "Registered user: $($enrollmentState.username) `r`n"
            Write-Host 'Would you still like to send a wipe command to the device? (Y/N)'
            $response = Read-Host
            while ($response -notin 'Y', 'N')
            {
                Write-Host 'Please enter Y or N.' -ForegroundColor Yellow
                [console]::beep(500, 300)
                $response = Read-Host
            }
            if ($response -eq 'Y')
            {
                $response = SendDeviceCommand -ManagedDeviceId $enrollmentState.id
                if ($response -eq $true)
                {
                    Write-Host "The wipe command has been sent to the device with serial number $SerialNumber."
                    Write-Host 'Please manually sync the device or give the device enough time to sync and reset.'
                    Write-Host 'The device will be ready for another user after the wipe is complete.'
                    Write-Host 'Please contact an Intune admin if you have any problems.'
                }
                else
                {
                    Write-Host "The wipe command failed to send to the device with serial number $SerialNumber."
                    Write-Host 'Please contact an Intune admin.'
                }
                exit 0
            }
            else
            {
                Write-Host 'Aborting script.'
                exit 0
            }
        }
        else
        {
            Write-Host 'The user is not registered.'
        }
    }
    else
    {
        Write-Host 'Unknown error.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        exit 1
    }
}

#Let us check if the device has already been imported.
$assignment = Get-AutopilotDevice -serial $serial
if ($assignment)
{
    Write-Host 'The device is already in Intune.' -ForegroundColor Yellow
    Write-Host 'Checking profile assignment'
    if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState')
    {
        Write-Host 'The device is assigned to a deployment profile and ready for enrollment.' -ForegroundColor Green
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
        GetDeviceHash -Device $deviceObject -OutputFile $outputFile
        exit 1
    }
}

$importStart = Get-Date
# Add the device to Intune.
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
            Write-Host 'Congratulations!!! ' -ForegroundColor Magenta
            Write-Host 'The device is successfully assigned to a deployment profile.' -ForegroundColor Green
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


# SIG # Begin signature block
# MII9YAYJKoZIhvcNAQcCoII9UTCCPU0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+MRfXYQoL58I8
# 35TEyYCXdepGm2pXq9RWH4SmXfrEqKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAIuPHTH
# MqChChR4AAAAAi48MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwMzIzMDcwNTE3WhcNMjUwMzI2
# MDcwNTE3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# jq07Oc856+3Ar5sHEN8BkdCRP7uZCDM2SCvyXjno19/OfMlTIkrkSTVhd7t89i/R
# z8rZh0Paeqx9kJVzbLPgaiHQjQNjBiAOaBCNXrbI/BO4+VQSbufELlhbuPUvMENu
# Z9LXtgYfdpR3rdhukeDuyFtehpr4AU0IgGbfEiR2FPqsVibESebdB7hS2qfUntC5
# kyi2lRUJ5juOvOvV7CUWeG4gGf68td0yILRbXTAuO6Xdjp8DIHvJbVbAmifiWctR
# gqITnSBgdX8KRTyFyKA1nWsKA1xFzRB1B7ZWvanBZG7eMcDCRUsAgpVKJIxIz9sM
# ArrJIEzgSWUxRtbaxEAiTe3Aaln4JrjR6ngPJLN+Ueq8Rz7wWGxDRtnbf23skByf
# YYTw90kmeAWt1NuYvyxvlgYaRq1m+snwfZ85h+WlbecP1jCt8Is29grlcCrthiaZ
# BuEt3VDk+gHL5Yyx1ZmHbiPv103w5s5n8WMz1n2Yrsyxho90+0zWXNCQHgCfxDmP
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFP0DrSq+3Bg1I0fWPLvz2OOId/T2MB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAIa5KqNBil9JzDDA
# bwYwAtBECoU1CaE3A5gjRdWU1G9PanUkG0EVOyPG2/bn4tz9A3pPZLqTk+g6jdWY
# 0w526YhOJzYV/YysDZN6Few33TgXcW4S4dlF29nNhcBre7KQYRmDO8S194hoFq0h
# fvaSTp2Pbvz5nofEhQxmB1sxA9gbAaXhUqJ61wVJZNEtN9H83Ia+9qFJl+gJU/8g
# TliqE/HM7op+05r08x/46tLoYhvBL8tJ1GA3JMB3RM7xBvu0sELgvNJSqI3gUL8W
# HJYkUuCN4uv86r/0F/mo+0/zUtVpKp112QmCCjTj/XkRMV63In94t2FpmqQFNVmm
# bRLMEMHJeLLUYfW05FfobW5j49rEuswDkQwhBBWvqugHzdEKFsmGPn3Mw2zUUwTm
# /FOHNOHvEN2sCl2N1hgZRsqnnX+otH7/60nQz0vDoRC2ssYZxS8Ck2Guv884wPrb
# WfxL9Yykc51gbT7ywcrJpLgCRO9D1krtTR/j2MTttT3hrb1E38zaOjknlLvuBDAE
# M3usM5sQiy2AAMHAjoYH6Mb1E+p6Nf4F5vfL7F2almZUMi9tMxFwsBcw3FAH35vA
# wM669BBGPYG0e7QcLWLxofYNfGNmG3L8M2lpR/m/POFOnZwDfRR5WI+YAXS5Awc2
# A2NremqS9vgmvambJYB4wW2ynPzmMIIG5zCCBM+gAwIBAgITMwACLjx0xzKgoQoU
# eAAAAAIuPDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDMyMzA3MDUxN1oXDTI1MDMyNjA3MDUx
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAI6tOznP
# OevtwK+bBxDfAZHQkT+7mQgzNkgr8l456NffznzJUyJK5Ek1YXe7fPYv0c/K2YdD
# 2nqsfZCVc2yz4Goh0I0DYwYgDmgQjV62yPwTuPlUEm7nxC5YW7j1LzBDbmfS17YG
# H3aUd63YbpHg7shbXoaa+AFNCIBm3xIkdhT6rFYmxEnm3Qe4Utqn1J7QuZMotpUV
# CeY7jrzr1ewlFnhuIBn+vLXdMiC0W10wLjul3Y6fAyB7yW1WwJon4lnLUYKiE50g
# YHV/CkU8hcigNZ1rCgNcRc0QdQe2Vr2pwWRu3jHAwkVLAIKVSiSMSM/bDAK6ySBM
# 4EllMUbW2sRAIk3twGpZ+Ca40ep4DySzflHqvEc+8FhsQ0bZ239t7JAcn2GE8PdJ
# JngFrdTbmL8sb5YGGkatZvrJ8H2fOYflpW3nD9YwrfCLNvYK5XAq7YYmmQbhLd1Q
# 5PoBy+WMsdWZh24j79dN8ObOZ/FjM9Z9mK7MsYaPdPtM1lzQkB4An8Q5jwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBT9A60qvtwYNSNH1jy789jjiHf09jAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQCGuSqjQYpfScwwwG8GMALQ
# RAqFNQmhNwOYI0XVlNRvT2p1JBtBFTsjxtv25+Lc/QN6T2S6k5PoOo3VmNMOdumI
# Tic2Ff2MrA2TehXsN904F3FuEuHZRdvZzYXAa3uykGEZgzvEtfeIaBatIX72kk6d
# j278+Z6HxIUMZgdbMQPYGwGl4VKietcFSWTRLTfR/NyGvvahSZfoCVP/IE5YqhPx
# zO6KftOa9PMf+OrS6GIbwS/LSdRgNyTAd0TO8Qb7tLBC4LzSUqiN4FC/FhyWJFLg
# jeLr/Oq/9Bf5qPtP81LVaSqdddkJggo04/15ETFetyJ/eLdhaZqkBTVZpm0SzBDB
# yXiy1GH1tORX6G1uY+PaxLrMA5EMIQQVr6roB83RChbJhj59zMNs1FME5vxThzTh
# 7xDdrApdjdYYGUbKp51/qLR+/+tJ0M9Lw6EQtrLGGcUvApNhrr/POMD621n8S/WM
# pHOdYG0+8sHKyaS4AkTvQ9ZK7U0f49jE7bU94a29RN/M2jo5J5S77gQwBDN7rDOb
# EIstgADBwI6GB+jG9RPqejX+Beb3y+xdmpZmVDIvbTMRcLAXMNxQB9+bwMDOuvQQ
# Rj2BtHu0HC1i8aH2DXxjZhty/DNpaUf5vzzhTp2cA30UeViPmAF0uQMHNgNja3pq
# kvb4Jr2pmyWAeMFtspz85jCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGhAwghoMAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACLjx0xzKgoQoUeAAAAAIuPDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBnEOTueCHMK4sFA0leaI0e5Og7
# 2BJFu6SV9Ev6mBp2nDANBgkqhkiG9w0BAQEFAASCAYBew/tMujbydV1vq9He3tBi
# prCzVE8mMQF6thNaiwgkSAqr+e3V727tQKk3oHdDWD6Q5VxgGQNpTatSKcuBnmrr
# iHT6lHAz37imS5VNkW+2ISYWhORb+eCOlGOsjc9RwdGudjoKBNmKPymtyl9vXFUm
# uiH5lH8LUfveMKZv9CxLoQyczMllebCyaMEx9B1lwpSsSESUouBxueM/UxJCirBO
# Kc3RiPGtYaIT4miJ4WlP8XWxcK/IBDAlZNoyl3QG5iBgV/0DkcOrVBTAPF7V+4gb
# eMW1ZBHhNi6L6yx4lbztqT+GYgMZdd/CRSVlWP2d+R9WTElnY0KHpngTmALL6X5B
# O9r/3pD60CSZy0+IwV7Gz6UikA21pFJHhS5geZvauSrucIVNUK3ELYBIjlhY9Zj7
# Pm8cliJ9w3BTP9ILluu+7Avl+f7pHcZGK8PweZYeR9CbJJVkN8tMFdAq+JJW+nXc
# fl9zNBJ7lZ0PaMoDjxX+k28LEwT80I3SSLIZ1wTmPzOhgheQMIIXjAYKKwYBBAGC
# NwMDATGCF3wwghd4BgkqhkiG9w0BBwKgghdpMIIXZQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQg3FuUZiPTKnwrgMIIC00HgW5e+SoWibtkdJmIMzPQ
# bn8CBmfYCnfm9xgTMjAyNTAzMjQwNDEzNTAuOTIyWjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046NDVENi05NkM1LTVFNjMxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF
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
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQIC
# EzMAAABJcL2GqhZ4TDEAAAAAAEkwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODU0WhcNMjUxMTE5MTg0ODU0WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046NDVENi05NkM1LTVFNjMxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA+pnMBEJ5wYi/nr7N
# 9J+y+uRiVD3AMm7/Q/hyzkTwT7NbQgYHobrt4NzYffDmTKX7EhoDOE0ivbiIlvSC
# p3AggM2AUVGQ3DpZRWYsTQJrPgEIK7JJ0WADhp8HOLAm3RDEfTkTyi2VZg4jJtYS
# MaQpgGPlp32JoQlHfWnYLNTwHoxhLEhuM2nv8tYkS0G30+SF+0jO4E61Zqr/oSHs
# xHE008r+dVyI5o6M9dCPczDaqAv/+aDc6QJ50tj/2Ug5uK8w3+otsQEh4R6n8JBD
# vXigwdJz8jgHdIzS5qTptOEHqzw0WiaSfA0xaF7AyeRYqe3KbD40UokOnXfiMJRb
# IXNz+wxi1tu1sKJIwPWP7PJFV4xnESb9uXsao5CCkWhCNqOZkbX2VKSkvjLVy3CC
# hpxTKZHgTsYERHg5goOr5svVmlI+zxZaPf7SzoLhk1eFiE2I8LUQ7hEs8oKfGtFk
# EwedPAjv7bpS1jKd5b6zjnTPGaNpI50Ulj3m4oqoQ1s0snP/tOOal3mVhsj9YbTK
# oY142uqgkiZhxrYMgIxkCAowm2OQDAWVhzITxjer/KGHzwnL4VX/1BSfJRs8LnI0
# GKDFhrMT3N1EufYiHEwvY+cw9wuvZVuSToLZzXDAWhqBbOClXL3e9z3dUlYolWRC
# LPgGWE9xCf6qrugNB2NZOrADiOMCAwEAAaOCAcswggHHMB0GA1UdDgQWBBRVjnhP
# XjrArN1QumQu7fwTWwJKCzAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBAGF+OSZ1G/RYme6il24h6LDoni1m
# wawibMfur2XjEPdVwGjz91D3c7wavAVE1rnX1EKWyVJ1+QNCsN2EewZ9h3/Fhl1t
# YrjBz+6T4jgOzsgFEXiFhmuIieWMY2+eFMFSw4RcNUdP1fOJz1cNNPk12XL2W69y
# mUXhJLZjD1xVE98Y+Nt2NG0WPzXBHkzQW+rhepIsL1hQmgTWXs1cP/R/K7AT4VB8
# /D7X+u3U2HILtYJad72zlBYfQQZH5tsPsVjlBtRWYcMeAsdJzSNjsxOyWgyA6jqZ
# ivOm7wLuv1xS7yiaIfyTotDGNHJ1VGPwITrbTv0PQiirFLumFLIUEywIXqC1sudZ
# NxXI8z48QmuHH/KMPGkiFyq1E2XUB3PDjgjv5bCHV170f/Lgh+msMFqO/V3YoOfA
# jsRUdgJX7TlE4Dnp9NhPqLTcH8evZldegxHs6YzEflUovsJpBK6wCBuqt9TAqx1r
# H0REYeBmTVIVUh68i6yVmPFYsJazv8WXVDLbmSDuCrQ8kbv4MHdoYJy7dF/qmURf
# 9xkBuajORGaT+uRmDRLboMZHLIufi/pglNDt0Bb16+HvkJ654b+sTZ45SWNLmUb9
# QXKSt5iMMdCfzsM8LDsovzgeRG+Oal7YeLSi6GSOGxPLlcSvtXN2csLGzRPVNMJt
# FeaToNBfSPI9KyaIMYIGxDCCBsACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAElwvYaqFnhMMQAAAAAA
# STANBglghkgBZQMEAgEFAKCCBB0wEQYLKoZIhvcNAQkQAg8xAgUAMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUwMzI0MDQxMzUw
# WjAvBgkqhkiG9w0BCQQxIgQgwIvwUBmSDUTlzQxhayzdQD051J7d4QxI6t477lte
# uXAwgbkGCyqGSIb3DQEJEAIvMYGpMIGmMIGjMIGgBCBZKDgGu8T+xwIzm2AmYzwg
# NDM/08rlNoMjGGIJ5AbVIjB8MGWkYzBhMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVibGlj
# IFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAElwvYaqFnhMMQAAAAAASTCC
# At8GCyqGSIb3DQEJEAISMYICzjCCAsqhggLGMIICwjCCAisCAQEwggEIoYHgpIHd
# MIHaMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjo0NUQ2LTk2QzUtNUU2MzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1Ymxp
# YyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMVACAL
# jk8yViMVfCNap6QGEogntH7UoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBBQUAAgUA64sa
# kDAiGA8yMDI1MDMyMzIzNDEwNFoYDzIwMjUwMzI0MjM0MTA0WjB3MD0GCisGAQQB
# hFkKBAExLzAtMAoCBQDrixqQAgEAMAoCAQACAg6aAgH/MAcCAQACAhHjMAoCBQDr
# jGwQAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAm0J676IofY/OkraTt59O
# Jj+A11ZaLCFUprAJ8FcdRigB0nJr5FXgY2CALhKWt5jGnlpf8OXhyUiVSBYTfcAY
# rQjoSgr6d4Gyp1S5yFFWi5sXKLgDmVEF+ckW/h73oze8wZCUEXWCA2EehnZU9BXS
# eN57EkIadRhD5izN/eCy014wDQYJKoZIhvcNAQEBBQAEggIAgMLbxNL2+NijZoFz
# zrhUorXVEU9rKO27CAIM1HTTC3Sxzwn/GZD+xVl+tbMUpLj4TzDmGnhLV/l3lYQ7
# MnLsq9DPddhjVSm8P0+AICfvkn5E60aX6atzfrnRx+6zkCqcJZFijbtlg7iU67Az
# SRsoBATvDYMAFqHx62pVniayzJb+56kELL0Y6rZbPvwgVuUywjTrcRk3RQ5lvC1O
# nAasU84vmqXnUIiIuuQccR/eUp3F7tac0zUvcfuPUUtx3skNDLHIOFxc26N2DNOV
# CHceF71INHpTFHBRouf1Ic+yEqGQhB25EAzdkULctWf6ILI/0WoxcToFrpC1vzX9
# jRUDHL77JR/90f6uDWSvf27u08ujOi1Ed96Yo2+5qfshzAKzxUNIyTX9CMcj2Mog
# M4ct8N8HLwGi2UmBshc81p7hcYds1F5qiGqB9SgJuyhbJOOTDHd0FOdky/ccTgpI
# uyJH43vhwhXXNHsYvycXyHagGxa0/ULehOVO4Uc860LX96Q2EtcnqZpFVi/xojIZ
# Ik92TkNyvMqsD6T9CWZkZWRZFoNkpUC2niRGyn5zsQxl0VZMJ1RG1AyPPHocFY9J
# XRuEBG6zLGmjoMjkUVBCMdq8k1G3oRMRIOIX0QvdsdgI+WKnuZsnrcSJouBPmMIq
# Z8vVG/Apc1xz6phPG0anwe2bbZs=
# SIG # End signature block
