

[CmdletBinding()]
param (
    [string]$label = 'WINPE',
    [switch]$check,
    [switch]$noUSB,
    [switch]$fixed,
    [switch]$getHash
)


Write-Output 'Checking whether the script has sufficient permissions to run.'
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
{
    Write-Warning 'You do not have sufficient permissions to run this script.'
    Write-Host 'Please run this script as an administrator.'
    exit 1
}
else
{
    Write-Host 'The script has sufficient permissions. Continuing.'
}

#import functions.
$functionsFolder = "$PSScriptRoot\functions"
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


if ($noUSB)
{
    Write-Verbose 'Skipping USB drive detection.'
    Write-Verbose "Getting drive letter from the script root at $PSScriptRoot"
    if ($fixed)
    {
        $scriptPath = $PSScriptRoot
    }
    else
    {
        $scriptPath = $PSScriptRoot
    }
    $driveLetter = $PSScriptRoot.Substring(0, 2)
    Write-Verbose "The drive letter is $driveLetter"
}
else
{
    $driveLetter = Get-USBDriveLetter -Label $label
    Write-Verbose "The function returned the drive letter $driveLetter"
}
if ($driveLetter -eq ':')
{
    Write-Host 'Cannot determine drive letter of USB drive. Exiting script.' -ForegroundColor Red
    exit 1
}


#Define variables   
$scriptName = "$scriptPath\Register-Device.ps1"
$backupScriptName = "$scriptPath\Get-WindowsAutoPilotInfo.ps1"
$scriptConfig = "$scriptPath\.secrets\config.json"
$localVersion = '1.0.0'


Write-Verbose "The drive letter is $driveLetter"
Write-Verbose "The script path is $scriptPath"
Write-Verbose "The script name is $scriptName"
Write-Host "The script version is $localVersion"
Write-Verbose "The backup script name is $backupScriptName"
Write-Verbose "The script configuration file is located at $scriptConfig"


Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Continue
$modulesToInstall = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.DirectoryManagement',
    'PackageManagement',
    'PowerShellGet',
    'WindowsAutoPilotIntune'
)
$modules = Get-requiredModules -moduleNames $modulesToInstall
Write-Host "$modules modules were installed." -ForegroundColor Green


if ($getHash)
{
    Write-Host 'Creating a backup of the device hardware hash.' -BackgroundColor Yellow
    $success = Get-DeviceHash -scriptToRun $backupScriptName -driveLetter $driveLetter
    if ($success)
    {
        Write-Host 'Device hash saved successfully.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to save the device hash.' -ForegroundColor Red
    }
    exit 0
}


Write-Verbose "Looking for $scriptName"
if (Test-Path $scriptName)
{
    if (-not($check))
    {
        Write-Host "Calling $scriptName with configuration at $scriptConfig" -ForegroundColor Green
        & $scriptName -config $scriptConfig
        if ($LASTEXITCODE -eq 1)
        {
            Write-Host 'Failed to register the device.' -ForegroundColor Red
            Write-Host 'Creating a backup of the device hardware hash.' -BackgroundColor Yellow
            $success = Get-DeviceHash-DeviceHash -scriptToRun $backupScriptName -driveLetter $driveLetter
            if ($success)
            {
                Write-Host 'Device hash saved successfully.' -ForegroundColor Green
            }
            else
            {
                Write-Host 'Failed to save the device hash. Please contact an Intune administrator.' -ForegroundColor Red
            }
        }
        elseif ($LASTEXITCODE -eq 100)
        {
            Write-Host 'The device is already registered but is not ready for enrollment.' -ForegroundColor Red
            Write-Host 'Please contact an Intune administrator.' -ForegroundColor Red
        }
        else
        {
            Write-Host 'Device registered successfully.' -ForegroundColor Green
            Restart-Device -bootMessage 'Rebooting the device to start the device enrollment. Please remove the USB stick from the computer.'
        }
    }
    else
    {
        Write-Host 'Checking for device assignment.'
        & $scriptName -config $scriptConfig -check
        if ($LASTEXITCODE -eq 0)
        {
            Write-Host 'The device is correctly assigned.' -ForegroundColor Green
            Restart-Device -bootMessage 'Rebooting the device to start the device enrollment. Please remove the USB stick from the computer.'
        }
        else
        {
            Write-Host 'The device is not assigned to a profile.' -ForegroundColor Red
        }
    }
}
else
{
    Write-Host "Cannot find $scriptName" -ForegroundColor Red
    exit 1
}   
Write-Host 'Script completed.' -ForegroundColor Green

