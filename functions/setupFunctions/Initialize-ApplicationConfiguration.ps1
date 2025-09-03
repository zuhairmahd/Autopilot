function Initialize-ApplicationConfiguration()
{
    <#
    .SYNOPSIS
        Initializes application configuration from settings files or defaults.
    
    .DESCRIPTION
        Centralized function to handle configuration loading, including settings.json and strings.json 
        file validation, auth configuration processing, and scope merging. Eliminates code duplication
        and provides robust error handling.
    
    .PARAMETER InitFile
        Path to the settings.json file.
    
    .PARAMETER StringsFile
        Path to the strings.json file.
    
    .PARAMETER Domain
        The domain name for configuration defaults.
    
    .PARAMETER PSBoundParameters
        Parameters passed from the calling script to preserve command-line overrides.
    
    .PARAMETER LogFile
        Path to the log file for logging.
    
    .PARAMETER ScriptName
        Name of the calling script for logging.
    
    .OUTPUTS
        Hashtable containing:
        - Auth: Auth configuration hashtable
        - GlobalSettings: Global settings hashtable  
        - LocalSettings: Local/domain settings hashtable
        - Menus: Menu configuration array
        - RequiredScopes: Merged and deduplicated scopes array
        - Success: Boolean indicating success/failure
        - ErrorMessage: Error message if Success is false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InitFile,
        [Parameter(Mandatory = $true)]
        [string]$StringsFile,
        [string]$Domain = "contoso.com",
        [hashtable]$PSBoundParameters = @{}
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Initializing application configuration"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    Write-Verbose "[$functionName] StringsFile: $StringsFile"
    Write-Verbose "[$functionName] Domain: $Domain"
    
    # Helper function for batched file validation (Performance Optimization Phase 2)
    function Test-ConfigurationFilesExist() 
    {
        [CmdletBinding()]
        param (
            [array]$FilesToCheck
        )
        $functionName = $MyInvocation.MyCommand.Name
        $validationResults = @{}
        $existingCount = 0
        $missingCount = 0
        
        Write-Verbose "[$functionName] Batch validating $($FilesToCheck.Count) configuration files"
        Write-Log -logFile $logFile -module $functionName -Message "Batch validating $($FilesToCheck.Count) configuration files" -logLevel "Information"
        foreach ($file in $FilesToCheck)
        {
            Write-Verbose "[$functionName] Checking $($file.Path)"
            Write-Log -logFile $logFile -module $functionName -Message "Checking $($file.Path)" -logLevel "Verbose"
            $exists = Test-Path -Path $file.Path
            Write-Log -logFile $logFile -module $functionName -Message "File $($file.Path) exists: $exists" -logLevel "Verbose"
            $validationResults[$file.Type] = @{
                Path   = $file.Path
                Exists = $exists
                Type   = $file.Type
            }
            
            if ($exists)
            {
                $existingCount++
            }
            else
            {
                $missingCount++
            }
        }
        
        Write-Verbose "[$functionName] File validation complete: $existingCount existing, $missingCount missing"
        Write-Log -logFile $logFile -module $functionName -Message "File validation complete: $existingCount existing, $missingCount missing" -logLevel "Information"
        return $validationResults
    }
    
    try
    {
        # Initialize result object
        $result = @{
            Auth           = @{}
            GlobalSettings = @{}
            LocalSettings  = @{}
            Menus          = @()
            RequiredScopes = @()
            Success        = $false
            ErrorMessage   = ""
        }
        
        # Step 1: Ensure configuration files exist with defaults
        $configResult = Initialize-ConfigurationFiles -InitFile $InitFile -StringsFile $StringsFile -Domain $Domain
        if (-not $configResult.Success)
        {
            $result.ErrorMessage = $configResult.ErrorMessage
            return $result
        }
        
        # Step 2: Batch validate critical configuration files (Performance Optimization Phase 2)
        $filesToValidate = @(
            @{ Path = $InitFile; Type = "Settings" }
            @{ Path = $StringsFile; Type = "Strings" }
            @{ Path = "$([System.IO.Path]::GetDirectoryName($InitFile))\menu.json"; Type = "Menu" }
        )
        
        $fileValidation = Test-ConfigurationFilesExist $filesToValidate
        
        # Step 3: Load and process configuration if settings.json exists
        if ($fileValidation["Settings"].Exists)
        {
            Write-Verbose "[$functionName] Loading configuration from $InitFile"
            
            try
            {
                # Load configuration content
                $initFileContent = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
                
                # Step 3: Process auth configuration
                $authResult = Initialize-AuthConfiguration -AuthConfiguration $initFileContent.auth -PSBoundParameters $PSBoundParameters
                $result.Auth = $authResult.Auth
                
                # Step 4: Process global settings
                $globalResult = Initialize-GlobalSettings -GlobalConfigData $initFileContent.globalSettings -PSBoundParameters $PSBoundParameters -processConfigOverwrite
                $result.GlobalSettings = $globalResult.GlobalSettings
                
                # Step 5: Process domain-specific settings
                $configurationPath = Split-Path -Parent $InitFile
                $localResult = Initialize-LocalSettings -InitFileContent $initFileContent -Domain $Domain -PSBoundParameters $PSBoundParameters -GlobalSettings $result.GlobalSettings -ConfigurationPath $configurationPath -processConfigOverwrite
                $result.LocalSettings = $localResult.LocalSettings
                
                # Step 6: Process and merge scopes
                $scopeResult = Initialize-RequiredScopes -InitFileContent $initFileContent -Domain $Domain
                $result.RequiredScopes = $scopeResult.RequiredScopes
            }
            catch
            {
                $result.ErrorMessage = "Error loading configuration from $InitFile`: $($_.Exception.Message)"
                Write-Verbose "[$functionName] $($result.ErrorMessage)"
                return $result
            }
        }
        else
        {
            Write-Verbose "[$functionName] Settings file not found, using default configuration"
            
            # Use default auth configuration when no settings file exists
            $result.Auth = @{
                delegated = $true
                authType  = "PublicAuthFlow"
                scope     = @("offline_access", "openid", "Device.ReadWrite.All")
            }
            
            # Initialize empty collections for other settings
            $result.GlobalSettings = @{}
            $result.LocalSettings = @{}
            $result.RequiredScopes = @()
        }
        
        $result.Success = $true
        Write-Verbose "[$functionName] Configuration initialization completed successfully"
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Unexpected error during configuration initialization: $($_.Exception.Message)"
        Write-Verbose "[$functionName] $($result.ErrorMessage)"
        return $result
    }
}

function Initialize-ConfigurationFiles()
{
    <#
    .SYNOPSIS
        Ensures configuration files exist with proper defaults.
    #>
    [CmdletBinding()]
    param(
        [string]$InitFile,
        [string]$StringsFile,
        [string]$Domain
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $result = @{ Success = $false; ErrorMessage = "" }
    
    try
    {
        # Ensure settings.json exists with defaults
        Write-Verbose "[$functionName] Ensuring settings.json exists with defaults"
        $settingsCreated = Test-SettingsJsonExists -SettingsFile $InitFile -Silent
        if (-not $settingsCreated)
        {
            $result.ErrorMessage = "Failed to create or validate settings.json file"
            return $result
        }
        
        # Ensure strings.json exists with defaults
        Write-Verbose "[$functionName] Ensuring strings.json exists with defaults"
        $stringsCreated = Test-StringsJsonExists -StringsFile $StringsFile -Silent
        if (-not $stringsCreated)
        {
            $result.ErrorMessage = "Failed to create or validate strings.json file"
            return $result
        }
        
        # Ensure menu.json exists with defaults
        Write-Verbose "[$functionName] Ensuring menu.json exists with defaults"
        $MenuFile = "$pwd\menu.json"
        $menuCreated = Test-MenuJsonExists -MenuFile $MenuFile -Silent
        if (-not $menuCreated)
        {
            $result.ErrorMessage = "Failed to create or validate menu.json file"
            return $result
        }
        
        $result.Success = $true
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Error ensuring configuration files exist: $($_.Exception.Message)"
        return $result
    }
}

function Initialize-AuthConfiguration()
{
    <#
    .SYNOPSIS
        Processes auth configuration from settings file.
    #>
    [CmdletBinding()]
    param(
        [object]$AuthConfiguration,
        [hashtable]$PSBoundParameters
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $auth = @{}
    
    if ($null -eq $AuthConfiguration)
    {
        Write-Verbose "[$functionName] No auth configuration found, using defaults"
        return @{ Auth = $auth }
    }
    
    Write-Verbose "[$functionName] Processing auth configuration"
    
    # Batch processing counters for performance optimization
    $authProcessedCount = 0
    $authBooleanCount = 0
    $authOverrideCount = 0
    
    foreach ($key in $AuthConfiguration.PSObject.Properties.Name)
    {
        # Conditional verbose logging - only log individual settings when explicit verbose is used
        if ($VerbosePreference -eq 'Continue')
        {
            Write-Verbose "[$functionName] Processing auth key: $key"
        }
        
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $AuthConfiguration.$key)
        {
            if ($AuthConfiguration.$key -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($AuthConfiguration.$key)
                $auth.add($key, $keyBooleanValue)
                if ($VerbosePreference -eq 'Continue')
                {
                    Write-Verbose "[$functionName] Set $key to boolean value: $keyBooleanValue"
                }
                $authBooleanCount++
            }
            else
            {
                $auth.add($key, $AuthConfiguration.$key)
                if ($VerbosePreference -eq 'Continue')
                {
                    Write-Verbose "[$functionName] Set $key to string value: $($AuthConfiguration.$key)"
                }
            }
            $authProcessedCount++
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $auth.add($key, $PSBoundParameters[$key])
            if ($VerbosePreference -eq 'Continue')
            {
                Write-Verbose "[$functionName] Used command-line parameter for $key`: $($PSBoundParameters[$key])"
            }
            $authOverrideCount++
        }
    }
    
    # Batch summary logging for performance optimization
    Write-Verbose "[$functionName] Completed processing $authProcessedCount auth settings ($authBooleanCount boolean, $authOverrideCount overrides)"
    
    return @{ Auth = $auth }
}

function Initialize-GlobalSettings()
{
    <#
    .SYNOPSIS
        Processes global settings from configuration file with overwrite support.
    #>
    [CmdletBinding()]
    param(
        [object]$GlobalConfigData,
        [hashtable]$PSBoundParameters,
        [switch]$processConfigOverwrite
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $logFile -Message "Initializing global settings" -module $functionName -logLevel "Information"
    $globalSettings = @{}
    
    if ($null -eq $GlobalConfigData)
    {
        Write-Log -logFile $logFile -Message "No global settings found" -module $functionName -LogLevel "Verbose"
        return @{ GlobalSettings = $globalSettings }
    }
    
    Write-Log -logFile $logFile -Message "Processing $($GlobalConfigData.PSObject.Properties.Name.count) global settings" -module $functionName -LogLevel "Verbose"
    
    # Batch processing counters for performance optimization
    $processedCount = 0
    $booleanCount = 0
    $overrideCount = 0
    
    foreach ($key in $GlobalConfigData.PSObject.Properties.Name)
    {
        # Conditional verbose logging - only log individual settings when explicit verbose is used
        if ($VerbosePreference -eq 'Continue')
        {
        }
        Write-Log -logFile $logFile -Message "Processing global setting: $key" -module $functionName -logLevel "Verbose"
        
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $GlobalConfigData.$key)
        {
            if ($VerbosePreference -eq 'Continue')
            {
            }
            Write-Log -logFile $logFile -Message "Checking if $key is a boolean" -module $functionName -logLevel "Verbose"
            
            if ($GlobalConfigData.$key -in ('true', 'false'))
            {
                if ($VerbosePreference -eq 'Continue')
                {
                }
                Write-Log -logFile $logFile -Message "$key is a boolean" -module $functionName -logLevel "Verbose"
                $keyBooleanValue = [bool]::Parse($GlobalConfigData.$key)
                $globalSettings.add($key, $keyBooleanValue)
                if ($VerbosePreference -eq 'Continue')
                {
                }
                Write-Log -logFile $logFile -Message "Set global $key to boolean: $keyBooleanValue" -module $functionName -logLevel "Verbose"
                $booleanCount++
            }
            else
            {
                $globalSettings.add($key, $GlobalConfigData.$key)
                if ($VerbosePreference -eq 'Continue')
                {
                }
                Write-Log -logFile $logFile -Message "Set global $key to: $($GlobalConfigData.$key)" -module $functionName -logLevel "Verbose"
            }
            $processedCount++
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $globalSettings.add($key, $PSBoundParameters[$key])
            if ($VerbosePreference -eq 'Continue')
            {
            }
            Write-Log -logFile $logFile -Message "Used command-line override for global $key" -module $functionName -logLevel "Verbose"
            $overrideCount++
        }
    }
    
    # Batch summary logging for performance optimization
    Write-Log -logFile $logFile -Message "Completed processing $processedCount global settings ($booleanCount boolean, $overrideCount overrides)" -module $functionName -LogLevel "Verbose"
    
    # Apply overwrite settings to global configuration
    if ($processConfigOverwrite)
    {
        Write-Log -logFile $logFile -Message "Applying overwrite configuration to global settings" -module $functionName -logLevel "Information"
        try
        {
            $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
            # Apply global-specific overwrites
            Write-Log -logFile $logFile -Message "Applying global-specific overwrite configuration" -module $functionName -logLevel "Information"
            if ($overwriteConfig.GlobalSettings)
            {
                Write-Log -logFile $logFile -Message "Applying $($overwriteConfig.GlobalSettings.Count) global overwrite settings" -module $functionName -logLevel "Information"
                foreach ($overwriteKey in $overwriteConfig.GlobalSettings.Keys)
                {
                    $oldValue = if ($globalSettings.ContainsKey($overwriteKey))
                    {
                        $globalSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $globalSettings[$overwriteKey] = $overwriteConfig.GlobalSettings[$overwriteKey]
                    Write-Log -LogFile $logFile -Message "Applied global overwrite '$overwriteKey': $oldValue -> $($overwriteConfig.GlobalSettings[$overwriteKey])" -Module $functionName -LogLevel "Information"
                }
            }
            # Apply universal overwrites
            Write-Log -logFile $logFile -Message "Applying universal overwrite configuration" -module $functionName -logLevel "Information"
            if ($overwriteConfig.UniversalSettings)
            {
                Write-Log -logFile $logFile -Message "Applying $($overwriteConfig.UniversalSettings.Count) universal overwrite settings to global" -module $functionName -logLevel "Information"
                foreach ($overwriteKey in $overwriteConfig.UniversalSettings.Keys)
                {
                    $oldValue = if ($globalSettings.ContainsKey($overwriteKey))
                    {
                        $globalSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $globalSettings[$overwriteKey] = $overwriteConfig.UniversalSettings[$overwriteKey]
                    Write-Log -LogFile $logFile -Message "Applied universal overwrite '$overwriteKey': $oldValue -> $($overwriteConfig.UniversalSettings[$overwriteKey])" -Module $functionName -LogLevel "Information"
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error applying overwrite configuration: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Error applying overwrite configuration: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
        }
    }    
    return @{ GlobalSettings = $globalSettings }
}

function Initialize-LocalSettings()
{
    <#
    .SYNOPSIS
        Processes domain-specific settings from separate domain configuration files.
    #>
    [CmdletBinding()]
    param(
        [object]$InitFileContent,
        [string]$Domain,
        [hashtable]$PSBoundParameters,
        [hashtable]$GlobalSettings = @{},
        [string]$ConfigurationPath = $pwd,
        [switch]$processConfigOverwrite
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $localSettings = @{}
    Write-Log -LogFile $logFile -Message "Initializing local settings for domain: $Domain" -Module $functionName -LogLevel "Information"
    # First, check for migration from old format (domains in settings.json)
    if ($InitFileContent.domains -and $InitFileContent.domains.$Domain)
    {
        Write-Log -LogFile $logFile -Message "Found domain configuration in settings.json, performing migration" -Module $functionName -LogLevel "Verbose"
        $settingsFile = Join-Path $ConfigurationPath "settings.json"
        $migrationResult = Migrate-DomainsToSeparateFiles -SettingsFile $settingsFile -ConfigurationPath $ConfigurationPath -RemoveFromSettings $true
        if ($migrationResult.Success)
        {
            Write-Verbose "[$functionName] Migration completed successfully"
            Write-Log -LogFile $logFile -Message "Domain migration completed successfully" -Module $functionName -LogLevel "Information"
        }
        else
        {
            Write-Warning "[$functionName] Migration had issues: $($migrationResult.ErrorMessages -join '; ')"
            Write-Log -LogFile $logFile -Message "Domain migration had issues: $($migrationResult.ErrorMessages -join '; ')" -Module $functionName -LogLevel "Warning"
        }
    }
    
    # Load domain configuration from separate file
    Write-Verbose "[$functionName] Loading domain configuration from separate file for: $Domain"
    $domainConfig = Get-DomainConfigurationFromFiles -DomainName $Domain -GlobalSettings $GlobalSettings -ConfigurationPath $ConfigurationPath
    
    if ($null -eq $domainConfig -or $null -eq $domainConfig.settings)
    {
        Write-Verbose "[$functionName] No domain-specific settings found for $Domain"
        return @{ LocalSettings = $localSettings }
    }
    
    $localConfigData = ConvertFrom-JsonToHashtable -JsonObject $domainConfig
    Write-Log -LogFile $logFile -Message "Processing domain settings for $Domain from separate file" -Module $functionName -LogLevel "Verbose"
    
    # Handle both hashtables and PSCustomObjects correctly
    # Avoid hashtable system properties (IsReadOnly, IsFixedSize, IsSynchronized, Keys, Values, SyncRoot, Count)
    $settingsKeys = @()
    if ($localConfigData -is [hashtable])
    {
        Write-Verbose "[$functionName] Processing hashtable-based domain settings"
        $settingsKeys = $localConfigData.Keys
    }
    elseif ($localConfigData.PSObject.Properties)
    {
        Write-Verbose "[$functionName] Processing PSCustomObject-based domain settings"
        # Filter out hashtable system properties in case they were inadvertently included
        $unwantedProperties = @('IsReadOnly', 'IsFixedSize', 'IsSynchronized', 'Keys', 'Values', 'SyncRoot', 'Count')
        $settingsKeys = $localConfigData.PSObject.Properties.Name | Where-Object { $_ -notin $unwantedProperties }
    }
    else
    {
        Write-Log -LogFile $logFile -Message "No settings properties found in domain configuration" -Module $functionName -LogLevel "Verbose"
    }
    
    Write-Verbose "[$functionName] Processing $($settingsKeys.Count) settings keys"
    Write-Log -LogFile $logFile -Message "Processing $($settingsKeys.Count) settings keys: $($settingsKeys -join ', ')" -Module $functionName -LogLevel "Verbose"
    
    foreach ($key in $settingsKeys)
    {
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $localConfigData.$key)
        {
            if ($localConfigData.$key -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($localConfigData.$key)
                $localSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$functionName] Set local $key to boolean: $keyBooleanValue"
            }
            else
            {
                $localSettings.add($key, $localConfigData.$key)
                Write-Verbose "[$functionName] Set local $key to: $($localConfigData.$key)"
            }
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $localSettings.add($key, $PSBoundParameters[$key])
            Write-Verbose "[$functionName] Used command-line override for local $key"
        }
    }
    
    # Apply overwrite settings to local/domain configuration
    if ($processConfigOverwrite)
    {
        Write-Log -logFile $logFile -Message "Applying overwrite configuration to local settings" -module $functionName -logLevel "Information"
        try
        {
            $overwriteConfig = Get-ApplicationDefaults -DefaultType "Overwrite"
            # Apply local-specific overwrites
            if ($overwriteConfig.LocalSettings)
            {
                Write-Log -logFile $logFile -Message "Applying $($overwriteConfig.LocalSettings.Count) local overwrite settings" -module $functionName -logLevel "Information"
                foreach ($overwriteKey in $overwriteConfig.LocalSettings.Keys)
                {
                    $oldValue = if ($localSettings.ContainsKey($overwriteKey))
                    {
                        $localSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $localSettings[$overwriteKey] = $overwriteConfig.LocalSettings[$overwriteKey]
                    Write-Log -LogFile $logFile -Message "Applied local overwrite '$overwriteKey': $oldValue -> $($overwriteConfig.LocalSettings[$overwriteKey])" -Module $functionName -LogLevel "Information"
                }
            }
            # Apply universal overwrites
            Write-Log -logFile $logFile -Message "Applying universal overwrite configuration to local settings" -module $functionName -logLevel "Information"
            if ($overwriteConfig.UniversalSettings)
            {
                Write-Verbose "[$functionName] Applying $($overwriteConfig.UniversalSettings.Count) universal overwrite settings to local"
                foreach ($overwriteKey in $overwriteConfig.UniversalSettings.Keys)
                {
                    $oldValue = if ($localSettings.ContainsKey($overwriteKey))
                    {
                        $localSettings[$overwriteKey] 
                    }
                    else
                    {
                        "NOT_SET" 
                    }
                    $localSettings[$overwriteKey] = $overwriteConfig.UniversalSettings[$overwriteKey]
                    Write-Log -LogFile $logFile -Message "Applied universal overwrite '$overwriteKey': $oldValue -> $($overwriteConfig.UniversalSettings[$overwriteKey])" -Module $functionName -LogLevel "Information"
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error applying overwrite configuration: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Error applying overwrite configuration: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
        }
    }
    return @{ LocalSettings = $localSettings }
}

function Initialize-RequiredScopes()
{
    <#
    .SYNOPSIS
        Processes and merges required scopes from configuration.
    #>
    [CmdletBinding()]
    param(
        [object]$InitFileContent,
        [string]$Domain
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Get basic scopes from configuration
    $basicScopes = $InitFileContent.requiredScopes
    if ($null -eq $basicScopes) 
    { 
        Write-Verbose "[$functionName] No basic scopes found, initializing as empty array"
        $basicScopes = @() 
    }
    
    # Get additional scopes for the domain from separate file
    $additionalScopes = $null
    
    # First check if domain exists in old format (for backward compatibility)
    if ($InitFileContent.domains -and $InitFileContent.domains.$Domain)
    {
        $additionalScopes = $InitFileContent.domains.$Domain.additionalScopes
    }
    else
    {
        # Load from separate domain file
        Write-Verbose "[$functionName] Loading additional scopes from separate domain file for: $Domain"
        $domainConfig = Get-DomainConfigurationFromFiles -DomainName $Domain -ConfigurationPath $pwd
        if ($domainConfig -and $domainConfig.additionalScopes)
        {
            $additionalScopes = $domainConfig.additionalScopes
        }
    }
    
    if ($null -eq $additionalScopes) 
    { 
        Write-Verbose "[$functionName] No additional scopes found for $Domain, initializing as empty array"
        $additionalScopes = @() 
    }
    
    # Ensure arrays and merge
    $basicScopes = @($basicScopes)
    $additionalScopes = @($additionalScopes)
    
    Write-Verbose "[$functionName] Basic scopes: $($basicScopes.Count), Additional scopes: $($additionalScopes.Count)"
    
    # Merge and deduplicate
    $allScopes = @($basicScopes) + @($additionalScopes)
    $requiredScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
    
    Write-Verbose "[$functionName] Merged scopes - Total unique: $($requiredScopes.Count)"
    
    return @{ RequiredScopes = $requiredScopes }
}