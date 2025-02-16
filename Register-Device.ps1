<#
.SYNOPSIS
    A script to import a device into Intune using the Windows AutoPilot service.
.DESCRIPTION
    This script will import a device into Intune using the Windows AutoPilot service.  The script will check for the required modules and install them if they are not present.  The script will also check for the required configuration file and read the necessary details from it.  The script will then connect to Microsoft Graph using the provided credentials and add the device to Intune.  The script will then check the status of the device import and assignment.  The script will reboot the device if the -Reboot switch is used.
.PARAMETER configFile
    The path to the configuration file that contains the required details for the script to run.  The configuration file should be a JSON file with the following properties: appId, tenantId, and either appSecret or thumbprint.  The appSecret should be a client secret and the thumbprint should be the thumbprint of a certificate that is installed on the machine running the script. The configuration file should be encrypted using the Encrypt-ConfigFile.ps1 script.
.PARAMETER Name
    The name of the device to import.  This can be the DNSHostName, ComputerName, or Computer.  The default value is localhost.
.PARAMETER GroupTag
    The group tag to assign to the device.  The default value is ENTRA.
.PARAMETER AssignedUser
    The user to assign to the device.  The default value is an empty string.
.PARAMETER Reboot
    A switch to reboot the device after the import is complete.  The default value is $false.
.PARAMETER check
    A switch to check the status of the device import and assignment without importing the device.  The default value is $false.
.EXAMPLE
    RegisterMe.ps1 -configFile '.\.secrets\config.json' -Name 'localhost' -GroupTag 'ENTRA' -AssignedUser '
    This example will import the device localhost into Intune with the group tag ENTRA and the assigned user .
.EXAMPLE
    RegisterMe.ps1 -configFile '.\.secrets\config.json' -Name 'localhost' -GroupTag 'ENTRA' -AssignedUser 'user@contoso.com' -Reboot
    This example will import the device localhost into Intune with the group tag ENTRA and the assigned user 'user@contoso.com'.  The device will be rebooted after the import is complete.
.NOTES
    File Name      : RegisterMe.ps1
    Author         : Zuhair Mahmoud
    Prerequisite   : PowerShell V5
#>



[CmdletBinding()]
param (
    [string]$configFile = '.\.secrets\config.json',
    [Parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)][alias('DNSHostName', 'ComputerName', 'Computer')] [String[]] $Name = @('localhost'),
    [Parameter(Mandatory = $False)] [String] $GroupTag = 'MSB01',
    [Parameter(Mandatory = $False)] [String] $AssignedUser = '',
    [Parameter(Mandatory = $False)] [switch]$check
)

Write-Output 'Checking whether the script is running as an administrator.'
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
{
    Write-Warning 'You do not have sufficient permissions to run this script. Please run this script as an administrator.'
    exit 1
}
else
{
    Write-Output 'The script is running as an administrator. Continuing.'
}

function Get-decryptedObject
<#
.SYNOPSIS
    A function to decrypt the values in a hash table.
.DESCRIPTION
    This function will decrypt the values in a hash table.  The function will iterate through the properties of the hash table and check if the property is in the exclude list.  If the property is in the exclude list, the function will skip the property.  If the property is not in the exclude list, the function will decode the value from base 64 and add the decoded value to a new hash table.
.EXAMPLE
    Get-decryptedObject -encryptedObject $data -excludeFields 'password'
    This will decrypt the values in the data hash table and exclude the password field.
#>
{
    [CmdletBinding()]
    param (
        [psObject]$encryptedObject,
        [string[]]$excludeFields
    )
    $decryptedObject = @{}
    foreach ($prop in $encryptedObject.PSObject.Properties)
    {
        Write-Verbose "The exclude list is $($excludeFields -join ',')"
        Write-Verbose "Checking if $($prop.Name) is in the exclude list."
        if ($excludeFields -contains $prop.Name)
        {
            Write-Verbose "Skipping $($prop.Name) because it is in the exclude list."
            Write-Verbose "Adding the raw entry $($prop.Name) with value $($prop.Value) to the decrypted object."            
            $decryptedObject.Add($prop.Name, $prop.Value)
            continue
        }
        Write-Verbose "Decrypting $($prop.Name) with value $($prop.Value)"
        $propValue = $prop.Value.ToString()
        #convert the value from base 64 to a regular string.
        $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($propValue))
        Write-Verbose "The unencrypted value for $($prop.Name) is $decodedValue"
        #add the decoded dictionary to the hash table.
        $decryptedObject.Add($prop.Name, $decodedValue)
    }
    if ($decryptedObject)
    {
        Write-Verbose "The decoded data is: $($decodedData | ConvertTo-Json)"
        return $decryptedObject
    }
    else
    {
        Write-Error 'No values were decrypted.'
        return $null
    }
}


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
Write-Host "Checked $checkedModulesCount module(s)." -ForegroundColor Green
Write-Host "Installed $installedModulesCount module(s)" -ForegroundColor Green

Write-Verbose "Reading app registration details from $configFile."
if ($configFile)
{
    $Config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
    $config = Get-decryptedObject -encryptedObject $Config -excludeFields 'domain'
    if ($Config.appId)
    {
        $clientID = $Config.AppId
    }
    else 
    {
        Write-Error 'A client id must be provided in the config file.'
        exit 1
    }
    if ($config.domain)
    {
        $domain = $config.domain
    }
    else 
    {
        Write-Host 'No domain was provided.  Defaulting  to Your Company'
        $domain = 'Your Company'
    }
    if ($Config.tenantId)
    {
        $tenantID = $Config.tenantId
    }
    else 
    {
        Write-Error 'A tenant id must be provided in the config file.'
        exit 1
    }
    if ($Config.AppSecret)
    {
        $clientSecret = $Config.AppSecret
    }
    elseif ($Config.thumbprint)
    {
        $thumbprint = $Config.thumbprint
    }
    else 
    {
        Write-Error 'Either a client secret or a certificate thumbprint must be provided in the config file.'
        exit 1
    }
}
else
{
    Write-Error "The file $configFile does not exist."
    Write-Output 'Please provide a valid config file.'
    exit 1
}

if ($clientSecret)
{
    Write-Verbose 'Connecting to Microsoft Graph using client secret authentication with the following details:'
    Write-Verbose "Client ID: $clientID"
    Write-Verbose "Tenant ID: $tenantID"
    Write-Verbose "Client Secret: $clientSecret"
    $credentials = New-Object System.Management.Automation.PSCredential ($clientID, (ConvertTo-SecureString $clientSecret -AsPlainText -Force))
    Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credentials -NoWelcome -ErrorAction Stop
    Write-Output "Successfully connected to $domain using a client secret"
}
else
{
    Write-Verbose 'Connecting to Microsoft Graph using certificate authentication with the following details:'
    Write-Verbose "Client ID: $clientID"
    Write-Verbose "Tenant ID: $tenantID"
    Write-Verbose "Certificate Thumbprint: $thumbprint"
    Connect-MgGraph -TenantId $tenantID -ClientId $clientID -CertificateThumbprint $thumbprint -NoWelcome -ErrorAction Stop
    Write-Output "Successfully connected to $domain    using certificate authentication."
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

#Get device information.
$session = New-CimSession
Write-Verbose "Checking $name for hardware hash."
$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber
Write-Verbose "The serial number is $serial."
$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
Write-Verbose "The device details are: $($devDetail | ConvertTo-Json)"
if ($devDetail)
{
    $hash = $devDetail.DeviceHardwareData
    Write-Verbose "The hardware hash is $hash."
}
else
{
    Write-Error 'No hardware hash was found.'
    exit 1
}
#Get other -NoTypeInformation
$cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
$make = $cs.Manufacturer.Trim()
Write-Verbose "The manufacturer is $make."
$model = $cs.Model.Trim()
Write-Verbose "The model is $model."
Remove-CimSession $session
Write-Host "Processing device $make $model, serial number $serial."

$maxWaitTime = 20
$timeInSeconds = 60
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
        Write-Host "The import status is $($device.state.deviceImportStatus).'
        Write-Output 'Will check again in $timeInSeconds seconds."
        Start-Sleep -Seconds $timeInSeconds
        $device = Get-AutopilotImportedDevice -id $imported.id
        $index++
    }
    Write-Output "The device import status is $($device.state.deviceImportStatus)'
    Write-Verbose 'The index count is $index."
    if (($device.state.deviceImportStatus -eq 'unknown') -and ($index -gt $maxWaitTime))
    {
        Write-Output "The import is taking too long (over $maxWaitTime minutes)." 
        Write-Output 'Please check the Intune portal or contact an Intune administrator.'
        exit 1
    }
}
if (($device.state.deviceImportStatus -eq 'complete') -or ($check))
{
    Write-Output 'Checking device assignment.'
    Start-Sleep -Seconds $timeInSeconds
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
            Write-Verbose "The assignment details are: $($assignment | ConvertTo-Json)"
        }
        Write-Output "The device assignment status is $($assignment.deploymentProfileAssignmentStatus)"
        Write-Output "The device assignment date is $($assignment.deploymentProfileAssignedDateTime)"
        if ((($assignment.deploymentProfileAssignmentStatus -ne 'assignedUnkownSyncState') -or -not($assignment.deploymentProfileAssignedDateTime)) -and ($index -gt $maxWaitTime))
        {
            Write-Output "The device assignment is taking too long (over $maxWaitTime minutes)."
            Write-Output 'Please check the Intune portal or contact an Intune administrator.'
            exit 1
        }
        elseif ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState') 
        {
            Write-Host 'Congratulations!!! ' -ForegroundColor Magenta
            Write-Host 'The device has been successfully assigned to a deployment profile.' -ForegroundColor Green
            $importDuration = (Get-Date) - $importStart
            $importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
            Write-Output "Elapsed time to complete: $importSeconds seconds"
            exit 0
        }
    }
    else
    {
        Write-Output 'The device cannot be found in Intune.'
        Write-Output 'Please check the Intune Portal or contact an Intune administrator.'
        exit 1
    }
}
elseif ($device.state.deviceImportStatus -eq 'error')
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host "$($device.state.deviceErrorName)" -ForegroundColor red
    exit 1
}
else
{
    Write-Host 'The device import failed with the following error:' -ForegroundColor Red
    Write-Host   "$($device.state.deviceImportStatus)" -ForegroundColor Red
    exit 1
}

# SIG # Begin signature block
# MII94QYJKoZIhvcNAQcCoII90jCCPc4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAyk/YdN476rqan
# tL6vPgO7QlxDDHpNJExBta8/h7+/RKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAGoS/AF
# ih9+lWPbAAAAAahLMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwMjEzMDk0NjIzWhcNMjUwMjE2
# MDk0NjIzWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# iwvXimm0+umF7dSEr0sEUTJnrCSLaTUTQ5Y3ui3inufSnmrrMeoHW69KKSzA9qRW
# HvHRfCKOt4JN/OTnt6IqDoiuoRHRNuua8UzqN7fjrv13iqePTaALsi3QRgwYCQTa
# NkQrphDDGlAdKbCcVF50arrLvJhYosxq53aoYRTEhfK2m6ZFDSk62Fhb4pj6aU7X
# FHE2gKiW3QqKnOMAM3RMa6CQ1hs6P5/hoOahysTMpnB9wxA83+nBoy+zd+NWOQsk
# YMlAh6JFkMWjL0nFvMvLOHDAxxAQ1J9FDdScg1clUe0AwWotGcBsn2URLPVXRgjH
# POP4KCAhEetNFz2luKJQvdJC1NRCs6fEks8fvpNAImRl9YyvCEEll8bXm+wY7G/y
# QR6YRldZ0JcPx3lxGq6c4gaV3oYeE83CuJ07P3EVz8RbNz0pXgORU4b5a2PCTQ4L
# abz0Oqxqw2xSdUZkm103MXsYv4F7IU/Sq7UdGngEIJ14OTBBgrDPQYSFE18CyOhV
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFGHN41tqHDcFlM4tLGxbIHbVW9M9MB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAB320sKy2D8FCyjQ
# jA1yWRwIKsbidEECD1wpDx4789PNahch+kwoGLh/nDmW/BT2iiLzlmIEeyDR2Bgn
# 1vQUkk9BbsLaRf2u/Iz7ij2hQA1dEWuysTjdKvD2zOP5R+qYWx/67AkcKthc1bNl
# AH1nWdacvs0cnL4os9xki9WBhvw+AjsLM6iUUgvRWkYj0PhPgkrbkeZUqG9lnjlJ
# 0P+EQsSdQZ7VotBmzQ2u9oE6V+10TfmLTPHISYVYmDiGax3bp1+unOpp3j3CETDN
# Uk1fiigfNVZnHmwssNCXdUN0hrsSqkXJHkym7KORarnmfKLV1yjywFeAZP0DoDZs
# OvZnko9Rg6mBvDDbroK7IBe1REvH9V3ukvvvyKj5Gh54C0dhuSUQ2nfMTCfshc+/
# mHHI0edTOBbG2VkksDPSN6LcYGz7+KgmnYLnT+KeX9+Kbgof3vO3jNhDRRoC4MCw
# bL1Lo9nqmY/rFloI7ueSaCa0Yw5UnSrZrri1bC5VNwUFb+AgzQh6hISeIpBojGBk
# IEv1sWY16LWLFKcSq/IWUwITicTWKW+RTgym5JmpvVUKgNlvm74uDwAK1//Jr5xn
# hKY/czdRomlglGr/+dZU77Dk5z4vWEhqs525ineAp8y+ciRwgR52OlqR2UHS9E9M
# 7vbHyFT9ROZVTP7ecNo3hlggAS7bMIIG5zCCBM+gAwIBAgITMwABqEvwBYoffpVj
# 2wAAAAGoSzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDIxMzA5NDYyM1oXDTI1MDIxNjA5NDYy
# M1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIsL14pp
# tPrphe3UhK9LBFEyZ6wki2k1E0OWN7ot4p7n0p5q6zHqB1uvSikswPakVh7x0Xwi
# jreCTfzk57eiKg6IrqER0TbrmvFM6je34679d4qnj02gC7It0EYMGAkE2jZEK6YQ
# wxpQHSmwnFRedGq6y7yYWKLMaud2qGEUxIXytpumRQ0pOthYW+KY+mlO1xRxNoCo
# lt0KipzjADN0TGugkNYbOj+f4aDmocrEzKZwfcMQPN/pwaMvs3fjVjkLJGDJQIei
# RZDFoy9JxbzLyzhwwMcQENSfRQ3UnINXJVHtAMFqLRnAbJ9lESz1V0YIxzzj+Cgg
# IRHrTRc9pbiiUL3SQtTUQrOnxJLPH76TQCJkZfWMrwhBJZfG15vsGOxv8kEemEZX
# WdCXD8d5cRqunOIGld6GHhPNwridOz9xFc/EWzc9KV4DkVOG+Wtjwk0OC2m89Dqs
# asNsUnVGZJtdNzF7GL+BeyFP0qu1HRp4BCCdeDkwQYKwz0GEhRNfAsjoVQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRhzeNbahw3BZTOLSxsWyB21VvTPTAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQAd9tLCstg/BQso0IwNclkc
# CCrG4nRBAg9cKQ8eO/PTzWoXIfpMKBi4f5w5lvwU9ooi85ZiBHsg0dgYJ9b0FJJP
# QW7C2kX9rvyM+4o9oUANXRFrsrE43Srw9szj+UfqmFsf+uwJHCrYXNWzZQB9Z1nW
# nL7NHJy+KLPcZIvVgYb8PgI7CzOolFIL0VpGI9D4T4JK25HmVKhvZZ45SdD/hELE
# nUGe1aLQZs0NrvaBOlftdE35i0zxyEmFWJg4hmsd26dfrpzqad49whEwzVJNX4oo
# HzVWZx5sLLDQl3VDdIa7EqpFyR5MpuyjkWq55nyi1dco8sBXgGT9A6A2bDr2Z5KP
# UYOpgbww266CuyAXtURLx/Vd7pL778io+RoeeAtHYbklENp3zEwn7IXPv5hxyNHn
# UzgWxtlZJLAz0jei3GBs+/ioJp2C50/inl/fim4KH97zt4zYQ0UaAuDAsGy9S6PZ
# 6pmP6xZaCO7nkmgmtGMOVJ0q2a64tWwuVTcFBW/gIM0IeoSEniKQaIxgZCBL9bFm
# Nei1ixSnEqvyFlMCE4nE1ilvkU4MpuSZqb1VCoDZb5u+Lg8ACtf/ya+cZ4SmP3M3
# UaJpYJRq//nWVO+w5Oc+L1hIarOduYp3gKfMvnIkcIEedjpakdlB0vRPTO72x8hU
# /UTmVUz+3nDaN4ZYIAEu2zCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCGpEwghqNAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwABqEvwBYoffpVj2wAAAAGoSzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCzf44FU/IHaKlqWAWsjeZ+Y1n2
# K1FZZLS1kFV67D3lRzANBgkqhkiG9w0BAQEFAASCAYB2Ems/dT6McaAvgHnKex2s
# xu3zXRzeGNvOJ+99sKuK1ketFGIM+aDS/cUjUdEUk4M3ju4eGe8xE653dOWpb1Og
# nboNYXpgiU9ug/yBxpJ3riWIN8JxT2TONO7ZPfp18ENNeuMZ80tRWJgx6BkKWUis
# 0tMamnAu7vc5AN3wkTvI0cvaEmx+4k0OBUvQGp+8nzQhIYOJnv007DW31EJTxqar
# pgYjPq1O8FO0Ia/6tdhNQ+AMyadB2oR2U3CkuYKMNGXT+hX9HsrL6773fRJNC455
# NHsmghFExmD1vNzw7b9Fh18hehGL41syR9CD4h09sHEFC/OVWY6Z4qoHbYUYz2at
# LNZILBoPY5TfeB7wQ+hypHhCf5fhEvXRQG29DqgwhTNBUrxCERqkMfjk8tW+FNuB
# dUAy6y+APA5RYzNKeukXyhbE23zYZJFiBB3e2zYCdgQECH9biLdV7Fy66qznlqM7
# Tbt8VtPpXRhE6whLJfhHLPT/mYv8/R5pvx/1Q32BHoahghgRMIIYDQYKKwYBBAGC
# NwMDATGCF/0wghf5BgkqhkiG9w0BBwKgghfqMIIX5gIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgkrWHdKNsoj4Fb+R/a7sJteCM5k6U6IPNrYK67uMH
# jMsCBmeXbBJLCRgTMjAyNTAyMTQwMzQ4NDIuMzU1WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
# QSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAA
# BeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29m
# dCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eX
# M9ETBb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3T
# OYtgoBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/S
# sah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i
# 5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx6
# 9uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3G
# gZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2
# HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT
# 4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnG
# nsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914Aq
# HOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3E
# Q79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3Nv
# ZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYI
# KwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAX4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVj
# JviceW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGE
# ndSpZ5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1Cesuf
# U211rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3a
# d4Xtm7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P
# 8tHYIFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAo
# dDW8HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb
# +H7DRon9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D
# +mTm8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN
# 41LGXHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgH
# APUvIdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgEC
# AhMzAAAAS6GxreFZ/Oc0AAAAAABLMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1N1oXDTI1MTExOTE4NDg1N1owgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCdnYqzfzSDLZ8t
# /IcnBhZ/VS77fz7MIUKa1I9mDjnJRNPdVWovmgU5UbARCbLCIIzZj8J0/YDeyJBD
# YFTySXAgaHlDw06rUBcryq2eaxoWfShTHSdlOnyzhDUw8GXGYJT1x/q+nGm6k1or
# uwW2wrYNR86/Q5sr1XYCJlM8yteWaJFvZJGE6vCOPQxni/lEN2qoTrq2ejmpVVMP
# ngkX9IMCyrlxav40gC15WTU7dZ3o19bQs7u+drzbzON0MtKsqa1vDFsHuqvH2q1S
# 21zETmed/llmTK5QaRLLhk5WCd9w1n/Do5gHarg6Jv861uSCqAdMdNnI34fnTsIR
# naEtCGWGu7W1Zd7blHSligBaGALIC61vJzWj1Mb8JxhhmhfPX20d6nB1Jpmm4qIP
# /FW02uCxJSq9Fe8ziedvlg4m1aCqjWX0Q566/i7VieVsOA3rx1xRXeIbADmsxnw3
# 6YlZohsqREsZUMjQZ4e6cCfKAlaO02ca7GizIRn7mNvzHNYc47gQCFEC+YgX2SLv
# w4b6R5Taq43XJ0hfhDwPSPiT60dySjLUIcmDcs2vI878t3WxEl2an9HJCaYPKvV/
# UZ1Ay9HjkSJc3ZqIXvgGlh1VI7kCpPTBayY7RC0IzJl5a7+DM7FcBhei9h1eJ8Ad
# ZszVcUGk+LkF+uqU3GAnjYadJC/x2QIDAQABo4IByzCCAccwHQYDVR0OBBYEFCCZ
# GsUvRVF/zToRWkE3JYWmuHQmMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAMb3YbNgyOUIdvrmh8yK25QWz
# U4kVUvlJmCygDGdnUKokh4ZAMzZu+c7cTlw+hcCH8vbx7zMRbKbLzp1XOXP+/Bvn
# UKynTgEGBkXPEbKwEezCtNwGZm7fAHHh7fAC8GN0R4dEneZBuyvUwjv/RMa3bRCN
# 0IuMTsIpjzwOVivH6lDU8o6dxkE6w+1EhKgImb3iCnGXS1gnotzJ6oa0x3lYMuir
# YOpLFlc54xJR1RncJBKqVqC+2vu31GRaVmBiwVU/bFuYN0o6LVnAPTcu1fMDcn6t
# s5EbW5chgEMFIoUM3tSDMNXoMIQkMQvN3beZpjnLDb4V8OANLd5oXz+bd+p5zW21
# v6odGTBUX/qhjSxBhTbwTPqlV1/Dx95x/6/52PrETq6bQb6t6TAFq4fpXTmRo8uB
# Vj1pkGVljJPDxvi6DyaBZECqlHQws8wM4qDWTk9hTIZrKlK/mvD6J3hR782HLG6W
# JiEuuVSxv+8zsI86ibPK6ywwjlBloH6/+YEtQtS4gIx4D/1xnP7qVfK7FcPtRO4A
# HEw2g+Nm37R+6B+RDime4WvUvxR8FweNjEry0QGtQVvZcEIflDXryIp2UdQIIgW+
# zmUO2b05TulkFPIsiVsgcAYPZjeBuyJkdlhZpYdP0JpYPQiUZTY3hjkum3n/7FnE
# aVhOV+ZdS+0XXVa3A7kxggdDMIIHPwIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAA
# AABLMA0GCWCGSAFlAwQCAQUAoIIEnDARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTAyMTQwMzQ4
# NDJaMC8GCSqGSIb3DQEJBDEiBCAoHzvC+yKsqeK6+0d9vjbwasQScrn6Wt9sKubC
# a18ZBDCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEINuJKJ0rsvRcScm4woZm
# CKowMSTh9DWm0OSNAeUABkSnMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAAAABL
# MIIDXgYLKoZIhvcNAQkQAhIxggNNMIIDSaGCA0UwggNBMIICKQIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# APV6ws6b5FNHUOmEILADVgzql5kzoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 61j8rDAiGA8yMDI1MDIxMzIzMjAxMloYDzIwMjUwMjE0MjMyMDEyWjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDrWPysAgEAMAcCAQACAhVgMAcCAQACAhFBMAoCBQDr
# Wk4sAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAKzP68TBBi5PUpBrFMAP
# vqYUWEK+opDY7mWdXPXWsAXPKAO4h97RPWuW6Dq0xmPjdjbt5Tqg8FnBafYjI8fM
# GpNp14/bM0NAj9n2wb2QrDjpUYmxO+FHHu1Ke318S3wbONiz4L1zSYzbG94XWfM5
# iA1U9ou6H5XoVeoYKHkj1T8G9IVIJxo0L0QwksnHBHiGCb7lWpC7LTSydGnAJ2ZV
# Yw+8ZYKMLcr0VKxi1S1L8GKUCl6tOXTsA+hOR8rqRU3HNiafR19VmYialHrWJwvp
# MQ2uw07EGgqNDL2Yf/BFNEFWBNJV9Fi/44lKfTGQbc8zH/grldkyEVoH3cXxdTUU
# zcEwDQYJKoZIhvcNAQEBBQAEggIAJDtHGkQlE6UgVAD2L5k2lR2s5bpL/TnO3wpC
# kE2DYUv4uXiArMP788A2ThSjR0QvSX3leXpeICFJ2Fa8UVnrUYsX01Tw7FnIC26O
# ydIGvLB8Sy607QQGT7tyGfSEjLpEBFGS0kizOaf8ArlhBEXzgaYfI7mm06n3uA/x
# 1YNFPOoe/dAMCGVjDVDD7t0afbfuYTO5rId527icUrcy+KlamSZPnFL2O2jnRBdR
# LujVqnun63MC+9ixOxXp31estj9PG9e408mthAM6sa2PuREem78Haa6PbogBAsjm
# On4dtqNqPks8Q6vz3Y8/XvVbQ+qbEKJe5XZm4/z3Qi9zpfc1om4phUECwBSEA5yk
# hR0xLSJI8l5lXeE83Y+Cc+E8dqos4sapgXx6DXwo2h4zT2dPBPnhxpMfbsUzH9OP
# i0edT49Jl+KeGhJOi3+WE9cwiQ3R2kzSEbxW1ALlHJJxgTirb/GJesC1FxH6IIm+
# PtPKYLC6Y9n8ZwOPVbHzFt/XxCDR3CWzSJ2illPSLFNqJWIH3f+h0FBdbHdasSAK
# 7js/iqcH+14I/8DTsmMZ0UxSkGbpEI1Zk5HBd9Vb/lG9gJhRBNwFTCvBbo+iC5n+
# UqgYRBk+qyRyCNPUspV6hwfM+VnyIExWTjYxzZwqa5VIFJYQELzoH1EcjbKAyLy8
# 7IZERtM=
# SIG # End signature block
