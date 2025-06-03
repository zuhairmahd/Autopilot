[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\settings.json",
    [int]$maxWaitTime = 60,
    [int]$timeInSeconds = 30,
    [string]$Configuration = 'vars.json',
    [String] $GroupTag = 'MSB01',
    [String] $AssignedUser = '',
    [switch]$Reconfigure,
    [switch]$ReInitialize,
    [switch]$showAdvancedOptions,
    [switch]$Update,
    [string]$Repo = 'github',
    [string]$Release = 'main'
)

#region Load parameters from the configuration file if it exists
$scriptName = $MyInvocation.MyCommand.Name
if (Test-Path -Path $InitFile)
{
    Write-Host " Loading configuration values from $(Split-Path -Path $initFile -Leaf)"
    $configData = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json | Select-Object -ExpandProperty 'vars'
    Write-Verbose "[$scriptName] Found $($configData.PSObject.Properties.Name.count) configurations."
    foreach ($key in $configData.PSObject.Properties.Name)
    {
        Write-Verbose "[$scriptName] Checking if $($key) was provided on the command line."
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $configData.$key)
        {
            Write-Verbose "[$scriptName] Read parameter $key from the configuration file as $($configData.$key)"
            Write-Verbose "[$scriptName] Setting $key to $($configData.$key)"
            if ($configData.$key -in ('true', 'false'))
            {
                Write-Verbose "[$scriptName] Converting $key to boolean."
                $keyBooleanValue = [bool]::Parse($configData.$key)
                Write-Verbose "[$scriptName] Setting the value of $key to the boolean value ($keybooleanValue)."
                Set-Variable -Name $key -Value $keyBooleanValue
            }
            else
            {
                Write-Verbose "[$scriptName] Setting the value of $key to the string value ($($configData.$key))."
                Set-Variable -Name $key -Value $configData.$key
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Read parameter $key from the commandline as $($PSBoundParameters[$key])"
        }
    }
}
else
{
    Write-Host "Configuration file $Configuration not found. Using default values."
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
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
Write-Verbose "[$scriptName] Domain: $domain"
$init = Get-Content -Path $initFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json 
Write-Verbose "[$scriptName] Init: $($init | Out-String)"
$groupsToInclude = $init.domains.$domain.groupsToInclude
Write-Verbose "[$scriptName] Groups to include: $($groupsToInclude | Out-String)"
$groupsToExclude = $init.domains.$domain.groupsToExclude
Write-Verbose "[$scriptName] Groups to exclude: $($groupsToExclude | Out-String)"
$domainSettings = $init.domains.$domain.settings
Write-Verbose "[$scriptName] Domain settings: $($domainSettings | Out-String)"
$globalSettings = $init.globalSettings
Write-Verbose "[$scriptName] Global settings: $($globalSettings | Out-String)"
$settings = MergeSettings -settings $domainSettings -globalSettings $globalSettings
Write-Verbose "[$scriptName] Settings: $($settings | Out-String)"
$backoutText = 'Returning to previous menu'
# $scopes = "offline_access Device.ReadWrite.All DeviceManagementApps.Read.All DeviceManagementConfiguration.ReadWrite.All DeviceManagementManagedDevices.PrivilegedOperations.All DeviceManagementManagedDevices.ReadWrite.All DeviceManagementServiceConfig.ReadWrite.All"
$application = 'Register'
Write-Verbose "[$scriptName] Application: $application"
$updateURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease"
Write-Verbose "[$scriptName] Update URL: $updateURL"
$version = '3.0.0'
Write-Verbose "[$scriptName] Version: $version"
$versionFile = 'version.txt'
Write-Verbose "[$scriptName] Version file: $versionFile"
$remoteVersionURL = "$baseSourceURL/$repoPath/$repoName/$latestRelease/version.txt"
Write-Verbose "[$scriptName] Remote version URL: $remoteVersionURL"
$returnValues = [ordered] @{
    EnrolledMessage         = 'The device is enrolled.'
    notContactedMessage     = 'The device has not contacted the enrollment service.'
    PendingResetMessage     = 'The device is pending a reset.'
    EnrollmentFailedMessage = 'The device enrollment failed.'
    UnassignedMessage       = 'The device is not assigned to a deployment profile.'
    PendingMessage          = 'The device is pending assignment to a deployment profile.'
    notInIntuneMessage      = 'The device is not in Intune.'
    ImportSuccessMessage    = 'The device was imported successfully.'
    ImportFailedMessage     = 'The device import failed.'
    DeleteSuccessMessage    = 'The device was deleted successfully.'
    DeleteFailedMessage     = 'The device deletion failed.'
    UpdateFailedMessage     = 'Could not download update.'
    UpdateSuccessMessage    = 'The script was updated successfully.'
    UpdateNotNeededMessage  = 'The script is already up to date.'
}
if ($domain -eq 'arabictutor.com')
{
    Write-Verbose "[$scriptName] Changing groupTag to 'entra'."
    $GroupTag = 'entra'
}
if (Test-Path -Path $versionFile)
{
    Write-Verbose "[$scriptName] Version file $versionFile found. Reading version."
    $localVersion = Get-Content -Path $versionFile -Raw -ErrorAction Stop
    Write-Verbose "[$scriptName] Local version: $localVersion"
    $localVersionObject = [System.Version]::Parse($LocalVersion)
    Write-Verbose "[$scriptName] Local version object: $localVersionObject"
    $versionVariableObject = [System.Version]::Parse($version)
    Write-Verbose "[$scriptName] Version object: $versionVariableObject"
    if ($versionVariableObject -le $localVersionObject)
    {
        Write-Verbose "[$scriptName] Version file $versionFile is up to date."
    }
    else
    {
        Write-Verbose "[$scriptName] Version file $versionFile is not up to date. Updating version file."
        Set-Content -Path $versionFile -Value $version -Force
        $localVersion = $version
    }
}
else
{
    Write-Verbose "[$scriptName] Version file $versionFile not found. Creating version file."
    Set-Content -Path $versionFile -Value $version -Force
    $localVersion = $version
}
# Initialize navigation context variables
$script:History = New-Object System.Collections.ArrayList
$script:MenuHistory = New-Object System.Collections.ArrayList
$script:previousMenu = New-Object System.Collections.Hashtable
$script:depth = 0
# Device enrollment state cache (serialNumber -> enrollmentState)
$script:DeviceEnrollmentCache = @{}
#endregion Define variables

#region logging
Write-Verbose "[$scriptName] Received the following parameters: $($PSBoundParameters | ConvertTo-Json)"
Write-Verbose "[$scriptName] The current parameter set is $($PSCmdlet.ParameterSetName)"
Write-Verbose "[$scriptName] Configuration file: $configFile"
Write-Verbose "[$scriptName] Initial values file: $initialValues"
Write-Verbose "[$scriptName] Computer name: $Name"
Write-Verbose "[$scriptName] Group tag: $GroupTag"
Write-Verbose "[$scriptName] Assigned user: $AssignedUser"
Write-Verbose "[$scriptName] Reconfigure: $Reconfigure"
Write-Verbose "[$scriptName] Repository: $Repo"
Write-Verbose "[$scriptName] Release: $Release"
Write-Verbose "[$scriptName] Domain: $domain"
Write-Verbose "[$scriptName] Application name: $application"
Write-Verbose "[$scriptName] Functions folder: $functionsFolder"
Write-Verbose "[$scriptName] Base source URL: $baseSourceURL"
Write-Verbose "[$scriptName] Backout text: $backoutText"
#endregion logging

#region Helper Functions
function GetCachedDeviceEnrollmentState()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        $Settings = $settings
    )
    $functionName = $MyInvocation.MyCommand.Name
    if ($script:DeviceEnrollmentCache.ContainsKey($SerialNumber) -eq $false)
    {
        Write-Verbose "[$functionName] Cache miss for serial number: $SerialNumber. Fetching from API."
        $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken -Settings $Settings
        if ($enrollmentState)
        {
            $script:DeviceEnrollmentCache[$SerialNumber] = $enrollmentState
            Write-Verbose "[$functionName] Cached enrollment state for serial number: $SerialNumber."
        }
        else
        {
            Write-Verbose "[$functionName] No enrollment state found for serial number: $SerialNumber. Not caching."
        }
        return $enrollmentState
    }
    else
    {
        Write-Verbose "[$functionName] Cache hit for serial number: $SerialNumber. Returning cached enrollment state."
        Write-Host "Using cached enrollment state for serial number: $SerialNumber" -ForegroundColor Cyan
        return $script:DeviceEnrollmentCache[$SerialNumber]
    }
}

function NormalizeUserName()
{
    [CmdletBinding()]
    param (
        [string]$UserName,
        $Settings = $settings # Use the script-level $settings by default
    )
    $functionName = $MyInvocation.MyCommand.Name
    $domain = $settings.domain
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] UserName: $UserName"
    Write-Verbose "[$functionName] Normalizing user name: $UserName"
    $UserName = $UserName.Trim()
    Write-Verbose "[$functionName] Checking if the user name $username is missing the $domain suffix."
    if ($userName -notmatch "@$domain$")
    {
        Write-Verbose "[$functionName] the user name $username is missing the $domain suffix."
        $UserName = "$UserName@$domain"
        Write-Verbose "[$functionName] The user name is now $userName"
    }
    else
    {
        Write-Verbose "[$functionName] The user name is already in the correct format: $UserName"
    }
    Write-Verbose "[$functionName] Final user name: $UserName"
    Write-Verbose "[$functionName] Returning user name: $UserName"
    return $UserName
}

function validateInput()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput,
        [parameter(Mandatory = $true)]
        [string]$type,
        $settings = $settings # Use the script-level $settings by default
    )
    $functionName = $MyInvocation.MyCommand.Name
    $domain = $settings.domain
    $MaxUserNameLength = $settings.MaxUserNameLength
    $MaxSerialNumberLength = $settings.MaxSerialNumberLength
    $MinSerialNumberLength = $settings.MinSerialNumberLength
    $minUsernameLength = $settings.MinUsernameLength
    $returnValue = @{ valid = $false; value = $null } # Initialize return hash table
    Write-Verbose "[$functionName] Validating input of type '$type': '$UserInput'"
    Write-Verbose "[$functionName] Domain: $domain"
    Write-Verbose "[$functionName] MaxUserNameLength: $MaxUserNameLength"
    Write-Verbose "[$functionName] MinUserNameLength: $minUsernameLength"
    Write-Verbose "[$functionName] MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "[$functionName] MinSerialNumberLength: $MinSerialNumberLength"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    Write-Verbose "[$functionName] Trimmed input: '$UserInput'"
    switch ($type)
    {
        'serialNumber'
        {
            Write-Verbose "[$functionName] Checking serial number length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number exceeds maximum length of $MaxSerialNumberLength characters"
                Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput.Length -lt $MinSerialNumberLength)
            {
                Write-Verbose "[$functionName] Serial number is shorter than minimum length of $MinSerialNumberLength characters"
                Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
                return $returnValue
            }
            elseif ($UserInput -match '^[a-zA-Z0-9-\s]+$') 
            {
                Write-Verbose "[$functionName] Serial number validation passed"
                $returnValue.value = $UserInput
                $returnValue.valid = $true
                return $returnValue
            }
            else
            {
                Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
                return $returnValue
            }
        }
        'userName'
        {
            Write-Verbose "[$functionName] Checking user name length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxUserNameLength -or $UserInput.Length -lt $minUsernameLength -or $UserInput -match '^\d' -and $null -ne $UserInput)
            {
                Write-Verbose "[$functionName] Username exceeds maximum length of $MaxUserNameLength characters"
                Write-Host "Username needs to have a minimum of $minUsernameLength characters and cannot exceed $MaxUserNameLength characters." -ForegroundColor Red
                Write-Host "The username cannot start with a digit." -ForegroundColor Red
                return $returnValue
            }
            else
            {
                $normalizedUserInput = NormalizeUserName -UserName $UserInput -Settings $settings
                # Basic email format check
                if ($normalizedUserInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                {
                    Write-Verbose "[$functionName] Username validation passed"
                    $returnValue.valid = $true
                    $returnValue.value = $normalizedUserInput
                }
                else
                {
                    Write-Verbose "[$functionName] Username validation failed - must be a valid email format (e.g., user@$domain)"
                    Write-Host "Invalid user name format. Please enter a valid email address (e.g., user@$domain)." -ForegroundColor Red
                    return $returnValue
                }
            }
        }
        default
        {
            Write-Verbose "[$functionName] Unknown validation type: '$type'"
            Write-Host "Unknown validation type: '$type'" -ForegroundColor Red
            return $returnValue
        }
    }
    Write-Verbose "[$functionName] Returning validation result: $($returnValue.valid)"
    Write-Verbose "[$functionName] Returning validation value: $($returnValue.value)"
    return $returnValue
}

function GetUserInput()
{
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt,
        [validateSet('userName', 'serialNumber')]
        [string]$InputType,
        $settings = $settings # Use the script-level $settings by default
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Message: $Message"
    Write-Verbose "[$functionName] Prompt: $Prompt"
    Write-Verbose "[$functionName] InputType: $InputType"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 

    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity

        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $BackoutText."
            return $null # Return null to signal going back
        }

        # Validate the input if it's not empty
        $validationResult = validateInput -UserInput $inputItem -type $InputType -settings $settings
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value

        if ($inputResultValid)
        {
            Write-Verbose "[$functionName] Valid $inputType entered: $inputResultValid"
            Write-Verbose "[$functionName] Input result: $inputResult"
            return $inputResult # Return the validated input
        }
        else
        {
            # Beep and show error if validation failed
            [console]::beep(1000, 500)
            # Updated error message
            Write-Host "Invalid $inputType. Please try again or press Enter to return." -ForegroundColor Red 
            # The loop will continue, prompting the user again
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
        $Settings = $settings
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
        if ($enrollmentState.Imported)
        {
            Write-Verbose "[$scriptName] Imported in Autopilot: $($enrollmentState.inAutopilot)"
            Write-Verbose "[$scriptName] Imported count: $($enrollmentState.ImportedAutopilotDevice.Count)"
            if ($enrollmentState.ImportedAutopilotDevice.Count -gt 1)
            {
                Write-Host "This device was imported into Autopilot $($enrollmentState.ImportedAutopilotDevice.Count) times." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice[$enrollmentState.ImportedAutopilotDevice.Count - 1]
            }
            else
            {
                Write-Host "This device was recently imported into Autopilot." -ForegroundColor Green
                $importedDeviceInfo = $enrollmentState.ImportedAutopilotDevice
            }
            if (!$enrollmentState.managed)
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
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'sync' -MonitorAction
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Restart Device" -Action {
                Write-Host "`nRestarting device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
                SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'restart' | Out-Null
            }
            $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Show Device Health Status" -Action {
                ShowDeviceReport -enrollmentState $enrollmentState -SerialNumber $serialNumber 
            }
            # Show the device actions menu with navigation context
            Write-Verbose "[$functionName] Showing device actions menu with Depth: $depth, History count: $($History.Count), MenuHistory count: $($MenuHistory.Count)"
            $result = ShowMenu -Menu $deviceActionsMenu
            Write-Verbose "Returning from device actions menu with result: $result"
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
#endregion Helper Functions

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune Helpdesk menu.  What would you like to do?"
$CheckMenu = NewMenu -Title "Check Device Status" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$deviceExportMenu = newMenu -Title "Export Devices" -Description "Choose which devices you want to export."
$settingsMenu = NewMenu -title "Settings menu" -Description "Make changes to the application settings"
$autopilotMenu = NewMenu -Title "Autopilot Menu" -Description "Import a device into Autopilot and perform related actions"
$autopilotSerialNumberMenu = newMenu -Title "Check device registration" -Description "How would you like to enter the serial number?."

#region export menu
$deviceExportMenu = AddMenuItem -menu $deviceExportMenu -name "Export Autopilot Devices" -Action {
    $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
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
    $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
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
    $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
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
    $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
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
    $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
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
    if ($null -eq $serialNumber)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    }
    else
    {
        Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
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
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        Write-Verbose "Result returned: $result"
        # Check if ProcessSerialNumber returned an exit signal
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
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
        Read-Host "Press Enter to continue"
    }
}
#endregion serial number menu

$autopilotSerialNumberMenu = AddMenuItem -Menu $autopilotSerialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers and is no more than 10 digits long.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number'
    # Check if user entered 'back'
    if ($null -eq $serialNumber)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    } 
    else # Process only if a serial number was entered
    {
        Write-Verbose "[$scriptName] Got serial number: $SerialNumber"
        Write-Host "Checking device with serial number $($SerialNumber)..."
        $deviceObject = @{SerialNumber = $serialNumber}
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        $result = ProcessDevice -accessToken $accessToken -deviceObject $deviceObject -action 'check'
    }
}
$autopilotSerialNumberMenu = AddMenuItem -Menu $autopilotSerialNumberMenu -Name "Use this device's serial number." -Action {
    Write-Verbose "[$scriptName] Getting the serial number for this device..."
    $deviceObject = getDeviceInfo -name 'localhost' -groupTag $GroupTag -assignedUser $AssignedUser -NoHash
    Write-Verbose "[$scriptName] Device object: $($deviceObject)"
    if ($deviceObject)
    {
        Write-Host "Checking device with serial number $($deviceObject.serialNumber): $($deviceObject.manufacturer) $($deviceObject.make) $($deviceObject.model)."
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'check'
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
    }
}

#region Autopilot menu   
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Quick Import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Quick import device into Autopilot."
    $result = PrepareImportDevice
}
$autopilotMenu = AddMenuItem -menu $autopilotMenu -Name "Custom import device into Autopilot (requires admin rights)" -Action {
    Write-Verbose "[$scriptName] Custom import device into Autopilot."
    $result = PrepareImportDevice -CustomImport
    if ($result -eq $backoutText)
    {
        Write-Verbose "[$scriptName] Custom import aborted. Returning $backoutText."
        return $backoutText
    }
}
$autopilotMenu = AddMenuItem -Menu $autopilotMenu -Name "Check device Autopilot status" -Submenu $serialNumberMenu
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
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        $result = ProcessDevice -accessToken $accessToken -DeviceObject $deviceObject -action 'delete'
        Write-Verbose "[$scriptName] Device deletion result: $result"
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
#endregion Autopilot menu

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
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by Serial Number" -Submenu $serialNumberMenu
$CheckMenu = AddMenuItem -Menu $CheckMenu -Name "Lookup device by User" -Action {
    $userName = GetUserInput -Message "Enter the username (email address) of the user whose device you want to look up." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    if ($null -eq $userName)
    {
        Write-Verbose "[$scriptName] User pressed Enter. Returning $BackoutText."
        return $backoutText
    }
    else
    {
        Write-Verbose "[$scriptName] Got user name: $userName"
        $accessToken = GetGraphAccessToken -ConfigFile $configFile 
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
        elseif ($serialNumber -ne '0' -and $null -ne $serialNumber -and $serialNumber -ne "Back" -and $serialNumber -ne "Main Menu")
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
            Write-Host "No device found for user $userName." -ForegroundColor Red
            Read-Host "Press Enter to continue"
        }
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
        Write-Host "Checking group membership for user $userName."
        Write-Verbose "[$scriptName] Getting access token..."
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
        if ($groups.success -eq $true)
        {
            Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
            Write-Host "The user is a member of all $($groupsToInclude.Count) required groups and is not a member of any of the $($groupsToExclude.Count) forbidden groups."
            $hasCorrectGroups = $true
        }
        else
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
                # Pass navigation context to ProcessSerialNumber
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
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
$mainMenu = AddMenuItem -menu $mainMenu -Name "Change application settings" -Submenu $settingsMenu
$mainMenu = AddMenuItem -menu $mainMenu -Name "Check for script updates" -Action {
    Write-Host "Checking for script updates..."
    $updateResult = GetUpdates -RootFolder $pwd -LocalVersion $localVersion -remoteVersionURL $remoteVersionURL -updateURL $updateURL -returnValues $returnValues -verbose
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
# Add the main menu title to the title history (for breadcrumb display) and menu object to menu history (for navigation)
try
{
    # [void]$script:History.Add("Main Menu")
    [void]$script:MenuHistory.Add($mainMenu)
}
catch
{
    # Fallback for older PowerShell versions
    $script:MainMenuHistory += "Main Menu"
    $script:MainMenuHistory_Menu += $mainMenu
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
