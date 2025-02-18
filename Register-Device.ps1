<#PSScriptInfo
.VERSION 1.0
.GUID 9c73a06a-4834-4f16-a2fe-b5077101d5c6
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Deploys De-Bloat application
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
    [Parameter(Mandatory = $False)] [switch]$NoHashVerify
)

#Define variables.
$hashFile = "$PWD\hashes.json"
$maxWaitTime = 30
$timeInSeconds = 60
$updateURL = 'https://raw.githubusercontent.com/zuhairmahd/Autopilot/main'
$remoteVersionURL = 'https://raw.githubusercontent.com/zuhairmahd/Autopilot/main/version.json'
$scriptHashURL = 'https://raw.githubusercontent.com/zuhairmahd/Autopilot/main/hashes.json'
$localVersions = Get-Content -Path "$PSScriptRoot\version.json" -Raw | ConvertFrom-Json
$outputFile = "\device_$serial.csv"
$functionsFolder = "$PWD\functions"
$modulesFolder = "$PWD\modules"
$modulesToInstall = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Identity.DirectoryManagement',
    'PackageManagement',
    'PowerShellGet',
    'WindowsAutoPilotIntune'
)


#import functions.
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

if (-not($NoSignatureVerify))
{
    Write-Host 'Verifying code signature.'
    $codeAuthenticity = Get-SignatureStatus -scriptFolders @("$PSScriptRoot", "$functionsFolder")
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
    $fileIntegrity = Get-ScriptIntegrity -scriptFolders @("$PSScriptRoot", "$functionsFolder") -hashFilePath $hashFile
    if ($fileIntegrity.count -gt 0)
    {
        Write-Host "$($fileIntegrity.count) scripts failed the integrity check." -ForegroundColor Red
        foreach ($Script in $fileIntegrity.keys)
        {
            Write-Host "The script $script is $($fileIntegrity[$script].status)."
            Write-Host "The reason is $($fileIntegrity[$script].reason)."
        }
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
    $scriptsToUpdate = Test-ScriptUpdates -updateURL $updateURL -scriptVersionURL $remoteVersionURL -scripts $localVersions
    Write-Verbose "$($scriptsToUpdate.count) to update"
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
            if (Get-ScriptUpdates -scriptsToUpdate $scriptsToUpdate -scriptURI $updateURL -ScriptRoot $PSScriptRoot -scriptVersionURL $remoteVersionURL -scriptHashURL $scriptHashURL -verbose)
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
        Write-Host 'Exiting script.'
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
    $module = Get-RequiredModules -moduleNames $modulesToInstall -ModulesFolder $modulesFolder
    if ($module -eq 0)
    {
        Write-Host 'All required modules are installed.' -ForegroundColor Green
    }
    else
    {
        Write-Host "$module modules were installed."
    }
}
else
{
    Write-Host 'Skipping module check.'
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

$deviceObject = get-DeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
$serial = $deviceObject.serialNumber
$hash = $deviceObject.hardwareHash
$make = $deviceObject.manufacturer
$model = $deviceObject.model
Write-Host "Processing device with serial number $serial, manufacturer $make, and model $model."

#Let us check if the device has already been imported.
$assignment = Get-AutopilotDevice -serial $serial
if ($assignment)
{
    Write-Host 'The device is already in Intune.' -ForegroundColor Yellow
    Write-Host 'Checking profile assignment'
    if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState')
    {
        Write-Host 'The device is assigned to a deployment profile and ready for enrollment.' -ForegroundColor Green
        Restart-Device
        exit 0
    }
    else
    {
        Write-Host 'The device is imported but not assigned to a deployment profile.' -ForegroundColor Yellow
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        Get-deviceHash -Device $deviceObject -OutputFile $outputFile
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
        Get-deviceHash -Device $deviceObject -OutputFile $outputFile
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
            Get-deviceHash -Device $deviceObject -OutputFile $outputFile
            exit 1
        }
        elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState') 
        {
            Write-Host 'Congratulations!!! ' -ForegroundColor Magenta
            Write-Host 'The device is successfully assigned to a deployment profile.' -ForegroundColor Green
            $importDuration = (Get-Date) - $importStart
            $importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
            Write-Host "Elapsed time to complete: $importSeconds seconds"
            exit 0
        }
    }
    else
    {
        Write-Host 'The device cannot be found in Intune.'
        Write-Host 'Please check the Intune Portal or contact an Intune administrator.'
        Get-deviceHash -Device $deviceObject -OutputFile $outputFile
        exit 1
    }
}
elseif ($device.state.deviceImportStatus -eq 'error')
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
    Get-deviceHash -Device $deviceObject -OutputFile $outputFile
    exit 1
}
else
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host   "$($device.state.deviceImportStatus)" -ForegroundColor Red
    Get-deviceHash -Device $deviceObject -OutputFile $outputFile
    exit 1
}
Restart-Device
# SIG # Begin signature block
# MII9YAYJKoZIhvcNAQcCoII9UTCCPU0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAH1jRZUEZ+6041
# CZYaNAq3JZEdyDIUycSCDwmKuGZu8aCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAG3TBId
# dYfjBp1eAAAAAbdMMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDIwHhcNMjUwMjE3MDkyNzE3WhcNMjUwMjIw
# MDkyNzE3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# ieTkALH6JH9smRuHSJNMSBs83oHdTz2q9i2jh3lA5HKEfGnU045qIswN5wrhuFaY
# PgAhIYFle4C1kGih1TSTY2vmSdsuA9zjjjfaNUCw7e6mo/DG/q7pp/S7NXqCdtvl
# u/voszMbi+4NanDPAGZXsZNqvAAPGXHsaHPYamKDH/mTvz7Ati9K3Zp4DufbOhb7
# 6JQWua7nEAtfVIM1cKrg7KvHStBEe+4vRDxDqKPaGApIa1dG4BoKtV9UAbtGKS0h
# H0Taaa+4u01jpzv+VXT1aHcY0ZTf+sijPyIRYtkV49qPH+1f3jh43+SWMqoGN7lz
# Vvgu1EB1fXcVfFchWYB21ORvLRQWWRpbRoa14EWhxCgM1IWfj+k3ko3MNcEWaj7a
# XYhomi8fGXkA+3g8YC1+1ty4rVKZfeL6d+6hebsx2rbzw8skMU0E5HPzMhrsQs7M
# 3JB9HbROLu83TU1X9gplI5SNmjCMVNptDr2FHAkRSzJU6zyt7IYxdzyD/1KKUghR
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCnwBg0W15N7CNiCaytuOv9Tuvq5MB8GA1UdIwQY
# MBaAFGWfUc6FaH8vikWIqt2nMbseDQBeMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAEoJkddxwuXD3Vrt
# pnxf45cKYjTJKWgWcL34ziN0DltHMJhkymeSOTr3ePxuSoo4OwNjlb7Fprve9P3q
# flroqzleivlwOQAxCpG9aVmJjwjcBrVQ5Hlj2I3MvAqwsC+Ws0bEJ4KIKimb8Vws
# q2CUl3M/l59iM8ybDKsEln/wgwCa+Z2xQ53hF16WXal8KNtV/AIwhiKSK38vKfeb
# a1l7xMn6PkWDWTqGLU/r9KI1CqfGgLCnZ/wI0aW7S5lLaPwQ9or85w1NGdjgQ8Zi
# npIN/ef6BWGJQtZX1kDR1qhnRtqRXdhjkBRT934bxNs7J+muPUaAOwBNz+GO2A13
# fwT1UfcPeTGYAijT+F24H1uqDmTcqzXCUXbWID00vcQyYsC3VPnGvSpMnatxVcR8
# Ir/1cs/a36+lwag4EPS8H6WvGUevYzyy6UqBPjFL5EOErvXl30mamenn0WRiPFD1
# gexYHQFnCUcP4rXbk72ErrCdSXYMRyku2eiCSHTFBgisISIeHRkzpaVwqIaCciLs
# 7Utd5Dec32cdAB5Ge2qAHXT6Ja3ckyyPr2BZgt4ZPwXsu/rl0jDwtmzT8tsbBTV5
# o2xF35XfUxvsP4/S2uaK6VP4DGqSDERJdaVXzJ2hBVwy8F9r7/LKmxYiDpbdUL6J
# lZ/MPpWFA6I17SPnTaMwIfl0z1iRMIIG5zCCBM+gAwIBAgITMwABt0wSHXWH4wad
# XgAAAAG3TDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAyMB4XDTI1MDIxNzA5MjcxN1oXDTI1MDIyMDA5Mjcx
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAInk5ACx
# +iR/bJkbh0iTTEgbPN6B3U89qvYto4d5QORyhHxp1NOOaiLMDecK4bhWmD4AISGB
# ZXuAtZBoodU0k2Nr5knbLgPc44432jVAsO3upqPwxv6u6af0uzV6gnbb5bv76LMz
# G4vuDWpwzwBmV7GTarwADxlx7Ghz2Gpigx/5k78+wLYvSt2aeA7n2zoW++iUFrmu
# 5xALX1SDNXCq4Oyrx0rQRHvuL0Q8Q6ij2hgKSGtXRuAaCrVfVAG7RiktIR9E2mmv
# uLtNY6c7/lV09Wh3GNGU3/rIoz8iEWLZFePajx/tX944eN/kljKqBje5c1b4LtRA
# dX13FXxXIVmAdtTkby0UFlkaW0aGteBFocQoDNSFn4/pN5KNzDXBFmo+2l2IaJov
# Hxl5APt4PGAtftbcuK1SmX3i+nfuoXm7Mdq288PLJDFNBORz8zIa7ELOzNyQfR20
# Ti7vN01NV/YKZSOUjZowjFTabQ69hRwJEUsyVOs8reyGMXc8g/9SilIIUQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQp8AYNFteTewjYgmsrbjr/U7r6uTAfBgNVHSMEGDAWgBRl
# n1HOhWh/L4pFiKrdpzG7Hg0AXjBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBKCZHXccLlw91a7aZ8X+OX
# CmI0ySloFnC9+M4jdA5bRzCYZMpnkjk693j8bkqKODsDY5W+xaa73vT96n5a6Ks5
# Xor5cDkAMQqRvWlZiY8I3Aa1UOR5Y9iNzLwKsLAvlrNGxCeCiCopm/FcLKtglJdz
# P5efYjPMmwyrBJZ/8IMAmvmdsUOd4Rdell2pfCjbVfwCMIYikit/Lyn3m2tZe8TJ
# +j5Fg1k6hi1P6/SiNQqnxoCwp2f8CNGlu0uZS2j8EPaK/OcNTRnY4EPGYp6SDf3n
# +gVhiULWV9ZA0daoZ0bakV3YY5AUU/d+G8TbOyfprj1GgDsATc/hjtgNd38E9VH3
# D3kxmAIo0/hduB9bqg5k3Ks1wlF21iA9NL3EMmLAt1T5xr0qTJ2rcVXEfCK/9XLP
# 2t+vpcGoOBD0vB+lrxlHr2M8sulKgT4xS+RDhK715d9Jmpnp59FkYjxQ9YHsWB0B
# ZwlHD+K125O9hK6wnUl2DEcpLtnogkh0xQYIrCEiHh0ZM6WlcKiGgnIi7O1LXeQ3
# nN9nHQAeRntqgB10+iWt3JMsj69gWYLeGT8F7Lv65dIw8LZs0/LbGwU1eaNsRd+V
# 31Mb7D+P0trmiulT+AxqkgxESXWlV8ydoQVcMvBfa+/yypsWIg6W3VC+iZWfzD6V
# hQOiNe0j502jMCH5dM9YkTCCB1owggVCoAMCAQICEzMAAAAF+3pcMhNh310AAAAA
# AAUwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTNaFw0yNjA0MTMx
# NzMxNTNaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDSGpl8PzKQpMDoINta
# +yGYGkOgF/su/XfZFW5KpXBA7doAsuS5GedMihGYwajR8gxCu3BHpQcHTrF2o6QB
# +oHp7G5tdMe7jj524dQJ0TieCMQsFDKW4y5I6cdoR294hu3fU6EwRf/idCSmHj4C
# HR5HgfaxNGtUqYquU6hCWGJrvdCDZ0eiK1xfW5PW9bcqem30y3voftkdss2ykxku
# RYFpsoyXoF1pZldik8Z1L6pjzSANo0K8WrR3XRQy7vEd6wipelMNPdDcB47FLKVJ
# Nz/vg/eiD2Pc656YQVq4XMvnm3Uy+lp0SFCYPy4UzEW/+Jk6PC9x1jXOFqdUsvKm
# XPXf83NKhTdCOE92oAaFEjCH9gPOjeMJ1UmBZBGtbzc/epYUWTE2IwTaI7gi5iCP
# tHCx4bC/sj1zE7JoeKEox1P016hKOlI3NWcooZxgy050y0oWqhXsKKbabzgaYhhl
# MGitH8+j2LCVqxNgoWkZmp1YrJick7YVXygyZaQgrWJqAsuAS3plpHSuT/WNRiyz
# JOJGpavzhCzdcv9XkpQES1QRB9D/hG2cjT24UVQgYllX2YP/E5SSxah0asJBJ6bo
# fLbrXEwkAepOoy4MqDCLzGT+Z+WvvKFc8vvdI5Qua7UCq7gjsal7pDA1bZO1AHEz
# e+1JOZ09bqsrnLSAQPnVGOzIrQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRln1HOhWh/L4pFiKrdpzG7Hg0A
# XjBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAEVJ
# YNR3TxfiDkfO9V+sHVKJXymTpc8dP2M+QKa9T+68HOZlECNiTaAphHelehK1Elon
# +WGMLkOr/ZHs/VhFkcINjIrTO9JEx0TphC2AaOax2HMPScJLqFVVyB+Y1Cxw8nVY
# fFu8bkRCBhDRkQPUU3Qw49DNZ7XNsflVrR1LG2eh0FVGOfINgSbuw0Ry8kdMbd5f
# MDJ3TQTkoMKwSXjPk7Sa9erBofY9LTbTQTo/haovCCz82ZS7n4BrwvD/YSfZWQhb
# s+SKvhSfWMbr62P96G6qAXJQ88KHqRue+TjxuKyL/M+MBWSPuoSuvt9JggILMniz
# hhQ1VUeB2gWfbFtbtl8FPdAD3N+Gr27gTFdutUPmvFdJMURSDaDNCr0kfGx0fIx9
# wIosVA5c4NLNxh4ukJ36voZygMFOjI90pxyMLqYCrr7+GIwOem8pQgenJgTNZR5q
# 23Ipe0x/5Csl5D6fLmMEv7Gp0448TPd2Duqfz+imtStRsYsG/19abXx9Zd0C/U8K
# 0sv9pwwu0ejJ5JUwpBioMdvdCbS5D41DRgTiRTFJBr5b9wLNgAjfa43Sdv0zgyvW
# mPhslmJ02QzgnJip7OiEgvFiSAdtuglAhKtBaublFh3KEoGmm0n0kmfRnrcuN2fO
# U5TGOWwBtCKvZabP84kTvTcFseZBlHDM/HW+7tLnMIIHnjCCBYagAwIBAgITMwAA
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
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMgITMwABt0wSHXWH4wadXgAAAAG3TDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCA35c6bHHeV1pWqYz/vtZK+lOYb
# ktzqRNDMJ/vte6NdFTANBgkqhkiG9w0BAQEFAASCAYCBBfMeoRiIPYufTxkzsnx2
# V3NcJlkg8owjreAXDl9XW5jmItj2OZcq55OJgBA9TbxmRcexPDaigf5xYq+W2jsU
# A8nLfPYGoUQEWXN6EgO+n0qZBDeCxeIIFnDGeTZ7lqBDxVCXrilkz0KJ7vGpK0xJ
# 9lOxD7R3w72iuWOtRa+BdcPpnq16LIOxBEtoQMZ14AFpcgp2DI1wqB8toIQw9NVx
# 3sWT14Rj1nZMLrFnd6wy4d8zTPOSULoi5wKTKUxMDfmoMGJyxVBlw/tFDkalBQkQ
# tiStuoGEZQWh+pGaJnWkZBDFMw2T8v/aYjaBvEfyyvkYeFlXOOzvPfOTzG/W9bgJ
# z7/ZT4zu9cHNEIypoN1o7z6PpFHI8+L2XntuWgpLQD5UUarM/6VL0uiKNWxQYZli
# 1v8ZxKexsdiZKGOP2Y1/e+pmCgzMlOlyHR31kvSYctWoMz0oq92AIrXilp/tk+K2
# mx1bCHrpC8eyyTw2EK/nuf+qqOyw8zLICvmi8LVEMSehgheQMIIXjAYKKwYBBAGC
# NwMDATGCF3wwghd4BgkqhkiG9w0BBwKgghdpMIIXZQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgRjvr7nj2iCdmu/7bFka/dBDEYQ7Qg803fX7LexgR
# dv0CBmezHhIFtxgTMjAyNTAyMTgwNzQ0MjAuMzM2WjAEgAIB9KCB4KSB3TCB2jEL
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
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUwMjE4MDc0NDIw
# WjAvBgkqhkiG9w0BCQQxIgQgyCdnTzjt4USm3pdxaxzJNkW/zqN1EC/y44yUJ/fy
# IC8wgbkGCyqGSIb3DQEJEAIvMYGpMIGmMIGjMIGgBCBZKDgGu8T+xwIzm2AmYzwg
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
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBBQUAAgUA615F
# UDAiGA8yMDI1MDIxNzIzMzEyOFoYDzIwMjUwMjE4MjMzMTI4WjB3MD0GCisGAQQB
# hFkKBAExLzAtMAoCBQDrXkVQAgEAMAoCAQACAhNcAgH/MAcCAQACAhFdMAoCBQDr
# X5bQAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAQDnpmv6dUf4f/F8Z+CCJ
# 0wXLy5eSQ83PrlKeep+uhhzhgwBAFwujC3VfNM5sIBCeAi/x7zr3Wcd8WOXVBo3e
# AIIpnQByPaoYOgfTjtXn8dhR+mGzBqicyRqixS5OXx8IyNhIqIrYhl2f6Aqp63xY
# Az2V33gwFL7+A3Wmd3slIIswDQYJKoZIhvcNAQEBBQAEggIAwtqlKKLuI5Er641P
# MY6OGOW5G0mE7wEDykEtXw2fH8MoYGHiyOj7xGWt5Pa4McavvcvgyHJBQhJeC042
# h8zTr3hi/PjHVKVVgZ2QdMc8miEUD5XqkrfieXKc1mx21YvQ81FxNHZ34c0MlzFO
# uwDOge4DS+THA6nb2u7eCZpvSroY3hh5iSq6qitlMxA7Rgbn5GdQvo4t09ILzmSb
# BNoB8RMCJMzfM6GuzWgaVZVidcgUoRZ7ZAXZuFrsSk8YJmcktYyT3+9isZBYJe10
# 1Syi7CmabYc/Sea/zxcv9VPQTnJoEt9pX+g31bkKMqB8ki3DT+lZavcXRoKXQabm
# duwu4cXRLYHzBdGV7Vd0/EOqwh+kEHTHc7qP33Y3DaSTSEJSPJ6WF8qIApmLN8j/
# 6bXMoMRzIEeJLRgHImHpfyrWy/cDHIs9tRS0bNNS9wo6F8JPLIel6nkAU9rXNsZr
# XCK0I2kc4a4qEmQYrhsSGNjl9+u1JKrn8TDHVOR7olhC0BNrKck2+1sCaRnishXq
# uGr9FGNGBg32ujyAYbpYfZ/IS6kyDna8ReHtjIY6DJ86GJ4BSSM7esgNztXtexUC
# 78P9LhsxadgGkU+65QRaLtIecnmouTWZHgjpH4FRuB1iFRUlqq/9msjqtwbfRUc+
# lkc+HTaqJt8z+PdmznC040V7WE4=
# SIG # End signature block
