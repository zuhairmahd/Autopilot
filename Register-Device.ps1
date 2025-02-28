<#PSScriptInfo
.VERSION 1.0
.AUTHOR zuhairmahd
.DESCRIPTION Registers a device in Intune
#>
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
    [Parameter(Mandatory = $False)] [switch]$check,
    [Parameter(Mandatory = $False)] [switch]$ModuleCheck
)

Write-Output 'Checking whether the script has sufficient permissions to run.'
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
{
    Write-Warning 'You do not have sufficient permissions to run this script. Please run this script as an administrator.'
    exit 1
}
else
{
    Write-Output 'The script has sufficient permissions. Continuing.'
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


if ($ModuleCheck)
{
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
}


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

$maxWaitTime = 30
$timeInSeconds = 60

#Let us check if the device has already been imported.
$assignment = Get-AutopilotDevice -serial $serial
if ($assignment)
{
    Write-Host 'The device is already in Intune.' -ForegroundColor Yellow
    Write-Host 'Checking profile assignment'
    if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState')
    {
        Write-Host 'The device is assigned to a deployment profile and ready for enrollment.' -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host 'The device is imported but not assigned to a deployment profile.' -ForegroundColor Yellow
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        exit 100
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
    Write-Output "The device import status is $($device.state.deviceImportStatus)"
    Write-Verbose "The index count is $index."
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
            Write-Host 'The device is successfully assigned to a deployment profile.' -ForegroundColor Green
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
