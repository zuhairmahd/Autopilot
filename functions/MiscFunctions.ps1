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

function InitializeConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [switch]$overwrite
    )
    
    #region print verbose log of received parameters
    Write-Verbose "Root folder: $RootFolder"
    Write-Verbose "InitFile: $InitFile"
    Write-Verbose "Overwrite: $overwrite"
    #endregion
    
    $initVars = @(
        [ordered] @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; default = ".\\.secrets\\config.json"; type = 'string'},
        [ordered] @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; devdefault = 'vars.json'; reldefault = 'vars.json'; default = 'vars.json'; type = 'string'},
        [ordered] @{ShowAdvancedOptions = @('True', 'False'); description = "Show advanced options in the GUI."; devdefault = 'True'; reldefault = 'True'; default = 'False'; type = 'array'},
        [ordered] @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; default = ''; type = 'string'},
        [ordered] @{name = 'maxWaitTime'; value = '60'; description = 'How long to wait before giving up on importing a device.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        [ordered] @{name = 'timeInSeconds'; value = '60'; description = 'How long to wait before initiating another check.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        [ordered] @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Github'; default = 'Github'; type = 'array'}, 
        [ordered] @{name = 'Release'; value = "2.2"; description = 'The release branch to use.'; devdefault = 'main'; reldefault = '2.2'; default = 'main'; type = 'string'}
    )
    $vars = @()
    $success = $false
    if (-not(Test-Path $InitFile))
    {
        Write-Verbose "Creating configuration file at $InitFile."
        foreach ($var in $initVars)
        {
            $vars += [ordered] @{
                name        = $var.name
                value       = $var.value
                description = $var.description
                devdefault  = $var.devdefault
                reldefault  = $var.reldefault
                default     = $var.default
                type        = $var.type
            }
        }
        $Vars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
    }
    else
    {
        if ($overwrite)
        {
            Write-Verbose "Overwriting configuration file at $InitFile."
            $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
        }
        else
        {
            Write-Host "Initialization file already exists at $InitFile."
            Write-Host "Would you like to overwrite the file?"
            $choice = Read-Host "Overwrite? (y/n)"
            while ($choice -notin ('y', 'n'))
            {
                Write-Host "Invalid input. Please enter 'y' or 'n'."
                [console]::beep(1000, 500)
                $choice = Read-Host "Overwrite? (y/n)"
            }
            if ($choice -eq 'y')
            {
                Write-Verbose "Overwriting initialization file at $InitFile."
                $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
            }
            else
            {
                Write-Host "Initialization file not overwritten."
                return $success
            }
        }
    }
    if (Test-Path $InitFile)
    {
        Write-Host "Initialization file created successfully at $InitFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create initialization file at $InitFile."
    }
    return $success
}

function CreateConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [ValidateSet('dev', 'release', 'default')]
        [string]$ConfigurationType = 'release'
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Root folder: $Folder"
    Write-Verbose "[$functionName] Init file: $InitFile"
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] ConfigurationType: $ConfigurationType"
    $success = $false
    if (Test-Path -Path $InitFile)
    {
        Write-Verbose "[$functionName] Found init file at $InitFile."
        $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    }
    else
    {
        Write-Host "No init file found at $InitFile."
        Write-Host "Creating init file at $InitFile."
        if (InitializeConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Init file created successfully."
            $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
        }
        else
        {
            Write-Host "Failed to create init file."
            return $success
        }
    }
    $data = @{}
    #endregion
    
    Write-Verbose "[$functionName] Found $($valuesToEdit.PSCustomObject.Count) properties."
    #Iterate over the ValuesToEdit and create the config data
    foreach ($value in $valuesToEdit)
    {
        Write-Verbose "[$functionName] Processing property name: $($value.Name)"
        switch ($ConfigurationType)
        {
            'release'
            {
                Write-Verbose "[$functionName] Name: $($value.Name)"
                Write-Verbose "[$functionName] Release Value: $($value.reldefault)"
                $Data += [ordered] @{$value.Name = $value.relDefault}
            }
            'dev'
            {
                Write-Verbose "[$functionName] Name: $($value.Name)"
                Write-Verbose "[$functionName] Dev Value: $($value.devdefault)"
                $Data += [ordered] @{$value.Name = $value.devdefault}
            }
            'default'
            {
                Write-Verbose "[$functionName] Name: $($value.Name)"
                Write-Verbose "[$functionName] Default Value: $($value.default)"
                $Data += [ordered] @{$value.Name = $value.default}
            }
        }
    }
    Write-Verbose "[$functionName] Config data: $($Data | ConvertTo-Json -Depth 10)"
    #write the config data to the configuration file
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    #Check to make sure it was written.
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "[$functionName] Configuration file created successfully at $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create configuration file at $ConfigurationFile."
        $success = $false
    }
    #Return the success status
    return $success
}

function CreateFullConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [string]$InitFile = "$RootFolder\init.json"
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] RootFolder: $RootFolder"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    $success = $false
    if (-not(Test-Path -Path $InitFile))
    {
        Write-Host "No init file found at $InitFile."
        Write-Host "Creating init file at $InitFile."
        if (InitializeConfiguration -RootFolder $RootFolder -InitFile $InitFile)
        {
            Write-Host "Init file created successfully."
        }
        else
        {
            Write-Host "Failed to create init file."
            return $success
        }
    }
    Write-Verbose "[$functionName] Reading init file at $InitFile."
    $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    $configData = @()
    #endregion
    
    #region Load parameters from the configuration file if it exists
    if (-not(Test-Path -Path $ConfigurationFile))
    {
        Write-Host "No configuration file found at $ConfigurationFile."
        Write-Host "Creating configuration file at $ConfigurationFile."
        if (CreateConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Configuration file created successfully."
        }
        else
        {
            Write-Host "Failed to create configuration file."
            return $success
        }
    }
    Write-Host " Loading configuration values from $ConfigurationFile."
    $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
    Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    #endregion
    
    #itterate over the configuration data and prompt the user to choose a value
    foreach ($config in $configData.PSObject.Properties)
    {
        Write-Verbose "[$functionName] Configuration: $($config.Name) = $($config.Value)"
        if ($valuesToEdit.name -contains $config.Name)
        {
            $configType = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).type
            $configDescription = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).description
            $configValue = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).value
            if ($configValue -eq '')
            {
                Write-Verbose "[$functionName] Config value is empty."
                Write-Verbose "[$functionName] Setting config value to 'none'."
                $configValue = 'none'
            }
            Write-Verbose "[$functionName] Stored Key name: $($config.Name)"
            Write-Verbose "[$functionName] Stored Key value: $($config.Value)"
            Write-Verbose "[$functionName] Possible Key values: $configValue"
            Write-Verbose "[$functionName] Key description: $configDescription"
            Write-Verbose "[$functionName] Key type: $configType"
            switch ($configType)
            {
                'string'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Description: $($configDescription)"
                    $value = Read-Host -Prompt "Press enter to keep the current value: ($($config.Value))"
                    if ($value -eq '' -or $null -eq $value)
                    {
                        $value = $config.Value
                    }
                    Write-Host "New value: $value"
                    Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                'array'
                {
                    Write-Host "Please enter a new value for $($config.Name)."
                    Write-Host "Press enter to keep the current value: $($config.Value)."
                    Write-Host "Description: $($configDescription)"
                    foreach ($item in $configValue)
                    {
                        Write-Host "[$($configValue.IndexOf($item)+1)] $item"
                        if ($config.Value -contains $item)
                        {
                            $currentlySelected = $configValue.IndexOf($item) + 1
                            Write-Verbose "[$functionName] The currently selected value is $currentlySelected"
                        }
                    }
                    $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    while ($value -lt 1 -or $value -gt $configValue.Count -and $value -ne '')
                    {
                        Write-Host "Invalid choice."
                        [console]::beep(500, 300)
                        $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    }
                    if ($value -eq '')
                    {
                        $value = $config.Value
                    }
                    else
                    {
                        $value = $configValue[$value - 1]
                    }
                    Write-Host "Value: $value"
                    Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                    $config.Value = $value
                }
                'static'
                {
                    Write-Verbose "[$functionName] This is a static value and cannot be changed."
                    Write-Host "Value: $($config.Value)"
                }
            }
        }
    } # Closing brace for foreach loop
    #Print all the new configuration data but only in verbose mode.
    Write-Verbose "[$functionName] New configuration data:"
    $configData.PSObject.Properties | ForEach-Object {
        Write-Verbose "[$functionName] $($_.Name) = $($_.Value)"
    }
    #Save the new configuration data to the configuration file
    Write-Verbose "[$functionName] Saving configuration to $ConfigurationFile."
    $configData | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
    Write-Verbose "[$functionName] Checking if configuration file exists."
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Verbose "[$functionName] Failed to save configuration to $ConfigurationFile."
    }
    return $success
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
    )
    $functionName = $MyInvocation.MyCommand.Name
    $processedUser = [ordered] @{}
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

function MergeSettings()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $localSettings,
        [Parameter(Mandatory = $true)]
        $globalSettings,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Local', 'Global')]
        [string]$ConflictResolution = 'Global'
    )
    $functionName = $MyInvocation.MyCommand.Name
    $merged = @{}
    
    # Helper function to flatten a nested object into a flat hashtable
    function ConvertTo-FlatHashtable($object, $prefix = '')
    {
        $flatHash = @{}
        $functionName = $MyInvocation.MyCommand.Name
        if ($object -is [hashtable] -or $object -is [System.Collections.IDictionary])
        {
            Write-Verbose "[$functionName] Flattening hashtable/dictionary with $($object.Keys.Count) keys"
            foreach ($key in $object.Keys)
            {
                $fullKey = if ($prefix)
                {
                    "$prefix.$key" 
                }
                else
                {
                    $key 
                }
                $value = $object[$key]
                
                if (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                    ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0))
                {
                    Write-Verbose "[$functionName] Found nested object at key: $fullKey"
                    $nestedFlat = ConvertTo-FlatHashtable $value $fullKey
                    foreach ($nestedKey in $nestedFlat.Keys)
                    {
                        $flatHash[$nestedKey] = $nestedFlat[$nestedKey]
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Adding flat key: $fullKey"
                    $flatHash[$fullKey] = $value
                }
            }
        }
        elseif ($object -is [PSCustomObject])
        {
            Write-Verbose "[$functionName] Flattening PSCustomObject with $($object.PSObject.Properties.Count) properties"
            foreach ($property in $object.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' })
            {
                $fullKey = if ($prefix)
                {
                    "$prefix.$($property.Name)" 
                }
                else
                {
                    $property.Name 
                }
                $value = $property.Value
                
                if (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                    ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0))
                {
                    Write-Verbose "[$functionName] Found nested object at property: $fullKey"
                    $nestedFlat = ConvertTo-FlatHashtable $value $fullKey
                    foreach ($nestedKey in $nestedFlat.Keys)
                    {
                        $flatHash[$nestedKey] = $nestedFlat[$nestedKey]
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Adding flat property: $fullKey"
                    $flatHash[$fullKey] = $value
                }
            }
        }
        else
        {
            # If it's a simple value, just return it with the prefix as key
            if ($prefix)
            {
                $flatHash[$prefix] = $object
            }
        }
        
        return $flatHash
    }    Write-Verbose "[$functionName] Merging settings with conflict resolution: $ConflictResolution"
    
    # Flatten local settings
    Write-Verbose "[$functionName] Flattening local settings"
    $flatLocalSettings = ConvertTo-FlatHashtable $localSettings
    Write-Verbose "[$functionName] Local settings flattened to $($flatLocalSettings.Count) properties"
    
    # Flatten global settings
    Write-Verbose "[$functionName] Flattening global settings"
    $flatGlobalSettings = ConvertTo-FlatHashtable $globalSettings
    Write-Verbose "[$functionName] Global settings flattened to $($flatGlobalSettings.Count) properties"
    
    # Normalize all keys to simple format (remove any prefixes)
    function Get-SimpleKey($key)
    {
        if ($key.Contains('.'))
        {
            return $key.Split('.')[-1]  # Get the last part after the last dot
        }
        return $key
    }
    
    # Create normalized hashtables with simple keys
    $normalizedLocal = @{}
    foreach ($key in $flatLocalSettings.Keys)
    {
        $simpleKey = Get-SimpleKey $key
        $normalizedLocal[$simpleKey] = $flatLocalSettings[$key]
        Write-Verbose "[$functionName] Normalized local key: $key -> $simpleKey"
    }
    
    $normalizedGlobal = @{}
    foreach ($key in $flatGlobalSettings.Keys)
    {
        $simpleKey = Get-SimpleKey $key
        $normalizedGlobal[$simpleKey] = $flatGlobalSettings[$key]
        Write-Verbose "[$functionName] Normalized global key: $key -> $simpleKey"
    }
    
    # Start with local settings
    foreach ($key in $normalizedLocal.Keys)
    {
        $merged[$key] = $normalizedLocal[$key]
        Write-Verbose "[$functionName] Added local setting: $key"
    }
    
    # Merge global settings
    foreach ($key in $normalizedGlobal.Keys)
    {
        if ($merged.ContainsKey($key))
        {
            Write-Verbose "[$functionName] Conflict detected for property: $key"
            
            # If both are arrays, merge arrays
            if ($merged[$key] -is [System.Collections.IEnumerable] -and
                $normalizedGlobal[$key] -is [System.Collections.IEnumerable] -and
                ($merged[$key] -isnot [string]) -and
                ($normalizedGlobal[$key] -isnot [string]))
            {
                Write-Verbose "[$functionName] Both values are arrays, merging arrays for: $key"
                $merged[$key] = @($merged[$key] + $normalizedGlobal[$key])
            }
            else
            {
                # Handle conflict based on ConflictResolution parameter
                if ($ConflictResolution -eq 'Global')
                {
                    Write-Verbose "[$functionName] Resolving conflict by using global value for: $key"
                    $merged[$key] = $normalizedGlobal[$key]
                }
                else
                {
                    Write-Verbose "[$functionName] Resolving conflict by keeping local value for: $key"
                    # Keep the existing local value (do nothing)
                }
            }
        }
        else
        {
            $merged[$key] = $normalizedGlobal[$key]
            Write-Verbose "[$functionName] Added global setting: $key"
        }
    }
    
    Write-Verbose "[$functionName] Final merged settings count: $($merged.Count)"
    return $merged
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
        Write-Verbose "[$functionName] Entering validation loop"
        $inputItem = Read-Host $Prompt
        Write-Verbose "[$functionName] Item entered: '$inputItem'" # Added quotes for clarity
        # Check if the user just pressed Enter (empty string OR null)
        if ($null -eq $inputItem -or $inputItem -eq '')
        {
            Write-Verbose "[$functionName] User pressed Enter. Returning $BackoutText."
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
