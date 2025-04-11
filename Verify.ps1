[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$configFile = "$PSScriptRoot\.secrets\config.json",
    [Parameter(Mandatory = $false)]
    [string]$InitFile = "$PSScriptRoot\initVerify.json"
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
#endregion import functions.

#region Define variables
$init = Get-Content -Path $InitFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json
$groupsToInclude = $init.groupsToInclude
$groupsToExclude = $init.groupsToExclude
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
$accessToken = GetGraphAccessToken -configFile $configFile
#endregion Define variables


#region Get user input.
Write-Host 'What would you like to do?'
$choices = @('Verify this device', 'Verify another device', 'Verify a user', 'Exit')
foreach ($i in 0..($choices.Count - 1)) {
    Write-Host "$($i + 1). $($choices[$i])"
}
$choice = Read-Host 'Please enter the number of your choice'
while ($choice -notin 1..$choices.Count) {
    Write-Host 'Please enter a valid number.' -ForegroundColor Yellow
    [console]::beep(500, 300)
    $choice = Read-Host 'Please enter the number of your choice'
}
switch ($choice) {
    1 {
        $deviceObject = GetDeviceInfo -NoHash
        if ($deviceObject) {
            $serialNumber = $deviceObject.serialNumber
            Write-Verbose "The serial number is $serialNumber."
            $make = $deviceObject.manufacturer
            Write-Verbose "The manufacturer is $make"
            $model = $deviceObject.model
            Write-Verbose "The model is $model"
            Write-Host "Checking device with serial number $($serialNumber): $make $model "
        }
        else {
            Write-Host "Could not obtain the device's serial number." -ForegroundColor Red
            Write-Host "You may need to run this script as an administrator." -ForegroundColor Red
            exit 1
        }
        $whatToDo = 'Device'
    }
    2 {
        Write-Host 'Please enter the serial number of the device you want to verify.'
        Write-Host 'The serial number is typically a combination of letters and numbers and is no more than 10 digits long.'
        $SerialNumber = Read-Host 'Please enter the serial number of the device'
        Write-Verbose "Got serial number: $SerialNumber"
        $SerialNumber = $SerialNumber.Trim()
        Write-Verbose "Trimmed serial number: $SerialNumber"
        $whatToDo = 'Device'
    }
    3 {
        Write-Host 'Please enter the user name (email address) of the user you want to verify.'
        Write-Host 'You can type the full email address or just the user name.'
        Write-Host "If you type just the user name, it will be converted to userName@$domain."
        Write-Host 'The user name is not case sensitive.'
        $userName = Read-Host 'Please enter the user name (email address)'
        Write-Verbose "Got user name: $userName"
        $userName = $userName.Trim()
        Write-Verbose "Trimmed user name: $userName"
        Write-Verbose 'Checking if the user name is missing the domain suffix.'
        if ($userName -notmatch "@$domain$") {
            Write-Verbose 'The user name is missing the domain suffix. Adding it now.'
            $userName = "$userName@$domain"
        }
        Write-Verbose "The user name is now: $userName"
        $whatToDo = 'User'
    }
    4 {
        Write-Host 'Exiting script.'
        exit 0 
    }
}
#endregion Get user input.

# #region Connect to Microsoft Graph
# if (connectToTenant($configFile))
# {
#     Write-Verbose 'Successfully connected to Microsoft Graph.' 
# }
# else
# {
#     Write-Host 'Failed to connect to Microsoft Graph.' -ForegroundColor Red
#     exit 1
# }
# $scopes = Get-MgContext | Select-Object -ExpandProperty Scopes | Sort-Object
# if ($scopes)
# {
#     Write-Verbose "The following $($scopes.Count) scopes are available:"
#     $scopes | ForEach-Object { Write-Verbose $_ }
# }
# else
# {
#     Get-MgContext | Format-List
# }
# #endregion Connect to Microsoft Graph

Write-Verbose "Action to execute: $whatToDo"
if ($whatToDo -eq 'device') {
    Write-Host "Checking deployment status for device with serial number $SerialNumber."
    $global:enrollmentState = VerifyEnrollmentStatus -serialNumber $SerialNumber -AccessToken $accessToken
    exit 0
    Write-Verbose "The enrollment state is: $($enrollmentState | Out-String)"
    if (($enrollmentState.imported -eq $false) -and ($enrollmentState.enrolled -eq $false)) {
        Write-Host "The device with serial number $SerialNumber is not imported or enrolled." -ForegroundColor Yellow
        Write-Host 'You need to import the device in Intune manually or using the provided script.' -ForegroundColor Yellow
    }
    elseif (($enrollmentState.imported -eq $true) -and ($enrollmentState.enrolled -eq $false)) {
        Write-Host 'The device is imported in Intune but is not enrolled.' -ForegroundColor Yellow
    }
    elseif (($enrollmentState.imported -eq $false) -and ($enrollmentState.enrolled -eq $true) -and ($enrollmentState.userName -ne 'unknown')) {
        Write-Host "This device is enrolled and is being used by $($enrollmentState.usersLoggedOn[0].userPrincipalName) ($($enrollmentState.DisplayName))" -ForegroundColor Green
    }
    elseif (($enrollmentState.imported -eq $true) -and ($enrollmentState.enrolled -eq $true)) {
        Write-Host 'The device is enrolled and is registered to a user.'
        if ($enrollmentState.usersLoggedOn.userPrincipalName -ne 'unknown') {
            Write-Host "The registered user is $($enrollmentState.usersLoggedOn[0].userPrincipalName) ($($enrollmentState.usersLoggedOn[0].DisplayName))" -ForegroundColor Green
            Write-Host 'You must wipe the device to get it ready for another user'
            Write-Host 'Wiping a device is a distructive command.  Make sure you are wiping the correct device.'
            Write-Host "Device id: $($enrollmentState.deviceId)"
            Write-Host "Device serial number: $SerialNumber"
            Write-Host "Registered user: $($enrollmentState.usersLoggedOn[0].userPrincipalName) `r`n"
            Write-Host 'Would you still like to send a wipe command to the device? (Y/N)'
            $response = Read-Host
            while ($response -notin 'Y', 'N') {
                Write-Host 'Please enter Y or N.' -ForegroundColor Yellow
                [console]::beep(500, 300)
                $response = Read-Host
            }
            if ($response -eq 'Y') {
                $response = SendDeviceCommand -ManagedDeviceId $enrollmentState.id
                if ($response -eq $true) {
                    Write-Host "The wipe command has been sent to the device with serial number $SerialNumber."
                    Write-Host 'Please manually sync the device or give the device enough time to sync and reset.'
                    Write-Host 'The device will be ready for another user after the wipe is complete.'
                    Write-Host 'Please contact an Intune admin if you have any problems.'
                }
                else {
                    Write-Host "The wipe command failed to send to the device with serial number $SerialNumber."
                    Write-Host 'Please contact an Intune admin.'
                }
                exit 0
            }
            else {
                Write-Host 'Aborting script.'
                exit 0
            }
        }
        else {
            Write-Host 'The user is not registered.'
        }
    }
    else {
        Write-Host 'Unknown error.' -ForegroundColor Red
        Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        exit 1
    }
}
elseif ($whatToDo -eq 'user') {
    Write-Host "Checking group membership for user $userName."
    $groups = VerifyGroupMembership -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
    if ($groups -eq $true) {
        Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
        Write-Host 'You may proceed with enrollment.'
    }
    else {
        Write-Verbose "The function returned $($groups.missingIncludeGroups.Count) missing groups and $($groups.invalidExcludeGroups.Count) invalid groups."
        Write-Verbose "Missing include groups: $($groups.missingIncludeGroups) | Out-String)"
        Write-Verbose "The function returned $($groups.invalidExcludeGroups.Count) invalid exclude groups."
        Write-Verbose "Invalid exclude groups: $($groups.invalidExcludeGroups) | Out-String)"
        if ($groups.missingIncludeGroups.Count -gt 0) {
            Write-Host 'The user needs to be added to the following groups:' -ForegroundColor Red
            foreach ($group in $groups.missingIncludeGroups) {
                Write-Host $group -ForegroundColor Red
            }
        }
        if ($groups.invalidExcludeGroups.Count -gt 0) {
            Write-Host 'The user needs to be removed from the following groups:' -ForegroundColor Red
            foreach ($group in $groups.invalidExcludeGroups) {
                Write-Host $group -ForegroundColor Red
            }
        }
        Write-Host 'Please contact an Intune administrator.' -ForegroundColor Red
    }
}
else {
    Write-Host 'Unknown error.' -ForegroundColor Red
    Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
}
