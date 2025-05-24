[CmdletBinding()]
param(
    [string]$configFile = "$pwd\.secrets\config.json",
    [string]$InitFile = "$pwd\initVerify.json"
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
    $minUsernameLength = $settings.MinUsernameLength
    $returnValue = @{ valid = $false; value = $null } # Initialize return hash table
    Write-Verbose "Validating input of type '$type': '$UserInput'"
    Write-Verbose "Domain: $domain"
    Write-Verbose "MaxUserNameLength: $MaxUserNameLength"
    Write-Verbose "MinUserNameLength: $minUsernameLength"
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
            elseif ($UserInput -match '^[a-zA-Z0-9-\s]+$') 
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
            if ($UserInput.Length -gt $MaxUserNameLength -or $UserInput.Length -lt $minUsernameLength -or $UserInput -match '^\d' -and $null -ne $UserInput)
            {
                Write-Verbose "Username exceeds maximum length of $MaxUserNameLength characters"
                Write-Host "Username needs to have a minimum of $minUsernameLength characters and cannot exceed $MaxUserNameLength characters." -ForegroundColor Red
                Write-Host "The username cannot start with a digit." -ForegroundColor Red
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

function DisplayDeviceHealth {
    [CmdletBinding()]
    param (
        [string]$SerialNumber,
        [string]$AccessToken
    )
    
    Write-Host "`nRetrieving comprehensive device health information..." -ForegroundColor Yellow
    
    # Use existing CheckDeviceAssignment function which returns rich device info
    $deviceAssignment = CheckDeviceAssignment -serialNumber $SerialNumber -AccessToken $AccessToken
    
    if ($deviceAssignment) {
        Write-Host "`n=== Device Health & Status Report ===" -ForegroundColor Cyan
        Write-Host "Serial Number: $SerialNumber"
        Write-Host "Device ID: $($deviceAssignment.id)"
        Write-Host "Autopilot Profile: $($deviceAssignment.deploymentProfile.displayName)"
        Write-Host "Profile Assignment Status: $($deviceAssignment.deploymentProfileAssignmentStatus)"
        Write-Host "Enrollment State: $($deviceAssignment.enrollmentState)"
        
        if ($deviceAssignment.deploymentProfileAssignedDateTime) {
            $assignmentDate = $deviceAssignment.deploymentProfileAssignedDateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt K"
            Write-Host "Profile Assigned On: $assignmentDate"
        }
        
        # Get additional managed device details if available
        $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken
        if ($enrollmentState.managed) {
            Write-Host "`n--- Managed Device Details ---" -ForegroundColor Green
            Write-Host "Device Name: $($enrollmentState.managedDevice.device.deviceName)"
            Write-Host "Model: $($enrollmentState.managedDevice.device.model)"
            Write-Host "Manufacturer: $($enrollmentState.managedDevice.device.manufacturer)"
            Write-Host "OS Version: $($enrollmentState.managedDevice.device.osVersion)"
            Write-Host "Compliance State: $($enrollmentState.managedDevice.device.complianceState)"
            Write-Host "Management State: $($enrollmentState.managedDevice.device.managementState)"
            Write-Host "Last Sync: $($enrollmentState.managedDevice.device.lastSyncDateTime)"
        }
        
        Write-Host "========================================`n" -ForegroundColor Cyan
        return $true
    } else {
        Write-Host "`nDevice not found in Autopilot/Intune." -ForegroundColor Red
        return $false
    }
}

function ProcessSerialNumber
{
    [CmdletBinding()]
    param (
        [string]$SerialNumber,
        $AccessToken,
        $Settings = $settings
    )
    
    Write-Verbose "Processing device lookup for serial number: $SerialNumber"
    $SerialNumber = $SerialNumber.Trim()
    
    Write-Host "`nLooking up device information for serial number: $SerialNumber" -ForegroundColor Cyan
    $enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken
    
    # Display basic device information
    Write-Host "`n=== Device Information ===" -ForegroundColor Green
    Write-Host "Serial Number: $SerialNumber"
    
    if ($enrollmentState.managed) {
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
            $result = SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'wipe'
            Read-Host "`nPress Enter to continue"
        }
        
        $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Clean Device" -Action {
            Write-Host "`nInitiating device clean for: $deviceName ($SerialNumber)" -ForegroundColor Yellow
            $result = SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'clean'
            Read-Host "`nPress Enter to continue"
        }
        
        $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Sync Device" -Action {
            Write-Host "`nSyncing device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
            $result = SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'sync'
            Read-Host "`nPress Enter to continue"
        }
        
        $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Restart Device" -Action {
            Write-Host "`nRestarting device: $deviceName ($SerialNumber)" -ForegroundColor Yellow
            $result = SendDeviceCommand -AccessToken $AccessToken -ManagedDeviceId $managedDeviceId -Command 'restart'
            Read-Host "`nPress Enter to continue"
        }
        
        $deviceActionsMenu = AddMenuItem -Menu $deviceActionsMenu -Name "Show Device Health Status" -Action {
            DisplayDeviceHealth -SerialNumber $SerialNumber -AccessToken $AccessToken
            Read-Host "`nPress Enter to continue"
        }
        
        # Show the device actions menu
        $result = ShowMenu -Menu $deviceActionsMenu
        return $result
    }
    else {
        Write-Host "Status: Not managed by Intune" -ForegroundColor Yellow
        Write-Host "=============================`n" -ForegroundColor Yellow
        
        # For unmanaged devices, show limited information
        DisplayDeviceHealth -SerialNumber $SerialNumber -AccessToken $AccessToken
        Read-Host "`nPress Enter to continue"
        return $null
    }
}
#endregion Helper Functions

#region Menu Definitions
$mainMenu = NewMenu -Title "Main Menu" -Description "Welcome to the Intune Helpdesk menu.  What would you like to do?"
$CheckMenu = NewMenu -Title "Check Device Status" -Description "How would you like to lookup the device?"
$serialNumberMenu = newMenu -Title "Lookup by Serial Number" -Description "How would you like to enter the serial number?."
$deviceExportMenu = newMenu -Title "Export Devices" -Description "Choose which devices you want to export."

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

$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Enter a serial number." -Action {
    Write-Host 'Please enter the serial number of the device.'
    Write-Host 'The serial number is typically a combination of letters and numbers.'
    $serialNumber = GetUserInput -Message "Enter the serial number of the device." -Prompt 'Please enter the serial number' -InputType 'serialNumber' -settings $settings
    
    if ($null -eq $serialNumber)
    {
        Write-Verbose "User pressed Enter. Returning $BackoutText."
        return $backoutText
    } 
    else
    {
        Write-Verbose "Got serial number: $SerialNumber"
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
    }
}
$serialNumberMenu = AddMenuItem -Menu $serialNumberMenu -Name "Use this device's serial number." -Action {
    Write-Verbose "Getting the serial number for this device..."
    $deviceObject = GetDeviceInfo -NoHash
    Write-Verbose "Device object: $($deviceObject)"
    
    if ($deviceObject)
    {
        $serialNumber = $deviceObject.serialNumber
        $make = $deviceObject.manufacturer
        $model = $deviceObject.model
        Write-Host "Found local device: $make $model (Serial: $serialNumber)"
        
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
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
        Write-Verbose "User pressed Enter. Returning $BackoutText."
        return $backoutText
    } 
    else
    {
        Write-Verbose "Got user name: $UserName"
        $accessToken = GetGraphAccessToken -ConfigFile $configFile
        $serialNumber = GetDeviceByUser -AccessToken $accessToken -UserName $userName -OperatingSystem $settings.operatingSystem
        Write-Verbose "Serial number: $($serialNumber)"
        
        if ($serialNumber -ne '0' -and $null -ne $serialNumber)
        {
            Write-Host "Found device for user $userName with serial number: $serialNumber"
            ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
        }
        elseif ($serialNumber -eq '0')
        {
            Write-Verbose "User selected Exit option (0). Returning $BackoutText."
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
        Write-Verbose "User pressed Enter. Returning $BackoutText."
        return $backoutText # Return to the previous menu
    } 
    else # Continue only if a username was entered
    {
        Write-Host "Checking group membership for user $userName."
        Write-Verbose "Getting access token..."
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
                Write-Verbose "User pressed Enter. Returning $BackoutText."
                return $backoutText # Return to the previous menu
            } 
            else # Process only if a serial number was entered
            {
                ProcessSerialNumber -SerialNumber $serialNumber -AccessToken $accessToken -Settings $settings
            }
        }
        else
        {
            Write-Verbose "The function returned $($groups.MissingGroups.Count) missing group membershipss and $($groups.ForbiddenGroups.Count) forbidden group membershipss."
            Write-Verbose "Missing group memberships: $($groups.missingGroups | Out-String)"
            Write-Verbose "Forbidden groups: $($groups.ForbiddenGroups | Out-String)"
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
ShowMenu -Menu $mainMenu
#endregion Show Menu


# SIG # Begin signature block
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBCV9TYZIrpnLsY
# 20OQPRDKmjJY1Z0k+a5t9MjO26sgjqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN0uwl7
# vtDCSQaiAAAAA3S7MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDIzMDQ0NDU1WhcNMjUwNDI2
# MDQ0NDU1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# h/5tCSWKbPKt8F93wvLZlP5AAfdF3mukm8z0mBQtyMLGXK+NWnLO8fvV0ge5eUjI
# A9wcMLEcX2TvQCW7IyvihQMgHy1L6uzT9xKUmyQI9kJGEXpw64rtKAgDlJqD6GgA
# WnyhOzNcHRfgN0HNTai/MezVyct6AF9SxZn1XinCOhUbBx1wTZTvScxwTEqe43HU
# ZIVJ40G32BYnBeOoSXYAO0ZK4b+mxStrfB9II8lQ3tdTxu524cM+qaIF23QUnhBa
# asuCBhne2rFQuaQnY++/GvWc+ZdkR1d4eoV4zyt9d+mzYHNZ9JNOI4XWn78S2rKd
# gsL9xWj1YKAD1mhVFuuBKMIXktSaSDXiPdhGWSQcaTYbchw2OI0Peb3Xf50WD9qD
# GAPcYdjtB0vugl/dx5YJOLBfqiIxXeVg6TEsgSQTRDQdBaKDjHma/gXRJIsQw5KP
# mJMHaAZ5dEDoVuXbDev27Yvv4VV95giO3wLUx2iOsC1qDenBWiFyWPe4WovyDvxF
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCmIHt4RADaTywJxAromEjAGzJZjMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAFXeJOg62AhYTxzF
# Yip4wYPtqc/tDdCid07e6FTg2jM84hJXep5mqbcU8VtqDNTqVODwDy1dFGRmHAdu
# 3F4o2Hkb0W4QVFAZsHR9yd+BQTJGDBFv+i23cHJ+qODBTZ6rh1NOMRGSuH6k3lX7
# nsI0/WQXbff/5XsSqpO9/d0+2VwWmeujUSCQf48tY7PsXBH+4rPOe3U9NW0/HXiI
# adefC8/N9UltDmQ4by+CtRmra3nBkIEAPRmFC1ERfq3JMPAJ4yJ3ddzakrjO0w56
# JyW7yeawoSB3iX8due4vRy2rDIfFWsKrcIKEqBZItd3ZTDIuLXbpQD/tZxocQPIx
# Eg6Wy5XRMlKxgQmxVP8IIsmz9InLM1qjhAtGgIv+kx+iisyg1qvojhnGnJohaZbq
# 2XH5Nx84JnfOfTAZ0mfEuSnuZA7IvCtaL66lP6Q1TikBAIGUa5wwk6cL0GGFGcI4
# p/Lr9n34HsCuJp4Qu/d6IaHMwA0s4YJnwH/bJctKJYO5VhV5MEVDU2QgeVkAkQ5G
# EIKOIBA1SR+fC87xg9dmbFjmAHqA3wkNgL1DVijsPpMXByQnkP3IqFFlDrP+rlBz
# WBv7814VxOszcciIgYPGI24asSBGXE6oQyAKkmTfTthhzNdgT5JxpNrgBwFEuUle
# mnqxm4/T9GIubTff34taJzANNNJVMIIG5zCCBM+gAwIBAgITMwADdLsJe77QwkkG
# ogAAAAN0uzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyMzA0NDQ1NVoXDTI1MDQyNjA0NDQ1
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIf+bQkl
# imzyrfBfd8Ly2ZT+QAH3Rd5rpJvM9JgULcjCxlyvjVpyzvH71dIHuXlIyAPcHDCx
# HF9k70AluyMr4oUDIB8tS+rs0/cSlJskCPZCRhF6cOuK7SgIA5Sag+hoAFp8oTsz
# XB0X4DdBzU2ovzHs1cnLegBfUsWZ9V4pwjoVGwcdcE2U70nMcExKnuNx1GSFSeNB
# t9gWJwXjqEl2ADtGSuG/psUra3wfSCPJUN7XU8buduHDPqmiBdt0FJ4QWmrLggYZ
# 3tqxULmkJ2Pvvxr1nPmXZEdXeHqFeM8rfXfps2BzWfSTTiOF1p+/EtqynYLC/cVo
# 9WCgA9ZoVRbrgSjCF5LUmkg14j3YRlkkHGk2G3IcNjiND3m913+dFg/agxgD3GHY
# 7QdL7oJf3ceWCTiwX6oiMV3lYOkxLIEkE0Q0HQWig4x5mv4F0SSLEMOSj5iTB2gG
# eXRA6Fbl2w3r9u2L7+FVfeYIjt8C1MdojrAtag3pwVohclj3uFqL8g78RQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQpiB7eEQA2k8sCcQK6JhIwBsyWYzAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBV3iToOtgIWE8cxWIqeMGD
# 7anP7Q3QondO3uhU4NozPOISV3qeZqm3FPFbagzU6lTg8A8tXRRkZhwHbtxeKNh5
# G9FuEFRQGbB0fcnfgUEyRgwRb/ott3ByfqjgwU2eq4dTTjERkrh+pN5V+57CNP1k
# F233/+V7EqqTvf3dPtlcFpnro1EgkH+PLWOz7FwR/uKzznt1PTVtPx14iGnXnwvP
# zfVJbQ5kOG8vgrUZq2t5wZCBAD0ZhQtREX6tyTDwCeMid3Xc2pK4ztMOeiclu8nm
# sKEgd4l/HbnuL0ctqwyHxVrCq3CChKgWSLXd2UwyLi126UA/7WcaHEDyMRIOlsuV
# 0TJSsYEJsVT/CCLJs/SJyzNao4QLRoCL/pMfoorMoNar6I4ZxpyaIWmW6tlx+Tcf
# OCZ3zn0wGdJnxLkp7mQOyLwrWi+upT+kNU4pAQCBlGucMJOnC9BhhRnCOKfy6/Z9
# +B7AriaeELv3eiGhzMANLOGCZ8B/2yXLSiWDuVYVeTBFQ1NkIHlZAJEORhCCjiAQ
# NUkfnwvO8YPXZmxY5gB6gN8JDYC9Q1Yo7D6TFwckJ5D9yKhRZQ6z/q5Qc1gb+/Ne
# FcTrM3HIiIGDxiNuGrEgRlxOqEMgCpJkTfTthhzNdgT5JxpNrgBwFEuUlemnqxm4
# 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 cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF U046M0RBNS05NjNCLUUxRjQxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0 IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0 eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5 i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3 oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0 aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3 he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0 Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4 fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6 ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQIC EzMAAABGF+R1esr92uUAAAAAAEYwDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2 MTg0ODQ5WhcNMjUxMTE5MTg0ODQ5WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0 aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046M0RBNS05NjNCLUUxRjQxNTAz BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsJV86I/zDS9QX51f oIOHdH2bptR3VCYnUjU3A86Ryb5iAah+euswWHFdE8je/t6jpyY6aE8eiQTIDWJy +QZk1/R65l9FnTTC3++LuzbQUrgA9rH+p9qlFK8+4vH+69CYmYsSiZ5LwP9WpCx6 aUDAwroNaAtAGI3e+d2+b8tb1nax1xPYS+9QWXuQwquf+CwZ8vGjkGZc743sIDjZ ImZvkn3LZCY4fS8XZA5auRLxhOmFNLgt+1xe6pB7yJLA9vl4AT9JRDH5jyaNnyPR cCAPWDF+yiCDRDOTmOp5Lyq8jPbOWyui1eM+PDWKYiNcbx9eWA6bPtfZxwrSjFU2 XQeHGIQNHVaie3QLuFXMVMA9QBHDMVmyDkdc+jhZFWPRl+aB/JNe3fbd+T1n59F7 sVuEhv64poLRYKRP7IUbMuZzAmx8ngnVtB3taZa2EKk7Ehz9p/5c9gwoCJZ8frrz y1X+fiRv9XdYvy3cGwtlh+lBBCcmSJd2tGMDOK3c6Efj+HTvSP9qFjsVwmKhcrWH QsvZYxC1MG8i4640XXbXkfEE8awn2nSqSnxWOgJPxzWT1B2gD2pN22jiL1e0PGsa Nw1kMtom9811eoTDzbdb/dKb/qvXWkHcFM1K4HG8E4Xa0YVh8JUSFYNrEeuvBz5+ P/JfYpBqJKy+oAJlcTbMBGfWsAsCAwEAAaOCAcswggHHMB0GA1UdDgQWBBQRNtDU r3awumenJukTxj/GG6iK8TAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0 cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUFBwIBFjNodHRw Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0w CAYGZ4EMAQQBMA0GCSqGSIb3DQEMBQADggIBABSFuS/oBs1+IMh6K0t92Cl7ivYg vdYmU6Zt9MfxHRxulPDQLtqorcsY2VaujA6t9NILKRtJ7cy2KlYY35Lu4jcxO/JO rTYBQq/cLxpCB3ivkNkQDvf7OUfK4TQvpcsDgfuiuWYtJHztGoFV3+zZNjuheg/Q BMzS4oxvnDnuRH9heZeGbFUpCxQiOYxCwvq+CpzWY7p3Pqr40s9g5DbF364xYcpP iu7+1O/iRWfJGefMhbsRF9HMQyqSS8YjYfzgwji9lMWJIcnyNwEdBIX8V/UGR1YM cmcJ2r0d+Rcai0ohk3gCbCu2Dd2yMcrj+ngnJ5F/EzHabvZDw/e7B5zO6aNFEA64 2je3rb4iw8Z2sdp3pnbyVtwXsDixaw9Z0p3e2R3Txjwd6Fkwmivf918EBES4t14/ h2XPPUT+dDbe4e/txuqKtpF2DYnSPYlnfoC/pb5EGR/WEyHwQi1o77l71FFFPgLx SNNFLaq73ayHaghWqhPRx0IEn13kOd8S1nTAs7VD/2JzF4icTQZHOlBNqcf6Ovvy 1yQyKcCF0eB0qHS35H7DUJehRaydcbDmBkh73BZB/N/PUZlL6469TQW3XrHOAbuJ KMft3GmzmXNc5vPRvtUUS9rUXhc0jJWEhjt4ip9xhl5kIkZhZQW9wqW1FUM/n4MV TH3i9I+C5ikH09YyMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEYX5HV6yv3a5QAAAAAA RjANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE MC8GCSqGSIb3DQEJBDEiBCCZLwLcM8qJieYZ04Atcngyo774Q2qEECpJgQIRmBiZ DzCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEIBIndkiaVD4+cUJu9zOL6g5l YdUEek4rk1FZC9z/ForOMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAARhfkdXrK/drlAAAAAABGMCIE INTYHIveKQSa5Ou3G1cW7I5Mt+CUJHe2Udof3J4IQx9BMA0GCSqGSIb3DQEBCwUA BIICAJ9I/Llf2+3OnVUrgLsTniBrqG7N6uCllFfB3IecojAAkSE2zeA0yi3h/S7D PmEnyzc5zxAlVCD2eC/BbVCMNappyKJGjid9elNulu7CCraMkBn7vGai5sTxBvmx PKeyG4lSnhaaCYguyVm90t9evb4svctWYOboUbzTJyNvkXrfwMUHmXN1gC+jyHkR qZubkwelE21FrJuF5q4uPtOJsRUPR4R7sh+lnIABW1na5tjAjXsuDaZFDFqY9Mue 7sgwaqN3qKHAbLVwV1qlQLSX8Yr+KZ+evc+yg+maAqopiaRPI7LdVb2/vgkf5+D8 696l/jKA5K0GelwoIrOWNxDZwHIE3jjjxx2KHg8ZnM+rCySx+bfNKzwpWMzEx7t6 DMr5w2NOYTQ2iH6QPW4X+3Oni5rZDvmAM2iuUR/BXp0TIcbu0npgsa0P4PLTZaqn 3puH2sKDfxZJrnex3O7uOII+6gAVOVqneucuXdqX3/9T53A8MqYrhAb1Qd3hOkIA o3uKPoA+bxpwFiZkCP+CN/QDR1faKaZ3Us/03zBd2IwVdta/0Ilb2IlLKZHGZNa4 7Pzo2qJMsX1AhbgMVogEQGU+Dzd23x6DfSOPS+ICe07jM5blywhtDaAUsISBKRmO 6eyNO28pnf3cTDiNGK90jLodoe/TpZb7h3hhcaCgJ+Ouby0Q
# SIG # End signature block
