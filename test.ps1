[CmdletBinding()]
param
(
    [parameter(helpMessage = 'Please enter the object id of the device you want to find.', Position = 0)]$ObjectId = 'C4N8054'
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
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $deviceUri = "devices"
# $deviceManagementUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $configFile = "$pwd\.secrets\config.json"
# $accessToken = GetGraphAccessToken -configFile $configFile
#endregion variables

if ($extraParameters)
{
    Write-Host "Extra parameters provided."
    Write-Host "Splitting the extra parameters by ampersand to get individual key-value pairs."
    
    # Initialize the parameter list
    $paramsList = @()
    
    # Split by ampersand to get individual key-value pairs
    $keyValuePairs = $extraParameters -split '&'
    Write-Host "Found $($keyValuePairs.Count) key-value pairs."
    
    foreach ($pair in $keyValuePairs)
    {
        Write-Host "Processing key-value pair: $pair"
        
        # Split each pair by equals sign to separate key and value
        $keyAndValue = $pair -split '=', 2
        
        if ($keyAndValue.Count -eq 2)
        {
            $key = $keyAndValue[0].Trim()
            $value = $keyAndValue[1].Trim()
            
            Write-Host "Key: $key"
            Write-Host "Value: $value"
            
            # Add the $ prefix to the key for OData parameters
            $formattedKey = "`$$key"
            Write-Host "Formatted Key with $ prefix: $formattedKey"
            
            # Add the formatted parameter to the list
            $paramsList += "$formattedKey=$value"
        }
        else
        {
            Write-Warning "Invalid parameter format: $pair - skipping"
        }
    }
    
    Write-Host "Final parameter list:"
    $paramsList | ForEach-Object { Write-Host $_ }
    
    # Join the parameters with & to create a complete query string
    $queryString = $paramsList -join '&'
    Write-Host "Final query string: $queryString"
}

# GetDeviceReport -enrollmentState $enrollmentState