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
function ProcessSerialNumber
{
    param (
        [string]$SerialNumber,
        $AccessToken,
        $Settings
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
    if (AssessDeviceState -enrollmentState $enrollmentState -Settings $Settings)
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
function validateInput()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput,
        [parameter(Mandatory = $true)]
        [string]$type
    )
    
    Write-Verbose "Validating input of type '$type': '$UserInput'"
    
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    Write-Verbose "Trimmed input: '$UserInput'"
    
    switch ($type)
    {
        'serialNumber'
        {
            # Check if input exceeds maximum length
            if ($UserInput.Length -gt 30)
            {
                Write-Verbose "Serial number exceeds maximum length of 30 characters"
                Write-Host "Serial number cannot exceed 30 characters." -ForegroundColor Red
                return $false
            }
            
            if ($UserInput -match '^[a-zA-Z0-9]{7,}$')
            {
                Write-Verbose "Serial number validation passed"
                return $true
            }
            else
            {
                Write-Verbose "Serial number validation failed - must be alphanumeric and at least 10 characters"
                Write-Host 'Invalid serial number format.' -ForegroundColor Red
                return $false
            }
        }
        'userName'
        {
            # Check if input exceeds maximum length
            if ($UserInput.Length -gt 50)
            {
                Write-Verbose "Username exceeds maximum length of 50 characters"
                Write-Host "Username cannot exceed 50 characters." -ForegroundColor Red
                return $false
            }
            
            if ($UserInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            {
                Write-Verbose "Username validation passed"
                return $true
            }
            else
            {
                Write-Verbose "Username validation failed - must be a valid email format"
                Write-Host 'Invalid user name format.' -ForegroundColor Red
                return $false
            }
        }
        default 
        {
            Write-Verbose "Unknown validation type: '$type'"
            Write-Host "Unknown validation type: '$type'" -ForegroundColor Red
            return $false
        }
    }
}
#endregion import functions.

function ProcessSerialNumber
{
    param (
        [string]$SerialNumber,
        $AccessToken,
        $Settings
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
    if (AssessDeviceState -enrollmentState $enrollmentState -Settings $Settings)
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
function validateInput()
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$UserInput,
        [parameter(Mandatory = $true)]
        [string]$type
    )
    
    Write-Verbose "Validating input of type '$type': '$UserInput'"
    
    # Trim input to remove any leading or trailing spaces
    $UserInput = $UserInput.Trim()
    Write-Verbose "Trimmed input: '$UserInput'"
    
    switch ($type)
    {
        'serialNumber'
        {
            # Check if input exceeds maximum length
            if ($UserInput.Length -gt 30)
            {
                Write-Verbose "Serial number exceeds maximum length of 30 characters"
                Write-Host "Serial number cannot exceed 30 characters." -ForegroundColor Red
                return $false
            }
            
            if ($UserInput -match '^[a-zA-Z0-9]{7,}$')
            {
                Write-Verbose "Serial number validation passed"
                return $true
            }
            else
            {
                Write-Verbose "Serial number validation failed - must be alphanumeric and at least 10 characters"
                Write-Host 'Invalid serial number format.' -ForegroundColor Red
                return $false
            }
        }
        'userName'
        {
            # Check if input exceeds maximum length
            if ($UserInput.Length -gt 50)
            {
                Write-Verbose "Username exceeds maximum length of 50 characters"
                Write-Host "Username cannot exceed 50 characters." -ForegroundColor Red
                return $false
            }
            
            if ($UserInput -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            {
                Write-Verbose "Username validation passed"
                return $true
            }
            else
            {
                Write-Verbose "Username validation failed - must be a valid email format"
                Write-Host 'Invalid user name format.' -ForegroundColor Red
                return $false
            }
        }
        default 
        {
            Write-Verbose "Unknown validation type: '$type'"
            Write-Host "Unknown validation type: '$type'" -ForegroundColor Red
            return $false
        }
    }
}

function GetUserInput()
{
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Prompt,
        [validateSet('userName', 'serialNumber')]
        [string]$InputType
    )
    Write-Verbose "Message: $Message"
    Write-Verbose "Prompt: $Prompt"
    Write-Verbose "InputType: $InputType"
    Write-Host $Message
    $inputItem = Read-Host $Prompt
    Write-Verbose "Item entered: $inputItem"
    while (-not (validateInput -UserInput $inputItem -type $InputType))
    {
        #beep
        [console]::beep(1000, 500)
        Write-Host "Invalid $inputType. Enter a valid $inputType." -ForegroundColor Red
        $inputItem = Read-Host $Prompt
    }
    return $inputItem
}

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
#endregion Define variables

$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune Helpdesk menu.  What would you like to do?"
$receiveMenu = NewMenu -Title "Receive Device" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers and is no more than 10 digits long.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber'
    Write-Verbose "Got serial number: $SerialNumber"
    Write-Host "Checking device with serial number $($SerialNumber)..."
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
        Write-Verbose "The model is $model"
        Write-Host "Checking device with serial number $($serialNumber): $make $model "
    }
    else
    {
        Write-Host "Could not obtain the serial number." -ForegroundColor Red
        exit 1
    }
}
$receiveMenu = AddMenuItem -Menu $receiveMenu -Name "Lookup device by Serial Number" -Submenu $serialNumberMenu
$receiveMenu = AddMenuItem -Menu $receiveMenu -Name "Lookup device by User" -Action {
    $userName = GetUserInput -Message "Enter the username (email address) of the user whose device you want to look up." -Prompt 'Please enter the user name (email address)' -InputType 'userName'
    Write-Verbose "Got user name: $UserName"
    Write-Verbose "Getting access token..."
    $accessToken = GetGraphAccessToken -ConfigFile $configFile
    $serialNumber = GetDeviceByUser -AccessToken $accessToken -UserName $userName -DeviceNamePrefix $settings.deviceNamePrefix
    Write-Host "Checking device with serial number $($serialNumber)..."
}
$mainMenu = AddMenuItem -Menu $mainMenu -Name "Give a device to a user" -Action {
    $username = GetUserInput -Message "Enter the username (email address) of the user receiving the device." -Prompt 'Please enter the user name (email address)' -InputType 'userName'
    Write-Host "Checking group membership for user $userName."
    Write-Verbose "Getting access token..."
    $accessToken = GetGraphAccessToken -ConfigFile $configFile
    $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
    if ($groups -eq $true)
    {
        Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
        Write-Host "We will now check the device state." -ForegroundColor Green
        Write-Host "Enter the device's serial number."
        Write-Host "This would be the device you plan to give to the user."
        $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber'
        Write-Host "Checking device with serial number $($serialNumber)..."
        $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $serialNumber -AccessToken $accessToken
        $deviceState = AssessDeviceState -enrollmentState $enrollmentState -Settings $settings
        Write-Host "Device state: $($deviceState)"
        Write-Host 'You may proceed with enrollment.'
    }
    else
    {
        Write-Verbose "The function returned $($groups.missingIncludeGroups.Count) missing groups and $($groups.invalidExcludeGroups.Count) invalid groups."
        Write-Verbose "Missing include groups: $($groups.missingIncludeGroups) | Out-String)"
        Write-Verbose "The function returned $($groups.invalidExcludeGroups.Count) invalid exclude groups."
        Write-Verbose "Invalid exclude groups: $($groups.invalidExcludeGroups) | Out-String)"
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
        exit 1
    }
}

$mainMenu = AddMenuItem -Menu $mainMenu -Name "Receive a device from a user" -Submenu $receiveMenu



ShowMenu -Menu $mainMenu

