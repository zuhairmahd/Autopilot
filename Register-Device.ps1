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
    $scriptsToUpdate = $remoteManifest | Where-Object { $_.method -eq 'update' }
    Write-Host "The number of scripts to update is $($scriptsToUpdate.count)"
    exit 0
    if ($scriptsToUpdate.count -gt 0)
    {
        Write-Host 'Would you like to download the latest version of the scripts? (Y/N)' -ForegroundColor Yellow
        $response = Read-Host
        while ($response -notin 'Y', 'N')
        {
            Write-Host 'Please enter Y or N.' -ForegroundColor Yellow
            [console]::beep(500, 300)
            $response = Read-Host
        }
        if ($response -eq 'Y')
        {
            Write-Host 'Downloading the latest version of the script.'
            if (GetScriptUpdates -scriptsToUpdate $scriptsToUpdate -scriptURI $updateURL -ScriptRoot $PSScriptRoot -scriptVersionURL $remoteVersionURL -scriptHashURL $scriptHashURL)
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
            Write-Host 'Skipping script update.'
        }
    }
    else
    {
        Write-Host 'All scripts are up to date.' -ForegroundColor Green
    }
    if ($UpdateOnly)
    {
        Write-Host 'Update check complete.'
        exit 0
    }
}
else
{
    Write-Host 'Skipping script update check.'
}

if (-not($NoAdminCheck))
{
    Write-Host 'Checking whether the script has sufficient permissions to run.'
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
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
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDzsqavqJmV5D+I
# 0qxuhFVqyIVaukngQYtdixpb1zeh+KCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAMMtJvn
# rrWgNRokAAAAAwy0MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwMzIxMDcxNDE1WhcNMjUwMzI0
# MDcxNDE1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# tBsEz+zbg92T+0waG5eMjJkVWC9CW3VdTvZl7bFz8UrQV4ym1lWDXIuixT/obXOR
# 10SMyZ8nfRztD3Nxzyx6WF7crrKI6exQTRFkXclbyxiIpYYggA0h2HcVjGn0woEY
# JLQMGplBHinAUvJnVX5L2QHhw2Z3LEAbmjIcI5cfE96UdOMV2hj6e/Rn15I4qvgi
# o7viABNWhxNOPDu0tXi7HmoDxJR5Y859WQ+PEs+i1k7GuIdp9Um4l2StLa5zGzfJ
# rEWvMbVSWN7qFifgxyIYJKPnMlMDJVJWGDgNqclCjypW9UtKcu3YdeXBwmNBkQqQ
# 9DocbACp2xmmS/2a5++lv4gL8tQpHEVdkqoW7CiY5dsOXAZa1WSOZMaV49Lle+hv
# jEAcZzjucWB1vOAjJUz9y39wuyzNZMgUpV9N+VrzsNIQMTMOTDEQAuKRPy01Ycig
# nBSHjqZPYxuyjIqF7i1GzJ6jEDcpvS42e1IrqwfoKX1VRbyn5NxZwmQ0UstvWo0N
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFDW4qjO4Q+HRGucAaV+VaeqapYe6MB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBACEZW/cvYGkaW6NA
# ypVO36NtlcPr4ZdnY8lOgk6mhdBz1xjIO7R1xRPmtLhIApomav0Q8CqKZYRrNywX
# g1la6IG8wfNRbhswGtxSXztJA5fB9NlOyEAEa+73cX4HRc9ilCN/Fd16naercH0k
# tjkVsHjhouuvCOPgR78EwpXC/KHEEzh8vMsrcuwfBT7URUYRG24qnz11VXyAix2W
# 90fm8DK4Ob6KefSd46Fii/aLLzabm3LHTOjUR6+bmYWg+8KxA7qfe9zQTa2op6YK
# OMkuBiJzxmcqpni9BkoM1dewbwsjhfXFEiKRIOgbYT2F/oHTRUtAKhvtp0WAvR4Y
# GYlr1L5l0swqGoh7cfvieDYrRR9yYF0eeRxy8yAlqemwjM1hZ5FfKBudFVXQlCuO
# i/I/Nsrx8e7NuDp2xOC9dKnpm02UD3PCcwtY+wmUYGJ7VAQwXPyon7JMZqTVsU54
# KZtHYPsWFEtDmTZ1VFxMCva12TU3e/b+yxdlzS3Cn2Ov0CDDQQtZPSnI44pfBNDL
# v3ZerM45bJFRXPhD1ouzf7FHES0oqBnc5NsmbueFwXMzY/s2CKHhQip2ZAMWpoXe
# ros6Dvn4ABn3Hfe+yzZ3LBCxD/zQ7zdQjEjmQY5AjGuL6UVkHpR4jR6mJ6xTlw8z
# 2+oF0pWpLFCRxiLBiDsjVWIZUcfFMIIG5zCCBM+gAwIBAgITMwADDLSb5661oDUa
# JAAAAAMMtDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDMyMTA3MTQxNVoXDTI1MDMyNDA3MTQx
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBALQbBM/s
# 24Pdk/tMGhuXjIyZFVgvQlt1XU72Ze2xc/FK0FeMptZVg1yLosU/6G1zkddEjMmf
# J30c7Q9zcc8selhe3K6yiOnsUE0RZF3JW8sYiKWGIIANIdh3FYxp9MKBGCS0DBqZ
# QR4pwFLyZ1V+S9kB4cNmdyxAG5oyHCOXHxPelHTjFdoY+nv0Z9eSOKr4IqO74gAT
# VocTTjw7tLV4ux5qA8SUeWPOfVkPjxLPotZOxriHafVJuJdkrS2ucxs3yaxFrzG1
# Ulje6hYn4MciGCSj5zJTAyVSVhg4DanJQo8qVvVLSnLt2HXlwcJjQZEKkPQ6HGwA
# qdsZpkv9mufvpb+IC/LUKRxFXZKqFuwomOXbDlwGWtVkjmTGlePS5Xvob4xAHGc4
# 7nFgdbzgIyVM/ct/cLsszWTIFKVfTfla87DSEDEzDkwxEALikT8tNWHIoJwUh46m
# T2MbsoyKhe4tRsyeoxA3Kb0uNntSK6sH6Cl9VUW8p+TcWcJkNFLLb1qNDQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQ1uKozuEPh0RrnAGlflWnqmqWHujAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQAhGVv3L2BpGlujQMqVTt+j
# bZXD6+GXZ2PJToJOpoXQc9cYyDu0dcUT5rS4SAKaJmr9EPAqimWEazcsF4NZWuiB
# vMHzUW4bMBrcUl87SQOXwfTZTshABGvu93F+B0XPYpQjfxXdep2nq3B9JLY5FbB4
# 4aLrrwjj4Ee/BMKVwvyhxBM4fLzLK3LsHwU+1EVGERtuKp89dVV8gIsdlvdH5vAy
# uDm+inn0neOhYov2iy82m5tyx0zo1Eevm5mFoPvCsQO6n3vc0E2tqKemCjjJLgYi
# c8ZnKqZ4vQZKDNXXsG8LI4X1xRIikSDoG2E9hf6B00VLQCob7adFgL0eGBmJa9S+
# ZdLMKhqIe3H74ng2K0UfcmBdHnkccvMgJanpsIzNYWeRXygbnRVV0JQrjovyPzbK
# 8fHuzbg6dsTgvXSp6ZtNlA9zwnMLWPsJlGBie1QEMFz8qJ+yTGak1bFOeCmbR2D7
# FhRLQ5k2dVRcTAr2tdk1N3v2/ssXZc0twp9jr9Agw0ELWT0pyOOKXwTQy792XqzO
# OWyRUVz4Q9aLs3+xRxEtKKgZ3OTbJm7nhcFzM2P7Ngih4UIqdmQDFqaF3q6LOg75
# +AAZ9x33vss2dywQsQ/80O83UIxI5kGOQIxri+lFZB6UeI0epiesU5cPM9vqBdKV
# qSxQkcYiwYg7I1ViGVHHxTCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC398ADKAfFuj6PEDTi
# E0jxvP4Spta9K711GABrCMJlq7VjnghBqXkCuklaLxwiPRYD6anCLHyJNGC6r0kQ
# tm9MyjZnVToC0TVOfea+rebLBn1J7FV36s85Ov651roZWDAsDzQuFF/zYC+tLDGZ
# mkIf+VpPTx2fv4a3RxdhU0ok5GbWFKsCOMNCJnUmKr9KqIOgc3o8aZPmFcqzbYTv
# 0x4VZgHjLRSU2pbRnYs825ryTStsRF2I1L6dM//GwRJlSetubJdloe9zIQpgrzlY
# HPdKvoS3xWVt2J3+mMGlwcj4fK2hpQAYTqtJaqaHv9oRl4MNSTP24wo4ZqwiBid6
# dSTkTRvZT/9tCoO/ep2GP1QlhYAM1gL/eLeLFxbVUQtpT7BOpdPEsAV6UKL+VEdK
# NpaKkN4T9NsFvTNMKIudz2eY6Nk8qW60w2Gj3XDGjiK1wmgiTZs+i3234BX5TA1o
# NEhtwRpBoHJyX2lxjBaZ/RsnggWf8KZgxUbV6QIHEHLJE2QWQea4xctfo8xdy94T
# jqMyv2zILczwkdF11HjNWN38XEGdLkc6ujemDpK24Q+yGunsj8qTVxMbzI5aXxqp
# /o4l4BXIbiXIn1X5nEKViZpTnK+0pgqTUUsGcQF8NbD5QDNBXS9wunoBXHYVzyfS
# +mjK52vdLBmZyQm7PtH5Lv0HMwIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTog8Qz19yfDJx2mgqm1N+Hpl5Y
# 7jBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+
# 60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72
# gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE0
# 4dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7oh
# qfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJb
# DDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV
# +4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgN
# ZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJe
# S7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+H
# LeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2Agdd
# ynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8Xngsb
# raLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwADDLSb5661oDUaJAAAAAMMtDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDLl+5wS825CKqQSfGmuMrA1GSg
# sZ/O2lxrOkXzBEWvGzANBgkqhkiG9w0BAQEFAASCAYAuTgs9zfY5IRFjegg2mRqT
# IHej2uhNXP9bCkPjPQyVEyFipAnRLPAFaSBgZXsVaWDmFnNuFOGZK9LdpIawrWEt
# 4RA9eqIOgKR9qHgGiTvybOPGBdL0irFzdenoPg0H5c5yU0vPHhnBbH6W6CA73oyD
# jFtjzv5KnN+e9VcYEB5exev1ZxrOSy35VnUhCs9fC1Yzbpno50p/JMAdvbnVo8SO
# 2Yz6oD0oEnWINR6OUB/eznqul3JnIJutwPXeDQ3vcQQbXRI8CTs7ll2EOW2VnmC/
# tRp0a05lUT3Ql78HwBNlzirBlTdonvw4f/RZqCPbJc07D9OK4i1XAH81Lux8Iu4G
# ttxk+0+4Uuuoy6oouT/EzKkZ43adkEURyicgUfXCv+XH7LctRNL32kYPBKspPSle
# C2y5h1wI4bgpEPAoQuo8PsCSY2kZzJw9YwOnn59GEyMkMfoIb2/ffmyDFZExGar0
# zjVwSWX+aJhe3WTIso6w6tKmFRLFyAlQKv13NAQNKAihghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgsGDjuhZffiRnFwe8oizaYkDPqmOHcR4oM9s92f/n
# SSoCBmfdnxSNcRgTMjAyNTAzMjIwMjM3MjcuMjIzWjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046RTQ2Mi05NkYwLTQ0MkUxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
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
# EzMAAABK/bhVx2KqyYkAAAAAAEowDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODU1WhcNMjUxMTE5MTg0ODU1WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046RTQ2Mi05NkYwLTQ0MkUxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA6DkQYZ6zYlw1AbxF
# kFNwc0V0BaXCCo1/+d01YKizalK9bX8fGrIUSVf75pYJOrhYmofIMh7wBv8j+kIp
# lOKYixrtVq+aQwAezI0wBFdFFeOyNCIynTQwz343z5IWVZ0/7cOXT1IDk9fIsI51
# kZKHa4SPf9rFmH9XtH1/P1ExueAGskBF/AvI1Ol2Vv2W9EDke8csxcPgXTkDNG9I
# 5ljEjM9pZUzf9kgw8Po8CVpD1/OFb468jcaWpsi/ydqboa3KJnPoyUlnq+cmgp6f
# kpqYmPM3EhAr1aAqbMnkiUrD4Q15DTv0XoZOi1zjXRhF5xxXKLr1m5k5xZlHp7mn
# PimiG67T7/e5DuFFt7XbAsOCW8N1Zq5jdNeLrMLtBvkRyKlkTSsp6nJQXR4Rf2e8
# 7TrveQiJjLsW+ZQ46KXdcDI1WoaxI0JzypicOQBbcU98823p/TArYdVpIYuYlXq0
# 923cf9+im62BVFG9eXhm+601RsXdWlH7QUMZzbD233aAP8LiB0pDrkK/ybUpYs6D
# okAJ9r0am4NFXu7LC+DfIFveRIZOCBaHGt4SJ3G2VgkFIoALFcThj+ro7oX+BT3s
# r0L57Lzi/QmU2UkTCwV1qKM6+aqbzhV4BxsxRjfQdetqzFvxI4IHf0IBuPoYYMiJ
# 4AXTa2moymfuejK2NZgL75mWwisCAwEAAaOCAcswggHHMB0GA1UdDgQWBBQXdNaJ
# ti4We46ErU/TNnIOeWGVejAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBADApzTDXWbyj/r85v6Az19sJPtwK
# dE5ukA0FrPxJffIDQ0WJLW1G7zXIXIJY3S5dCHbvXr5bDrmL67MlnU0M0RIapm5x
# pS8ejuWdRplHqkRiwhB5hm+7nEdxm+YdKCcoIPxbGqI1t8E0S0Zt7uw1/9LzRUar
# duTHQ0PKyZQnuYkHLGx83/+RR40w1gemiIFtC/UfvNY9URHCfB6bWp90qi3TjWLM
# O03FwcpuvZ15RubMVH/eH3WavJjLB4rDWd7NzeSAkiTqCEUAFNqrGFbnjOviBMUb
# KkAa/mFj9m1Dk6Zx4SbXtT5wCodX3k30m0cSB2nClULbR4YyWO5/MoSlTwnMPvFX
# MOWUkzd/SARbw7XVF6WLtgZHVBKAyZ4MFKwrKCP8hXdozdkeOX3Ru12+wewRk8An
# o/f9zrm4G/B/wO6u7smB3eR8OerqioPt73ufFMWsSCwXhSGz8xpjq6DKiG39sDRP
# F2CHnsBIJmv7dPMgYCKxskb7GiIkHbqa79vIAqQs9nY4s7XhR8NKRAKVIYj9/8Xk
# eY5S1G0YQhCwQlRUtvHZMY0pYmOXBfWpjQG+ZaIwfd07tB0hprJBh5zJLIussfsI
# P3tGr4o64tqRa8+OItP3mLWCdslKcBY5HIzHC2b0NnasAY1bqzfTfotsflhrV+pX
# SyN3As36dKMTqpGGMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEr9uFXHYqrJiQAAAAAA
# SjANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCB2GcocjWpLDBaHTwyvmdoPUUOSo61ir7IyBB+74wlA
# 9DCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEIGZ7KbWlzY0AQkdLdW/gAxiy
# l7PEf9Wpsv+xde8uw+EKMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASv24VcdiqsmJAAAAAABKMCIE
# IA5OXdWa2jrxjgDX5jJZMsCRkbZKXb8O2lmxdrYqXo/yMA0GCSqGSIb3DQEBCwUA
# BIICAHf8nEmPf2SscQpv/n92ywrEJVE+3Jzqsq8WXD2saPXnMOlZA7yw94cA2AI2
# Wuyiz+BNk+VqS0oDQnSesqPsbTLPJI73zgmCDRdBY/b8TBFOHmQoaJddWZ2ZqANX
# hX2L/uAtnW+dH6ENDsuQ/Q+FiMf6Zp8c0tQlp3j3qunCmbqm+24aCbFQEHzCzUhg
# QuLoz9eO7VCYaKXBIT+7cDfq4C48Rgq/c33D7LgbNg7tlDqxipidu3MpvWf4loS4
# 5isdswY+YbwdxKVGPuZoZhToaMQCSNXJtWm0mSVB1yOBshT01F702GUIKubTnuh8
# jQA+OXFnjdxCAZ4TUHZOegqqtcGr+YsjCayQkm6+QiGr0V6ztMm5KCcw2W5DA6Tu
# U6EnNXeYqL3joN7wjbp3QJCNpRlSPdjSItBUT/piay1jbP65fBnH9093k1gd4l2r
# RzZtxAfhuJBr1CcaUWTd9rVKx4p5emFJ0B59Kc0s3ZueriYTiYgjszIPkkKyA+fp
# i75o2TjREWxaFg59hm6Y00pWAjLLxq5bDJ7jr6NcmZv007PqQ+QzFGhpYy+d64hz
# PRa8M1J5Oq/4iAEgM1TaPrjWQbyp6nqOvfpMbptmt3HFYAX8LLKvsya0jhlX0t/T
# INu7eiUNrQTJdj4+N4fL3t6rPeXbaJoMrjFgd0+J0OjRIU8J
# SIG # End signature block
