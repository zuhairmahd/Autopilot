[CmdletBinding()]
param
(
    $userName,
    $repo = 'Github', # Options: Github, gitlab
    $release = 'auto',
    $configFile = "$pwd\.secrets\config.json",
    $outputFile = "$pwd\deviceMemory-export.csv"
)

#region Load parameters from the configuration file if it exists
$scriptName = $MyInvocation.MyCommand.Name
$initFile = "$pwd\settings.json"
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
Write-Verbose "[$scriptName] Domain: $domain"
if (Test-Path -Path $InitFile)
{
    Write-Host " Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
    $global:globalSettings = @{}
    $global:localSettings = @{}
    $globalConfigData = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty 'globalSettings'
    Write-Verbose "[$scriptName] Reading global settings..."
    Write-Verbose "[$scriptName] Found $($globalConfigData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $globalConfigData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $globalConfigData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($globalConfigData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($globalConfigData.$key)"
            if ($globalConfigData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($globalConfigData.$key)
                $globalSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
                # Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($globalConfigData.$key))."
                # Set-Variable -Name $key -Value $globalConfigData.$key
                $globalSettings.add($key, $globalConfigData.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Got parameter $key from the commandline as $($PSBoundParameters[$key])"
            #add it to the global settings hashtable.
            $globalSettings.add($key, $PSBoundParameters[$key])
        }
    }
    $localConfigData = (Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty "domains").$domain
    Write-Verbose "[$scriptName] Reading local settings for domain $domain..."
    Write-Verbose "[$scriptName] Found $($localConfigData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $localConfigData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $localConfigData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($localConfigData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($localConfigData.$key)"
            if ($localConfigData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($localConfigData.$key)
                $localSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
                # Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($localConfigData.$key))."
                # Set-Variable -Name $key -Value $localConfigData.$key
                $localSettings.add($key, $localConfigData.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Read parameter $key from the commandline as $($PSBoundParameters[$key])"
            #add it to the local settings hashtable.
            $localSettings.add($key, $PSBoundParameters[$key])
        }
    }   
}
else
{
    Write-Host "Configuration file $initFile not found. Using default values."
}
#endregion Load parameters from the configuration file if it exists

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
$auth = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty auth
$scope = $auth.scope
# $logfile = "mylog.log"
$settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
# $serialNumber = '0F3CFP724223KV'
# $serialNumber = 'BTSB25000BCR'
# $serialNumber = '5R3SBZ3'
# $userUri = "users"
# $managedAppUri = "deviceAppManagement/mobileApps"
# $appAssignmentURI = "deviceAppManagement/mobileApps/$($app.id)/assignments"
# $importedAutopilotDeviceURI = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
# $importedAutopilotDeviceExtraParameters = "select=serialNumber,importId,groupTag,state"
# $unmanagedDeviceUri = "devices"
# $managedDeviceUri = "deviceManagement/managedDevices"
# $autoPilotDeviceURI = "deviceManagement/windowsAutopilotDeviceIdentities"
# $autopilotExtraParameters = "select=serialNumber,groupTag,manufacturer,model,systemFamily,enrollmentState,deploymentProfileAssignmentStatus&top=9999&skip=0&count=true"
# $managedDeviceFilter = "serialNumber eq '$serialNumber'"
# $managedDeviceFilter = "startswith(deviceName,'w11-')"
# $autopilotDeviceFilter = "contains(serialNumber,'$serialNumber')"
# $importedDeviceFilter = "serialNumber eq '$serialNumber'"
# $deviceConfigurationUri = "deviceManagement/deviceConfigurations"
# $autopilotCsv = [System.Collections.ArrayList]@()
# $importedCsv = [System.Collections.ArrayList]@()
$accessToken = GetGraphAccessToken -configFile $configFile -deligated -scope $scope -AuthType 'PublicAuthFlow' 
# $accessToken = GetGraphAccessToken -configFile $configFile
# $autopilotDevices = CallGraphApi -ResourcePath $autoPilotDeviceURI -accessToken $accessToken -extraParameters $autopilotExtraParameters -consistencyLevel -verbose
# $importedDevices = CallGraphApi -ResourcePath $importedAutopilotDeviceURI -accessToken $accessToken -consistencyLevel -extraParameters $importedAutopilotDeviceExtraParameters -verbose
# $unmanagedDevices = CallGraphApi -ResourcePath $unmanagedDeviceUri -accessToken $accessToken
# $global:enrollments = [ordered] @{
# "autopilot" = $autopilotDevices
# "managed" = $managedDevices
# "imported"  = $importedDevices
# "unmanaged" = $unmanagedDevices
# }
#endregion variables

$deviceId = "17156ac7-e2ae-4204-ab08-4eb7115b6ae9"
$URI = "informationProtection/bitlocker/recoveryKeys"
$filter = "deviceId eq '$deviceId'"
# First, get the list of recovery keys (without the actual key values)
$extraParameters = "select=id,createdDateTime,volumeType,deviceId" 
Write-Verbose "[$scriptName] Getting BitLocker recovery keys for device: $deviceId"
$global:bitlockerKeys = CallGraphApi -accessToken $accessToken -ResourcePath $URI -filter $filter -extraParameters $extraParameters 

if ($bitlockerKeys.value.count -gt 0)
{
    Write-Host "Found $($bitlockerKeys.value.count) BitLocker recovery keys" -ForegroundColor Green
    
    # Get the most recently created key
    $latestKeyInfo = $bitlockerKeys.value | Sort-Object -Property createdDateTime -Descending | Select-Object -First 1
    Write-Verbose "[$scriptName] Latest key ID: $($latestKeyInfo.id)"
    
    # Now make a separate call to get the actual recovery key value
    $keyRetrievalURI = "informationProtection/bitlocker/recoveryKeys/$($latestKeyInfo.id)"
    $keyRetrievalParameters = "select=key"
    Write-Verbose "[$scriptName] Retrieving actual BitLocker recovery key..."
    
    try
    {
        $global:recoveryKeyDetails = CallGraphApi -accessToken $accessToken -ResourcePath $keyRetrievalURI -extraParameters $keyRetrievalParameters
        
        # Display the recovery key information
        Write-Host "Latest BitLocker recovery key:" -ForegroundColor Cyan
        Write-Host "Key: $($global:recoveryKeyDetails.key)" -ForegroundColor Yellow
        Write-Host "Created: $($latestKeyInfo.createdDateTime)" -ForegroundColor Yellow
        Write-Host "Volume Type: $($latestKeyInfo.volumeType)" -ForegroundColor Yellow
        Write-Host "Device ID: $($latestKeyInfo.deviceId)" -ForegroundColor Yellow
        Write-Host "Key ID: $($latestKeyInfo.id)" -ForegroundColor Yellow
    }
    catch
    {
        Write-Error "[$scriptName] Failed to retrieve BitLocker recovery key: $($_.Exception.Message)"
        Write-Host "Key metadata available:" -ForegroundColor Yellow
        Write-Host "Created: $($latestKeyInfo.createdDateTime)" -ForegroundColor Yellow
        Write-Host "Volume Type: $($latestKeyInfo.volumeType)" -ForegroundColor Yellow
        Write-Host "Device ID: $($latestKeyInfo.deviceId)" -ForegroundColor Yellow
        Write-Host "Key ID: $($latestKeyInfo.id)" -ForegroundColor Yellow
    }
}
else
{
    Write-Host "No BitLocker recovery keys found for device: $deviceId" -ForegroundColor Red
}
