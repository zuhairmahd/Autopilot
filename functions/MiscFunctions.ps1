function CreateSecretsFile()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$SecretsFile = "$RootFolder\.secrets\secrets.json"
    )
    
    #region print verbose log of received parameters
    Write-Verbose "Root folder: $RootFolder"
    Write-Verbose "SecretsFile: $SecretsFile"
    #endregion
    
    if (-not(Test-Path $SecretsFile))
    {
        Write-Verbose "Creating secrets file at $SecretsFile."
        $secrets = @{}
        $secrets | ConvertTo-Json -Depth 10 | Set-Content -Path $SecretsFile -Force
        Write-Host "Secrets file created successfully at $SecretsFile."
    }
    else
    {
        Write-Host "Secrets file already exists at $SecretsFile."
    }
}

function GetTimeZoneAbbreviation()
{
    param (
        [Parameter(Mandatory = $true)]
        [DateTime]$DateTime
    )
    $functionName = $MyInvocation.MyCommand.Name    
    # Get the current time zone
    Write-Verbose "[$functionName] Getting current time zone."
    $timeZone = [System.TimeZoneInfo]::Local
    Write-Verbose "[$functionName] Current time zone: $($timeZone.DisplayName)"
    
    # Check if it's daylight saving time
    Write-Verbose "[$functionName] Checking if it's daylight saving time."
    $isDaylightSavingTime = $timeZone.IsDaylightSavingTime($DateTime)
    Write-Verbose "[$functionName] Is daylight saving time: $isDaylightSavingTime"
    
    # Get the display name
    Write-Verbose "[$functionName] Getting display name."
    $displayName = if ($isDaylightSavingTime)
    {
        Write-Verbose "[$functionName] Getting daylight name."
        $timeZone.DaylightName 
        Write-Verbose "[$functionName] Daylight name: $($timeZone.DaylightName)"
    }
    else
    {
        Write-Verbose "[$functionName] Getting standard name."
        $timeZone.StandardName 
        Write-Verbose "[$functionName] Standard name: $($timeZone.StandardName)"
    }
    
    # Try to extract abbreviation from display name (usually in parentheses)
    Write-Verbose "[$functionName] Extracting abbreviation from display name."
    if ($displayName -match '\(([A-Z]{3})\)')
    {
        Write-Verbose "[$functionName] Found abbreviation in display name."
        return $matches[1]
    }
    
    # If no abbreviation in parentheses, create one from the time zone id
    Write-Verbose "[$functionName] No abbreviation found in display name. Creating one from time zone ID."
    $abbreviation = switch -Regex ($timeZone.Id)
    {
        'Eastern'
        {
            Write-Verbose "[$functionName] Time zone ID is Eastern."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'EDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: EDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'EST' 
                Write-Verbose "[$functionName] Standard time abbreviation: EST"
            } 
        }
        'Central'
        {
            Write-Verbose "[$functionName] Time zone ID is Central."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'CDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: CDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'CST' 
                Write-Verbose "[$functionName] Standard time abbreviation: CST"
            } 
        }
        'Mountain'
        {
            Write-Verbose "[$functionName] Time zone ID is Mountain."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'MDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: MDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'MST' 
                Write-Verbose "[$functionName] Standard time abbreviation: MST"
            } 
        }
        'Pacific'
        {
            Write-Verbose "[$functionName] Time zone ID is Pacific."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'PDT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: PDT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'PST' 
                Write-Verbose "[$functionName] Standard time abbreviation: PST"
            } 
        }
        'Alaska'
        {
            Write-Verbose "[$functionName] Time zone ID is Alaska."
            if ($isDaylightSavingTime)
            {
                Write-Verbose "[$functionName] Daylight saving time is true."
                'ADT' 
                Write-Verbose "[$functionName] Daylight saving time abbreviation: ADT"
            }
            else
            {
                Write-Verbose "[$functionName] Daylight saving time is false."
                'AST' 
                Write-Verbose "[$functionName] Standard time abbreviation: AST"
            } 
        }
        'Hawaii'
        {
            Write-Verbose "[$functionName] Time zone ID is Hawaii."
            'HST' 
            Write-Verbose "[$functionName] Standard time abbreviation: HST"
        }
        default
        { 
            Write-Verbose "[$functionName] Time zone ID is not recognized. Creating abbreviation from offset."
            # Create abbreviation from offset
            $offset = $timeZone.GetUtcOffset($DateTime)
            Write-Verbose "[$functionName] Offset: $offset"
            Write-Verbose "[$functionName] Total hours: $($offset.TotalHours)"
            $prefix = if ($offset.TotalHours -ge 0)
            {
                Write-Verbose "[$functionName] Offset is positive."
                '+' 
            }
            else
            {
                Write-Verbose "[$functionName] Offset is negative."
                '-' 
            }
            Write-Verbose "[$functionName] Prefix: $prefix"
            "UTC$prefix$([Math]::Abs($offset.TotalHours))"
            Write-Verbose "[$functionName] Abbreviation: UTC$prefix$([Math]::Abs($offset.TotalHours))"
        }
    }
    Write-Verbose "[$functionName] Final abbreviation: $abbreviation"
    return $abbreviation
}

function FormatDateWithTimeZone()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        $DateTime
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #Print verbose log of parameters
    Write-Verbose "[$functionName] Received parameters $DateTime"
    #Verify the passed datetime is a valid date.
    Write-Verbose "[$functionName] Verifying DateTime: $($DateTime | Out-String)"
    #If the datetime is passed as a string, convert it to a datetime object.
    if ($DateTime -is [string])
    {
        Write-Verbose "[$functionName] Converting string to DateTime."
        $DateTime = [System.DateTime]::Parse($DateTime)
    }
    if ($null -eq $DateTime -or $DateTime -eq [System.DateTime]::MinValue)
    {
        Write-Verbose "[$functionName] Invalid DateTime provided."
        return $null
    }
    Write-Verbose "[$functionName] DateTime is valid."
    
    # Convert from UTC to local time if the datetime is in UTC
    if ($DateTime.Kind -eq [System.DateTimeKind]::Utc)
    {
        Write-Verbose "[$functionName] Converting UTC DateTime to local time."
        $DateTime = $DateTime.ToLocalTime()
    }
    
    Write-Verbose "[$functionName] Formatting DateTime: $($DateTime | Out-String)"
    # Get the timezone abbreviation
    $tzAbbreviation = GetTimeZoneAbbreviation -DateTime $DateTime
    Write-Verbose "[$functionName] Time zone abbreviation: $tzAbbreviation"
    
    # Format the date without timezone, then append our custom abbreviation
    $formattedDate = $DateTime | Get-Date -Format "dddd, MMMM d, yyyy h:mm:ss tt"
    $formattedWithTz = "$formattedDate $tzAbbreviation"
    
    Write-Verbose "[$functionName] Formatted DateTime: $formattedWithTz"
    return $formattedWithTz
}

function normalizeADUserDisplayName()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDisplayName
    )    $functionName = $MyInvocation.MyCommand.Name
    # PowerShell 5.1 compatible - using regular hashtable
    $processedUser = @{}
    # Convert "Lastname, Firstname Middle (nickname)" to "Firstname Middle Lastname (nickname)" if nickname exists,
    # otherwise to "Firstname Middle Lastname"
    # Also handles "Lastname, Firstname M." format where M. is a middle initial
    Write-Verbose "[$functionName] Converting user display name: $UserDisplayName"
    if ($UserDisplayName -match '^(.*), (.*?)(?:\s([A-Z]\.?))?(?: \((.*?)\))?$')
    {
        Write-Verbose "[$functionName] Extracting first name, last name, middle initial and nickname."
        $lastName = $matches[1].Trim()
        Write-Verbose "[$functionName] Last name: $lastName"
        $firstName = $matches[2].Trim()
        Write-Verbose "[$functionName] First name: $firstName"
        $middleInitial = if ($matches[3])
        {
            $matches[3].Trim() 
            Write-Verbose "[$functionName] Middle initial: $middleInitial"
        }
        else
        {
            $null 
            Write-Verbose "[$functionName] No middle initial found."
        }
        $nickname = $matches[4]
        Write-Verbose "[$functionName] Nickname: $nickname"
        $fullName = if ($middleInitial)
        {
            "$firstName $middleInitial $lastName"
            Write-Verbose "[$functionName] Full name with middle initial: $fullName"
        }
        else
        {
            "$firstName $lastName"
            Write-Verbose "[$functionName] Full name without middle initial: $fullName"
        }
        if ($nickname)
        {
            Write-Verbose "[$functionName] Nickname found: $nickname"
            $currentUser = "$fullName ($nickname)"
            Write-Verbose "[$functionName] Current user with nickname: $currentUser"
        }
        else
        {
            Write-Verbose "[$functionName] No nickname found."
            $currentUser = $fullName
            Write-Verbose "[$functionName] Current user without nickname: $currentUser"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No match found for user display name format."
        Write-Verbose "[$functionName] Returning original display name."
        $currentUser = $UserDisplayName
    }
    #Add what we got the the processedUser hashtable
    $processedUser.Add('FullName', $currentUser)
    $processedUser.Add('FirstName', $firstName)
    $processedUser.Add('LastName', $lastName)
    $processedUser.Add('MiddleInitial', $middleInitial)
    $processedUser.Add('Nickname', $nickname)
    return $processedUser
}

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
        Write-Verbose "[$functionName] Entering validation loop"
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $($returnValues.backoutText)."
            return $null # Return null to signal going back
        }
        # Validate the input if it's not empty
        Write-Verbose "[$functionName] Validating input $inputItem as $InputType"
        $validationResult = validateInput -UserInput $inputItem -type $InputType -settings $settings
        Write-Verbose "[$functionName] Validation result: $($validationResult.valid)"
        Write-Verbose "[$functionName] Validation value: $($validationResult.value)"
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
    Write-Verbose "[$functionName] Exiting GetUserInput function"
}

function DisplayUserList()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$UserList,
        [Parameter(Mandatory = $false)]
        [int]$maxDisplay = 10
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Displaying user list"

    if ($UserList.Count -eq 0)
    {
        Write-Host "No users found." -ForegroundColor Yellow
        return $returnValues.noUserFoundInDirectoryMessage
    }
    if ($userList.count -gt $maxDisplay)
    {
        Write-Verbose "[$functionName] User list has more than $maxDisplay users, truncating to $maxDisplay."
        $UserList = $UserList | Select-Object -First $maxDisplay
    }
    # Create user selection menu
    $userMenu = NewMenu -Title "Select a user" -Description "Did you mean:"
    # Store devices in an array to reference later
    $users = $UserList
    Write-Verbose "[$functionName] Creating user menu with $($userList.Count) users."
    # Add each user as a menu item
    foreach ($user in $users)
    {
        # Create a display name for the menu
        $menuItemName = "$($user.displayName): ($($user.userPrincipalName))"
        Write-Verbose "[$functionName] Adding menu item: $menuItemName"
        # Create a scriptblock action that returns This specific user id when selected.
        $UPN = $user.userPrincipalName
        Write-Verbose "[$functionName] Creating action for user: $user"
        $action = {
            Write-Verbose "[$functionName] Returning user name: $($UPN)"
            return $UPN
        }.GetNewClosure()
        # Add the menu item with the action
        $userMenu = AddMenuItem -Menu $userMenu -Name $menuItemName -Action $action -ReturnsValue
    }
    Write-Verbose "[$functionName] Showing user selection menu with $($userMenu.Items.Count) items"
    Write-Verbose "[$functionName] Current navigation - Depth: $Depth, History count: $($History.Count)"
    Write-Verbose "[$functionName] Current menu title: $($userMenu.Title)"
    $selectedUser = ShowMenu -Menu $userMenu -CalledBy 'Action'
    if ($null -ne $selectedUser -and $selectedUser -is [string])
    {
        Write-Verbose "[$functionName] Selected user: $selectedUser"
    }
    else
    {
        Write-Verbose "[$functionName] Selected user is null or not a string"
    }
    return $selectedUser
}


function Write-Log()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Normal')]
        [string]$Message,
        [Parameter(Mandatory = $true, ParameterSetName = 'Normal')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StartLogging')]
        [Parameter(Mandatory = $true, ParameterSetName = 'FinishLogging')]
        [ValidateScript({
                $parentDir = Split-Path $_ -Parent
                if (-not (Test-Path $parentDir))
                {
                    try
                    {
                        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    }
                    catch
                    {
                        throw "Failed to create log directory: $_. Exception: $($_.Exception.Message)"
                    }
                }
                return $true
            })]
        [string]$LogFile,
        [Parameter(Mandatory = $true, ParameterSetName = 'Normal')]
        [string]$Module,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [ValidateSet("Verbose", "Debug", "Information", "Warning", "Error")]
        [string]$LogLevel = "Information",
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [Parameter(Mandatory = $false, ParameterSetName = 'StartLogging')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FinishLogging')]
        [switch]$CMTraceFormat,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [Parameter(Mandatory = $false, ParameterSetName = 'StartLogging')]
        [Parameter(Mandatory = $false, ParameterSetName = 'FinishLogging')]
        [int]$MaxLogSizeMB = 10,
        [Parameter(Mandatory = $false, ParameterSetName = 'Normal')]
        [switch]$PassThru,
        [Parameter(Mandatory = $true, ParameterSetName = 'StartLogging')]
        [switch]$StartLogging,
        [Parameter(Mandatory = $true, ParameterSetName = 'FinishLogging')]
        [switch]$FinishLogging
    )
    try
    {
        # Handle StartLogging and FinishLogging switches
        if ($StartLogging -or $FinishLogging)
        {
            # Set default values when using StartLogging or FinishLogging
            $Module = $MyInvocation.MyCommand.Name
            $LogLevel = "Information"
            
            # Create separator line
            $separatorLine = "=" * 80
            
            # Ensure log directory exists
            $logDir = Split-Path $LogFile -Parent
            if (-not (Test-Path $logDir))
            {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Check for log rotation if file exists and is too large
            if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt ($MaxLogSizeMB * 1MB))
            {
                $archiveFile = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $LogFile -Destination $archiveFile -Force
                Write-Verbose "Log file rotated to: $archiveFile"
            }
            
            if ($CMTraceFormat)
            {
                # For CMTrace format, still use the separator but in CMTrace format
                $cmTime = Get-Date -Format "HH:mm:ss.fff+000"
                $cmDate = Get-Date -Format "MM-dd-yyyy"
                $thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                $logEntry = "<![LOG[$separatorLine]LOG]!><time=`"$cmTime`" date=`"$cmDate`" component=`"$Module`" context=`"`" type=`"1`" thread=`"$thread`" file=`"`">"
            }
            else
            {
                # For standard format, just use the separator line without timestamp
                $logEntry = $separatorLine
            }
            
            # Use mutex for thread safety
            $mutexName = "LogMutex_" + ($LogFile -replace '[\\/:*?"<>|]', '_')
            $mutex = New-Object System.Threading.Mutex($false, $mutexName)
            
            try
            {
                $mutex.WaitOne() | Out-Null
                Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -Force
            }
            finally
            {
                $mutex.ReleaseMutex()
                $mutex.Dispose()
            }
            
            # Write to console
            Write-Host $separatorLine
            
            return
        }
        
        # Ensure log directory exists
        $logDir = Split-Path $LogFile -Parent
        if (-not (Test-Path $logDir))
        {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        # Check for log rotation if file exists and is too large
        if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt ($MaxLogSizeMB * 1MB))
        {
            $archiveFile = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Move-Item -Path $LogFile -Destination $archiveFile -Force
            Write-Verbose "Log file rotated to: $archiveFile"
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        
        if ($CMTraceFormat)
        {
            # True CMTrace format: <![LOG[Message]LOG]!><time="HH:mm:ss.fff+000" date="MM-dd-yyyy" component="Component" context="" type="1" thread="1234" file="">
            $cmTime = Get-Date -Format "HH:mm:ss.fff+000"
            $cmDate = Get-Date -Format "MM-dd-yyyy"
            $severity = switch ($LogLevel)
            {
                "Error"
                {
                    3 
                }
                "Warning"
                {
                    2 
                }
                default
                {
                    1 
                }
            }
            $logEntry = "<![LOG[$Message]LOG]!><time=`"$cmTime`" date=`"$cmDate`" component=`"$Module`" context=`"`" type=`"$severity`" thread=`"$thread`" file=`"`">"
        }
        else
        {
            # Enhanced standard format with thread ID
            $logEntry = "$timestamp [$LogLevel] [$Module] [Thread:$thread] $Message"
        }
        
        # Use mutex for thread safety in concurrent scenarios
        $mutexName = "LogMutex_" + ($LogFile -replace '[\\/:*?"<>|]', '_')
        $mutex = New-Object System.Threading.Mutex($false, $mutexName)
        
        try
        {
            $mutex.WaitOne() | Out-Null
            Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -Force
        }
        finally
        {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
        
        # Write to appropriate PowerShell stream based on log level
        switch ($LogLevel)
        {
            "Error"
            {
                Write-Error "[$Module] $Message" -ErrorAction SilentlyContinue 
            }
            "Warning"
            {
                Write-Warning "[$Module] $Message" 
            }
            "Verbose"
            {
                Write-Verbose "[$Module] $Message" 
            }
            "Debug"
            {
                Write-Debug "[$Module] $Message" 
            }
            default
            {
                Write-Verbose "Logged: $logEntry" 
            }
        }
        
        # Return log entry if PassThru is specified
        if ($PassThru)
        {
            return [PSCustomObject]@{
                Timestamp = $timestamp
                LogLevel  = $LogLevel
                Module    = $Module
                Message   = $Message
                Thread    = $thread
                LogFile   = $LogFile
                Entry     = $logEntry
            }
        }
    }
    catch
    {
        Write-Error "Failed to write to log file '$LogFile': $_"
        # Fallback to console output
        Write-Host "$timestamp [$LogLevel] [$Module] $Message" -ForegroundColor $(
            switch ($LogLevel)
            {
                "Error"
                {
                    "Red" 
                }
                "Warning"
                {
                    "Yellow" 
                }
                "Debug"
                {
                    "Cyan" 
                }
                default
                {
                    "White" 
                }
            }
        )
    }
}

