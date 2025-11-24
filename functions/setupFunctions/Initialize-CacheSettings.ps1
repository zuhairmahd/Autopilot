function Initialize-CacheSettings()
{
    <#
    .SYNOPSIS
        Processes cache settings configuration from settings file.
    
    .DESCRIPTION
        Validates and processes cache settings from the configuration file,
        performing deep merge with defaults from Get-ApplicationDefaults.
        Handles both top-level settings (enabled, maxCacheSize, defaultExpirationMinutes)
        and nested cacheTypes configuration.
    
    .PARAMETER CacheSettingsData
        Cache settings hashtable from settings.psd1.
    
    .PARAMETER BoundParameters
        Hashtable of command-line parameters to preserve overrides.
    
    .OUTPUTS
        Hashtable containing:
        - CacheSettings: Merged cache settings hashtable with nested cacheTypes
        - Changed: Boolean indicating whether missing keys were merged from defaults
    
    .EXAMPLE
        $cacheResult = Initialize-CacheSettings -CacheSettingsData $initFileContent.cacheSettings -BoundParameters $PSBoundParameters
        $cacheSettings = $cacheResult.CacheSettings
    #>
    [CmdletBinding()]
    param(
        $CacheSettingsData,
        [hashtable]$BoundParameters = @{}
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -logFile $logFile -module $functionName -Message "Initializing cache settings" -logLevel "Information"
    Write-Verbose "[$functionName] Initializing cache settings"
    
    # Helper function to test dictionary membership (handles both Hashtable and OrderedDictionary)
    function Test-DictContains()
    {
        [CmdletBinding()]
        param(
            $Dictionary,
            [string]$Key
        )
        $functionName = $MyInvocation.MyCommand.Name
        if ($null -eq $Dictionary)
        {
            Write-Verbose "[$functionName] Dictionary is null"
            Write-Log -logFile $logFile -module $functionName -Message "Dictionary is null" -logLevel "Verbose"         
            return $false 
        }
        if ($Dictionary -is [hashtable])
        {
            Write-Verbose "[$functionName] Checking if hashtable contains key '$Key'"
            Write-Log -logFile $logFile -module $functionName -Message "Checking if hashtable contains key '$Key'" -logLevel "Verbose"
            return $Dictionary.ContainsKey($Key) 
        }
        elseif ($Dictionary -is [System.Collections.IDictionary])
        {
            Write-Verbose "[$functionName] Checking if IDictionary contains key '$Key'"
            Write-Log -logFile $logFile -module $functionName -Message "Checking if IDictionary contains key '$Key'" -logLevel "Verbose"
            return $Dictionary.Contains($Key) 
        }
        else
        {
            Write-Verbose "[$functionName] Unsupported dictionary type: $($Dictionary.GetType().FullName)"
            Write-Log -logFile $logFile -module $functionName -Message "Unsupported dictionary type: $($Dictionary.GetType().FullName)" -logLevel "Warning"
            return $false 
        }
    }
    
    $cacheSettings = @{}
    
    if ($null -eq $CacheSettingsData)
    {
        Write-Log -logFile $logFile -module $functionName -Message "No cache settings found in configuration, using defaults" -logLevel "Verbose"
        Write-Verbose "[$functionName] No cache settings found in configuration, using defaults"
        
        # Get defaults and return
        try
        {
            $defaultCacheSettings = Get-ApplicationDefaults -DefaultType 'cacheSettings'
            return @{ CacheSettings = $defaultCacheSettings; Changed = $true }
        }
        catch
        {
            Write-Warning "[$functionName] Error getting default cache settings: $($_.Exception.Message)"
            Write-Log -logFile $logFile -module $functionName -Message "Error getting default cache settings: $($_.Exception.Message)" -logLevel "Warning"
            return @{ CacheSettings = @{}; Changed = $false }
        }
    }
    
    Write-Verbose "[$functionName] Processing cache settings configuration"
    Write-Log -logFile $logFile -module $functionName -Message "Processing cache settings configuration" -logLevel "Verbose"
    
    # Get defaults for merging
    $cacheDefaults = Get-ApplicationDefaults -DefaultType 'cacheSettings'
    
    # Initialize with default structure
    $cacheSettings = @{
        enabled                  = $cacheDefaults.enabled
        maxCacheSize             = $cacheDefaults.maxCacheSize
        defaultExpirationMinutes = $cacheDefaults.defaultExpirationMinutes
        cacheTypes               = @{}
    }
    
    # Merge top-level settings (enabled, maxCacheSize, defaultExpirationMinutes)
    $topLevelKeys = @('enabled', 'maxCacheSize', 'defaultExpirationMinutes')
    foreach ($key in $topLevelKeys)
    {
        # Command-line parameter takes highest priority
        if ($BoundParameters.ContainsKey($key))
        {
            $cacheSettings[$key] = $BoundParameters[$key]
            Write-Verbose "[$functionName] Using command-line override for $key"
            Write-Log -logFile $logFile -module $functionName -Message "Using command-line override for $key" -logLevel "Verbose"
        }
        # Then loaded configuration value
        elseif ($CacheSettingsData -and (Test-DictContains $CacheSettingsData $key) -and $null -ne $CacheSettingsData[$key])
        {
            $cacheSettings[$key] = $CacheSettingsData[$key]
            Write-Verbose "[$functionName] Using loaded value for $key`: $($CacheSettingsData[$key])"
            Write-Log -logFile $logFile -module $functionName -Message "Using loaded value for $key`: $($CacheSettingsData[$key])" -logLevel "Verbose"
        }
        # Else keep default (already set above)
    }
    
    # Deep merge cacheTypes (preserving any additional types from loaded configuration)
    $allTypeNames = @()
    
    # Collect type names from defaults
    if ($cacheDefaults.cacheTypes -and $cacheDefaults.cacheTypes.Keys)
    {
        $allTypeNames += $cacheDefaults.cacheTypes.Keys
    }
    
    # Collect type names from loaded configuration
    if ($CacheSettingsData -and $CacheSettingsData.cacheTypes -and $CacheSettingsData.cacheTypes.Keys)
    {
        $allTypeNames += $CacheSettingsData.cacheTypes.Keys
    }
    
    $allTypeNames = $allTypeNames | Sort-Object -Unique
    
    Write-Verbose "[$functionName] Processing $($allTypeNames.Count) cache type configurations"
    Write-Log -logFile $logFile -module $functionName -Message "Processing $($allTypeNames.Count) cache type configurations" -logLevel "Verbose"
    
    foreach ($typeName in $allTypeNames)
    {
        # Get default type configuration
        $defType = if (Test-DictContains $cacheDefaults.cacheTypes $typeName)
        {
            $cacheDefaults.cacheTypes[$typeName]
        }
        else
        {
            @{}
        }
        
        # Get loaded type configuration
        $loadedType = if ($CacheSettingsData -and $CacheSettingsData.cacheTypes -and (Test-DictContains $CacheSettingsData.cacheTypes $typeName))
        {
            $CacheSettingsData.cacheTypes[$typeName]
        }
        else
        {
            @{}
        }
        
        # Merge this cache type
        $computedType = @{}
        
        # Process 'enabled' property
        if (Test-DictContains $loadedType 'enabled')
        {
            $computedType.enabled = $loadedType.enabled
            Write-Verbose "[$functionName] Using loaded 'enabled' for $typeName`: $($loadedType.enabled)"
        }
        elseif (Test-DictContains $defType 'enabled')
        {
            $computedType.enabled = $defType.enabled
            Write-Verbose "[$functionName] Using default 'enabled' for $typeName`: $($defType.enabled)"
        }
        
        # Process 'expirationMinutes' property
        if (Test-DictContains $loadedType 'expirationMinutes')
        {
            $computedType.expirationMinutes = $loadedType.expirationMinutes
            Write-Verbose "[$functionName] Using loaded 'expirationMinutes' for $typeName`: $($loadedType.expirationMinutes)"
        }
        elseif (Test-DictContains $defType 'expirationMinutes')
        {
            $computedType.expirationMinutes = $defType.expirationMinutes
            Write-Verbose "[$functionName] Using default 'expirationMinutes' for $typeName`: $($defType.expirationMinutes)"
        }
        
        $cacheSettings.cacheTypes[$typeName] = $computedType
    }
    
    # Determine if changes were made (any missing keys were filled from defaults)
    $changesMade = $false
    
    # Check top-level keys
    foreach ($key in $topLevelKeys)
    {
        if ($CacheSettingsData -and -not (Test-DictContains $CacheSettingsData $key))
        {
            $changesMade = $true
            break
        }
    }
    
    # Check if cacheTypes structure was missing or incomplete
    if (-not $changesMade)
    {
        if ($null -eq $CacheSettingsData -or -not $CacheSettingsData.cacheTypes)
        {
            $changesMade = $true
        }
        else
        {
            # Check if any default cache types were missing
            foreach ($typeName in $cacheDefaults.cacheTypes.Keys)
            {
                if (-not (Test-DictContains $CacheSettingsData.cacheTypes $typeName))
                {
                    $changesMade = $true
                    break
                }
            }
        }
    }
    
    Write-Verbose "[$functionName] Cache settings processed (Changed: $changesMade)"
    Write-Log -logFile $logFile -module $functionName -Message "Cache settings processed (Enabled: $($cacheSettings.enabled), Types: $($cacheSettings.cacheTypes.Count), Changed: $changesMade)" -logLevel "Information"
    
    return @{ CacheSettings = $cacheSettings; Changed = $changesMade }
}
