[CmdletBinding()]
param(
    [string]$configFile = "$PSScriptRoot\.secrets\config.json",
    [string]$InitFile = "$PSScriptRoot\initVerify.json"
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
#endregion import functions.

#region Define variables
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
Write-Verbose "Domain: $domain"
$init = (Get-Content -Path $InitFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domains).$domain
Write-Verbose "Init: $($init | Out-String)"
$groupsToInclude = $init.groupsToInclude
Write-Verbose "Groups to include: $($groupsToInclude | Out-String)"
$groupsToExclude = $init.groupsToExclude
Write-Verbose "Groups to exclude: $($groupsToExclude | Out-String)"
$settings = $init.settings
Write-Verbose "Settings: $($settings | Out-String)"
$backoutText = 'Backout'
#endregion Define variables

#region Helper Functions (Consolidated and Corrected)
function NormalizeUserName()
{
    [CmdletBinding()]
    param (
        [string]$UserName,
        $Settings = $settings # Use the script-level $settings by default
    )
    $domain = $settings.domain
    Write-Verbose "Domain: $domain"
    Write-Verbose "UserName: $UserName"
    Write-Verbose "Normalizing user name: $UserName"
    $UserName = $UserName.Trim()
    Write-Verbose "Checking if the user name $username is missing the $domain suffix."
    if ($userName -notmatch "@$domain$")
    {
        Write-Verbose "the user name $username is missing the $domain suffix."
        $UserName = "$UserName@$domain"
        Write-Verbose "The user name is now $userName"
    }
    else
    {
        Write-Verbose "The user name is already in the correct format: $UserName"
    }
    Write-Verbose "Final user name: $UserName"
    Write-Verbose "Returning user name: $UserName"
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

    $domain = $settings.domain
    $MaxUserNameLength = $settings.MaxUserNameLength
    $MaxSerialNumberLength = $settings.MaxSerialNumberLength
    $MinSerialNumberLength = $settings.MinSerialNumberLength
    $returnValue = @{ valid = $false; value = $null } # Initialize return hash table
    Write-Verbose "Validating input of type '$type': '$UserInput'"
    Write-Verbose "Domain: $domain"
    Write-Verbose "MaxUserNameLength: $MaxUserNameLength"
    Write-Verbose "MaxSerialNumberLength: $MaxSerialNumberLength"
    Write-Verbose "MinSerialNumberLength: $MinSerialNumberLength"
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    Write-Verbose "Trimmed input: '$UserInput'"
    switch ($type)
    {
        'serialNumber'
        {
            Write-Verbose "Checking serial number length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxSerialNumberLength)
            {
                Write-Verbose "Serial number exceeds maximum length of $MaxSerialNumberLength characters"
                Write-Host "Serial number cannot exceed $MaxSerialNumberLength characters." -ForegroundColor Red
            }
            elseif ($UserInput.Length -lt $MinSerialNumberLength)
            {
                Write-Verbose "Serial number is shorter than minimum length of $MinSerialNumberLength characters"
                Write-Host "Serial number must be at least $MinSerialNumberLength characters." -ForegroundColor Red
            }
            elseif ($UserInput -match '^[a-zA-Z0-9]+$') # Check if alphanumeric
            {
                Write-Verbose "Serial number validation passed"
                $returnValue.valid = $true
                $returnValue.value = $UserInput
            }
            else
            {
                Write-Host 'Invalid serial number format. Only alphanumeric characters are allowed.' -ForegroundColor Red
            }
        }
        'userName'
        {
            Write-Verbose "Checking user name length: $($UserInput.Length)"
            if ($UserInput.Length -gt $MaxUserNameLength)
            {
                Write-Verbose "Username exceeds maximum length of $MaxUserNameLength characters"
                Write-Host "Username cannot exceed $MaxUserNameLength characters." -ForegroundColor Red
            }
            else
            {
                $normalizedUserInput = NormalizeUserName -UserName $UserInput -Settings $settings
                # Basic email format check
                if ($normalizedUserInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                {
                    Write-Verbose "Username validation passed"
                    $returnValue.valid = $true
                    $returnValue.value = $normalizedUserInput
                }
                else
                {
                    Write-Verbose "Username validation failed - must be a valid email format (e.g., user@$domain)"
                    Write-Host "Invalid user name format. Please enter a valid email address (e.g., user@$domain)." -ForegroundColor Red
                }
            }
        }
        default
        {
            Write-Verbose "Unknown validation type: '$type'"
            Write-Host "Unknown validation type: '$type'" -ForegroundColor Red
        }
    }
    Write-Verbose "Returning validation result: $($returnValue.valid)"
    Write-Verbose "Returning validation value: $($returnValue.value)"
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
    Write-Verbose "Message: $Message"
    Write-Verbose "Prompt: $Prompt"
    Write-Verbose "InputType: $InputType"
    Write-Host $Message
    # Updated instruction
    Write-Host "Press Enter without typing anything to return to the previous menu." 

    while ($true) # Loop indefinitely until valid input or Enter is pressed
    {
        $inputItem = Read-Host $Prompt
        Write-Verbose "Item entered: '$inputItem'" # Added quotes for clarity

        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "User pressed Enter. Returning $BackoutText."
            return $null # Return null to signal going back
        }

        # Validate the input if it's not empty
        $validationResult = validateInput -UserInput $inputItem -type $InputType -settings $settings
        $inputResultValid = $validationResult.valid
        $inputResult = $validationResult.value

        if ($inputResultValid)
        {
            Write-Verbose "Valid $inputType entered: $inputResultValid"
            Write-Verbose "Input result: $inputResult"
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

function ProcessSerialNumber
{
    [CmdletBinding()]
    param (
        [string]$SerialNumber,
        $AccessToken,
        $Settings = $settings, # Use the script-level $settings by default
        [string]$AssessmentType = 'GeneralCheck' # Default assessment type
    )
    Write-Verbose "Trimming serial number: $SerialNumber"
    $SerialNumber = $SerialNumber.Trim()
    Write-Verbose "Trimmed serial number: $SerialNumber"
    Write-Host "Checking deployment status for device with serial number $SerialNumber."
    $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken
    Write-Verbose "The management state is: $($enrollmentState.managed)"
    Write-Verbose "The Autopilot registration state is: $($enrollmentState.InAutopilot)"
    Write-Verbose "The imported state is: $($enrollmentState.imported)"
    Write-Verbose "Has device object: $($enrollmentState.hasDeviceObject)"

    if (AssessDeviceState -enrollmentState $enrollmentState -Settings $Settings -AssessmentType $AssessmentType)
    {
        Write-Host 'The device is in the correct state.' -ForegroundColor Green
        Write-Host 'You may proceed with enrollment.' -ForegroundColor Green
    }
    else
    {
        Write-Host 'The device is not in the correct state.' -ForegroundColor Red
        Write-Host "The function returned a value of false." -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
    }
}
#endregion Helper Functions

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune Helpdesk menu.  What would you like to do?"
$receiveMenu = NewMenu -Title "Receive Device" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers and is no more than 10 digits long.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
    # Check if user entered 'back'
    if ($null -eq $serialNumber)
    {
        Write-Verbose "User pressed Enter. Returning $BackoutText."
        return $backoutText
    } 
    else # Process only if a serial number was entered
    {
        Write-Verbose "Got serial number: $SerialNumber"
        Write-Host "Checking device with serial number $($SerialNumber)..."
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -AssessmentType 'NextUserReadiness'
    }
}

$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number." -Action {
    Write-Verbose "Getting the serial number for this device..."
    $deviceObject = GetDeviceInfo -NoHash
    Write-Verbose "Device object: $($deviceObject)"
    if ($deviceObject)
    {
        $serialNumber = $deviceObject.serialNumber
        Write-Verbose "The serial number is $serialNumber."
        $make = $deviceObject.manufacturer
        Write-Verbose "The manufacturer is $make"
        $model = $deviceObject.model
        Write-Host "Checking device with serial number $($serialNumber): $make $model "
        $accessToken = GetGraphAccessToken -ConfigFile $configFile # Ensure accessToken is available
        ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -AssessmentType 'NextUserReadiness'
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
        # Removed exit 1 to allow returning to menu
    }
}
$receiveMenu = AddMenuItem -Menu $receiveMenu -Name "Lookup device by Serial Number" -Submenu $serialNumberMenu
$receiveMenu = AddMenuItem -Menu $receiveMenu -Name "Lookup device by User" -Action {
    $userName = GetUserInput -Message "Enter the username (email address) of the user whose device you want to look up." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    # Check if user entered 'back'
    if ($null -eq $userName)
    {
        Write-Verbose "User pressed Enter. Returning $BackoutText."
        return $backoutText
    } 
    else # Process only if a username was entered
    {
        Write-Verbose "Got user name: $UserName"
        Write-Verbose "Getting access token..."
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        $serialNumber = GetDeviceByUser -AccessToken $accessToken -UserName $userName -OperatingSystem $settings.operatingSystem
        Write-Verbose "Serial number: $($serialNumber)"
        if ($serialNumber)
        {
            Write-Host "Checking device with serial number $($serialNumber)..."
            ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -AssessmentType 'NextUserReadiness'
        }
        else
        {
            Write-Host "No device found for user $userName." -ForegroundColor Red
        }
    }
}

$mainMenu = AddMenuItem -Menu $mainMenu -Name "Give a device to a user" -Action {
    $username = GetUserInput -Message "Enter the username (email address) of the user receiving the device." -Prompt 'Please enter the user name (email address)' -InputType 'userName' -settings $settings
    # Check if user entered 'back'
    if ($null -eq $username)
    {
        Write-Verbose "User pressed Enter. Returning $BackoutText."
        return $backoutText # Return to the previous menu
    } 
    else # Continue only if a username was entered
    {
        Write-Host "Checking group membership for user $userName."
        Write-Verbose "Getting access token..."
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
        if ($groups)
        {
            Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
            Write-Host "We will now check the device state." -ForegroundColor Green
            Write-Host "Enter the device's serial number."
            Write-Host "This would be the device you plan to give to the user."
            $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
            # Check if user entered 'back'
            if ($null -eq $serialNumber)
            {
                Write-Verbose "User pressed Enter. Returning $BackoutText."
                return $backoutText # Return to the previous menu
            } 
            else # Process only if a serial number was entered
            {
                Write-Host "Checking device with serial number $($serialNumber)..."
                ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings -AssessmentType 'NextUserReadiness'
            }
        }
        else
        {
            Write-Verbose "The function returned $($groups.missingIncludeGroups.Count) missing groups and $($groups.invalidExcludeGroups.Count) invalid groups."
            Write-Verbose "Missing include groups: $($groups.missingIncludeGroups | Out-String)"
            Write-Verbose "The function returned $($groups.invalidExcludeGroups.Count) invalid exclude groups."
            Write-Verbose "Invalid exclude groups: $($groups.invalidExcludeGroups | Out-String)"
            if ($groups.missingIncludeGroups.Count -gt 0)
            {
                Write-Host 'The user needs to be added to the following groups:' -ForegroundColor Red
                foreach ($group in $groups.missingIncludeGroups)
                {
                    Write-Host $group -ForegroundColor Red
                }
            }
            if ($groups.invalidExcludeGroups.Count -gt 0)
            {
                Write-Host 'The user needs to be removed from the following groups:' -ForegroundColor Red
                foreach ($group in $groups.invalidExcludeGroups)
                {
                    Write-Host $group -ForegroundColor Red
                }
            }
            Write-Host 'Please contact an Intune administrator.' -ForegroundColor Red
            # Removed exit 1 to allow returning to menu
        }
    } # Corrected: Closing brace for the -Action script block was missing
}

$mainMenu = AddMenuItem -Menu $mainMenu -Name "Receive a device from a user" -Submenu $receiveMenu
#endregion Menu Definitions

#region Show Menu
ShowMenu -Menu $mainMenu
#endregion Show Menu

