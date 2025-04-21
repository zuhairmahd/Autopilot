[CmdletBinding()]
param(
    [switch]$currentDevice,
    [string]$SerialNumber = '',
    [string]$userName = '',
    [string]$configFile = "$PSScriptRoot\.secrets\config.json",
    [string]$InitFile = "$PSScriptRoot\initVerify.json",
    [Parameter(Mandatory = $false, ParameterSetName = 'Batch')]
    [switch]$batchProcessingMode,
    [Parameter(Mandatory = $false, ParameterSetName = 'Batch')]
    [string]$FileName = "$PSScriptRoot\sn.txt"
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

#region Define variables
$domain = Get-Content -Path $configFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domain
# $init = Get-Content -Path $InitFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json
$init = (Get-Content -Path $InitFile -Raw -Force -ErrorAction Stop | ConvertFrom-Json | Select-Object -ExpandProperty domains).$domain
$groupsToInclude = $init.groupsToInclude
$groupsToExclude = $init.groupsToExclude
$settings = $init.settings
$choices = @('Verify this device', 'Verify another device', 'Verify a user')
if ($batchProcessingMode)
{
    Write-Verbose "Batch processing mode enabled."
    if (Test-Path $BatchProcessFileName)
    {
        Write-Verbose "Batch process file found: $BatchProcessFileName"
        $batchProcess = (Get-Content -Path $BatchProcessFileName -Raw -Force) -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }
        Write-Host "Found $($batchProcess.Count) serial numbers in $BatchProcessFileName."
        Write-Verbose "Batch process file contents: $($batchProcess)"
    }
}
#endregion Define variables

#region get user input
if ($serialNumber -ne '' -or $batchProcessingMode)
{
    Write-Verbose "Serial number passed as parameter: $SerialNumber"
    $whatToDo = 'device'
    Write-Verbose "What to do: $whatToDo"
}
elseif ($userName -ne '')
{
    Write-Verbose "User name passed as parameter: $userName"
    $whatToDo = 'user'
    Write-Verbose "What to do: $whatToDo"
}
else
{
    $choice = displayNumericMenu -choices $choices -Prompt 'Type your selection and press Enter' -Banner 'What would you like to do today?'
    switch ($choice)
    {
        'Verify this device'
        {
            $deviceObject = GetDeviceInfo -NoHash
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
                Write-Host "Could not obtain the device's serial number." -ForegroundColor Red
                Write-Host "You may need to run this script as an administrator." -ForegroundColor Red
                exit 1
            }
            $whatToDo = 'device'
        }
        'Verify another device'
        {
            Write-Host 'Please enter the serial number of the device you want to verify.'
            Write-Host 'The serial number is typically a combination of letters and numbers and is no more than 10 digits long.'
            $SerialNumber = Read-Host 'Please enter the serial number of the device'
            #validate serial number
            while (-not (validateInput -UserInput $SerialNumber -type 'serialNumber'))
            {
                #beep
                [console]::beep(1000, 500)
                Write-Host 'Invalid serial number. Enter a valid serial number.' -ForegroundColor Red
                $SerialNumber = Read-Host 'Please enter the serial number of the device'
            }
            Write-Verbose "Got serial number: $SerialNumber"
            $whatToDo = 'device'
        }
        'Verify a user'
        {
            Write-Host 'Please enter the user name (email address) of the user you want to verify.'
            Write-Host 'You can type the full email address or just the user name.'
            Write-Host "If you type just the user name, it will be converted to userName@$domain."
            Write-Host 'The user name is not case sensitive.'
            $userName = Read-Host 'Please enter the user name (email address)'
            Write-Verbose "Got user name: $userName"
            $whatToDo = 'user'
        }
        0
        {
            Write-Host 'Exiting script.'
            exit 0 
        }
    }
}
#endregion Get user input.

Write-Verbose "Action to execute: $whatToDo"
$accessToken = GetGraphAccessToken -configFile $configFile
if ($whatToDo -eq 'device')
{
    if ($batchProcessingMode)
    {
        Write-Host "Batch processing mode enabled. Processing $($batchProcess.Count) serial numbers."
        foreach ($serial in $batchProcess)
        {
            Write-Verbose "Processing serial number: $serial"
            ProcessSerialNumber -SerialNumber $serial -AccessToken $accessToken -Settings $settings
        }
        exit 0
    }
    else
    {
        $global:enrollmentState = GetDeviceEnrollmentStatus -serialNumber $SerialNumber.Trim() -AccessToken $accessToken
        ProcessSerialNumber -SerialNumber $SerialNumber -AccessToken $accessToken -Settings $settings
        # ShowDeviceReport -EnrollmentState $enrollmentState
    }
}
elseif ($whatToDo -eq 'user')
{
    Write-Verbose "Trimming user name: $userName"        
    $userName = $userName.Trim()
    Write-Verbose "Trimmed user name: $userName"
    Write-Verbose 'Checking if the user name is missing the domain suffix.'
    if ($userName -notmatch "@$domain$")
    {
        Write-Verbose 'The user name is missing the domain suffix. Adding it now.'
        $userName = "$userName@$domain"
        Write-Verbose "The user name is now: $userName"
    }
    Write-Host "Checking group membership for user $userName."
    $groups = VerifyGroupMembership -AccessToken $accessToken -userName $userName -groupsToInclude $groupsToInclude -groupsToExclude $groupsToExclude
    if ($groups -eq $true)
    {
        Write-Host "The user $userName has the correct group memberships" -ForegroundColor Green
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
    }
}
else
{
    Write-Host 'Unknown error.' -ForegroundColor Red
    Write-Host 'Please check the Intune portal or contact an Intune administrator.' -ForegroundColor Red
}