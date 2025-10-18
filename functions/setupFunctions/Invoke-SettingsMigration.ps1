function Invoke-SettingsMigration()
{
    <#
    .SYNOPSIS
        Migration wizard to convert JSON configuration files to PSD1 format.
    
    .DESCRIPTION
        Scans the current directory for JSON files that need migration to PSD1 format:
        - Domain configuration files matching pattern: <domain>.json (e.g., contoso.com.json)
        - Global settings file: settings.json
        
        For domain files:
        - Flattens the [settings] subkey to root level
        - Converts 'appMode' (string) to 'appModes' (array)
        - Moves 'groupsToInclude', 'groupsToExclude', 'additionalScopes' to root level
        - Extracts fields from 'appInfo' nested object
        
        For settings.json:
        - Preserves 'auth', 'requiredScopes', 'globalSettings' structure
        - Removes 'menu' and 'domains' objects
        - Converts 'appMode' to 'appModes' within globalSettings
        - Extracts version and description from appInfo
    
    .PARAMETER SearchPath
        The directory path to search for JSON files to migrate.
        Defaults to the current working directory.
    
    .PARAMETER Validate
        Validates the resulting .psd1 files can be loaded successfully.
        Default is $true.
    
    .PARAMETER CreateBackup
        Creates a timestamped backup of existing files before overwriting.
        Default is $true.
    
    .PARAMETER RemoveJsonFiles
        Removes the original JSON files after successful migration.
        Default is $false.
    
    .PARAMETER Force
        Overwrites existing PSD1 files without prompting.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a detailed report of the migration operation with the following keys:
        - success: Overall success status (boolean)
        - migrationNeeded: Whether any files needed migration (boolean)
        - settingsFile: Status of settings.json migration (hashtable)
        - domainFiles: Array of domain file migration statuses (array of hashtables)
        - totalProcessed: Total number of files processed (int)
        - totalSucceeded: Total number of successful migrations (int)
        - totalFailed: Total number of failed migrations (int)
        - removedFileCount: Number of JSON files removed (int)
        - migratedAutopilotProfiles: Hashtable of autopilot profiles organized by domain name (hashtable where keys are domain names and values are arrays of profile hashtables with id and name)
        - errorMessages: Array of error messages (array)
    
    .EXAMPLE
        $result = Invoke-SettingsMigration
        
        Migrates all JSON configuration files in the current directory.
    
    .EXAMPLE
        $result = Invoke-SettingsMigration -RemoveJsonFiles -Force
        
        Migrates files, removes JSON originals, and overwrites existing PSD1 files.
    
    .NOTES
        - Leverages existing repository functions: ConvertFrom-JsonToHashtable and Export-PowerShellDataFile
        - Maintains PowerShell 5.1 compatibility
        - Handles nested structures and arrays properly
        - Provides detailed migration status for each file
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SearchPath = $pwd,
        [Parameter(Mandatory = $false)]
        [bool]$Validate = $true,
        [Parameter(Mandatory = $false)]
        [bool]$CreateBackup = $true,
        [Parameter(Mandatory = $false)]
        [switch]$RemoveJsonFiles,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting migration wizard in: $SearchPath"
    Write-Log -logFile $logFile -Module $functionName -Message "Starting migration wizard in: $SearchPath"
    
    # Domain pattern: <domain>.json (e.g., contoso.com.json, arabictutor.com.json)
    $domainPattern = '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+\.json$'
    
    # Initialize return object
    $returnObject = @{
        success                   = $false
        migrationNeeded           = $false
        settingsFile              = $null
        domainFiles               = @()
        totalProcessed            = 0
        totalSucceeded            = 0
        totalFailed               = 0
        removedFileCount          = 0
        migratedAutopilotProfiles = @{}
        errorMessages             = @()
    }
    
    try
    {
        # Step 1: Find settings.json
        $settingsJsonPath = Join-Path $SearchPath "settings.json"
        $settingsPSDPath = Join-Path $SearchPath "settings.psd1"
        $settingsJsonExists = (Test-Path $settingsJsonPath) -and (-not (Test-Path $settingsPSDPath))
        
        # Step 2: Find domain JSON files
        $domainJsonFiles = Get-ChildItem -Path $SearchPath -File -Filter "*.json" -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -match $domainPattern -and
                -not (Test-Path ([System.IO.Path]::ChangeExtension($_.FullName, '.psd1')))
            }

        Write-Verbose "[$functionName] Found settings.json: $settingsJsonExists"
        Write-Verbose "[$functionName] Found $($domainJsonFiles.Count) domain file(s)"
        Write-Log -logFile $logFile -Module $functionName -Message "Found settings.json: $settingsJsonExists"
        Write-Log -logFile $logFile -Module $functionName -Message "Found $($domainJsonFiles.Count) domain file(s)"
        
        # Check if migration is needed
        if (-not $settingsJsonExists -and $domainJsonFiles.Count -eq 0)
        {
            Write-Verbose "[$functionName] No migration needed - no JSON files found"
            Write-Log -logFile $logFile -Module $functionName -Message "No migration needed"
            $returnObject.errorMessages += "No JSON configuration files found"
            return $returnObject
        }
        
        $returnObject.migrationNeeded = $true
        Write-Host "This update uses a different format to store its configuration values."
        Write-Host "Your existing configuration files will now be migrated to the new format."
        # Step 3: Migrate settings.json if it exists
        if ($settingsJsonExists)
        {
            Write-Host "Migrating settings.json..." -ForegroundColor Cyan
            $settingsResult = Convert-SettingsJsonToPsd1 -JsonFilePath $settingsJsonPath -Validate $Validate -CreateBackup $CreateBackup -Force:$Force
            $returnObject.settingsFile = $settingsResult
            $returnObject.totalProcessed++
            
            if ($settingsResult.success)
            {
                $returnObject.totalSucceeded++
                Write-Host "Successfully migrated settings.json to settings.psd1" -ForegroundColor Green
            }
            else
            {
                $returnObject.totalFailed++
                $returnObject.errorMessages += "settings.json: $($settingsResult.errorMessage)"
                Write-Warning "Failed to migrate settings.json: $($settingsResult.errorMessage)"
            }
        }
        
        # Step 4: Migrate domain files
        foreach ($domainFile in $domainJsonFiles)
        {
            Write-Host "Migrating $($domainFile.Name)..." -ForegroundColor Cyan
            $domainResult = Convert-DomainJsonToPsd1 -JsonFilePath $domainFile.FullName -Validate $Validate -CreateBackup $CreateBackup -Force:$Force
            $returnObject.domainFiles += $domainResult
            $returnObject.totalProcessed++
            
            if ($domainResult.success)
            {
                $returnObject.totalSucceeded++
                Write-Host "Successfully migrated $($domainFile.Name) to $([System.IO.Path]::GetFileNameWithoutExtension($domainFile.Name)).psd1" -ForegroundColor Green
                
                # Collect autopilot profiles from this domain file, keyed by domain name
                if ($domainResult.ContainsKey('autopilotProfiles') -and $domainResult.autopilotProfiles.Count -gt 0)
                {
                    $domainName = [System.IO.Path]::GetFileNameWithoutExtension($domainFile.Name)
                    $returnObject.migratedAutopilotProfiles[$domainName] = $domainResult.autopilotProfiles
                    Write-Verbose "[$functionName] Added $($domainResult.autopilotProfiles.Count) autopilot profile(s) from $domainName"
                }
            }
            else
            {
                $returnObject.totalFailed++
                $returnObject.errorMessages += "$($domainFile.Name): $($domainResult.errorMessage)"
                Write-Warning "Failed to migrate $($domainFile.Name): $($domainResult.errorMessage)"
            }
        }
        
        # Step 5: Remove JSON files if requested and all migrations succeeded
        if ($RemoveJsonFiles -and $returnObject.totalFailed -eq 0)
        {
            Write-Host "`nRemoving original JSON files..." -ForegroundColor Cyan
            $filesToRemove = @()
            #see if any of init.json, strings.json and menu.json exist and if so add them to the $filesToRemove array
            $extraFiles = @("lastrun.json", "init.json", "strings.json", "menu.json") | ForEach-Object { Join-Path -Path $SearchPath -ChildPath $_ } | Where-Object { Test-Path $_ }
            $filesToRemove += $extraFiles
            if ($settingsJsonExists) { $filesToRemove += $settingsJsonPath }
            $filesToRemove += $domainJsonFiles.FullName
            Write-Host "Removing $($filesToRemove.Count) JSON files..."
            foreach ($jsonFile in $filesToRemove)
            {
                try
                {
                    Remove-Item -Path $jsonFile -Force -ErrorAction SilentlyContinue | Out-Null
                    $returnObject.removedFileCount++
                    Write-Verbose "[$functionName] Removed: $jsonFile"
                }
                catch
                {
                    Write-Warning "  Could not remove $jsonFile`: $($_.Exception.Message)"
                    $returnObject.errorMessages += "Remove failed: $jsonFile"
                }
            }
            Write-Host "  Removed $($returnObject.removedFileCount) of $($filesToRemove.Count) JSON file(s)" -ForegroundColor Yellow
        }
        
        # Step 6: Set overall success status
        $returnObject.success = ($returnObject.totalFailed -eq 0 -and $returnObject.totalProcessed -gt 0)
        
        # Step 7: Display summary
        Write-Host "`n=== Migration Summary ===" -ForegroundColor Cyan
        Write-Host "Total files processed: $($returnObject.totalProcessed)" -ForegroundColor White
        Write-Host "Successful migrations: $($returnObject.totalSucceeded)" -ForegroundColor Green
        Write-Host "Failed migrations: $($returnObject.totalFailed)" -ForegroundColor $(if ($returnObject.totalFailed -gt 0) { "Red" } else { "White" })
        
        if ($returnObject.errorMessages.Count -gt 0)
        {
            Write-Host "`nErrors encountered:" -ForegroundColor Red
            foreach ($errMsg in $returnObject.errorMessages)
            {
                Write-Host "  - $errMsg" -ForegroundColor Red
            }
        }
        
        Write-Log -logFile $logFile -Module $functionName -Message "Migration complete: $($returnObject.totalSucceeded)/$($returnObject.totalProcessed) succeeded"
    }
    catch
    {
        Write-Error "[$functionName] Migration wizard failed: $($_.Exception.Message)"
        Write-Log -logFile $logFile -Module $functionName -Message "Migration wizard failed: $($_.Exception.Message)" -LogLevel Error
        $returnObject.success = $false
        $returnObject.errorMessages += $_.Exception.Message
    }
    
    return $returnObject
}

function ConvertTo-Psd1Structure()
{
    <#
    .SYNOPSIS
        Transforms a domain JSON configuration structure to PSD1 format structure.
    
    .DESCRIPTION
        Internal helper function that performs the structural transformation from 
        JSON format to PSD1 format for domain configuration files:
        - Flattens 'settings' subkey to root level
        - Converts 'appMode' (string) to 'appModes' (array)
        - Moves 'groupsToInclude', 'groupsToExclude', 'additionalScopes' to root
        - Handles nested 'appInfo' object structure
        - Renames keys as needed for PSD1 compatibility
    
    .PARAMETER JsonConfig
        Hashtable containing the converted JSON configuration.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns the transformed hashtable ready for PSD1 export.
    
    .NOTES
        - Private helper function for domain file conversion
        - Handles all structural differences between JSON and PSD1 formats
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$JsonConfig
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting domain structure transformation"
    Write-Log -logFile $logFile -Module $functionName -Message "Starting domain structure transformation"
    
    # Create the output hashtable
    $psd1Config = @{}
    
    # Step 1: Process root-level arrays (groupsToInclude, groupsToExclude, additionalScopes)
    if ($JsonConfig.ContainsKey('groupsToInclude'))
    {
        $psd1Config['groupsToInclude'] = $JsonConfig['groupsToInclude']
        Write-Verbose "[$functionName] Copied groupsToInclude to root level"
    }
    
    if ($JsonConfig.ContainsKey('groupsToExclude'))
    {
        $psd1Config['groupsToExclude'] = $JsonConfig['groupsToExclude']
        Write-Verbose "[$functionName] Copied groupsToExclude to root level"
    }
    
    if ($JsonConfig.ContainsKey('additionalScopes'))
    {
        $psd1Config['additionalScopes'] = $JsonConfig['additionalScopes']
        Write-Verbose "[$functionName] Copied additionalScopes to root level"
    }
    
    # Step 2: Flatten settings subkey to root level
    if ($JsonConfig.ContainsKey('settings'))
    {
        Write-Verbose "[$functionName] Flattening 'settings' subkey to root level"
        $settings = $JsonConfig['settings']
        
        foreach ($key in $settings.Keys)
        {
            # Handle special cases
            if ($key -eq 'appMode')
            {
                # Convert appMode (string) to appModes (array)
                Write-Verbose "[$functionName] Converting 'appMode' to 'appModes' array"
                $appModeValue = $settings['appMode']
                
                if ($appModeValue -is [string])
                {
                    $psd1Config['appModes'] = @($appModeValue)
                }
                elseif ($appModeValue -is [array])
                {
                    $psd1Config['appModes'] = $appModeValue
                }
                else
                {
                    Write-Warning "[$functionName] Unexpected appMode type: $($appModeValue.GetType().Name), converting to string array"
                    $psd1Config['appModes'] = @($appModeValue.ToString())
                }
            }
            elseif ($key -eq 'appInfo')
            {
                # Handle appInfo nested structure - flatten relevant fields
                Write-Verbose "[$functionName] Processing 'appInfo' nested structure"
                $appInfo = $settings['appInfo']
                
                if ($appInfo -is [hashtable])
                {
                    if ($appInfo.ContainsKey('name'))
                    {
                        $psd1Config['name'] = $appInfo['name']
                        Write-Verbose "[$functionName] Extracted name from appInfo"
                    }
                    
                    if ($appInfo.ContainsKey('description'))
                    {
                        $psd1Config['description'] = $appInfo['description']
                        Write-Verbose "[$functionName] Extracted description from appInfo"
                    }
                    
                    if ($appInfo.ContainsKey('companyName'))
                    {
                        $psd1Config['companyName'] = $appInfo['companyName']
                        Write-Verbose "[$functionName] Extracted companyName from appInfo"
                    }
                    
                    if ($appInfo.ContainsKey('version'))
                    {
                        $psd1Config['version'] = $appInfo['version']
                        Write-Verbose "[$functionName] Extracted version from appInfo"
                    }
                }
            }
            elseif ($key -eq 'desiredAutopilotProfiles')
            {
                # Rename and transform to array of hashtables with id and name
                Write-Verbose "[$functionName] Converting 'desiredAutopilotProfiles' to 'autopilotProfilesToInclude' array of hashtables"
                $desiredProfiles = $settings['desiredAutopilotProfiles']
                $transformedProfiles = @()
                
                if ($null -eq $desiredProfiles -or ($desiredProfiles -is [array] -and $desiredProfiles.Count -eq 0))
                {
                    # Null or empty array - keep as empty array
                    Write-Verbose "[$functionName] desiredAutopilotProfiles is null or empty, setting empty array"
                    $transformedProfiles = @()
                }
                elseif ($desiredProfiles -is [array])
                {
                    foreach ($autopilotProfile in $desiredProfiles)
                    {
                        if ($autopilotProfile -is [string])
                        {
                            # Convert string to hashtable with name and null id
                            $transformedProfiles += @{
                                id   = $null
                                name = $autopilotProfile
                            }
                            Write-Verbose "[$functionName] Converted profile name '$autopilotProfile' to hashtable"
                        }
                        elseif ($autopilotProfile -is [hashtable])
                        {
                            # Already a hashtable - ensure it has id and name keys
                            if (-not $autopilotProfile.ContainsKey('id'))
                            {
                                $autopilotProfile['id'] = $null
                            }
                            if (-not $autopilotProfile.ContainsKey('name'))
                            {
                                $autopilotProfile['name'] = ''
                            }
                            $transformedProfiles += $autopilotProfile
                            Write-Verbose "[$functionName] Preserved existing hashtable profile"
                        }
                        else
                        {
                            # Unexpected type - convert to string
                            Write-Warning "[$functionName] Unexpected profile type: $($autopilotProfile.GetType().Name), converting to string"
                            $transformedProfiles += @{
                                id   = $null
                                name = $autopilotProfile.ToString()
                            }
                        }
                    }
                }
                elseif ($desiredProfiles -is [string])
                {
                    # Single string value - convert to array with one hashtable
                    Write-Verbose "[$functionName] Converting single profile string to array of hashtables"
                    $transformedProfiles += @{
                        id   = $null
                        name = $desiredProfiles
                    }
                }
                else
                {
                    Write-Warning "[$functionName] Unexpected desiredAutopilotProfiles type: $($desiredProfiles.GetType().Name)"
                }
                
                $psd1Config['autopilotProfilesToInclude'] = $transformedProfiles
                Write-Verbose "[$functionName] Transformed $($transformedProfiles.Count) autopilot profile(s)"
            }
            elseif ($key -eq 'repo')
            {
                # Skip 'repo' as it's not in PSD1 format (repoInfo is used instead)
                Write-Verbose "[$functionName] Skipping 'repo' field (repoInfo is used instead)"
                continue
            }
            else
            {
                # Copy all other settings to root level
                $psd1Config[$key] = $settings[$key]
                Write-Verbose "[$functionName] Copied '$key' from settings to root level"
            }
        }
    }
    else
    {
        Write-Warning "[$functionName] No 'settings' key found in JSON config"
    }
    
    # Step 3: Add autopilotDeviceAllowedVendors if not present (common in PSD1)
    if (-not $psd1Config.ContainsKey('autopilotDeviceAllowedVendors'))
    {
        $psd1Config['autopilotDeviceAllowedVendors'] = @(
            'Dell',
            'VMWare'
        )
        Write-Verbose "[$functionName] Added default empty 'autopilotDeviceAllowedVendors' array"
    }
    
    # Step 4: Add additional PSD1-specific fields with defaults if missing
    $psd1Defaults = @{
        'checkStrongMapping'         = $false
        'strongMappingOptional'      = $true
        'updateLocalSettings'        = $false
        'groupTag'                   = ''
        'assignedUser'               = ''
        'migrateLegacyConfiguration' = $true
    }
    
    foreach ($key in $psd1Defaults.Keys)
    {
        if (-not $psd1Config.ContainsKey($key))
        {
            $psd1Config[$key] = $psd1Defaults[$key]
            Write-Verbose "[$functionName] Added default value for '$key'"
        }
    }
    
    Write-Verbose "[$functionName] Domain structure transformation complete with $($psd1Config.Keys.Count) keys"
    return $psd1Config
}

function ConvertTo-SettingsPsd1Structure()
{
    <#
    .SYNOPSIS
        Transforms settings.json structure to settings.psd1 format.
    
    .DESCRIPTION
        Internal helper function that performs the structural transformation from 
        settings.json to settings.psd1 format:
        - Preserves 'auth', 'requiredScopes', 'globalSettings' structure
        - Removes 'menu' and 'domains' objects
        - Converts 'appMode' to 'appModes' within globalSettings
        - Extracts version and description to root level
        - Removes 'appInfo' object and flattens relevant fields
    
    .PARAMETER JsonConfig
        Hashtable containing the converted settings JSON configuration.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns the transformed hashtable ready for PSD1 export.
    
    .NOTES
        - Private helper function for settings.json conversion
        - Handles all structural differences between settings.json and settings.psd1
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$JsonConfig
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting settings structure transformation"
    Write-Log -logFile $logFile -Module $functionName -Message "Starting settings structure transformation"
    
    # Create the output hashtable
    $psd1Config = @{}
    
    # Step 1: Preserve root-level fields (description, version)
    if ($JsonConfig.ContainsKey('description'))
    {
        $psd1Config['description'] = $JsonConfig['description']
        Write-Verbose "[$functionName] Copied 'description' to root level"
    }
    
    if ($JsonConfig.ContainsKey('version'))
    {
        $psd1Config['version'] = $JsonConfig['version']
        Write-Verbose "[$functionName] Copied 'version' to root level"
    }
    
    # Step 2: Preserve auth configuration
    if ($JsonConfig.ContainsKey('auth'))
    {
        $psd1Config['auth'] = $JsonConfig['auth']
        Write-Verbose "[$functionName] Copied 'auth' configuration"
    }
    
    # Step 3: Preserve requiredScopes
    if ($JsonConfig.ContainsKey('requiredScopes'))
    {
        $psd1Config['requiredScopes'] = $JsonConfig['requiredScopes']
        Write-Verbose "[$functionName] Copied 'requiredScopes' array"
    }
    
    # Step 4: Process globalSettings - apply transformations
    if ($JsonConfig.ContainsKey('globalSettings'))
    {
        Write-Verbose "[$functionName] Processing 'globalSettings' object"
        $globalSettings = $JsonConfig['globalSettings']
        $transformedGlobalSettings = @{}
        
        foreach ($key in $globalSettings.Keys)
        {
            if ($key -eq 'appMode')
            {
                # Convert appMode (string) to appModes (array)
                Write-Verbose "[$functionName] Converting 'appMode' to 'appModes' in globalSettings"
                $appModeValue = $globalSettings['appMode']
                
                if ($appModeValue -is [string])
                {
                    $transformedGlobalSettings['appModes'] = @($appModeValue)
                }
                elseif ($appModeValue -is [array])
                {
                    $transformedGlobalSettings['appModes'] = $appModeValue
                }
                else
                {
                    Write-Warning "[$functionName] Unexpected appMode type: $($appModeValue.GetType().Name)"
                    $transformedGlobalSettings['appModes'] = @($appModeValue.ToString())
                }
            }
            elseif ($key -eq 'appInfo')
            {
                # Skip appInfo - it's already extracted to root level if needed
                Write-Verbose "[$functionName] Skipping 'appInfo' in globalSettings"
                continue
            }
            elseif ($key -eq 'repo')
            {
                # Skip 'repo' field (repoInfo is used instead)
                Write-Verbose "[$functionName] Skipping 'repo' field"
                continue
            }
            else
            {
                # Copy all other settings
                $transformedGlobalSettings[$key] = $globalSettings[$key]
                Write-Verbose "[$functionName] Copied '$key' in globalSettings"
            }
        }
        
        $psd1Config['globalSettings'] = $transformedGlobalSettings
        Write-Verbose "[$functionName] Transformed globalSettings with $($transformedGlobalSettings.Keys.Count) keys"
    }
    
    # Step 5: Explicitly remove 'menu' and 'domains' if present
    if ($JsonConfig.ContainsKey('menu'))
    {
        Write-Verbose "[$functionName] Removing 'menu' object as per settings.psd1 format"
    }
    
    if ($JsonConfig.ContainsKey('domains'))
    {
        Write-Verbose "[$functionName] Removing 'domains' object as per settings.psd1 format"
    }
    
    Write-Verbose "[$functionName] Settings structure transformation complete with $($psd1Config.Keys.Count) keys"
    return $psd1Config
}

function Convert-DomainJsonToPsd1()
{
    <#
    .SYNOPSIS
        Converts a domain JSON file to PSD1 format.
    
    .DESCRIPTION
        Internal helper function that handles the conversion of a single domain
        configuration file from JSON to PSD1 format.
    
    .PARAMETER JsonFilePath
        The full path to the domain JSON file to convert.
    
    .PARAMETER Validate
        Validates the resulting .psd1 file can be loaded successfully.
    
    .PARAMETER CreateBackup
        Creates a timestamped backup if the output file already exists.
    
    .PARAMETER Force
        Overwrites existing files without prompting.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns status information about the conversion.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,
        [bool]$Validate = $true,
        [bool]$CreateBackup = $true,
        [switch]$Force
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $result = @{
        success           = $false
        fileName          = [System.IO.Path]::GetFileName($JsonFilePath)
        outputPath        = $null
        autopilotProfiles = @()
        errorMessage      = $null
    }
    
    try
    {
        # Determine output path
        $directory = Split-Path -Path $JsonFilePath -Parent
        $filename = [System.IO.Path]::GetFileNameWithoutExtension($JsonFilePath)
        $outputPath = Join-Path $directory "$filename.psd1"
        
        Write-Verbose "[$functionName] Converting $($result.fileName) to $([System.IO.Path]::GetFileName($outputPath))"
        
        # Read and parse JSON
        $jsonContent = Get-Content -Path $JsonFilePath -Raw -ErrorAction Stop
        $jsonObject = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        # Convert to hashtable
        $jsonHashtable = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
        
        # Transform structure for domain PSD1
        $psd1Config = ConvertTo-Psd1Structure -JsonConfig $jsonHashtable
        
        # Extract autopilot profiles from the transformed config
        if ($psd1Config.ContainsKey('autopilotProfilesToInclude'))
        {
            $result.autopilotProfiles = $psd1Config['autopilotProfilesToInclude']
            Write-Verbose "[$functionName] Extracted $($result.autopilotProfiles.Count) autopilot profile(s)"
        }
        
        # Export to PSD1
        $exportParams = @{
            InputObject  = $psd1Config
            Path         = $outputPath
            Validate     = $Validate
            CreateBackup = $CreateBackup
            Force        = $Force
        }
        
        $resultPath = Export-PowerShellDataFile @exportParams
        
        $result.success = $true
        $result.outputPath = $resultPath
        Write-Verbose "[$functionName] Successfully converted domain file"
    }
    catch
    {
        $result.success = $false
        $result.errorMessage = $_.Exception.Message
        Write-Error "[$functionName] Failed to convert $($result.fileName): $($_.Exception.Message)"
    }
    
    return $result
}

function Convert-SettingsJsonToPsd1()
{
    <#
    .SYNOPSIS
        Converts settings.json to settings.psd1 format.
    
    .DESCRIPTION
        Internal helper function that handles the conversion of settings.json
        to settings.psd1 format, applying the specific transformations needed
        for the global settings file.
    
    .PARAMETER JsonFilePath
        The full path to the settings.json file to convert.
    
    .PARAMETER Validate
        Validates the resulting .psd1 file can be loaded successfully.
    
    .PARAMETER CreateBackup
        Creates a timestamped backup if the output file already exists.
    
    .PARAMETER Force
        Overwrites existing files without prompting.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns status information about the conversion.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,
        [bool]$Validate = $true,
        [bool]$CreateBackup = $true,
        [switch]$Force
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $result = @{
        success      = $false
        fileName     = [System.IO.Path]::GetFileName($JsonFilePath)
        outputPath   = $null
        errorMessage = $null
    }
    
    try
    {
        # Determine output path
        $directory = Split-Path -Path $JsonFilePath -Parent
        $outputPath = Join-Path $directory "settings.psd1"
        
        Write-Verbose "[$functionName] Converting settings.json to settings.psd1"
        
        # Read and parse JSON
        $jsonContent = Get-Content -Path $JsonFilePath -Raw -ErrorAction Stop
        $jsonObject = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        # Convert to hashtable
        $jsonHashtable = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
        
        # Transform structure for settings PSD1
        $psd1Config = ConvertTo-SettingsPsd1Structure -JsonConfig $jsonHashtable
        
        # Export to PSD1
        $exportParams = @{
            InputObject  = $psd1Config
            Path         = $outputPath
            Validate     = $Validate
            CreateBackup = $CreateBackup
            Force        = $Force
        }
        
        $resultPath = Export-PowerShellDataFile @exportParams
        
        $result.success = $true
        $result.outputPath = $resultPath
        Write-Verbose "[$functionName] Successfully converted settings.json"
    }
    catch
    {
        $result.success = $false
        $result.errorMessage = $_.Exception.Message
        Write-Error "[$functionName] Failed to convert settings.json: $($_.Exception.Message)"
    }
    
    return $result
}

