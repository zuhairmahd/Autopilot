[CmdletBinding()]
param
(
    $configFile = "$pwd\.secrets\config.json"
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

function Get-encryptedObject
<#
.SYNOPSIS
    A function to encrypt the values in a hash table.
.DESCRIPTION
    This function will encrypt the values in a hash table.  The function will iterate through the keys of the hash table and check if the key is in the exclude list.  If the key is in the exclude list, the function will skip encrypting that value.  If the key is not in the exclude list, the function will encode the value to base 64 and add the encoded value to a new hash table. 
.EXAMPLE
    Get-encryptedObject -decryptedObject $data -excludeFields 'password'
    This will encrypt the values in the data hash table and exclude the password field.
.NOTES
    Compatible with PowerShell 5.1
.GUID
    339d17c9-45d4-4e94-a7c2-7f0c35e9c9e2
#>
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]$decryptedObject,
        [string[]]$excludeFields
    )
    
    Write-Verbose "Starting encryption of hashtable object with $($decryptedObject.Count) entries"
    $encryptedObject = [ordered] @{}
    
    foreach ($key in $decryptedObject.Keys)
    {
        Write-Verbose "The exclude list is $($excludeFields -join ',')"
        Write-Verbose "Processing key: $key"
        Write-Verbose "Checking if $key is in the exclude list."
        
        if ($excludeFields -contains $key)
        {
            Write-Verbose "Skipping encryption for $key because it is in the exclude list."
            Write-Verbose "Adding the raw entry $key with value $($decryptedObject[$key]) to the encrypted object."
            $encryptedObject.Add($key, $decryptedObject[$key])
            continue
        }
        
        Write-Verbose "Encrypting $key with value $($decryptedObject[$key])"
        # Convert the value to a string and handle null values
        $propValue = if ($null -eq $decryptedObject[$key])
        {
            "" 
        }
        else
        {
            $decryptedObject[$key].ToString() 
        }
        
        # Convert the value to base 64
        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($propValue))
        Write-Verbose "The encrypted value for $key is $encodedValue"
        
        # Add the encoded value to the hash table
        $encryptedObject.Add($key, $encodedValue)
    }
    
    if ($encryptedObject.Count -gt 0)
    {
        Write-Verbose "Encryption complete. Returning object with $($encryptedObject.Count) entries."
        Write-Verbose "The encoded data is: $($encryptedObject | ConvertTo-Json)"
        return $encryptedObject
    }
    else
    {
        Write-Error 'No values were encrypted.'
        return $null
    }
}


#region variables
$scopes = "offline_access Device.ReadWrite.All DeviceLocalCredential.Read.All DeviceManagementApps.Read.All DeviceManagementApps.ReadWrite.All DeviceManagementConfiguration.ReadWrite.All DeviceManagementManagedDevices.PrivilegedOperations.All DeviceManagementManagedDevices.ReadWrite.All DeviceManagementServiceConfig.ReadWrite.All Directory.ReadWrite.All Domain.ReadWrite.All Group.Read.All GroupMember.ReadWrite.All Organization.ReadWrite.All"
# $scopes = "offline_access https://graph.microsoft.com/DeviceManagementApps.Read.All https://graph.microsoft.com/DeviceManagementApps.ReadWrite.All https://graph.microsoft.com/DeviceManagementConfiguration.ReadWrite.All https://graph.microsoft.com/DeviceManagementManagedDevices.ReadWrite.All https://graph.microsoft.com/DeviceManagementServiceConfig.ReadWrite.All"
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $deviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $accessToken = GetGraphAccessToken -configFile $configFile -deligated -scopes $scopes
$accessToken = GetGraphAccessToken -configFile $configFile
#endregion variables

