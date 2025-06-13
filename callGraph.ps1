[CmdletBinding()]
param (
    [string]$OutputFolder = "$pwd\json"
)

$autopilotSerialNumber = '5R3SBZ3'
$serialNumber = '5R3SBZ3'


#region Import functions
$functionsFolder = "$pwd\functions"
$functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1'
foreach ($function in $functions)
{
    Write-Verbose "Importing function: $($function.FullName)"
    . $function.FullName
}
#endregion

function GetAccessToken()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$tenantId,
        [Parameter(Mandatory = $true)]
        [string]$clientId,
        [Parameter(Mandatory = $true)]
        [string]$clientSecret
    )
    #write a verbose log of the received parameters
    Write-Verbose "TenantId: $tenantId"
    Write-Verbose "ClientId: $clientId"
    Write-Verbose "ClientSecret: $clientSecret"

    $body = @{
        client_id     = $clientId
        scope         = 'https://graph.microsoft.com/.default'
        client_secret = $clientSecret
        grant_type    = 'client_credentials'
    }
    $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType 'application/x-www-form-urlencoded' -Body $body
    $accessToken = $tokenResponse.access_token
    return $accessToken
}

function CallGraph()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$uri,
        [string]$method = 'get',
        [switch]$cl
    )
    
    Write-Verbose "AccessToken: $accessToken"
    Write-Verbose "Uri: $uri"

    if ($cl) 
    {
        $headers = @{
            Authorization    = "Bearer $accessToken"
            'Content-Type'   = 'application/json'
            ConsistencyLevel = 'Eventual'
        }
    }
    else
    {
        $headers = @{
            Authorization  = "Bearer $accessToken"
            'Content-Type' = 'application/json'
        }
    }
    Write-Host "Making the following call to the Url: $uri"
    $response = Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
    Write-Verbose "Response: $response"
    Write-Verbose "Response value: $($response.value)"
    return $response
}

function GetDeviceBySerial()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$serialNumber,
        [string]$DeviceType = 'device'
    )

    switch ($DeviceType)
    {
        'managedDevice'
        {
            Write-Host "Fetching serial number for a managed device with serial number: $serialNumber"
            $filter = "serialNumber eq '$serialNumber'"
            $encodedFilter = [uri]::EscapeDataString($filter)
            $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$encodedFilter" 
        }
        autopilotDevice
        {
            Write-Host "Fetching serial number for an autopilot device with serial number: $serialNumber"
            $filter = "startswith(serialNumber,'$serialNumber')"
            $encodedFilter = [uri]::EscapeDataString($filter)
            $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=$encodedFilter"
        }
        importedAutopilotDevice
        {
            Write-Host "Fetching serial number for an imported autopilot device with serial number: $serialNumber"
            $filter = "serialNumber eq '$serialNumber'"
            $encodedFilter = [uri]::EscapeDataString($filter)
            $uri = "https://graph.microsoft.com/beta/deviceManagement/importedAutopilotDeviceIdentities?`$filter=$encodedFilter"
        }
        default
        {
            Write-Host "$DeviceType is an Incorrect device type."
            return $null
        }
    }
    Write-Verbose "Filter: $filter"
    Write-Verbose "Encoded Filter: $encodedFilter"
    Write-Verbose "URI: $uri"  
    $device = CallGraph -accessToken $accessToken -uri $uri
    if ($device)
    {
        Write-Host "Found $($device.value.count) devices."
        return $device.value
    }
    else 
    {
        Write-Host 'Failed to find the device.'
        return $null
    }
}

#region ReadConfiguration
$configuration = Get-Content -Path "$pwd\.secrets\config.json" | ConvertFrom-Json
$config = GetDecryptedObject -encryptedObject $configuration
$tenantId = $config.tenantId
$clientId = $config.appId
$clientSecret = $config.AppSecret
Write-Verbose "Calling the GetAccessToken function with the following parameters: tenantId=$tenantId, clientId=$clientId, clientSecret=$clientSecret"
$accessToken = GetAccessToken -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret
if ($accessToken)
{
    Write-Verbose 'Received access token.'
}
else
{
    Write-Host 'Failed to receive access token.'
}
#endregion

$configFile = "$pwd\.secrets\config.json"
if (connectToTenant -configFile $configFile)
{
    Write-Host 'Connected to tenant.'
}
else
{
    Write-Host 'Failed to connect to tenant.'
}




#region variables

$autopilotDevices = Get-MgBetaDeviceManagementWindowsAutopilotDeviceIdentity -All
$importedAutopilotDevices = Get-MgBetaDeviceManagementImportedWindowsAutopilotDeviceIdentity -all 
$managedDevices = Get-MgBetaDeviceManagementManagedDevice -all
$windowsDevices = Get-MgBetaDevice -All
$autopilotDevices | ConvertTo-Json -Depth 10 | Set-Content -Path "$OutputFolder\autopilotDevices.json"
$importedAutopilotDevices | ConvertTo-Json -Depth 10 | Set-Content -Path "$OutputFolder\importedAutopilotDevices.json"
$managedDevices | ConvertTo-Json -Depth 10 | Set-Content -Path "$OutputFolder\managedDevices.json"
$windowsDevices | ConvertTo-Json -Depth 10 | Set-Content -Path "$OutputFolder\windowsDevices.json"
exit 0
$global:autopilotDevice = Get-MgBetaDeviceManagementWindowsAutopilotDeviceIdentity -Filter "contains(serialNumber,'$autopilotSerialNumber')" -All
$global:managedDevice = Get-MgBetaDeviceManagementManagedDevice -Filter "contains(serialNumber,'$serialNumber')" -All
$displayName = $managedDevice.deviceName
$global:device = Get-MgDevice -Filter "startswith(displayName,'$displayName')" -All
$global:profile = Get-MgBetaDeviceManagementWindowsAutopilotDeploymentProfile 
$assignedDevice = Get-MgBetaDeviceManagementWindowsAutopilotDeploymentProfileAssignedDevice -Filter "contains(serialNumber,'$serialNumber')" -WindowsAutopilotDeploymentProfileId $profile.id
#region

$listOfAutopilotProperties = @()
$listOfManagedProperties = @()
$listOfProperties = @()
foreach ($device in $global:managedDevice.PSObject.Properties)
{
    # Write-Host "Adding properties for $($device.Name)"
    $listOfManagedProperties += $device.value
}
$global:listofManagedProperties = $listOfManagedProperties

foreach ($device in $global:autopilotDevice.PSObject.Properties)
{
    # Write-Host "Adding properties for $($device.Name)"
    $listOfAutopilotProperties += $device.value
}
$global:listOfAutopilotProperties = $listOfAutopilotProperties

foreach ($device in $global:device.PSObject.Properties)
{
    # Write-Host "Adding properties for $($device.Name)"
    $listOfProperties += $device.value
}
$global:listOfProperties = $listOfProperties
foreach ($property in $autopilotDevice.PSObject.Properties)
{
    Write-Host "Checking for $($property.Name):"
    if ($null -ne $property.Value -and $property.Value -ne '')
    {
        $propertyValue = $property.value.toString()
        if ($propertyValue -in $listOfProperties)
        {
            Write-Host "Matched property: $($property.Name)"
            Write-Host "Value: $($property.Value)"
        }
        else
        {
            Write-Host "No match found for $($property.Name)"
        }
    }
    else
    {
        Write-Host "Property $($property.Name) is null or empty."
    }
}