function Get-CachedData()
{
    <#
    .SYNOPSIS
        Retrieves data from the unified cache management system.
    
    .DESCRIPTION
        Gets cached data with automatic expiration checking. Part of the unified
        cache management system that consolidates all application caching.
    
    .PARAMETER CacheType
        The type of cache to access: Configuration, DirectoryObjects, or Devices
    
    .PARAMETER Key
        The unique key for the cached item
    
    .PARAMETER CacheSettings
        Cache settings object. If not provided, uses $global:cacheSettings
    
    .OUTPUTS
        Returns cached data if valid, $null if not found or expired
    
    .EXAMPLE
        $menuData = Get-CachedData -CacheType 'Configuration' -Key 'menu:mainMenu'
    
    .EXAMPLE
        $userData = Get-CachedData -CacheType 'DirectoryObjects' -Key 'user:john@contoso.com'
    
    .NOTES
        - Automatically checks cache expiration
        - Returns $null if caching is disabled
        - Part of unified cache management system
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Configuration', 'DirectoryObjects', 'Devices')]
        [string]$CacheType,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $false)]
        $CacheSettings = $global:cacheSettings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Check if caching is enabled globally
    if ($CacheSettings -and -not $CacheSettings.enabled)
    {
        Write-Verbose "[$functionName] Caching is disabled globally"
        return $null
    }
    
    # Check if this cache type is enabled
    if ($CacheSettings -and $CacheSettings.cacheTypes -and 
        $CacheSettings.cacheTypes.ContainsKey($CacheType) -and 
        -not $CacheSettings.cacheTypes[$CacheType].enabled)
    {
        Write-Verbose "[$functionName] Caching is disabled for type: $CacheType"
        return $null
    }
    
    # Initialize global unified cache if needed
    if (-not $global:UnifiedCache)
    {
        Initialize-UnifiedCache
    }
    
    # Check if cache type exists
    if (-not $global:UnifiedCache.ContainsKey($CacheType))
    {
        Write-Verbose "[$functionName] Cache type not initialized: $CacheType"
        return $null
    }
    
    # Check if key exists
    if (-not $global:UnifiedCache[$CacheType].ContainsKey($Key))
    {
        Write-Verbose "[$functionName] Cache miss for key: $Key in type: $CacheType"
        return $null
    }
    
    $cacheEntry = $global:UnifiedCache[$CacheType][$Key]
    
    # Check expiration
    if ($cacheEntry.Timestamp)
    {
        $expirationMinutes = Get-CacheExpirationMinutes -CacheType $CacheType -CacheSettings $CacheSettings
        $age = (Get-Date) - $cacheEntry.Timestamp
        
        if ($age.TotalMinutes -gt $expirationMinutes)
        {
            Write-Verbose "[$functionName] Cache expired for key: $Key (age: $($age.TotalMinutes) minutes, expiration: $expirationMinutes minutes)"
            # Remove expired entry
            $global:UnifiedCache[$CacheType].Remove($Key)
            return $null
        }
    }
    
    Write-Verbose "[$functionName] Cache hit for key: $Key in type: $CacheType"
    return $cacheEntry.Data
}

function Set-CachedData()
{
    <#
    .SYNOPSIS
        Stores data in the unified cache management system.
    
    .DESCRIPTION
        Sets cached data with timestamp and metadata. Part of the unified
        cache management system that consolidates all application caching.
    
    .PARAMETER CacheType
        The type of cache to access: Configuration, DirectoryObjects, or Devices
    
    .PARAMETER Key
        The unique key for the cached item
    
    .PARAMETER Data
        The data to cache
    
    .PARAMETER Metadata
        Optional metadata to store with the cached data
    
    .PARAMETER CacheSettings
        Cache settings object. If not provided, uses $global:cacheSettings
    
    .OUTPUTS
        Returns $true if data was cached, $false otherwise
    
    .EXAMPLE
        Set-CachedData -CacheType 'Configuration' -Key 'menu:mainMenu' -Data $menuData
    
    .EXAMPLE
        Set-CachedData -CacheType 'DirectoryObjects' -Key 'user:john@contoso.com' -Data $userData -Metadata @{Source='GraphAPI'}
    
    .NOTES
        - Automatically manages cache size limits
        - Skips caching if disabled
        - Part of unified cache management system
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Configuration', 'DirectoryObjects', 'Devices')]
        [string]$CacheType,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        $Data,
        [Parameter(Mandatory = $false)]
        $Metadata,
        [Parameter(Mandatory = $false)]
        $CacheSettings = $global:cacheSettings
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Check if caching is enabled globally
    if ($CacheSettings -and -not $CacheSettings.enabled)
    {
        Write-Verbose "[$functionName] Caching is disabled globally"
        return $false
    }
    
    # Check if this cache type is enabled
    if ($CacheSettings -and $CacheSettings.cacheTypes -and 
        $CacheSettings.cacheTypes.ContainsKey($CacheType) -and 
        -not $CacheSettings.cacheTypes[$CacheType].enabled)
    {
        Write-Verbose "[$functionName] Caching is disabled for type: $CacheType"
        return $false
    }
    
    # Initialize global unified cache if needed
    if (-not $global:UnifiedCache)
    {
        Initialize-UnifiedCache
    }
    
    # Ensure cache type exists
    if (-not $global:UnifiedCache.ContainsKey($CacheType))
    {
        $global:UnifiedCache[$CacheType] = @{}
    }
    
    # Check cache size limit and trim if needed
    $maxSize = if ($CacheSettings -and $CacheSettings.maxCacheSize)
    {
        $CacheSettings.maxCacheSize
    }
    else
    {
        1000  # Default
    }
    
    if ($global:UnifiedCache[$CacheType].Count -ge $maxSize)
    {
        # Remove oldest entries (simple FIFO approach)
        $entriesToRemove = $global:UnifiedCache[$CacheType].Keys | 
            Select-Object -First ([Math]::Max(1, [Math]::Floor($maxSize * 0.1)))
        
        foreach ($oldKey in $entriesToRemove)
        {
            $global:UnifiedCache[$CacheType].Remove($oldKey)
        }
        
        Write-Verbose "[$functionName] Trimmed $($entriesToRemove.Count) entries from $CacheType cache"
    }
    
    # Store the data
    $cacheEntry = @{
        Data      = $Data
        Timestamp = Get-Date
        Metadata  = $Metadata
    }
    
    $global:UnifiedCache[$CacheType][$Key] = $cacheEntry
    Write-Verbose "[$functionName] Cached data for key: $Key in type: $CacheType"
    
    return $true
}

function Initialize-UnifiedCache()
{
    <#
    .SYNOPSIS
        Initializes the global unified cache structure.
    
    .DESCRIPTION
        Creates the global cache hashtable with predefined cache types.
        Called automatically by Get-CachedData and Set-CachedData.
    
    .NOTES
        - Internal helper function
        - Creates three cache type categories
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param()
    
    if (-not $global:UnifiedCache)
    {
        $global:UnifiedCache = @{
            Configuration    = @{}
            DirectoryObjects = @{}
            Devices          = @{}
        }
        
        Write-Verbose "Unified cache initialized"
    }
}

function Get-CacheExpirationMinutes()
{
    <#
    .SYNOPSIS
        Gets the expiration time in minutes for a specific cache type.
    
    .DESCRIPTION
        Retrieves the configured expiration time for a cache type,
        falling back to the default if not specified.
    
    .PARAMETER CacheType
        The cache type to get expiration for
    
    .PARAMETER CacheSettings
        Cache settings object
    
    .OUTPUTS
        Integer - Number of minutes before cache expires
    
    .NOTES
        - Internal helper function
        - Returns default of 15 minutes if not configured
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CacheType,
        
        [Parameter(Mandatory = $false)]
        $CacheSettings = $global:cacheSettings
    )
    
    $defaultExpiration = 15  # Default fallback
    
    if (-not $CacheSettings)
    {
        return $defaultExpiration
    }
    
    # Check for cache-type-specific expiration
    if ($CacheSettings.cacheTypes -and 
        $CacheSettings.cacheTypes.ContainsKey($CacheType) -and
        $CacheSettings.cacheTypes[$CacheType].expirationMinutes)
    {
        return $CacheSettings.cacheTypes[$CacheType].expirationMinutes
    }
    
    # Fall back to default expiration
    if ($CacheSettings.defaultExpirationMinutes)
    {
        return $CacheSettings.defaultExpirationMinutes
    }
    
    return $defaultExpiration
}

function Clear-UnifiedCache()
{
    <#
    .SYNOPSIS
        Clears all or specific unified cache data.
    
    .DESCRIPTION
        Clears cached data from the unified cache system. Can clear all caches
        or a specific cache type.
    
    .PARAMETER CacheType
        Optional. Specific cache type to clear. If not provided, clears all caches.
    
    .EXAMPLE
        Clear-UnifiedCache
    
    .EXAMPLE
        Clear-UnifiedCache -CacheType 'DirectoryObjects'
    
    .NOTES
        - Part of unified cache management system
        - Maintains PowerShell 5.1 compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Configuration', 'DirectoryObjects', 'Devices')]
        [string]$CacheType
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    if (-not $global:UnifiedCache)
    {
        Write-Verbose "[$functionName] No unified cache to clear"
        return
    }
    
    if ($CacheType)
    {
        if ($global:UnifiedCache.ContainsKey($CacheType))
        {
            $count = $global:UnifiedCache[$CacheType].Count
            $global:UnifiedCache[$CacheType].Clear()
            Write-Verbose "[$functionName] Cleared $count entries from $CacheType cache"
        }
    }
    else
    {
        $totalCleared = 0
        foreach ($type in $global:UnifiedCache.Keys)
        {
            $totalCleared += $global:UnifiedCache[$type].Count
            $global:UnifiedCache[$type].Clear()
        }
        Write-Verbose "[$functionName] Cleared $totalCleared total cache entries"
    }
}
