[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\initVerify.json"
)

$scriptName = $MyInvocation.MyCommand.Name
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
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
Write-Verbose "[$scriptName] Domain: $domain"
$init = (Get-Content -Path $InitFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domains).$domain
Write-Verbose "[$scriptName] Init: $($init | Out-String)"
$groupsToInclude = $init.groupsToInclude
Write-Verbose "[$scriptName] Groups to include: $($groupsToInclude | Out-String)"
$groupsToExclude = $init.groupsToExclude
Write-Verbose "[$scriptName] Groups to exclude: $($groupsToExclude | Out-String)"
$settings = $init.settings
Write-Verbose "[$scriptName] Settings: $($settings | Out-String)"
$backoutText = 'Returning to previous menu'
#endregion Define variables

#region Helper Functions (Consolidated and Corrected)
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
                return $returnValue
                $returnValue.value = $UserInput
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

function DisplayDeviceHealth()
{
    [CmdletBinding()]
    param (
        [string]$SerialNumber,
        [string]$AccessToken
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Host "`nRetrieving comprehensive device health information..." -ForegroundColor Yellow
    
    # First check if device is managed by Intune (regardless of Autopilot status)
    $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken
    
    # Also check Autopilot assignment for additional details
    $deviceAssignment = CheckDeviceAssignment -serialNumber $SerialNumber -AccessToken $AccessToken
    
    if ($enrollmentState.managed)
    {
        Write-Verbose "[$functionName] Device is managed by Intune."
        Write-Verbose "[$functionName] Device enrollment state: $($enrollmentState.managedDevice.enrollmentState)"
        Write-Host "`n=== Device Health & Status Report ===" -ForegroundColor Cyan
        Write-Host "Serial Number: $SerialNumber"
        
        # Display managed device information
        Write-Host "`n--- Managed Device Details ---" -ForegroundColor Green
        Write-Host "Device Name: $($enrollmentState.managedDevice.device.deviceName)"
        Write-Host "Model: $($enrollmentState.managedDevice.device.model)"
        Write-Host "Manufacturer: $($enrollmentState.managedDevice.device.manufacturer)"
        Write-Host "OS Version: $($enrollmentState.managedDevice.device.osVersion)"
        Write-Host "Compliance State: $($enrollmentState.managedDevice.device.complianceState)"
        Write-Host "Management State: $($enrollmentState.managedDevice.device.managementState)"
        Write-Host "Last Sync: $($enrollmentState.managedDevice.device.lastSyncDateTime)"
        Write-Host "Managed Device ID: $($enrollmentState.managedDevice.device.id)"
        
        # Display Autopilot information if available
        if ($deviceAssignment)
        {
            Write-Host "`n--- Autopilot Details ---" -ForegroundColor Blue
            Write-Host "Autopilot Device ID: $($deviceAssignment.id)"
            Write-Host "Autopilot Profile: $($deviceAssignment.deploymentProfile.displayName)"
            Write-Host "Profile Assignment Status: $($deviceAssignment.deploymentProfileAssignmentStatus)"
            Write-Host "Enrollment State: $($deviceAssignment.enrollmentState)"
            
            if ($deviceAssignment.deploymentProfileAssignedDateTime)
            {
                $assignmentDate = $deviceAssignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"
                Write-Host "Profile Assigned On: $assignmentDate"
            }
        }
        else
        {
            Write-Host "`n--- Autopilot Status ---" -ForegroundColor Yellow
            Write-Host "This device is managed by Intune but is not registered in Autopilot."
            Write-Host "This is normal for devices enrolled through other methods (manual enrollment, bulk enrollment, etc.)."
        }
        
        Write-Host "========================================`n" -ForegroundColor Cyan
        return $true
    }
    else
    {
        Write-Host "`n=== Device Status ===" -ForegroundColor Yellow
        Write-Host "Serial Number: $SerialNumber"
        
        if ($deviceAssignment)
        {
            Write-Host "`n--- Autopilot Details ---" -ForegroundColor Blue
            Write-Host "This device is registered in Autopilot but not yet enrolled in Intune management."
            Write-Host "Device ID: $($deviceAssignment.id)"
            Write-Host "Autopilot Profile: $($deviceAssignment.deploymentProfile.displayName)"
            Write-Host "Profile Assignment Status: $($deviceAssignment.deploymentProfileAssignmentStatus)"
            Write-Host "Enrollment State: $($deviceAssignment.enrollmentState)"
            
            if ($deviceAssignment.deploymentProfileAssignedDateTime)
            {
                $assignmentDate = $deviceAssignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"
                Write-Host "Profile Assigned On: $assignmentDate"
            }
        }
        else
        {
            Write-Host "`nDevice not found in Autopilot or Intune management." -ForegroundColor Red
            Write-Host "This device may not be enrolled in your organization's management system."
        }
        
        Write-Host "========================================`n" -ForegroundColor Yellow
        return $false
    }
}

# ProcessSerialNumber function - Enhanced with navigation parameter support
# This function creates a device actions menu when a managed device is found.
# Navigation parameters (Depth, History, MenuHistory) are passed through to maintain
# seamless menu navigation and allow users to go back or return to main menu.
function ProcessSerialNumber()
{
    [CmdletBinding()]
    param (
        [string]$SerialNumber,
        $AccessToken,
        $Settings = $settings,
        [Parameter(Mandatory = $false)]
        [int]$Depth = 0,
        [Parameter(Mandatory = $false)]
        [System.Collections.ArrayList]$History = $null,
        [Parameter(Mandatory = $false)]
        [System.Collections.ArrayList]$MenuHistory = $null
    )    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Processing device lookup for serial number: $SerialNumber"
    
    # Log navigation context for debugging
    $historyCount = if ($History)
    {
        $History.Count 
    }
    else
    {
        'null' 
    }
    $menuHistoryCount = if ($MenuHistory)
    {
        $MenuHistory.Count 
    }
    else
    {
        'null' 
    }
    Write-Verbose "[$functionName] Navigation context - Depth: $Depth, History count: $historyCount, MenuHistory count: $menuHistoryCount"
    
    # Initialize navigation parameters if not provided
    if ($null -eq $History)
    {
        Write-Verbose "[$functionName] Initializing History ArrayList"
        $History = New-Object System.Collections.ArrayList
    }
    
    if ($null -eq $MenuHistory)
    {
        Write-Verbose "[$functionName] Initializing MenuHistory ArrayList"
        $MenuHistory = New-Object System.Collections.ArrayList
    }
    
    $SerialNumber = $SerialNumber.Trim()
    
    Write-Host "`nLooking up device information for serial number: $SerialNumber" -ForegroundColor Cyan
    $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken
    
    # Display basic device information
    Write-Host "`n=== Device Information ===" -ForegroundColor Green
    Write-Host "Serial Number: $SerialNumber"
    
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
            SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'clean' | Out-Null
        }
        
        $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Sync Device" -Action {
            Write-Host "`nSyncing device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
            SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'sync' | Out-Null
        }
        
        $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Restart Device" -Action {
            Write-Host "`nRestarting device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
            SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'restart' | Out-Null
        }
        
        $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Show Device Health Status" -Action {
            DisplayDeviceHealth -SerialNumber $SerialNumber -AccessToken $AccessToken
            Read-Host "`nPress Enter to continue"        }
        
        # Show the device actions menu with navigation context
        Write-Verbose "[$functionName] Showing device actions menu with Depth: $($Depth + 1), History count: $($History.Count), MenuHistory count: $($MenuHistory.Count)"
        $result = ShowMenu -Menu $deviceActionsMenu -Depth ($Depth + 1) -History $History -MenuHistory $MenuHistory
        return $result
    }
    else
    {
        Write-Host "Status: Not managed by Intune" -ForegroundColor Yellow
        Write-Host "=============================`n" -ForegroundColor Yellow
        
        # For unmanaged devices, show limited information
        DisplayDeviceHealth -SerialNumber $SerialNumber -AccessToken $AccessToken
        return $null
    }
}
#endregion Helper Functions

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune Helpdesk menu.  What would you like to do?"
$CheckMenu = NewMenu -Title "Check Device Status" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$deviceExportMenu = newMenu -Title "Export Devices" -Description "Choose which devices you want to export."

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
        # Pass navigation context to ProcessSerialNumber
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -Depth $script:CurrentMenuDepth -History $script:CurrentMenuHistory -MenuHistory $script:CurrentMenuHistory_Menu
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
        Write-Host "Found local device: $make $model (Serial: $serialNumber)"
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        # Pass navigation context to ProcessSerialNumber
        $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -Depth $script:CurrentMenuDepth -History $script:CurrentMenuHistory -MenuHistory $script:CurrentMenuHistory_Menu
        # Check if ProcessSerialNumber returned an exit signal
        if ($null -eq $result)
        {
            Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
            return "EXIT_APPLICATION"
        }
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
        Read-Host "Press Enter to continue"
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
        
        # Call GetDeviceByUser to find devices for the specified user
        Write-Verbose "[$scriptName] Calling GetDeviceByUser for user: $userName"
        $serialNumber = GetDeviceByUser -UserName $userName -OperatingSystem 'Windows' -AccessToken $accessToken -Depth $script:CurrentMenuDepth -History $script:CurrentMenuHistory -MenuHistory $script:CurrentMenuHistory_Menu
        Write-Verbose "[$scriptName] GetDeviceByUser returned: $serialNumber"
        
        if ($serialNumber -eq "EXIT_APPLICATION")
        {
            Write-Verbose "[$scriptName] User requested application exit from device selection."
            return "EXIT_APPLICATION"
        }
        elseif ($serialNumber -ne '0' -and $null -ne $serialNumber)
        {
            Write-Host "Found device for user $userName with serial number: $serialNumber"
            # Pass navigation context to ProcessSerialNumber
            $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -Depth $script:CurrentMenuDepth -History $script:CurrentMenuHistory -MenuHistory $script:CurrentMenuHistory_Menu
            # Check if ProcessSerialNumber returned an exit signal
            if ($null -eq $result)
            {
                Write-Verbose "[$scriptName] ProcessSerialNumber returned exit signal"
                return "EXIT_APPLICATION"
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
        Write-Host "Checking group membership for user $userName."
        Write-Verbose "[$scriptName] Getting access token..."
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
        if ($groups.success -eq $true)
        {
            Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
            Write-Host "The user is a member of all $($groupsToInclude.Count) required groups and is not a member of any of the $($groupsToExclude.Count) forbidden groups."
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
                $result = ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -Depth $script:CurrentMenuDepth -History $script:CurrentMenuHistory -MenuHistory $script:CurrentMenuHistory_Menu
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
    } # Corrected: Closing brace for the -Action script block was missing
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Check device status " -Submenu $CheckMenu
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Export devices" -Submenu $deviceExportMenu
#endregion Menu Definitions

#region Show Menu
$result = ShowMenu -Menu $mainMenu
if ($null -eq $result)
{
    Write-Host "`nThank you for using the Intune Helpdesk menu. Goodbye!" -ForegroundColor Green
}
#endregion Show Menu
