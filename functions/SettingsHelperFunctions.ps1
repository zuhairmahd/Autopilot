function Get-StringsFromJson
<#
.SYNOPSIS
    Loads localized strings and messages from strings.json with comprehensive fallback support.

.DESCRIPTION
    This function loads localized strings, return values, device states, and device actions from
    the strings.json file. It uses the consolidated Get-JsonConfiguration function to provide
    robust JSON handling, validation, and fallback to default values when the file is missing
    or contains invalid data.

.PARAMETER StringsFile
    The path to the strings.json file. Defaults to "$PWD\strings.json".

.OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with three main sections:
    - returnValues: Messages for various operation results
    - deviceStates: Device state descriptions  
    - deviceActions: Available device actions

.EXAMPLE
    # Load strings from default location
    $strings = Get-StringsFromJson

.EXAMPLE  
    # Load strings from custom location
    $strings = Get-StringsFromJson -StringsFile "C:\Config\custom-strings.json"

.NOTES
    - Uses the consolidated Get-JsonConfiguration function for consistency
    - Provides comprehensive default values for all string categories
    - Handles missing files and invalid JSON gracefully
    - Maintains backward compatibility with existing code
    - Includes detailed logging for troubleshooting
#>
{
    [CmdletBinding()]
    param(
        [string]$StringsFile = "$PWD\strings.json"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Attempting to load strings from: $StringsFile"
    # Default fallback values organized by sections - PowerShell 5.1 compatible
    $defaultStringValues = @{
        returnValues  = @{
            unknownErrorMessage            = 'An unknown error occurred'
            noRestartMessage               = 'Device not restarted.'
            EnrolledMessage                = 'The device is enrolled.'
            notContactedMessage            = 'The device has not contacted the enrollment service.'
            PendingResetMessage            = 'The device is pending a reset.'
            EnrollmentFailedMessage        = 'The device enrollment failed.'
            deviceNotAssignedMessage       = 'The device is not assigned to a deployment profile.'
            deviceAssignmentPendingMessage = 'The device is pending assignment to a deployment profile.'
            deviceNotInIntuneMessage       = 'The device is not in Intune.'
            noUserDeviceFoundMessage       = 'No user or device found.'
            noUserFoundInDirectoryMessage  = 'This user does not exist'
            deviceUnknownActionMessage     = 'The action may still be in progress. You can check the device status in the Intune portal'
            deviceImportSuccessMessage     = 'The device was imported successfully.'
            deviceImportFailedMessage      = 'The device import failed.'
            deviceDeleteSuccessMessage     = 'The device was deleted successfully.'
            deviceDeleteFailedMessage      = 'The device deletion failed.'
            deviceWipeSuccessMessage       = 'The device was wiped successfully'
            deviceWipeFailedMessage        = 'The device wipe failed'
            deviceSyncSuccessMessage       = 'The device sync was successful'
            deviceSyncFailedMessage        = 'The device sync failed'
            deviceCleanSuccessMessage      = 'The device was cleaned successfully'
            deviceCleanFailedMessage       = 'The device clean failed'
            deviceRestartSuccessMessage    = 'The device was restarted successfully.'
            deviceRestartFailedMessage     = 'The device restart failed'
            serialNumberNotFoundMessage    = 'Serial number was not found'
            UpdateFailedMessage            = 'Could not download update.'
            noAccessTokenMessage           = 'Could not obtain an access token. Please check your credentials.'
            UpdateSuccessMessage           = 'The script was updated successfully.'
            UpdateNotNeededMessage         = 'The script is already up to date.'
            userCanceledMessage            = 'Operation canceled by user'
            999                            = 'No updates were found'
            1000                           = 'All updates were installed'
            1001                           = 'Some updates were installed'
            10002                          = 'Some updates were installed'
            1003                           = 'Updates failed to install'
        }
        deviceStates  = @{
            Ready    = 'The device is ready for the next user'
            NotReady = 'The device is not ready for the next user'
        }
        deviceActions = @{
            none            = 'No action'
            contactAdmin    = 'Contact an Intune administrator'
            contactHelpdesk = 'Contact the helpdesk'
            WipeOrClean     = 'Wipe or clean the device'
        }
    }
    
    try
    {
        # Use the consolidated configuration loader
        Write-Log -LogFile $LogFile -Module $functionName -Message "Loading strings configuration from: $StringsFile" -LogLevel "Debug"
        $stringsConfig = Get-JsonConfiguration -JsonFile $StringsFile -DefaultValues $defaultStringValues
        Write-Verbose "[$functionName] Successfully loaded strings configuration"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully loaded strings configuration" -LogLevel "Debug"
        return $stringsConfig
    }
    catch
    {
        Write-Warning "[$functionName] Failed to load strings configuration: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning default values"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load strings configuration: $($_.Exception.Message)" -LogLevel "Error"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Returning default values" -LogLevel "Warning"
        return $defaultStringValues
    }
}

function Get-JsonConfiguration
<#
.SYNOPSIS
    Universal JSON configuration loader with fallback support and validation.

.DESCRIPTION
    This function provides a consolidated approach for loading JSON configuration files with robust 
    error handling, validation, and fallback mechanisms. It supports multiple configuration formats:
    - Simple flat JSON objects
    - Complex structured JSON with sections (like strings.json)
    - Configuration arrays with environment-specific values (like init.json)

.PARAMETER JsonFile
    The full path to the JSON configuration file to load.

.PARAMETER DefaultValues
    A hashtable containing default values to use if the JSON file cannot be loaded or contains
    missing keys. For structured JSON, this should contain sections matching the JSON structure.

.PARAMETER ConfigurationType
    For init.json files, specifies which configuration values to use:
    - 'dev': Uses devdefault values
    - 'release': Uses reldefault values  
    - 'default': Uses default values
    For other JSON types, this parameter is ignored.

.OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable containing the loaded configuration. Structure depends on the JSON format:
    - Simple JSON: Flat hashtable with key-value pairs
    - Structured JSON: Nested hashtable with sections
    - Init JSON: Flat hashtable with processed configuration values

.EXAMPLE
    # Load strings configuration with fallback
    $defaultStrings = @{
        returnValues = @{ message1 = 'Default message' }
        deviceStates = @{ Ready = 'Device ready' }
    }
    $config = Get-JsonConfiguration -JsonFile "strings.json" -DefaultValues $defaultStrings

.EXAMPLE
    # Load init configuration for release environment
    $defaults = @{ configFile = 'config.json'; maxWaitTime = '30' }
    $config = Get-JsonConfiguration -JsonFile "init.json" -DefaultValues $defaults -ConfigurationType 'release'

.NOTES
    - Validates JSON syntax before processing
    - Preserves ordered hashtables where applicable
    - Merges JSON values with defaults, prioritizing JSON values
    - Adds comprehensive logging for troubleshooting
    - Gracefully handles missing files, invalid JSON, and missing keys
#>
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFile,
        [Parameter(Mandatory = $true)]
        [hashtable]$DefaultValues,
        [string]$ConfigurationType = 'default'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Attempting to load configuration from: $JsonFile" -LogLevel "Debug"
    Write-Verbose "[$functionName] Attempting to load configuration from: $JsonFile"
    Write-Verbose "[$functionName] Configuration Type: $ConfigurationType"
    
    try
    {
        if (Test-Path -Path $JsonFile)
        {
            Write-Verbose "[$functionName] Loading configuration from JSON file: $JsonFile"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Loading configuration from JSON file: $JsonFile" -LogLevel "Debug"
            $jsonContent = Get-Content -Path $JsonFile -Raw -Force -ErrorAction Stop
            
            # Validate JSON syntax
            try
            {
                $jsonData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
                Write-Verbose "[$functionName] JSON file is valid"
                Write-Log -LogFile $LogFile -Module $functionName -Message "JSON file is valid" -LogLevel "Debug"
            }
            catch
            {
                Write-Warning "[$functionName] Invalid JSON syntax in file: $JsonFile"
                Write-Verbose "[$functionName] JSON Error: $($_.Exception.Message)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Invalid JSON syntax in file: $JsonFile - $($_.Exception.Message)" -LogLevel "Error"
                throw "Invalid JSON format in configuration file"
            }
            # Handle different configuration types for init.json
            if ($JsonFile -like "*init.json")
            {
                Write-Verbose "[$functionName] Processing init.json with configuration type: $ConfigurationType"
                # Use regular hashtable for PowerShell 5.1 compatibility
                $processedData = @{}
                
                foreach ($item in $jsonData)
                {
                    $valueToUse = switch ($ConfigurationType)
                    {
                        'dev'
                        {
                            $item.devdefault 
                        }
                        'release'
                        {
                            $item.reldefault 
                        }
                        default
                        {
                            $item.default 
                        }
                    }
                    
                    if ($null -eq $valueToUse)
                    {
                        $valueToUse = $item.value
                    }
                    
                    $processedData[$item.name] = $valueToUse
                    Write-Verbose "[$functionName] Set $($item.name) = $valueToUse"
                }
                
                return $processedData
            }
            
            # Handle strings.json or simple JSON objects
            if ($jsonData -is [PSCustomObject])
            {
                # Use regular hashtable for PowerShell 5.1 compatibility
                $result = @{}
                
                # If it's a complex object like strings.json with sections
                if ($jsonData.PSObject.Properties.Name -contains 'returnValues' -or 
                    $jsonData.PSObject.Properties.Name -contains 'deviceStates' -or 
                    $jsonData.PSObject.Properties.Name -contains 'deviceActions')
                {
                    Write-Verbose "[$functionName] Processing structured JSON with sections"
                    foreach ($sectionName in $DefaultValues.Keys)
                    {
                        # Use regular hashtable for PowerShell 5.1 compatibility
                        $sectionData = @{}
                        $defaultSection = $DefaultValues[$sectionName]
                        
                        if ($jsonData.PSObject.Properties.Name -contains $sectionName)
                        {
                            Write-Verbose "[$functionName] Loading section '$sectionName' from JSON"
                            
                            # Load defaults first
                            foreach ($key in $defaultSection.Keys)
                            {
                                if ($jsonData.$sectionName.PSObject.Properties.Name -contains $key)
                                {
                                    $sectionData[$key] = $jsonData.$sectionName.$key
                                }
                                else
                                {
                                    Write-Verbose "[$functionName] Key '$key' not found in JSON section '$sectionName', using default"
                                    $sectionData[$key] = $defaultSection[$key]
                                }
                            }
                            
                            # Add any additional keys from JSON - PowerShell 5.1 compatible
                            foreach ($property in $jsonData.$sectionName.PSObject.Properties)
                            {
                                if (-not $sectionData.ContainsKey($property.Name))
                                {
                                    Write-Verbose "[$functionName] Adding additional key '$($property.Name)' from JSON section '$sectionName'"
                                    $sectionData[$property.Name] = $property.Value
                                }
                            }
                        }
                        else
                        {
                            Write-Verbose "[$functionName] Section '$sectionName' not found in JSON, using defaults"
                            # Create a copy of the defaults
                            $sectionData = @{}
                            foreach ($key in $defaultSection.Keys)
                            {
                                $sectionData[$key] = $defaultSection[$key]
                            }
                        }
                        
                        $result[$sectionName] = $sectionData
                    }
                }
                else
                {
                    # Simple flat JSON object
                    Write-Verbose "[$functionName] Processing flat JSON object"
                    foreach ($property in $jsonData.PSObject.Properties)
                    {
                        $result[$property.Name] = $property.Value
                    }
                }
                
                return $result
            }
            else
            {
                Write-Verbose "[$functionName] JSON data is array type, returning as-is"
                return $jsonData
            }
        }
        else
        {
            Write-Verbose "[$functionName] Configuration file not found: $JsonFile, using default values"
            return $DefaultValues
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error loading configuration from JSON file: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        Write-Verbose "[$functionName] Falling back to default values"
        return $DefaultValues
    }
}

function Get-InitConfiguration()
<#
.SYNOPSIS
    Loads initialization configuration from init.json with environment-specific value selection.

.DESCRIPTION
    This function loads configuration values from the init.json file and selects the appropriate
    values based on the specified configuration type (dev, release, or default). It uses the
    consolidated Get-JsonConfiguration function for robust JSON handling and fallback support.

.PARAMETER InitFile
    The path to the init.json file. Defaults to "$PWD\init.json".

.PARAMETER ConfigurationType
    Specifies which configuration values to load from the init.json structure:
    - 'dev': Uses devdefault values from each configuration item
    - 'release': Uses reldefault values from each configuration item
    - 'default': Uses default values from each configuration item

.OUTPUTS
    System.Collections.Hashtable
    Returns a flat hashtable with configuration name-value pairs selected based on ConfigurationType.

.EXAMPLE
    # Load development configuration
    $devConfig = Get-InitConfiguration -ConfigurationType 'dev'

.EXAMPLE
    # Load release configuration from specific file
    $releaseConfig = Get-InitConfiguration -InitFile "C:\Config\init.json" -ConfigurationType 'release'

.NOTES
    - Depends on Get-JsonConfiguration function
    - Provides sensible defaults for common configuration values
    - Handles missing files gracefully by returning default values
    - Includes comprehensive logging for troubleshooting
#>
{
    [CmdletBinding()]
    param(
        [string]$InitFile = "$PWD\init.json",
        [ValidateSet('dev', 'release', 'default')]
        [string]$ConfigurationType = 'default'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Loading initialization configuration from: $InitFile"
    Write-Verbose "[$functionName] Configuration Type: $ConfigurationType"
    # Default initialization values (fallback)
    $defaultInitValues = @{
        configFile          = ".\\.secrets\\config.json"
        configuration       = "settings.json" 
        ShowAdvancedOptions = "False"
        GroupTag            = ""
        maxWaitTime         = "30"
        timeInSeconds       = "30"
        Repo                = "Github"
        Release             = "main"
    }
    
    try
    {
        $config = Get-JsonConfiguration -JsonFile $InitFile -DefaultValues $defaultInitValues -ConfigurationType $ConfigurationType
        Write-Verbose "[$functionName] Successfully loaded initialization configuration"
        return $config
    }
    catch
    {
        Write-Warning "[$functionName] Failed to load initialization configuration: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning default values"
        return $defaultInitValues
    }
}

function MergeSettings()
<#
.SYNOPSIS
    Merges two hashtables (local and global settings) into a single flat hashtable with conflict resolution.

.DESCRIPTION
    The MergeSettings function combines local and global settings into a single hashtable, flattening nested structures and resolving conflicts according to the specified strategy. It supports merging arrays, nested hashtables, and PSCustomObjects. Keys are normalized to their simplest form (last segment after any dot notation). The function provides detailed verbose logging for each step, including flattening, normalization, and conflict resolution.

.PARAMETER localSettings
    The hashtable containing local (user or environment-specific) settings. These take precedence unless overridden by the ConflictResolution parameter.

.PARAMETER globalSettings
    The hashtable containing global (default or organization-wide) settings. These are merged in after local settings and may override them depending on the ConflictResolution parameter.

.PARAMETER ConflictResolution
    Determines which value to use when a key exists in both local and global settings:
    - 'Local': Keep the value from localSettings (default behavior)
    - 'Global': Use the value from globalSettings
    If both values are arrays, they are merged.

.OUTPUTS
    System.Collections.Hashtable
    Returns a flat hashtable containing the merged settings, with conflicts resolved as specified.

.EXAMPLE
    # Merge local and global settings, preferring global values on conflict
    $merged = MergeSettings -localSettings $local -globalSettings $global -ConflictResolution 'Global'

.EXAMPLE
    # Merge settings, keeping local values on conflict (default)
    $merged = MergeSettings -localSettings $local -globalSettings $global

.NOTES
    - Flattens nested hashtables and PSCustomObjects for key normalization
    - Merges arrays when both local and global values are arrays
    - Provides verbose logging for troubleshooting and auditing
    - Compatible with PowerShell 5.1 and later
#>
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

function InitializeConfiguration()
<#
.SYNOPSIS
    Creates or overwrites the initialization configuration file (init.json).

.DESCRIPTION
    This function generates the init.json file with predefined configuration structure including
    authentication settings, deployment profiles, timing configurations, and repository settings.
    The file supports environment-specific values (dev, release, default) for flexible deployment.

.PARAMETER RootFolder
    The root folder where the init.json file should be created.

.PARAMETER InitFile
    The full path to the init.json file. Defaults to "$RootFolder\init.json".

.PARAMETER overwrite
    When specified, overwrites the existing init.json file without prompting.
    When not specified, prompts the user for confirmation if the file already exists.

.OUTPUTS
    System.Boolean
    Returns $true if the initialization file was created successfully, $false otherwise.

.EXAMPLE
    # Create init.json in the current project root
    $success = InitializeConfiguration -RootFolder "C:\MyProject"

.EXAMPLE
    # Force overwrite existing init.json
    $success = InitializeConfiguration -RootFolder "C:\MyProject" -overwrite

.NOTES
    - Creates a comprehensive configuration structure with environment-specific defaults
    - Fixed issue with ShowAdvancedOptions array definition
    - Includes authentication, timing, repository, and deployment profile settings
    - Prompts for user confirmation before overwriting existing files
    - Provides detailed verbose logging throughout the process
#>
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [switch]$overwrite
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    #region print verbose log of received parameters
    Write-Verbose "[$functionName] Root folder: $RootFolder"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    Write-Verbose "[$functionName] Overwrite: $overwrite"
    #endregion
    # PowerShell 5.1 compatible - using regular hashtables instead of OrderedDictionary
    $initVars = @(
        @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; default = ".\\.secrets\\config.json"; type = 'string'},
        @{name = 'configuration'; value = "settings.json"; description = "The path to the configuration file."; devdefault = 'settings.json'; reldefault = 'settings.json'; default = 'settings.json'; type = 'string'},
        @{name = 'ShowAdvancedOptions'; value = @('True', 'False'); description = "Show advanced options in the GUI."; devdefault = 'True'; reldefault = 'True'; default = 'False'; type = 'array'},
        @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; default = ''; type = 'string'},
        @{name = 'maxWaitTime'; value = '60'; description = 'How long to wait before giving up on importing a device.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        @{name = 'timeInSeconds'; value = '60'; description = 'How long to wait before initiating another check.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Github'; default = 'Github'; type = 'array'}, 
        @{name = 'Release'; value = "2.2"; description = 'The release branch to use.'; devdefault = 'main'; reldefault = '2.2'; default = 'main'; type = 'string'}
    )
    
    $success = $false
    
    if (-not(Test-Path $InitFile))
    {
        Write-Verbose "[$functionName] Creating configuration file at $InitFile."
        $initVars | ConvertTo-Json -Depth 10 | Set-Content -Path $InitFile -Force
    }
    else
    {
        if ($overwrite)
        {
            Write-Verbose "[$functionName] Overwriting configuration file at $InitFile."
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
                Write-Verbose "[$functionName] Overwriting initialization file at $InitFile."
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
<#
.SYNOPSIS
    Creates a configuration file (settings.json) from initialization settings with environment-specific values.

.DESCRIPTION
    This function reads the init.json file and creates a settings.json configuration file using values
    appropriate for the specified environment (dev, release, or default). It leverages the consolidated
    configuration loading system for improved reliability and consistency.

.PARAMETER RootFolder
    The root folder containing the source init.json file.

.PARAMETER InitFile
    The path to the init.json file. Defaults to "$RootFolder\init.json".

.PARAMETER DestinationFolder
    The folder where the vars.json file should be created. Defaults to $RootFolder.

.PARAMETER ConfigurationFile
    The full path for the output configuration file. Defaults to "$DestinationFolder\vars.json".

.PARAMETER ConfigurationType
    Specifies which values to extract from the init.json structure:
    - 'dev': Uses devdefault values
    - 'release': Uses reldefault values
    - 'default': Uses default values

.OUTPUTS
    System.Boolean
    Returns $true if the configuration file was created successfully, $false otherwise.

.EXAMPLE
    # Create release configuration
    $success = CreateConfiguration -RootFolder "C:\MyProject" -ConfigurationType 'release'

.EXAMPLE
    # Create development configuration with custom paths
    $success = CreateConfiguration -RootFolder "C:\Source" -DestinationFolder "C:\Config" -ConfigurationType 'dev'

.NOTES
    - Uses the consolidated Get-InitConfiguration function for consistency
    - Automatically creates init.json if it doesn't exist
    - Provides comprehensive error handling and logging
    - Validates successful file creation before returning
#>
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json", [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\settings.json",
        [ValidateSet('dev', 'release', 'default')]
        [string]$ConfigurationType = 'release'
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Root folder: $RootFolder"
    Write-Verbose "[$functionName] Init file: $InitFile"
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] ConfigurationType: $ConfigurationType"
    $success = $false
    #endregion
    
    try
    {
        if (Test-Path -Path $InitFile)
        {
            Write-Verbose "[$functionName] Found init file at $InitFile."
            # Use the consolidated configuration loader with specific configuration type
            $configData = Get-InitConfiguration -InitFile $InitFile -ConfigurationType $ConfigurationType
        }
        else
        {
            Write-Host "No init file found at $InitFile."
            Write-Host "Creating init file at $InitFile."
            if (InitializeConfiguration -RootFolder $RootFolder)
            {
                Write-Host "Init file created successfully."
                $configData = Get-InitConfiguration -InitFile $InitFile -ConfigurationType $ConfigurationType
            }
            else
            {
                Write-Host "Failed to create init file."
                return $success
            }
        }
        Write-Verbose "[$functionName] Config data: $($configData | ConvertTo-Json -Depth 10)"
        
        # Create the settings.json structure with globalSettings and domains
        $settingsStructure = @{
            "description"    = "This is the configuration file for the script. It contains the settings for the script to run correctly."
            "version"        = "1.0"
            "globalSettings" = $configData
            "domains"        = @{}
        }
        
        # Write the structured data to the configuration file
        $settingsStructure | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
        
        # Check to make sure it was written
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
    }
    catch
    {
        Write-Warning "[$functionName] Error creating configuration: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        $success = $false
    }
    
    # Return the success status
    return $success
}

function CreateFullConfiguration()
<#
.SYNOPSIS
    Creates a comprehensive configuration file through interactive user prompts.

.DESCRIPTION
    This function provides an interactive configuration experience where users can customize
    configuration values based on initialization templates. It uses the consolidated JSON
    configuration system for robust file handling and validation.

.PARAMETER RootFolder
    The root folder containing the source init.json file.

.PARAMETER DestinationFolder
    The folder where the vars.json file should be created. Defaults to $RootFolder.

.PARAMETER ConfigurationFile
    The full path for the output configuration file. Defaults to "$DestinationFolder\vars.json".

.PARAMETER InitFile
    The path to the init.json file. Defaults to "$RootFolder\init.json".

.OUTPUTS
    System.Boolean
    Returns $true if the configuration file was created successfully, $false otherwise.

.EXAMPLE
    # Create interactive configuration in current project
    $success = CreateFullConfiguration -RootFolder "C:\MyProject"

.EXAMPLE
    # Create configuration with custom paths
    $success = CreateFullConfiguration -RootFolder "C:\Source" -DestinationFolder "C:\Config"

.NOTES
    - Uses consolidated JSON configuration system for consistency and reliability
    - Automatically creates missing init.json and vars.json files
    - Provides interactive prompts for each configurable value
    - Supports different input types (string, array, static)
    - Includes comprehensive error handling and validation
    - Improved array handling with better user experience
    - Enhanced error reporting and user feedback
#>
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder, 
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\settings.json",
        [string]$InitFile = "$RootFolder\init.json"
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] RootFolder: $RootFolder"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    $success = $false
    #endregion

    try
    {
        # Ensure init file exists using consolidated system
        Write-Verbose "[$functionName] Checking for init file at $InitFile."
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
        # Load raw init configuration directly to get full objects with type, description, value properties
        Write-Verbose "[$functionName] Loading raw init configuration from $InitFile."
        Write-Host "Loading initialization values from init file $InitFile."
        $initContent = Get-Content -Path $InitFile -Raw -Force
        $valuesToEdit = $initContent | ConvertFrom-Json
        Write-Verbose "[$functionName] Loaded raw init configuration values: $($valuesToEdit.count) items"
        Write-Host "Loaded $($valuesToEdit.count) initialization items from init file $InitFile."
        # Ensure configuration file exists using consolidated system
        if (-not(Test-Path -Path $ConfigurationFile))
        {
            Write-Host "No configuration file found at $ConfigurationFile."
            Write-Host "Creating configuration file at $ConfigurationFile."
            if (CreateConfiguration -RootFolder $RootFolder -ConfigurationFile $ConfigurationFile)
            {
                Write-Host "Configuration file created successfully."
            }
            else
            {
                Write-Host "Failed to create configuration file."
                return $success
            }
        }        
        # Load current configuration using consolidated system
        Write-Host "Loading settings from $ConfigurationFile."
        # Load the entire settings.json structure
        $settingsContent = Get-Content -Path $ConfigurationFile -Raw -Force
        $settingsObj = $settingsContent | ConvertFrom-Json
        # Extract globalSettings for editing
        Write-Verbose "[$functionName] Extracting globalSettings from configuration."
        if ($settingsObj.PSObject.Properties.Name -contains 'globalSettings')
        {
            Write-Verbose "[$functionName] Found globalSettings section in configuration."
            $configData = @{}
            foreach ($property in $settingsObj.globalSettings.PSObject.Properties)
            {
                $configData[$property.Name] = $property.Value
                Write-Verbose "[$functionName] Loaded global setting: $($property.Name) = $($property.Value)"
            }
            Write-Host "Found $($configData.Keys.Count) global settings."
        }
        else
        {
            Write-Warning "[$functionName] Configuration file does not contain globalSettings section"
            $configData = @{}
        }
        # Convert the loaded configuration to a PSCustomObject for compatibility with existing logic
        Write-Verbose "[$functionName] Converting configuration data to PSCustomObject."
        $configObject = [PSCustomObject]@{}
        # Add each key-value pair from the configuration data to the configObject
        Write-Verbose "[$functionName] Adding configuration data to configObject."
        foreach ($key in $configData.Keys)
        {
            $configObject | Add-Member -MemberType NoteProperty -Name $key -Value $configData[$key]
            Write-Verbose "[$functionName] Added $key = $($configData[$key]) to configObject."
        }

        # Iterate over the configuration data and prompt the user to choose a value
        Write-Host "Configuring settings interactively. Please follow the prompts."
        foreach ($config in $configObject.PSObject.Properties)
        {
            Write-Verbose "[$functionName] Configuration: $($config.Name) = $($config.Value)"
            Write-Verbose "[$functionName] Current value: $($config.Value)"
            # Find matching init configuration
            Write-Verbose "[$functionName] Searching for init configuration for $($config.Name)."
            $initConfig = $valuesToEdit | Where-Object { $_.name -eq $config.Name }
            Write-Verbose "[$functionName] Value in init configuration: $($initConfig | ConvertTo-Json -Depth 10)"
            if ($initConfig)
            {
                $configType = $initConfig.type
                $configDescription = $initConfig.description
                $configValue = $initConfig.value
                Write-Verbose "[$functionName] Found init configuration for $($config.Name)."
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
                Write-Host "Name: $($config.Name)."
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
                        
                        $currentlySelected = 1  # Default selection
                        for ($i = 0; $i -lt $configValue.Count; $i++)
                        {
                            Write-Host "[$($i+1)] $($configValue[$i])"
                            if ($config.Value -eq $configValue[$i])
                            {
                                $currentlySelected = $i + 1
                                Write-Verbose "[$functionName] The currently selected value is $currentlySelected"
                            }
                        }
                        
                        $value = Read-Host -Prompt "Choice: [$currentlySelected]"
                        while ($value -ne '' -and ($value -lt 1 -or $value -gt $configValue.Count))
                        {
                            Write-Host "Invalid choice." -ForegroundColor Red
                            [console]::beep(500, 300)
                            $value = Read-Host -Prompt "Choice: [$currentlySelected]"
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
                        Write-Host "Value: $($config.Value)" -ForegroundColor Yellow
                    }
                }
            }
            else
            {
                Write-Verbose "[$functionName] No matching init configuration found for $($config.Name). Using default string input."
                # If no init configuration is found, treat it as a simple string input
                Write-Host "Please enter a new value for $($config.Name)."
                Write-Host "Description: Advanced setting - no specific description available"
                $value = Read-Host -Prompt "Press enter to keep the current value: ($($config.Value))"
                if ($value -eq '' -or $null -eq $value)
                {
                    $value = $config.Value
                }
                Write-Host "New value: $value"
                Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                $config.Value = $value
            }
        }

        # Print all the new configuration data but only in verbose mode
        Write-Verbose "[$functionName] New configuration data:"
        $configObject.PSObject.Properties | ForEach-Object {
            Write-Verbose "[$functionName] $($_.Name) = $($_.Value)"
        }        
        # Convert back to hashtable for saving
        Write-Verbose "[$functionName] Converting configObject back to hashtable for saving."
        $finalConfig = @{}
        foreach ($prop in $configObject.PSObject.Properties)
        {
            $finalConfig[$prop.Name] = $prop.Value
            Write-Verbose "[$functionName] Final config: $($prop.Name) = $($prop.Value)"
        }

        # Preserve the settings.json structure with updated globalSettings
        $settingsObj.globalSettings = [PSCustomObject]$finalConfig
        Write-Verbose "[$functionName] Updated globalSettings in settingsObj."

        # Save the complete settings.json structure to the configuration file
        Write-Verbose "[$functionName] Saving configuration to $ConfigurationFile."
        $settingsObj | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
        Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
        
        # Verify the file was saved successfully
        Write-Verbose "[$functionName] Verifying configuration file at $ConfigurationFile."
        if (Test-Path -Path $ConfigurationFile)
        {
            Write-Verbose "[$functionName] Configuration saved successfully to $ConfigurationFile."
            Write-Host "Configuration saved successfully." -ForegroundColor Green
            $success = $true
        }
        else
        {
            Write-Verbose "[$functionName] Failed to save configuration to $ConfigurationFile."
            Write-Host "Failed to save configuration." -ForegroundColor Red
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error during configuration creation: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        Write-Host "An error occurred during configuration creation. Check verbose logs for details." -ForegroundColor Red
        $success = $false
    }
    return $success
}

function Update-GlobalSetting()
<#
.SYNOPSIS
    Updates a specific setting in the globalSettings section of settings.json.

.DESCRIPTION
    This function loads the existing settings.json file, updates a specific property
    in the globalSettings section, and saves the file back. This allows for granular
    updates without overwriting the entire configuration structure.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER SettingName
    The name of the setting to update in globalSettings.

.PARAMETER SettingValue
    The new value for the setting.

.OUTPUTS
    System.Boolean
    Returns $true if the setting was updated successfully, $false otherwise.

.EXAMPLE
    # Update the GroupTag in globalSettings
    $success = Update-GlobalSetting -SettingName "GroupTag" -SettingValue "NEWGROUP"

.EXAMPLE
    # Update the maxWaitTime setting
    $success = Update-GlobalSetting -SettingsFile "C:\Config\settings.json" -SettingName "maxWaitTime" -SettingValue "120"

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Preserves all other settings in the file
    - Creates backup before modification for safety
    - Validates JSON structure before and after update
#>
{
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [Parameter(Mandatory = $true)]
        [string]$SettingName,
        [Parameter(Mandatory = $true)]
        $SettingValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating setting '$SettingName' to '$SettingValue' in file: $SettingsFile"
    
    try
    {
        # Check if settings file exists
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Load existing settings
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settings = $jsonContent | ConvertFrom-Json
        
        # Validate structure
        if (-not $settings.PSObject.Properties.Name -contains 'globalSettings')
        {
            Write-Warning "[$functionName] Settings file does not contain globalSettings section"
            return $false
        }
        
        # Convert PSCustomObject to hashtable for easier manipulation (PowerShell 5.1 compatible)
        $globalSettingsHash = @{}
        foreach ($property in $settings.globalSettings.PSObject.Properties)
        {
            $globalSettingsHash[$property.Name] = $property.Value
        }
        
        # Update the specific setting
        $globalSettingsHash[$SettingName] = $SettingValue
        Write-Verbose "[$functionName] Updated globalSettings.$SettingName = $SettingValue"
        
        # Convert back to PSCustomObject structure
        $settings.globalSettings = [PSCustomObject]$globalSettingsHash
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Force
        
        # Verify the update
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        if ($verifySettings.globalSettings.PSObject.Properties.Name -contains $SettingName -and
            $verifySettings.globalSettings.$SettingName -eq $SettingValue)
        {
            Write-Verbose "[$functionName] Successfully updated and verified setting"
            return $true
        }
        else
        {
            Write-Warning "[$functionName] Failed to verify setting update"
            return $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error updating global setting: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

<#
.SYNOPSIS
    Updates a setting in the auth section of the settings.json file.

.DESCRIPTION
    This function loads the existing settings.json file, updates a specific setting in the auth
    section, and saves the file back. This allows for granular updates to authentication
    configuration without affecting other sections.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER SettingName
    The name of the auth setting to update (e.g., "Delegated", "authType", "ForceNewToken").

.PARAMETER SettingValue
    The value to set for the auth setting.

.OUTPUTS
    System.Boolean
    Returns $true if the auth setting was updated successfully, $false otherwise.

.EXAMPLE
    # Update Delegated property in auth section
    $success = Update-AuthSetting -SettingName "Delegated" -SettingValue $true

.EXAMPLE
    # Update authType property in auth section
    $success = Update-AuthSetting -SettingsFile "C:\Config\settings.json" -SettingName "authType" -SettingValue "PublicAuthFlow"

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Preserves all other settings sections
    - Creates backup before modification for safety
    - Validates settings file structure before updating
#>
function Update-AuthSetting()
{
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [Parameter(Mandatory = $true)]
        [string]$SettingName,
        [Parameter(Mandatory = $true)]
        $SettingValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating auth setting '$SettingName' to '$SettingValue' in file: $SettingsFile"
    
    try
    {
        # Check if settings file exists
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Load existing settings
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settings = $jsonContent | ConvertFrom-Json
        
        # Validate structure
        if (-not $settings.PSObject.Properties.Name -contains 'auth')
        {
            Write-Warning "[$functionName] Settings file does not contain auth section"
            return $false
        }
        
        # Convert PSCustomObject to hashtable for easier manipulation (PowerShell 5.1 compatible)
        $authSettingsHash = @{}
        foreach ($property in $settings.auth.PSObject.Properties)
        {
            $authSettingsHash[$property.Name] = $property.Value
        }
        
        # Update the specific setting
        $authSettingsHash[$SettingName] = $SettingValue
        Write-Verbose "[$functionName] Updated auth.$SettingName = $SettingValue"
        
        # Convert back to PSCustomObject structure
        $settings.auth = [PSCustomObject]$authSettingsHash
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Force
        
        # Verify the update
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        if ($verifySettings.auth.PSObject.Properties.Name -contains $SettingName -and
            $verifySettings.auth.$SettingName -eq $SettingValue)
        {
            Write-Verbose "[$functionName] Successfully updated and verified auth setting"
            return $true
        }
        else
        {
            Write-Warning "[$functionName] Failed to verify auth setting update"
            return $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error updating auth setting: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Update-DomainSettings()
<#
.SYNOPSIS
>>>>>>> master
    Updates settings for a specific domain in the settings.json file.

.DESCRIPTION
    This function loads the existing settings.json file, updates settings for a specific
    domain, and saves the file back. This allows for granular updates to domain-specific
    configurations without affecting other domains or global settings.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER DomainName
    The name of the domain to update settings for.

.PARAMETER Settings
    A hashtable containing the settings to update for the domain.

.PARAMETER MergeSettings
    If specified, merges the provided settings with existing domain settings.
    If not specified, replaces the entire settings section for the domain.

.OUTPUTS
    System.Boolean
    Returns $true if the domain settings were updated successfully, $false otherwise.

.EXAMPLE
    # Update GroupTag for a specific domain
    $domainSettings = @{ "GroupTag" = "NEWGROUP"; "deviceNamePrefix" = "win11-" }
    $success = Update-DomainSettings -DomainName "contoso.com" -Settings $domainSettings

.EXAMPLE
    # Merge settings with existing domain configuration
    $newSettings = @{ "MaxUserNameLength" = 60 }
    $success = Update-DomainSettings -DomainName "contoso.com" -Settings $newSettings -MergeSettings

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Preserves all other domains and global settings
    - Creates backup before modification for safety
    - Can either merge or replace domain settings
#>
{
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [Parameter(Mandatory = $true)]
        [string]$DomainName,
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,
        [switch]$MergeSettings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating settings for domain '$DomainName' in file: $SettingsFile"
    Write-Verbose "[$functionName] Merge mode: $MergeSettings"
    
    try
    {
        # Check if settings file exists
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Load existing settings
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settingsObj = $jsonContent | ConvertFrom-Json
        
        # Validate structure
        if (-not $settingsObj.PSObject.Properties.Name -contains 'domains')
        {
            Write-Warning "[$functionName] Settings file does not contain domains section"
            return $false
        }
        
        # Convert domains to hashtable for easier manipulation (PowerShell 5.1 compatible)
        $domainsHash = @{}
        foreach ($domainProperty in $settingsObj.domains.PSObject.Properties)
        {
            $domainHash = @{}
            
            # Convert each domain's properties
            foreach ($property in $domainProperty.Value.PSObject.Properties)
            {
                if ($property.Name -eq 'settings' -and $property.Value -is [PSCustomObject])
                {
                    # Convert settings object to hashtable
                    $settingsHash = @{}
                    foreach ($settingProperty in $property.Value.PSObject.Properties)
                    {
                        $settingsHash[$settingProperty.Name] = $settingProperty.Value
                    }
                    $domainHash[$property.Name] = $settingsHash
                }
                else
                {
                    $domainHash[$property.Name] = $property.Value
                }
            }
            
            $domainsHash[$domainProperty.Name] = $domainHash
        }
        
        # Initialize domain if it doesn't exist
        if (-not $domainsHash.ContainsKey($DomainName))
        {
            Write-Verbose "[$functionName] Creating new domain entry for: $DomainName"
            $domainsHash[$DomainName] = @{
                "groupsToInclude" = @()
                "groupsToExclude" = @()
                "settings"        = @{}
            }
        }
        
        # Update domain settings
        if ($MergeSettings -and $domainsHash[$DomainName].ContainsKey('settings'))
        {
            # Merge with existing settings
            Write-Verbose "[$functionName] Merging settings with existing domain configuration"
            foreach ($key in $Settings.Keys)
            {
                $domainsHash[$DomainName]['settings'][$key] = $Settings[$key]
                Write-Verbose "[$functionName] Updated domain setting: $key = $($Settings[$key])"
            }
        }
        else
        {
            # Replace entire settings section
            Write-Verbose "[$functionName] Replacing entire settings section for domain"
            $domainsHash[$DomainName]['settings'] = $Settings
        }
        
        # Convert back to nested PSCustomObjects
        $newDomainsObj = [PSCustomObject]@{}
        foreach ($domainKey in $domainsHash.Keys)
        {
            $domainValue = $domainsHash[$domainKey]
            $domainObj = [PSCustomObject]@{
                "groupsToInclude" = $domainValue['groupsToInclude']
                "groupsToExclude" = $domainValue['groupsToExclude']
                "settings"        = [PSCustomObject]$domainValue['settings']
            }
            $newDomainsObj | Add-Member -MemberType NoteProperty -Name $domainKey -Value $domainObj
        }
        
        # Update the settings object
        $settingsObj.domains = $newDomainsObj
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settingsObj | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Force
        
        # Verify the update
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        if ($verifySettings.domains.PSObject.Properties.Name -contains $DomainName)
        {
            Write-Verbose "[$functionName] Successfully updated and verified domain settings"
            return $true
        }
        else
        {
            Write-Warning "[$functionName] Failed to verify domain settings update"
            return $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error updating domain settings: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

function Set-SettingsJsonStructure()
<#
.SYNOPSIS
    Creates or updates the entire settings.json structure with new configuration data.

.DESCRIPTION
    This function creates a new settings.json file with the proper structure (description,
    version, globalSettings, domains) or updates an existing one. It wraps configuration
    data in the appropriate settings.json structure format.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER ConfigData
    A hashtable containing the configuration data to be placed in globalSettings.

.PARAMETER Description
    Optional description for the settings file. Defaults to a standard description.

.PARAMETER Version
    Optional version for the settings file. Defaults to "1.0".

.PARAMETER PreserveExistingDomains
    If specified and the settings file already exists, preserves existing domain configurations.

.OUTPUTS
    System.Boolean
    Returns $true if the settings file was created/updated successfully, $false otherwise.

.EXAMPLE
    # Create new settings.json with configuration data
    $config = @{ "GroupTag" = "MSB01"; "maxWaitTime" = "60" }
    $success = Set-SettingsJsonStructure -ConfigData $config

.EXAMPLE
    # Update settings.json while preserving existing domains
    $config = @{ "testMode" = $true }
    $success = Set-SettingsJsonStructure -ConfigData $config -PreserveExistingDomains

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Creates proper settings.json structure with globalSettings and domains
    - Can preserve existing domain configurations when updating
    - Creates backup before modification for safety
#>
{
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,
        [string]$Description = "This is the configuration file for the script. It contains the settings for the script to run correctly.",
        [string]$Version = "1.0",
        [switch]$PreserveExistingDomains
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating/updating settings structure in file: $SettingsFile"
    Write-Verbose "[$functionName] Preserve existing domains: $PreserveExistingDomains"
    
    try
    {
        $existingDomains = @{}
        
        # If preserving domains and file exists, load existing domains
        if ($PreserveExistingDomains -and (Test-Path -Path $SettingsFile))
        {
            Write-Verbose "[$functionName] Loading existing domains to preserve"
            $existingContent = Get-Content -Path $SettingsFile -Raw -Force
            $existingSettings = $existingContent | ConvertFrom-Json
            
            if ($existingSettings.PSObject.Properties.Name -contains 'domains')
            {
                # Convert existing domains to hashtable
                foreach ($domainProperty in $existingSettings.domains.PSObject.Properties)
                {
                    $domainHash = @{}
                    foreach ($property in $domainProperty.Value.PSObject.Properties)
                    {
                        if ($property.Name -eq 'settings' -and $property.Value -is [PSCustomObject])
                        {
                            $settingsHash = @{}
                            foreach ($settingProperty in $property.Value.PSObject.Properties)
                            {
                                $settingsHash[$settingProperty.Name] = $settingProperty.Value
                            }
                            $domainHash[$property.Name] = $settingsHash
                        }
                        else
                        {
                            $domainHash[$property.Name] = $property.Value
                        }
                    }
                    $existingDomains[$domainProperty.Name] = $domainHash
                }
                Write-Verbose "[$functionName] Preserved $($existingDomains.Count) existing domains"
            }
            
            # Create backup
            $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $SettingsFile -Destination $backupFile -Force
            Write-Verbose "[$functionName] Created backup: $backupFile"
        }
        
        # Create the settings structure
        $settingsStructure = @{
            "description"    = $Description
            "version"        = $Version
            "globalSettings" = $ConfigData
            "domains"        = @{}
        }
        
        # Add preserved domains if any
        if ($existingDomains.Count -gt 0)
        {
            $settingsStructure["domains"] = $existingDomains
        }
        
        # Convert to JSON and save
        $jsonOutput = $settingsStructure | ConvertTo-Json -Depth 10
        $jsonOutput | Set-Content -Path $SettingsFile -Force
        
        # Verify the file was created correctly
        if (Test-Path -Path $SettingsFile)
        {
            $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
            $verifySettings = $verifyContent | ConvertFrom-Json
            
            if ($verifySettings.PSObject.Properties.Name -contains 'globalSettings' -and
                $verifySettings.PSObject.Properties.Name -contains 'domains')
            {
                Write-Verbose "[$functionName] Successfully created/updated settings.json structure"
                return $true
            }
        }
        
        Write-Warning "[$functionName] Failed to verify settings.json structure"
        return $false
    }
    catch
    {
        Write-Warning "[$functionName] Error creating/updating settings structure: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}
