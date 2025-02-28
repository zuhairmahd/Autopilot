<#PSScriptInfo
.VERSION 1.0
.AUTHOR zuhairmahd
.DESCRIPTION Registers a device in Intune
#>


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

function Get-USBDriveLetter
{
    [CmdletBinding()]
    param
    (
        [string]$Label = 'WINPE'
    )
    # Get the volume(s) with a matching FileSystemLabel.
    $volumes = Get-Volume | Where-Object { $_.FileSystemLabel -eq $Label } -ErrorAction SilentlyContinue
    # Write-Verbose $volumes
    Write-Verbose "Found $($volumes.Count) volume(s) with the label '$Label'."
    if ($volumes)
    {
        foreach ($vol in $volumes)
        {
            Write-Verbose "Volume $vol has label '$($vol.FileSystemLabel)' and drive letter '$($vol.DriveLetter)'."
            $driveLetter = $vol.DriveLetter
            Write-Host "The windows installation is at $($driveLetter):\" -ForegroundColor Green
        }
    }
    else
    {
        Write-Host 'Cannot find the Windows installation drive' -ForegroundColor Red
        Write-Verbose "Cannot find a volume with the label '$Label'."
        $driveLetter = $null
    }
    return "$($driveLetter):"
}

function Restart-Device
{
    [CmdletBinding()]
    param (
        [string]$question = 'Do you want to reboot the device now? (Y/N)',
        [string]$bootMessage = 'Rebooting the device...',
        [string]$reminderMessage = 'Remember to reboot the device to start the device enrollment.'
    )
    $reboot = Read-Host -Prompt $question
    if ($reboot -eq 'Y')
    {
        Write-Host $bootMessage -ForegroundColor Green
        Restart-Computer -Force
    }
    else
    {
        Write-Host $reminderMessage -ForegroundColor Red
    }
}


function Get-DeviceHash
{
    [CmdletBinding()]
    param
    (
        [string]$scriptToRun,
        [string]$driveLetter
    )
    $success = $false
    Write-Verbose 'Calling function create-DeviceHash with the following parameters:'
    Write-Verbose "ScriptToRun=$scriptToRun"
    Write-Verbose "OutputFile=$outputFile"
    $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
    Write-Verbose "SerialNumber=$serialNumber"
    $outputFile = "$driveLetter\device_$serialNumber.csv"
    Write-Verbose "OutputFile=$outputFile"
    if (Test-Path $backupScriptName)
    {
        Write-Host "Running $scriptToRun with argument $outputFile" -ForegroundColor Green
        & $scriptToRun -OutputFile $outputFile
        if ($outputFile)
        {
            Write-Host "Device hash saved to $outputFile" -ForegroundColor Green
            Write-Host 'In case of problems, you can manually upload the file to Intune or contact an Intune admin.'
            $success = $true
        }
        else
        {
            Write-Host 'Failed to save the device hash' -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Cannot find $scriptToRun" -ForegroundColor Red
    }
    return $success 
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


Write-Verbose "The drive letter is $driveLetter"
Write-Verbose "The script path is $scriptPath"
$scriptName = "$scriptPath\Register-Device.ps1"
Write-Verbose "The script name is $scriptName"
$backupScriptName = "$scriptPath\Get-WindowsAutoPilotInfo.ps1"
Write-Verbose "The backup script name is $backupScriptName"
$scriptConfig = "$scriptPath\.secrets\config.json"
Write-Verbose "The script configuration file is located at $scriptConfig"


Write-Host 'Checking for Nuget.'
$provider = Get-PackageProvider NuGet -ErrorAction Ignore
if (-not $provider)
{
    Write-Host 'Attempting to install Nuget from the Internet.' -ForegroundColor Yellow
    Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
}
else
{
    Write-Host 'NuGet is installed.' -ForegroundColor Green
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Continue
$modulesToInstall = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.DirectoryManagement',
    'PackageManagement',
    'PowerShellGet',
    'WindowsAutoPilotIntune'
)
Write-Host 'Checkin for installed modules.'
$installedModulesCount = 0
$checkedModulesCount = 0
$installedModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name
foreach ($module in $modulesToInstall)
{
    Write-Verbose "Checking for $module"
    if ($installedModules -notcontains $module)
    {
        Write-Verbose "Installing $module"
        Install-Module -Name $module -Force -AllowClobber -Scope AllUsers
        $installedModulesCount++
    }
    else
    {
        Write-Verbose "$module is already installed."
        $checkedModulesCount++
    }
}
if ($installedModulesCount -eq 0)
{
    Write-Host 'All required modules are already installed.' -ForegroundColor Green
}
else
{
    Write-Host 'All required modules have been installed.' -ForegroundColor Green
    Write-Verbose "$checkedModulesCount module(s) were already installed."
    Write-Verbose "$installedModulesCount module(s) needed installation and were successfully installed."
}


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

