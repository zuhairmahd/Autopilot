[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\settings.json",
    [int]$maxWaitTime,
    [int]$timeInSeconds,
    [String] $GroupTag,
    [switch]$Reconfigure,
    [switch]$ReInitialize,
    [switch]$Update,
    [switch]$showAuth,
    [switch]$showSettings,
    [switch]$SecureString,
    [switch]$ForceNewToken,
    [parameter(parameterSetName = 'Deligated')]
    [switch]$Deligated,
    [parameter(parameterSetName = 'Deligated')]
    [switch]$ForceNewRefreshToken,
    [parameter(parameterSetName = 'Deligated')]
    [switch]$NoSaveRefreshToken,
    [parameter(parameterSetName = 'Deligated')]
    [string]$Scope,
    [parameter(parameterSetName = 'Deligated')]
    [ValidateSet('PublicAuthFlow', 'Interactive', 'Private')]
    [string]$AuthType,
    [ValidateSet('file', 'memory')]
    [string]$CacheType,
    [string]$Repo = 'github',
    [string]$Release = 'main',
    [ValidateSet('full', 'helpDesk', 'registration')]
    [string]$appMode
)

$scriptName = $MyInvocation.MyCommand.Name
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript")
{
    Write-Verbose "[$scriptName] Running as an external script."
    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    Write-Verbose "[$scriptName] Script path: $ScriptPath"
}
else
{
    Write-Verbose "[$scriptName] Running as a script block."
    $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    Write-Verbose "[$scriptName] Script path: $ScriptPath"
    if (!$ScriptPath)
    {
        Write-Verbose "[$scriptName] Script path is not set. Defaulting to current directory."
        $ScriptPath = "."
        $scriptName = 'main.ps1'
    }
}

#region Load parameters from the configuration file if it exists
Write-Verbose "[$scriptName] Checking configuration file: $configFile"
if (Test-Path $configFile)
{
    $domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
    $authConfiguration = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty auth
    $auth = @{}
    Write-Verbose "[$scriptName] Domain: $domain"
    Write-Verbose "[$scriptName] Loading Auth configuration from $configFile"
    foreach ($key in $authConfiguration.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $authConfiguration.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($authConfiguration.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($authConfiguration.$key)"
            if ($authConfiguration.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($authConfiguration.$key)
                $auth.add($key, $keyBooleanValue)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($authConfiguration.$key))."
                $auth.add($key, $authConfiguration.$key)
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Got parameter $key from the commandline as $($PSBoundParameters[$key])"
            $auth.add($key, $PSBoundParameters[$key])
        }
    }
}
if (Test-Path -Path $InitFile)
{
    Write-Verbose "[$scriptName] Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
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
    Write-Verbose "[$scriptName] Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "[$scriptName] Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}
#endregion import functions.

#region Define variables
if ($repo -eq 'github')
{
    $baseSourceURL = 'https://raw.githubusercontent.com'
    $repoPath = 'zuhairmahd'
    $repoName = 'autopilot'
    if ($release -eq 'auto')
    {
        $latestRelease = GetLatestGithubRelease -Repository "$repoPath/$repoName"
        if ($latestRelease)
        {
            Write-Host "The latest release is $latestRelease"
        }
        else
        {
            Write-Host 'Failed to retrieve the latest release information from GitHub.' -ForegroundColor Red
            Write-Host 'Defaulting to main branch.'
            $latestRelease = 'main'
        }
    }
    else
    {
        $latestRelease = $Release
    }
}
elseif ($repo -eq 'gitlab')
{
    $baseSourceURL = 'https://git.gao.gov'
    $repoPath = 'mahmoudz'
    $repoName = 'autopilot-deployment'
    $repoId = '1031'
    $latestRelease = GetLatestGitlabRelease -RepositoryId $repoId
}
else
{
    Write-Host 'Invalid repository specified.'
    Write-Host 'Defaulting to the main branch from GitHub.'
    $latestRelease = 'main'
}
$settings = MergeSettings -localSettings $localSettings -globalSettings $globalSettings -ConflictResolution 'Local'
$groupsToInclude = $settings.groupsToInclude
Write-Verbose "[$scriptName] Groups to include: $($groupsToInclude | Out-String)"
$groupsToExclude = $settings.groupsToExclude
Write-Verbose "[$scriptName] Groups to exclude: $($groupsToExclude | Out-String)"
Write-Verbose "[$scriptName] Settings are as follows:"
foreach ($key in $settings.Keys)
{
    Write-Verbose "[$scriptName] $($key): $($settings[$key])"
    if ($showSettings)
    {
        Write-Host "Setting $key: $($settings[$key])"
    }
}
Write-Verbose "[$scriptName] Auth configuration loaded from $configFile"
$getTokenParams = BuildAuthSplatTable -auth $auth
foreach ($key in $getTokenParams.Keys)
{
    Write-Verbose "[$scriptName] $($key): $($getTokenParams[$key])"
    if ($showAuth)
    {
        Write-Host "$($key): $($getTokenParams[$key])"
    }
}
Write-Verbose "[$scriptName] Using authentication parameters: $($getTokenParams | ConvertTo-Json -Depth 5)"
$backoutText = 'Returning to previous menu'
Write-Verbose "[$scriptName] Backout Text: $backoutText"
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
Write-Verbose "[$scriptName] Update URL: $updateURL"
$version = '3.0.0'
Write-Verbose "[$scriptName] Version: $version"
$versionFile = 'version.txt'
Write-Verbose "[$scriptName] Version file: $versionFile"
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/$versionFile"
Write-Verbose "[$scriptName] Remote version URL: $remoteVersionURL"
$stringsFile = "$PWD\strings.json"
Write-Verbose "[$scriptName] Loading strings from: $stringsFile"
$loadedStrings = Get-StringsFromJson -StringsFile $stringsFile
$returnValues = $loadedStrings.returnValues
$deviceStates = $loadedStrings.deviceStates
$deviceActions = $loadedStrings.deviceActions
Write-Verbose "[$scriptName] Loaded $($returnValues.Count) return values, $($deviceStates.Count) device states, and $($deviceActions.Count) device actions"
# Initialize navigation context variables
$Global:History = [System.Collections.ArrayList]::new() 
$Global:MenuHistory = [System.Collections.ArrayList]::new() 
$global:previousMenu = New-Object System.Collections.Hashtable
# Device enrollment state cache content
$script:DeviceEnrollmentCache = @{}
#endregion Define variables

#region logging
Write-Verbose "[$scriptName] Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Verbose "[$scriptName] The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Verbose "[$scriptName] Configuration file: $configFile"
Write-Verbose "[$scriptName] Computer name: $Name"
Write-Verbose "[$scriptName] Group tag: $GroupTag"
Write-Verbose "[$scriptName] Assigned user: $AssignedUser"
Write-Verbose "[$scriptName] Reconfigure: $Reconfigure"
Write-Verbose "[$scriptName] Repository: $Repo"
Write-Verbose "[$scriptName] Release: $Release"
Write-Verbose "[$scriptName] Domain: $domain"
Write-Verbose "[$scriptName] Max wait time: $maxWaitTime seconds"
Write-Verbose "[$scriptName] Time in seconds: $timeInSeconds"
Write-Verbose "[$scriptName] Auth type: $AuthType"
Write-Verbose "[$scriptName] Cache type: $CacheType"
Write-Verbose "[$scriptName] Force new token: $ForceNewToken"
Write-Verbose "[$scriptName] Force new refresh token: $ForceNewRefreshToken"
Write-Verbose "[$scriptName] No save refresh token: $NoSaveRefreshToken"
Write-Verbose "[$scriptName] Deligated: $Deligated"
Write-Verbose "[$scriptName] Scope: $Scope"
Write-Verbose "[$scriptName] Secure string: $SecureString"
Write-Verbose "[$scriptName] App mode: $appMode"
Write-Verbose "[$scriptName] Functions folder: $functionsFolder"
Write-Verbose "[$scriptName] Base source URL: $baseSourceURL"
Write-Verbose "[$scriptName] Backout text: $backoutText"
#endregion logging

#region helper functions
function ProcessDevice()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        $DeviceObject,
        $returnValues = $returnValues,
        [Parameter(Mandatory = $true)]
        [ValidateSet('import', 'check', 'delete')]
        [string]$action,
        [switch]$CustomImport
    )
    
    #region check and initialize variables
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking access token..."
    if ($accessToken)
    {
        Write-Verbose "[$functionName] Access token provided."
    }
    else
    {
        Write-Verbose "[$functionName] Access token not provided. Returning Null."
        return $null
    }
    Write-Verbose "[$functionName] Processing serial number: $($deviceObject.SerialNumber)."
    Write-Verbose "[$functionName] Action: $action"
    Write-Verbose "[$functionName] Custom import: $CustomImport"
    $serialNumber = $deviceObject.serialNumber
    Write-Verbose "[$functionName] The serial number is $serialNumber."
    $make = $deviceObject.manufacturer
    Write-Verbose "[$functionName] The manufacturer is $make"
    $model = $deviceObject.model
    Write-Verbose "[$functionName] The model is $model"
    #endregion check and initialize variables
    
    switch ($action)
    {
        'import'
        {
            Write-Verbose "[$functionName] Importing device with serial number $serialNumber."
            Write-Host "Checking to make sure the device hash is not already in Intune..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            Write-Verbose "[$functionName] Device assignment check returned: $deviceAssignment"
            if ($deviceAssignment)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment 
                Write-Verbose "[$functionName] Device assignment status: $isAssigned"
                if ($isAssigned)
                {
                    return $returnValues.deviceAssignedMessage
                }
            }
            else
            {
                Write-Host "The device is not in Intune." 
            }
            #region Add the device to Intune
            Write-Host "This will import the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) into Autopilot."
            $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            while ($choice -notin @('yes', 'no'))
            {
                Write-Host "Invalid choice. Please enter 'yes' or 'no'."
                #beep
                [console]::beep(1000, 500)
                $choice = Read-Host "Are you sure you want to import this device? (yes/no)"
            }
            if ($choice -eq 'no')
            {
                Write-Host "Exiting..."
                return $backoutText
            }
            $importStart = Get-Date
            $device = ImportAutopilotDevice -DeviceObject $deviceObject -AccessToken $accessToken -GroupTag $GroupTag -AssignedUser $AssignedUser -TimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime -CustomImport $CustomImport
            if ($device -eq $backoutText)
            {
                Write-Verbose "[$functionName] The import function returned $device."
                return $backoutText
            }
            $importResult = ProcessImportResult -device $device -returnValues $returnValues
            if ($importResult -ne $returnValues.deviceImportSuccessMessage)
            {
                return $importResult
            }
            
            Write-Host "Waiting for $timeInSeconds seconds to allow for profile assignment."
            Start-Sleep -Seconds $timeInSeconds
            
            $assignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -WaitForAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
            return ProcessAssignmentResult -assignment $assignment -importStart $importStart -returnValues $returnValues
            #endregion Add the device to Intune.
        }
        'check'
        {
            Write-Host "Checking device with serial number $serialNumber..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            if ($deviceAssignment)
            {
                $isAssigned = DisplayDeviceAssignmentStatus -deviceAssignment $deviceAssignment 
                if ($isAssigned)
                {
                    # Handle enrollment state for assigned devices
                    return HandleDeviceEnrollmentState -deviceAssignment $deviceAssignment -serialNumber $serialNumber -accessToken $accessToken -returnValues $returnValues -domain $domain
                }
                else
                {
                    # Handle unassigned devices
                    switch ($deviceAssignment.deploymentProfileAssignmentStatus)
                    {
                        'unassigned'
                        {
                            return $returnValues.deviceNotAssignedMessage
                        }
                        'pending'
                        {
                            return $returnValues.deviceAssignmentPendingMessage
                        }
                    }
                    # Show options for problem devices
                    Write-Host "What would you like to do?"
                    $deviceWaitMenu = NewMenu -Title "Options for Device With Serial Number $serialNumber" -Description "Choose what you would like to do with this device:"
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Restart the device" -Action {
                        Write-Host "Restarting the device..."
                        Write-Verbose "[$functionName] User chose to restart the device."
                        if (-not (RestartDevice))
                        {
                            Write-Verbose "[$functionName] RestartDevice function returned false."
                            return $returnValues.noRestartMessage 
                        }
                    }
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Continue to wait for profile assignment" -Action {
                        Write-Host "Continuing to wait for profile assignment..."
                        $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken -waitforAssignment -waitTimeInSeconds $timeInSeconds -maxWaitTime $maxWaitTime
                        return $deviceAssignment
                    }
                    $deviceWaitMenu = AddMenuItem -Menu $deviceWaitMenu -Name "Delete the device from Autopilot" -Action {
                        Write-Host "Deleting the device from Autopilot..."
                        if (DeleteAutopilotDevice -DeviceIdentifyer $deviceAssignment.id -IdentifyerType 'DeviceId')
                        {
                            Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                            return $returnValues.deviceDeleteSuccessMessage
                        }
                        else
                        {
                            Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                            return $returnValues.deviceDeleteFailedMessage
                        }
                    }
                    $result = ShowMenu -Menu $deviceWaitMenu -CalledBy 'Action'
                    Write-Verbose "[$functionName] Result from device wait menu: $result"
                    if ($result -eq $backoutText)
                    {
                        Write-Verbose "[$functionName] User selected Back from device wait menu."
                        return $backoutText
                    }
                    elseif ($result -eq "EXIT_APPLICATION")
                    {
                        Write-Verbose "[$functionName] User selected to exit the application."
                        return "EXIT_APPLICATION"
                    }
                    else 
                    {
                        return $result
                    }
                }
            }
            else
            {
                Write-Host 'The device is not in Autopilot.'
                return $returnValues.deviceNotInIntuneMessage
            }
        }
        'delete'
        {
            Write-Host "Checking whether the device is in Autopilot..."
            $deviceAssignment = CheckDeviceAssignment -serialNumber $serialNumber -AccessToken $accessToken
            if ($deviceAssignment)
            {
                Write-Host "Deleting device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) from Autopilot."
                if (DeleteAutopilotDevice -DeviceIdentifyer $serialNumber -IdentifyerType 'serialNumber')
                {
                    Write-Host 'The device was deleted from Autopilot.' -ForegroundColor Green
                    return $returnValues.deviceDeleteSuccessMessage
                }
                else
                {
                    Write-Host 'Failed to delete the device from Autopilot.' -ForegroundColor Red
                    return $returnValues.deviceDeleteFailedMessage
                }
            }
            else
            {
                Write-Host "The device with serial number $serialNumber is not in Autopilot." -ForegroundColor Yellow
                Write-Host "No action taken." -ForegroundColor Yellow
                return $returnValues.deviceNotInIntuneMessage 
            }
        }
        default
        {
            Write-Verbose "[$functionName] Invalid action: $action"
            return $returnValues.unknownErrorMessage
        }
    }
}

function ProcessSerialNumber()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$SerialNumber,
        $AccessToken,
        $Settings = $settings,
        [switch]$CheckUserReadiness
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing device lookup for serial number: $SerialNumber"
    Write-Verbose "[$functionName] Validating serial number: $SerialNumber"
    if ([string]::IsNullOrWhiteSpace($SerialNumber))
    {
        Write-Host "Serial number cannot be empty or null." -ForegroundColor Red
        return $null # Return null to signal no valid serial number
    }
    $success = $false
    $SerialNumber = $SerialNumber.Trim()
    Write-Host "`nLooking up device information for serial number: $SerialNumber" -ForegroundColor Cyan
    $enrollmentState = GetCachedDeviceEnrollmentState -SerialNumber $SerialNumber -AccessToken $AccessToken -Settings $Settings
    if ($enrollmentState)
    {
        $success = $true
        Write-Verbose "[$functionName] Device lookup successful"
        # Display basic device information
        Write-Host "`n=== Device Information ===" -ForegroundColor Green
        Write-Host "Serial Number: $SerialNumber"
        Write-Verbose "[$scriptName] Device is managed: $($enrollmentState.managed)"
        Write-Verbose "[$scriptName] Has device object: $($enrollmentState.hasDeviceObject)"
        Write-Verbose "[$scriptName] In Autopilot: $($enrollmentState.inAutopilot)"
        Write-Verbose "[$scriptName] Device imported: $($enrollmentState.Imported)"
        if ($CheckUserReadiness)
        {
            return GetNextUserReadinessReport -enrollmentState $enrollmentState
        }
        if ($enrollmentState.inAutopilot)
        {
            Write-Host "This device is enrolled in Autopilot."
            #capture the device information since this is the first place we can get it.
            if (-not $enrollmentState.managed)
            {
                Write-Host "Model: $($enrollmentState.autopilot.device.model)"
                Write-Host "Manufacturer: $($enrollmentState.autopilot.device.manufacturer)"
                Write-Host "System Family: $($enrollmentState.autopilot.device.systemFamily)"
                Write-Host "=============================`n" -ForegroundColor Green
                $DeviceAssessmentState = AssessDeviceState -enrollmentState $enrollmentState -AssessmentType 'NextUserReadiness'
                Write-Verbose "[$scriptName] Device assessment state: $DeviceAssessmentState"
                Write-Host "Device Assessment State: $DeviceAssessmentState" -ForegroundColor Green
            }
            Write-Host "Deployment profile assignment status: $($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus)"
            if ($enrollmentState.autopilot.device.deploymentProfileAssignmentStatus -in @('assignedInSync', 'assignedUnkownSyncState'))
            {
                Write-Host "Deployment profile: $($enrollmentState.autopilot.device.deploymentProfile.displayName)"
                Write-Host "Deployment Profile Assignment Date: $($enrollmentState.autopilot.device.deploymentProfileAssignedDateTime | FormatDateWithTimeZone)"
            }
            else
            {
                Write-Host "This device is not assigned to a deployment profile." -ForegroundColor Yellow
            }
        }
        else
        {
            Write-Host "This device is not enrolled in Autopilot." -ForegroundColor Yellow
            Write-Host "=============================`n" -ForegroundColor Yellow
        }
        if ($enrollmentState.Imported)
        {
            Write-Verbose "[$scriptName] Imported in Autopilot: $($enrollmentState.inAutopilot)"
            Write-Verbose "[$scriptName] Imported count: $($enrollmentState.Imported)"
            if ($enrollmentState.Imported -gt 1)
            {
                Write-Host "This device was imported into Autopilot $($enrollmentState.Imported) times." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice[$enrollmentState.ImportedAutopilotDevice.Count - 1]
            }
            else
            {
                Write-Host "This device was recently imported into Autopilot." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice
            }
            if (-not $enrollmentState.managed)
            {
                Write-Host "However, this device is not currently managed in Intune."
            }
            Write-Host "Here is the latest known import information:"
            Write-Host "Imported Device ID: $($importedDeviceInfo.id)"
            Write-Host "Last import registration id: $($importedDeviceInfo.state.deviceRegistrationId)"
            Write-Host "Last import status: $($importedDeviceInfo.state.deviceImportStatus)"
            Write-Host "Last import error: $($importedDeviceInfo.state.deviceErrorName)"
            Write-Host "Last import error code: $($importedDeviceInfo.state.deviceErrorCode)"
        }
        else
        {
            Write-Verbose "This device was not recently imported into Autopilot."
        }
        if ($enrollmentState.managed)
        {
            $deviceName = $enrollmentState.managedDevice.device.deviceName
            $model = $enrollmentState.managedDevice.device.model
            $manufacturer = $enrollmentState.managedDevice.device.manufacturer
            $managedDeviceId = $enrollmentState.managedDevice.device.id
            Write-Host "Device Name: $deviceName"
            Write-Host "Model: $model"
            Write-Host "Manufacturer: $manufacturer"
            Write-Host "Status: Managed by Intune" -ForegroundColor Green
            Write-Host "=============================`n" -ForegroundColor Green
            # Create and show device actions menu using main.ps1 menu structure
            $deviceActionsMenu = NewMenu -Title "Device Actions for $deviceName" -Description "Select an action to perform on this device:"
            # Add menu items for each device action
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Wipe Device" -Action {
                Write-Host "`nInitiating device wipe for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'wipe' | Out-Null
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Clean Device" -Action {
                Write-Host "`nInitiating device clean for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'clean' -MonitorAction
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Sync Device" -Action {
                Write-Host "`nSyncing device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'sync'
            }
            Write-Verbose "[$functionName] Checking if device has LAPS credentials."
            Write-Verbose "[$functionName] LAPS credentials count: $($enrollmentState.managedDevice.laps.credentials.count)"
            if ($enrollmentState.managedDevice.laps.credentials.count -gt 0)
            {
                $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Get LAPS Password" -Action {
                    GetDeviceLAPSCredentials -enrollmentState $enrollmentState
                }
            }            
            Write-Verbose "Checking if we have bitlocker keys for this device."
            Write-Verbose "[$functionName] BitLocker recovery key count: $($enrollmentState.managedDevice.bitLocker.value.count)"
            if ($null -ne $enrollmentState.managedDevice.latestBitlockerKey)
            {
                $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Get BitLocker Recovery Key" -Action {
                    Write-Host "Sending value of $($enrollmentState.managedDevice.latestBitlockerKey) to GetBitLockerRecoveryKey function."
                    GetBitLockerRecoveryKey -key $enrollmentState.managedDevice.latestBitlockerKey -accessToken $AccessToken -verbose 
                }
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Restart Device" -Action {
                Write-Host "`nRestarting device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'restart' | Out-Null
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Show Device Health Status" -Action {
                $deviceReport = ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber
                Write-Verbose "[$functionName] Device report: $deviceReport"
                # Handle navigation responses from ShowReport
                if ($deviceReport -eq "Back" -or $deviceReport -eq "back")
                {
                    Write-Verbose "[$scriptName] User selected Back from device selection, returning to previous menu"
                    return $backoutText
                }
                elseif ($deviceReport -eq "Main Menu" -or $deviceReport -eq "main menu")
                {
                    Write-Verbose "[$scriptName] User selected Main Menu from device selection"
                    return "EXIT_APPLICATION"
                }
                elseif ([string]::IsNullOrWhiteSpace($deviceReport) -or $null -eq $deviceReport)
                {
                    Write-Verbose "[$scriptName] User requested application exit from device selection."
                    return "EXIT_APPLICATION"
                }        
                elseif ($deviceReport -ne '0' -and $null -ne $deviceReport -and $deviceReport -ne "Back" -and $deviceReport -ne "Main Menu")
                {
                    if ($deviceReport -eq $true -or $deviceReport -in ("Export to HTML", "Export to CSV"))
                    {
                        Write-Host "`nDevice health status displayed successfully." -ForegroundColor Green
                    }
                    else
                    {
                        Write-Host "`nDevice health status could not be displayed." -ForegroundColor Red
                    }
                    Write-Verbose "[$scriptName] ShowDeviceReport returned: $deviceReport"
                }
                return $backoutText
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Check next user readiness state" -Action {
                return (GetNextUserReadinessReport -enrollmentState $enrollmentState).ReadinessState
            }
            # Show the device actions menu with navigation context
            Write-Verbose "[$functionName] Showing device actions menu with Depth: $depth, History count: $($History.Count), MenuHistory count: $($MenuHistory.Count)"
            $result = ShowMenu -Menu $deviceActionsMenu -CalledBy 'Action'
            Write-Verbose "[$functionName] Returning from device actions menu with result: $result"
            return $result
        }
        else
        {
            Write-Host "This device is not managed in Intune." -ForegroundColor Yellow
        }
        if ($enrollmentState.hasDeviceObject)
        {
            Write-Host "`nDevice object found in Intune." -ForegroundColor Green
            Write-Host "Device ID: $($enrollmentState.managedDevice.device.id)"
            Write-Host "Device Name: $($enrollmentState.managedDevice.device.deviceName)"
            Write-Host "Model: $($enrollmentState.managedDevice.device.model)"
        }
        else
        {
            Write-Host "This device does not have an associated object in Intune." -ForegroundColor Red
        }
    }
    else
    {
        # Explicitly return $null if no enrollmentState
        Write-Verbose "[$functionName] Device lookup failed or no enrollment state found"
        return $null
    }
    
    # Return success status for calling functions
    return $success
}

if ($auth.ForceNewToken -or $auth.ForceNewRefreshToken -or $auth.NoSaveRefreshToken)
{
    Write-Host "Forcing new token retrieval due to parameters." -ForegroundColor Yellow
    $accessToken = GetGraphAccessToken @getTokenParams
    if ($accessToken)
    {
        Write-Host "Access token retrieved successfully." -ForegroundColor Green
        Write-Host "The script will now exit."
        Write-Host "You can now run the script again to use the new access token." -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "Failed to retrieve access token." -ForegroundColor Red
        exit 1
    }
}
#endregion helper functions
#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune Helpdesk menu.  What would you like to do?"
$CheckMenu = NewMenu -Title "Check Device Status" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$deviceExportMenu = newMenu -Title "Export Devices" -Description "Choose which devices you want to export."
$settingsMenu = NewMenu -title "Settings menu" -Description "Make changes to the application settings"
$autopilotMenu = NewMenu -Title "Autopilot Menu" -Description "Import a device into Autopilot and perform related actions"

#region export menu
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Autopilot Devices" -Action {
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'autopilot'
    if ($exported)
    {
        Write-Host "Exported Autopilot devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Autopilot devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Imported Autopilot Devices" -Action {
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'imported'
    if ($exported)
    {
        Write-Host "Exported Imported Autopilot devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Imported Autopilot devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Managed Windows Devices" -Action {
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'managed'
    if ($exported)
    {
        Write-Host "Exported Managed devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Managed devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Unmanaged Windows Devices" -Action {
    $accessToken = GetGraphAccessToken @getTokenParams
    $exported, $outputFile = ExportDeviceList -AccessToken $AccessToken -outputPath $PSScriptRoot -deviceType 'unmanaged'
    if ($exported)
    {
        Write-Host "Exported Unmanaged devices to $($outputFile)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export Unmanaged devices." -ForegroundColor Red
    }
}
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export device storage report" -Action {
    $dateTime = Get-Date -Format "yyyyMMdd_HHmm"
    $storageOutputFileName = "DeviceStorageReport-$dateTime.csv"
    $accessToken = GetGraphAccessToken @getTokenParams
    if (ExportDeviceStorage -AccessToken $accessToken -OutputFile $storageOutputFileName -IncludeStorageInfo)
    {
        Write-Host "Exported device storage report to $($storageOutputFileName)." -ForegroundColor Green
    }
    else
    {
        Write-Host "Failed to export device storage report." -ForegroundColor Red
    }
}
#endregion export menu

#region serial number menu
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
    if ($null -ne $serialNumber)
    {
        Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
        Write-Host "Looking up device with serial number: $serialNumber"
        $accessToken = GetGraphAccessToken @getTokenParams
        $callingContext = Get-CallingContext -IncludeNavigationPath
        switch ($callingContext)
        {
            Action-ViaCheckMenu
            {
                Write-Verbose "[$scriptName] Action called via $callingContext"
                Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
                Write-Verbose "[$scriptName] Result returned: $result"
            }
            Action-ViaAutopilotMenu
            {
                Write-Verbose "[$scriptName] Action called via $callingContext"
                Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
                Write-Host "Checking device with serial number $($SerialNumber)..."
                $deviceObject = @{SerialNumber = $serialNumber}
                $result = ProcessDevice -accessToken $accessToken -deviceObject $deviceObject -action 'check'
                Write-Verbose "[$scriptName] Result returned: $result"
            }
        }
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
    }
    else
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    }
}
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number." -Action {
    Write-Verbose "[$scriptName] Getting the serial number for this device..."
    $deviceObject = GetDeviceInfo -NoHash
    Write-Verbose "[$scriptName] Device object: $($deviceObject)"
    if ($deviceObject)
    {
        $serialNumber = $deviceObject.serialNumber
        $make = $deviceObject.manufacturer
        $model = $deviceObject.model
        Write-Host "Looking up local device: $make $model (Serial: $serialNumber)"
        $accessToken = GetGraphAccessToken @getTokenParams
        $context = Get-CallingContext -IncludeNavigationPath
        switch ($context)
        {
            Action-ViaCheckMenu
            {
                Write-Verbose "[$scriptName] Action called via $context"
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
                Write-Verbose "[$scriptName] Result returned: $result"
            }
            Action-ViaAutopilotMenu
            {
                Write-Verbose "[$scriptName] Action called via $context"
                Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
                $result = ProcessDevice -accessToken $accessToken -deviceObject $deviceObject -action 'check' 
                Write-Verbose "[$scriptName] Result returned: $result"
            }
        }
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
        elseif ($result -eq $true -or $result -in $returnValues.Values)
        {
            Write-Host $result
        }
        else
        {
            Write-Host "Failed to fetch information for device with serial number: $serialNumber" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
        Read-Host "Press Enter to continue"
    }
}
#endregion serial number menu

#region Autopilot menu   
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Quick Import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Quick import device into Autopilot."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    $accessToken = GetGraphAccessToken @getTokenParams
    $result = PrepareImportDevice -accessToken $accessToken
    Write-Verbose "[$scriptName] Result of quick import: $result"
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Custom import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Custom import device into Autopilot."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Checking for Windows updates."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    $accessToken = GetGraphAccessToken @getTokenParams
    $result = PrepareImportDevice -accessToken $accessToken -CustomImport
    if ($result -eq $backoutText)
    {
        Write-Verbose "[$scriptName] Custom import aborted. Returning $backoutText."
        return $backoutText
    }
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -name "Get device hash for manual upload to Autopilot (requires admin rights)" -action {
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Getting device object."
        $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    if ($deviceObject)
    {
        Write-Host "Getting device hash for device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
        $outputFile = "\device_$($deviceObject.serialNumber).csv"
        if (GetDeviceHash -Device $deviceObject -OutputFile $outputFile)
        {
            Write-Host 'Device hash created successfully.' -ForegroundColor Green
            Write-Host "The device hash is saved to $outputFile." -ForegroundColor Green
            Write-Host 'You can now upload the device hash to Autopilot.' -ForegroundColor Green
            Write-Host 'Please check the Intune portal for more information.' -ForegroundColor Green
        }
        else
        {
            Write-Host 'Failed to create device hash.' -ForegroundColor Red
        }
    }
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Download and install latest Windows updates(requires admin rights)" -action {
    Write-Verbose "[$scriptName] Download and install latest Windows updates."
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        Write-Verbose "[$scriptName] The script is running with sufficient permissions."
        Write-Verbose "[$scriptName] Checking for Windows updates."
    }
    else
    {
        Write-Host 'The script is not running with sufficient permissions.' -ForegroundColor Red
        Write-Host 'Please exit the script and relaunch as an administrator.' -ForegroundColor Red
        return $null
    }
    Write-Host 'Downloading and installing the latest Windows updates...'
    $updateResult = ApplyWindowsUpdates
    Write-Host $returnValues.$updateResult
}
$autopilotMenu = AddMenuItem -Menu $autopilotMenu -Name "Check device Autopilot status" -Submenu $SerialNumberMenu
$autopilotMenu = AddMenuItem -menu $autopilotMenu -name "Delete device from Autopilot" -action {
    Write-Host 'Deleting the device from Autopilot...'
    $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser -nohash
    if ($deviceObject)
    {
        Write-Host "This will delete the device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model) from Autopilot."
        $choice = Read-Host "Are you sure you want to delete this device? (yes/no)"
        while ($choice -notin @('yes', 'no'))
        {
            Write-Host "Invalid choice. Please enter 'yes' or 'no'."
            #beep
            [console]::beep(1000, 500)
            $choice = Read-Host "Are you sure you want to delete this device? (yes/no)"
        }
        if ($choice -eq 'no')
        {
            Write-Host "Exiting..."
            return $backoutText
        }
        $accessToken = GetGraphAccessToken @getTokenParams
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'delete'
        Write-Verbose "[$scriptName] Device deletion result: $result"
    }
}

#endregion Autopilot menu

#region Settings menu
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change application settings" -Action {
    Write-Host 'Reconfiguring the script...'
    if (CreateFullConfiguration -DestinationFolder $pwd -RootFolder $pwd)
    {
        Write-Host 'The script has been reconfigured.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to reconfigure the script.' -ForegroundColor Red
    }
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Change application credentials" -Action {
    $AppId = Read-Host "Enter the application ID"
    $AppSecret = Read-Host "Enter the application secret"
    $TenantId = Read-Host "Enter the tenant ID"
    $appDomain = Read-Host "Enter the application domain"
    $appName = Read-Host "Enter the application name"
    $AppId = $AppId.Trim()
    $AppSecret = $AppSecret.Trim()
    $TenantId = $TenantId.Trim()
    $appDomain = $appDomain.Trim()
    $appName = $appName.Trim()
    $configObject = [PSCustomObject]@{
        AppId     = $AppId
        AppSecret = $AppSecret
        TenantId  = $TenantId
        domain    = $appDomain
        name      = $appName
    }
    $encryptedConfigObject = EncryptObject -decryptedObject $configObject -excludeFields @('name', 'domain')
    $json = $encryptedConfigObject | ConvertTo-Json -Depth 10
    Write-Host "Saving configuration to $configFile"
    Set-Content -Path $configFile -Value $json -Force
    Write-Host 'The application credentials have been changed.' -ForegroundColor Green
}
$settingsMenu = AddMenuItem -menu $settingsMenu -Name "Restore defaults" -Action {
    Write-Host 'Restoring the script to its default settings...'
    if (InitializeConfiguration -RootFolder $pwd -overWrite)
    {
        Write-Host 'The script defaults have been restored.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'Failed to restore script defaults..' -ForegroundColor Red
    }
}
#endregion Settings menu

$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by Serial Number" -Submenu $serialNumberMenu
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by User" -Action {
    $userName = GetUserInput -Message "Enter the username (email address) of the user whose device you want to look up." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    if ($null -eq $userName)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    }
    Write-Verbose "[$scriptName] Got user name: $userName"
    $accessToken = GetGraphAccessToken @getTokenParams
    
    #region Check if the user exists first.
    $userInfo = GetEntraUser -UserName $userName -AccessToken $accessToken -findSimilar
    Write-Verbose "[$scriptName] Substring search: $($userInfo)"
    Write-Verbose "[$scriptName] User info returned: $($userInfo[0].value.count) users."
    Write-Verbose "[$scriptName] User info: $($userInfo | ConvertTo-Json -Depth 10)"
    if ($null -ne $userInfo -and $userInfo[1] -eq $false)
    {
        Write-Host "Found user: $($userInfo[0].value.displayName) ($($userInfo[0].value.userPrincipalName))"
        $userName = $userInfo[0].value.userPrincipalName
        Write-Verbose "[$scriptName] User name set to: $userName"
    }
    elseif ($null -ne $userInfo -and $userInfo[1] -eq $true)
    {
        Write-Host "Could not find an exact match for user $($userName)."
        if ($userInfo[0].value.count -eq 1)
        {
            Write-Host "Found a user with a similar name."
        }
        else
        {
            Write-Host "Found $($($userInfo[0].value.count)) users with similar names:"
        }
        if ($($userInfo[0].value.count) -gt [int]$settings.maxUserMatchDisplay)
        {
            Write-Host "Displaying the first $($settings.maxUserMatchDisplay) matches:"
        }
        elseif ($($userInfo[0].value.count) -eq 1)
        {
            Write-Host "Is this the correct user?"
        }
        else
        {
            Write-Host "Displaying all $($userInfo[0].value.count) matches:"
        }
        $possibleUserName = DisplayUserList -UserList $userInfo[0].value -maxDisplay $settings.maxUserMatchDisplay
        Write-Verbose "[$scriptName] User name selected: $possibleUserName"
        # Handle navigation options returned from DisplayUserList
        if ($null -eq $possibleUserName)
        {
            Write-Verbose "[$scriptName] DisplayUserList returned null (exit signal)."
            return "EXIT_APPLICATION"
        }
        elseif ($possibleUserName -eq "Back" -or $possibleUserName -eq "back")
        {
            Write-Verbose "[$scriptName] User selected 'Back'. Returning $backoutText."
            return $backoutText
        }
        elseif ($possibleUserName -eq "Main Menu" -or $possibleUserName -eq "main menu")
        {
            Write-Verbose "[$scriptName] User selected 'Main Menu'. Returning to main menu."
            return "Main Menu"
        }
        elseif ($possibleUserName -eq 0 -or $possibleUserName -eq "0")
        {
            Write-Verbose "[$scriptName] User selected exit (0). Exiting application."
            return "EXIT_APPLICATION"
        }
        else
        {
            Write-Verbose "[$scriptName] User selected: $possibleUserName"
            $userName = $possibleUserName
        }
    }
    elseif ($userInfo -eq $returnValues.noUserFoundInDirectoryMessage)
    {
        return $userInfo
    }
    else
    {
        return $returnValues.noUserFoundInDirectoryMessage
    }
    #endregion Check if the user exists first.
    
    #Print the current navigation context prior too calling GetDeviceByUser
    Write-Verbose "[$scriptName] Current navigation context:"
    Write-Verbose "[$scriptName] Action History: $($actionHistory -join ' > ')"
    Write-Verbose "[$scriptName] Menu History: $($actionMenuHistory -join ' > ')"
    # Call GetDeviceByUser to find devices for the specified user
    Write-Verbose "[$scriptName] Calling GetDeviceByUser for user: $userName"
    $serialNumber = GetDeviceByUser -UserName $userName -OperatingSystem 'Windows' -AccessToken $accessToken
    Write-Verbose "[$scriptName] GetDeviceByUser returned: $serialNumber"
    # Handle navigation responses from GetDeviceByUser
    if ($serialNumber -eq "Back" -or $serialNumber -eq "back")
    {
        Write-Verbose "[$scriptName] User selected Back from device selection, returning to previous menu"
        return $backoutText
    }
    elseif ($serialNumber -eq "Main Menu" -or $serialNumber -eq "main menu")
    {
        Write-Verbose "[$scriptName] User selected Main Menu from device selection"
        return "EXIT_APPLICATION"
    }
    elseif ([string]::IsNullOrWhiteSpace($SerialNumber) -or $null -eq $serialNumber)
    {
        Write-Verbose "[$scriptName] User requested application exit from device selection."
        return "EXIT_APPLICATION"
    }        
    elseif ($serialNumber -ne '0' -and $null -ne $serialNumber -and $serialNumber -ne "Back" -and $serialNumber -ne "Main Menu" -and $serialNumber -notin $returnValues.Values)
    {
        Write-Host "Found device for user $userName with serial number: $serialNumber"
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        Write-Verbose "[$scriptName] ProcessSerialNumber returned: $result"
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
        elseif ($result -eq $true)
        {
            Write-Host "Device information for device with serial number: $serialNumber was retrieved successfully." -ForegroundColor Green
        }
        else
        {
            Write-Host "Failed to fetch information for device with serial number: $serialNumber" -ForegroundColor Red
        }
    }
    elseif ($serialNumber -eq '0')
    {
        Write-Verbose "[$scriptName] User selected Exit option (0). Returning $BackoutText."
        return $backoutText
    }
    else
    {
        Write-Host $serialNumber -ForegroundColor Red
    }
}

$mainMenu = AddMenuItem -Menu $mainMenu -Name "Give a device to a user" -Action {
    $username = GetUserInput -Message "Enter the username (email address) of the user receiving the device." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    # Check if user entered 'back'
    if ($null -eq $username)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText # Return to the previous menu
    } 
    else # Continue only if a username was entered
    {
        $hasCorrectGroups = $false
        $hasCorrectNumberOfDevices = $false
        
        Write-Verbose "[$scriptName] Getting access token..."
        $accessToken = GetGraphAccessToken @getTokenParams
        
        #region Check if the user exists first.
        $userInfo = GetEntraUser -UserName $userName -AccessToken $accessToken -findSimilar
        Write-Verbose "[$scriptName] Substring search: $($userInfo)"
        Write-Verbose "[$scriptName] User info returned: $($userInfo[0].value.count) users."
        Write-Verbose "[$scriptName] User info: $($userInfo | ConvertTo-Json -Depth 10)"
        if ($null -ne $userInfo -and $userInfo[1] -eq $false)
        {
            Write-Host "Found user: $($userInfo[0].value.displayName) ($($userInfo[0].value.userPrincipalName))"
            $userName = $userInfo[0].value.userPrincipalName
            Write-Verbose "[$scriptName] User name set to: $userName"
        }
        elseif ($null -ne $userInfo -and $userInfo[1] -eq $true)
        {
            Write-Host "Could not find an exact match for user $($userName)."
            if ($userInfo[0].value.count -eq 1)
            {
                Write-Host "Found a user with a similar name."
            }
            else
            {
                Write-Host "Found $($($userInfo[0].value.count)) users with similar names:"
            }
            if ($($userInfo[0].value.count) -gt [int]$settings.maxUserMatchDisplay)
            {
                Write-Host "Displaying the first $($settings.maxUserMatchDisplay) matches:"
            }
            elseif ($($userInfo[0].value.count) -eq 1)
            {
                Write-Host "Is this the correct user?"
            }
            else
            {
                Write-Host "Displaying all $($userInfo[0].value.count) matches:"
            }
            $possibleUserName = DisplayUserList -UserList $userInfo[0].value -maxDisplay $settings.maxUserMatchDisplay
            Write-Verbose "[$scriptName] User name selected: $possibleUserName"
            # Handle navigation options returned from DisplayUserList
            if ($null -eq $possibleUserName)
            {
                Write-Verbose "[$scriptName] DisplayUserList returned null (exit signal)."
                return "EXIT_APPLICATION"
            }
            elseif ($possibleUserName -eq "Back" -or $possibleUserName -eq "back")
            {
                Write-Verbose "[$scriptName] User selected 'Back'. Returning $backoutText."
                return $backoutText
            }
            elseif ($possibleUserName -eq "Main Menu" -or $possibleUserName -eq "main menu")
            {
                Write-Verbose "[$scriptName] User selected 'Main Menu'. Returning to main menu."
                return "Main Menu"
            }
            elseif ($possibleUserName -eq 0 -or $possibleUserName -eq "0")
            {
                Write-Verbose "[$scriptName] User selected exit (0). Exiting application."
                return "EXIT_APPLICATION"
            }
            else
            {
                Write-Verbose "[$scriptName] User selected: $possibleUserName"
                $userName = $possibleUserName
            }
        }
        elseif ($userInfo -eq $returnValues.noUserFoundInDirectoryMessage)
        {
            return $userInfo
        }
        else
        {
            return $returnValues.noUserFoundInDirectoryMessage
        }
        #endregion Check if the user exists first.
        Write-Host "Checking group membership for user $userName."
        $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
        if ($groups.success -eq $true)
        {
            Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
            Write-Host "The user is a member of all $($groupsToInclude.Count) required groups and is not a member of any of the $($groupsToExclude.Count) forbidden groups."
            $hasCorrectGroups = $true
        }
        elseif ($selectedItem.Submenu)
        {
            Write-Verbose "[$scriptName] The function returned $($groups.MissingGroups.Count) missing group membershipss and $($groups.ForbiddenGroups.Count) forbidden group membershipss."
            Write-Verbose "[$scriptName] Missing group memberships: $($groups.missingGroups | Out-String)"
            Write-Verbose "[$scriptName] Forbidden groups: $($groups.ForbiddenGroups | Out-String)"
            if ($groups.missingGroups.Count -gt 0)
            {
                Write-Host 'The user needs to be added to the following groups:' -ForegroundColor Red
                foreach ($group in $groups.missingGroups)
                {
                    Write-Host $group -ForegroundColor Red
                }
            }
            if ($groups.ForbiddenGroups.Count -gt 0)
            {
                Write-Host 'The user needs to be removed from the following groups:' -ForegroundColor Red
                foreach ($group in $groups.invalidExcludeGroups)
                {
                    Write-Host $group -ForegroundColor Red
                }
            }
            Write-Host 'Please contact an Intune administrator.' -ForegroundColor Red
        }
        Write-Host "`nChecking if the user $userName has exceeded the number of allowed devices." -ForegroundColor Cyan
        $totalDevices = GetTotalRegisteredDevicesByUser -Username $userName -AccessToken $accessToken 
        if ($totalDevices -lt $settings.maxNumberOfDevicesAllowed)
        {
            Write-Host "User $userName has $totalDevices devices, which is below the $($settings.maxNumberOfDevicesAllowed) allowed device limit." -ForegroundColor Green
            $hasCorrectNumberOfDevices = $true
        }
        else
        {
            Write-Host "User $userName has $totalDevices devices, which is equal to or above the $($settings.maxNumberOfDevicesAllowed) allowed device limit."
            Write-Host "No additional devices can be assigned to this user."
        }        
        if ($hasCorrectGroups -and $hasCorrectNumberOfDevices)
        {
            Write-Host "The user $userName is ready to receive a device." -ForegroundColor Green
            Write-Host "We will now check the device state." -ForegroundColor Green
            Write-Host "Enter the device's serial number."
            Write-Host "This would be the device you plan to give to the user."
            $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
            # Check if user entered 'back'
            if ($null -eq $serialNumber)
            {
                Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
                return $backoutText # Return to the previous menu
            }
            else # Process only if a serial number was entered
            {
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -CheckUserReadiness
                # Check if ProcessSerialNumber returned an exit signal
                if ($null -eq $result)
                {
                    Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
                    return "EXIT_APPLICATION"
                }
            }
        }
        else
        {
            Write-Host "The user $userName is not ready to receive a Windows 11 device." -ForegroundColor Red
        }
    }
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Check device status " -Submenu $CheckMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Autopilot menu" -Submenu $autopilotMenu
# $mainMenu = AddMenuItem -menu $mainMenu -Name "Change application settings" -Submenu $settingsMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Check for script updates" -Action {
    Write-Host "Checking for script updates..."
    $updateResult = GetUpdates -RootFolder $pwd -remoteVersionURL $remoteVersionURL -updateURL $updateURL -returnValues $returnValues
    Write-Verbose "[$scriptName] Update result: $updateResult"
    switch ($updateResult)
    {
        $returnValues.UpdateSuccessMessage
        {
            Write-Host 'The script has been updated.' -ForegroundColor Green
            Write-Host 'Please restart the script.' -ForegroundColor Green
            exit 0
        }
        $returnValues.UpdateFailedMessage
        {
            Write-Host 'The script update failed.' -ForegroundColor Red
        }
        $returnValues.UpdateNotNeededMessage
        {
            Write-Host 'The script is up to date.' -ForegroundColor Green
        }
        default
        {
            Write-Host 'An unknown error occurred while checking for updates.' -ForegroundColor Red
        }
    }
}
$mainMenu = AddMenuItem -menu $mainMenu -name "Restart the device" -action {
    Write-Host 'Restarting the device...'
    if (-not (RestartDevice))
    {
        Write-Verbose "[$scriptName] RestartDevice function failed."
        return $backoutText
    }
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Export devices" -Submenu $deviceExportMenu
#endregion Menu Definitions

#region Show Menu
# Add the main menu to both history arrays for proper stack synchronization
try
{
    Write-Verbose "[$scriptName] Adding main menu to both history arrays using newer powershell functions."
    [void]$global:History.Add("Main Menu")
    [void]$global:MenuHistory.Add($mainMenu)
}
catch
{
    # Fallback for older PowerShell versions
    Write-Verbose "[$scriptName] Adding main menu to both history arrays using older powershell functions."
    $global:MainMenuHistory += "Main Menu"
    $global:MainMenuHistory_Menu += $mainMenu
}

# Only show menu if not in test mode
if ($settings.testMode -eq $false)
{
    Write-Verbose "Test mode: $($settings.testMode)" 
    $result = ShowMenu -Menu $mainMenu
    if ($null -eq $result)
    {
        Write-Host "`nThank you for using the Intune Helpdesk menu. Goodbye!" -ForegroundColor Green
    }
}
else
{
    Write-Host "Test mode: $($settings.testMode). No menu will be shown." -ForegroundColor Yellow
    Write-Host "You can run the script in test mode to validate functionality without showing the menu."
}
#endregion Show Menu
