[CmdletBinding()]
param
(
    [parameter(helpMessage = 'Please enter the serial number of the device you want to verify.', Position = 0)]$serialNumber = '5R3SBZ3'
)


#region import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder) {
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions) {
        Write-Verbose "Importing function $function"
        . $function.FullName
    }
}
else {
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}
#endregion

#region variables
$importedAutopilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities'
$deviceUri = "https://graph.microsoft.com/beta/devices"
$deviceManagementUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
$autoPilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities'
$filter = "serialNumber eq '$serialNumber'"
$configFile = "$pwd\.secrets\config.json"
$accessToken = GetGraphAccessToken -configFile $configFile
#endregion variables



# $global:enrollmentState = VerifyEnrollmentStatus -serialNumber $serialNumber -accessToken $accessToken
# Write-Host "Enrollment State: $($global:enrollmentState |ConvertTo-Json)" -ForegroundColor Green
$global:devices = CallGraphAPI -AccessToken $accessToken -Uri $deviceUri -Filter "startswith(operatingSystem,'Windows')" -Method GET
$global:managedDevices = CallGraphAPI -AccessToken $accessToken -Uri $deviceManagementUri -Filter "startswith(OperatingSystem,'Windows')" -Method GET
$global:imported = CallGraphAPI -AccessToken $accessToken -Uri $importedAutopilotDeviceURI -Method GET
$global:autopilot = CallGraphAPI -AccessToken $accessToken -Uri $autoPilotDeviceURI -Method GET

exit 0
#region properties search
foreach ($global:autopilotDevice in $global:autopilot.value) {
    Write-Host "Checking autopilot device with serial number: $($global:autopilotDevice.serialNumber) and deviceId: $($global:autopilotDevice.id)" -ForegroundColor Green
    $id = $global:autopilotDevice.id
    $productKey = $global:autopilotDevice.productKey
    $azureActiveDirectoryDeviceId = $global:autopilotDevice.azureActiveDirectoryDeviceId
    $azureAdDeviceId = $global:autopilotDevice.azureAdDeviceId
    $managedDeviceId = $global:autopilotDevice.managedDeviceId
    for ($i = 0; $i -lt $global:devices.value.Count; $i++) {
        $device = $global:devices.value[$i]
        Write-Host "Checking device with serial number: $($device.serialNumber)"
        foreach ($property in $device.PSObject.Properties) {
            if (($property.Name -like '*Id') -and ($null -ne $property.value) -and ($property.value -contains $azureAdDeviceId -or $property.value -contains $azureActiveDirectoryDeviceId -or $property.value -contains $managedDeviceId -or $property.value -contains $productKey -or $property.value -contains $id)) {
                if ($property.value -contains $azureAdDeviceId) {
                    Write-Host "The property with name $($property.Name) contains the AzureAdDeviceId: $azureAdDeviceId" -ForegroundColor Yellow
                    Write-Host "The Property tested: AzureAdDeviceId"
                    Write-Host "The Property tested value: $azureAdDeviceId"
                    Write-Host "The Matching Property name: $($property.Name)"
                    Write-Host "The Matching Property value: $($property.value)"
                    $global:matchingDevices += @{
                        'PropertyTested'        = 'AzureAdDeviceId'
                        'PropertyTestedValue'   = $azureAdDeviceId
                        'MatchingPropertyName'  = $property.Name
                        'MatchingPropertyValue' = $property.value
                    }
                }
                if ($property.value -contains $azureActiveDirectoryDeviceId) {
                    Write-Host "The property with name $($property.Name) contains the AzureActiveDirectoryDeviceId: $azureActiveDirectoryDeviceId" -ForegroundColor Yellow
                    Write-Host "The Property tested: AzureActiveDirectoryDeviceId"
                    Write-Host "The Property tested value: $azureActiveDirectoryDeviceId"
                    Write-Host "The Matching Property name: $($property.Name)"
                    Write-Host "The Matching Property value: $($property.value)"
                    $global:matchingDevices += @{
                        'PropertyTested'        = 'AzureActiveDirectoryDeviceId'
                        'PropertyTestedValue'   = $azureActiveDirectoryDeviceId
                        'MatchingPropertyName'  = $property.Name
                        'MatchingPropertyValue' = $property.value
                    }
                }
                if ($property.value -contains $managedDeviceId) {
                    Write-Host "The property with name $($property.Name) contains the ManagedDeviceId: $managedDeviceId" -ForegroundColor Yellow
                    Write-Host "The Property tested: ManagedDeviceId"
                    Write-Host "The Property tested value: $managedDeviceId"
                    Write-Host "The Matching Property name: $($property.Name)"
                    Write-Host "The Matching Property value: $($property.value)"
                    $global:matchingDevices += @{
                        'PropertyTested'        = 'ManagedDeviceId'
                        'PropertyTestedValue'   = $managedDeviceId
                        'MatchingPropertyName'  = $property.Name
                        'MatchingPropertyValue' = $property.value
                    }
                } 
                if ($property.value -contains $productKey) {
                    Write-Host "The property with name $($property.Name) contains the ProductKey: $productKey" -ForegroundColor Yellow
                    Write-Host "The Property tested: ProductKey"
                    Write-Host "The Property tested value: $productKey"
                    Write-Host "The Matching Property name: $($property.Name)"
                    Write-Host "The Matching Property value: $($property.value)"
                    $global:matchingDevices += @{
                        'PropertyTested'        = 'ProductKey'
                        'PropertyTestedValue'   = $productKey
                        'MatchingPropertyName'  = $property.Name
                        'MatchingPropertyValue' = $property.value
                    }
                }
                if ($property.value -contains $id) {
                    Write-Host "The property with name $($property.Name) contains the Id: $id" -ForegroundColor Yellow
                    Write-Host "The Property tested: Id"
                    Write-Host "The Property tested value: $id"
                    Write-Host "The Matching Property name: $($property.Name)"
                    Write-Host "The Matching Property value: $($property.value)"
                    $global:matchingDevices += @{
                        'PropertyTested'        = 'Id'
                        'PropertyTestedValue'   = $id
                        'MatchingPropertyName'  = $property.Name
                        'MatchingPropertyValue' = $property.value
                    }
                }
            }
        }
    }
}
#endregion