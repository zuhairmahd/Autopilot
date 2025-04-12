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

Write-Verbose "Action to execute: $whatToDo"
if ($whatToDo -eq 'device') {
    Write-Host "Checking deployment status for device with serial number $SerialNumber."
    $global:enrollmentState = VerifyEnrollmentStatus -serialNumber $SerialNumber -AccessToken $accessToken
    Write-Host "The enrollment state is: $($enrollmentState.enrolled)"
    Write-Host "The registration state is: $($enrollmentState.registered)"
    Write-Host "The imported state is: $($enrollmentState.imported)"
    if ($enrollmentState.enrolled -eq $true) {
        Write-Host 'The device is enrolled.' -ForegroundColor Green
        Write-Host 'You may proceed with enrollment.'
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
