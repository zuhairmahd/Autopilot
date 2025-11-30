function Invoke-CacheManagement()
{
    <#
    .SYNOPSIS
        Unified cache management for application performance optimization.
    
    .DESCRIPTION
        Provides centralized management of all application caches including menu configuration,
        string resources, Graph API responses, and application defaults. Supports cache
        monitoring, clearing, and statistics reporting.
    
    .PARAMETER Action
        The cache management action to perform:
        - 'Clear': Clear all caches (legacy and unified)
        - 'ClearSpecific': Clear specific cache type
        - 'Get': Get data from unified cache
        - 'Set': Set data in unified cache
        - 'GetStatistics': Get cache usage statistics
        - 'ListCaches': List all available caches
        - 'Monitor': Display cache monitoring information
        - 'GetMenuConfiguration': Get cached menu configuration (legacy)
        - 'SetMenuConfiguration': Cache menu configuration (legacy)
    
    .PARAMETER CacheType
        Specific cache type for ClearSpecific, Get, or Set actions:
        - Legacy types (for ClearSpecific):
          - 'Menu': Menu configuration cache
          - 'Strings': String resources cache
          - 'Groups': Entra ID groups cache
          - 'Users': Entra ID users cache
          - 'Devices': Device ID cache
          - 'Defaults': Application defaults cache
        - Unified types (for Get/Set):
          - 'Configuration': Configuration data cache
          - 'DirectoryObjects': User and group cache
          - 'Devices': Device data cache
        
    .PARAMETER Key
        Cache key for Get or Set actions
        
    .PARAMETER Data
        Data to cache for Set action
        
    .PARAMETER Metadata
        Optional metadata to store with cached data for Set action
        
    .PARAMETER MenuName
        Specific menu name for GetMenuConfiguration action
        
    .PARAMETER MenuConfigFile
        Path to menu configuration file for GetMenuConfiguration action
        
    .PARAMETER ForceReload
        Force reload of menu configuration for GetMenuConfiguration action
        
    .PARAMETER MenuConfiguration
        Menu configuration object to cache for SetMenuConfiguration action
    
    .PARAMETER ShowDetails
        Show detailed cache information including keys and sizes
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns cache statistics and status information
    
    .EXAMPLE
        # Clear all caches
        Invoke-CacheManagement -Action Clear
    
    .EXAMPLE
        # Get cache statistics
        $stats = Invoke-CacheManagement -Action GetStatistics
    
    .EXAMPLE
        # Clear specific cache
        Invoke-CacheManagement -Action ClearSpecific -CacheType Groups
    
    .EXAMPLE
        # Monitor cache usage
        Invoke-CacheManagement -Action Monitor -ShowDetails
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Provides detailed logging for cache operations
        - Includes cache hit/miss tracking
        - Performance optimization feature for Issue #120
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Clear', 'ClearSpecific', 'Get', 'Set', 'GetStatistics', 'ListCaches', 'Monitor', 'GetMenuConfiguration', 'SetMenuConfiguration')]
        [string]$Action,
        [string]$CacheType,
        [string]$Key,
        $Data,
        $Metadata,
        [switch]$ShowDetails,
        [string]$MenuName,
        [string]$MenuConfigFile = "$pwd\menu",
        [switch]$ForceReload,
        [PSCustomObject]$MenuConfiguration
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Cache management action: $Action" -LogLevel "Debug"
    
    # Initialize cache tracking if not exists
    if (-not $global:CacheStats)
    {
        $global:CacheStats = @{
            Initialized = Get-Date
            Operations  = @{
                Hits   = 0
                Misses = 0
                Clears = 0
            }
            CacheTypes  = @{
                Menu     = @{ Hits = 0; Misses = 0; Size = 0 }
                Strings  = @{ Hits = 0; Misses = 0; Size = 0 }
                Defaults = @{ Hits = 0; Misses = 0; Size = 0 }
            }
        }
        Write-Verbose "[$functionName] Initialized cache statistics tracking"
    }
    
    switch ($Action)
    {
        'Get'
        {
            if (-not $CacheType)
            {
                Write-Warning "[$functionName] CacheType parameter required for Get action"
                return $null
            }
            if (-not $Key)
            {
                Write-Warning "[$functionName] Key parameter required for Get action"
                return $null
            }
            
            # Validate unified cache type
            if ($CacheType -notin @('Configuration', 'DirectoryObjects', 'Devices'))
            {
                Write-Warning "[$functionName] Invalid CacheType for unified cache: $CacheType. Use Configuration, DirectoryObjects, or Devices."
                return $null
            }
            
            Write-Verbose "[$functionName] Getting cached data: Type=$CacheType, Key=$Key"
            $result = Get-CachedData -CacheType $CacheType -Key $Key
            
            if ($null -ne $result)
            {
                if ($global:CacheStats)
                {
                    $global:CacheStats.Operations.Hits++
                }
                Write-Log -LogFile $LogFile -Module $functionName -Message "Cache hit for $CacheType`: $Key" -LogLevel "Debug"
            }
            else
            {
                if ($global:CacheStats)
                {
                    $global:CacheStats.Operations.Misses++
                }
                Write-Log -LogFile $LogFile -Module $functionName -Message "Cache miss for $CacheType`: $Key" -LogLevel "Debug"
            }
            
            return $result
        }
        'Set'
        {
            if (-not $CacheType)
            {
                Write-Warning "[$functionName] CacheType parameter required for Set action"
                return $null
            }
            if (-not $Key)
            {
                Write-Warning "[$functionName] Key parameter required for Set action"
                return $null
            }
            if ($null -eq $Data)
            {
                Write-Warning "[$functionName] Data parameter required for Set action"
                return $null
            }
            
            # Validate unified cache type
            if ($CacheType -notin @('Configuration', 'DirectoryObjects', 'Devices'))
            {
                Write-Warning "[$functionName] Invalid CacheType for unified cache: $CacheType. Use Configuration, DirectoryObjects, or Devices."
                return $null
            }
            
            Write-Verbose "[$functionName] Setting cached data: Type=$CacheType, Key=$Key"
            $success = Set-CachedData -CacheType $CacheType -Key $Key -Data $Data -Metadata $Metadata
            
            if ($success)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully cached data for $CacheType`: $Key" -LogLevel "Debug"
            }
            else
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to cache data for $CacheType`: $Key (caching may be disabled)" -LogLevel "Debug"
            }
            
            # Return boolean for success/failure (API contract for tests)
            return $success
        }
        'Clear'
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Starting comprehensive cache clearing operation (legacy + unified)" -LogLevel "Verbose"
            $clearedCaches = 0
            $cacheDetails = @()
            # Clear menu configuration cache
            if ($script:menuConfigCache)
            {
                $menuCacheSize = $script:menuConfigCache.Count
                $script:menuConfigCache.Clear()
                $script:menuFileTimestamp.Clear()
                $clearedCaches++
                $cacheDetails += "Menu ($menuCacheSize items)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared menu configuration cache ($menuCacheSize items)" -LogLevel "Debug"
            }
            
            # Clear strings cache
            if ($script:stringsCache)
            {
                $stringsCacheSize = $script:stringsCache.Count
                $script:stringsCache.Clear()
                $script:stringsFileTimestamp.Clear()
                $clearedCaches++
                $cacheDetails += "Strings ($stringsCacheSize items)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared strings cache ($stringsCacheSize items)" -LogLevel "Debug"
            }
            
            # Clear defaults cache
            if ($script:defaultsCache)
            {
                $defaultsCacheSize = $script:defaultsCache.Count
                $script:defaultsCache.Clear()
                $clearedCaches++
                $cacheDetails += "Defaults ($defaultsCacheSize items)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared application defaults cache ($defaultsCacheSize items)" -LogLevel "Debug"
            }
            
            # Clear unified cache
            if ($global:UnifiedCache)
            {
                $unifiedCount = 0
                foreach ($type in $global:UnifiedCache.Keys)
                {
                    $unifiedCount += $global:UnifiedCache[$type].Count
                }
                
                if ($unifiedCount -gt 0)
                {
                    Clear-UnifiedCache
                    $clearedCaches++
                    $cacheDetails += "Unified ($unifiedCount items)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared unified cache ($unifiedCount items)" -LogLevel "Debug"
                }
            }
            
            $global:CacheStats.Operations.Clears++
            Write-Host "Cleared $clearedCaches cache(s)" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cache clearing completed - Cleared: $clearedCaches caches [$($cacheDetails -join ', ')]" -LogLevel "Information"
            
            return @{ Action = 'Clear'; Status = 'Success'; CachesCleared = $clearedCaches; Details = $cacheDetails; Timestamp = Get-Date }
        }
        'ClearSpecific'
        {
            if (-not $CacheType)
            {
                Write-Warning "[$functionName] CacheType parameter required for ClearSpecific action"
                return $null
            }
            
            Write-Verbose "[$functionName] Clearing specific cache: $CacheType"
            $cleared = $false
            
            # Check if this is a unified cache type
            if ($CacheType -in @('Configuration', 'DirectoryObjects', 'Devices'))
            {
                Clear-UnifiedCache -CacheType $CacheType
                $cleared = $true
                Write-Host "Cleared unified $CacheType cache" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared unified $CacheType cache" -LogLevel "Information"
            }
            else
            {
                # Legacy cache types
                switch ($CacheType)
                {
                    'Menu'
                    {
                        if ($script:menuConfigCache)
                        {
                            $script:menuConfigCache.Clear()
                            $script:menuFileTimestamp.Clear()
                            $cleared = $true
                        }
                    }
                    'Strings'
                    {
                        if ($script:stringsCache)
                        {
                            $script:stringsCache.Clear()
                            $script:stringsFileTimestamp.Clear()
                            $cleared = $true
                        }
                    }
                    'Defaults'
                    {
                        if ($script:defaultsCache)
                        {
                            $script:defaultsCache.Clear()
                            $cleared = $true
                        }
                    }
                }
                
                if ($cleared)
                {
                    Write-Host "Cleared $CacheType cache" -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared $CacheType cache" -LogLevel "Information"
                }
            }
            
            if ($cleared)
            {
                return @{ Action = 'ClearSpecific'; Status = 'Success'; CacheType = $CacheType; Cleared = $true; Timestamp = Get-Date }
            }
            else
            {
                Write-Host "$CacheType cache not found or already empty" -ForegroundColor Yellow
                return @{ Action = 'ClearSpecific'; Status = 'NotFound'; CacheType = $CacheType; Cleared = $false; Timestamp = Get-Date }
            }
        }
        'GetStatistics'
        {
            Write-Verbose "[$functionName] Gathering cache statistics"
            
            $stats = @{
                Action          = 'GetStatistics'
                Timestamp       = Get-Date
                Initialized     = $global:CacheStats.Initialized
                TotalOperations = $global:CacheStats.Operations
                Caches          = @{}
                UnifiedCache    = @{}
            }
            
            # Get current cache sizes
            $stats.Caches.Menu = @{
                Enabled      = ($null -ne $script:menuConfigCache)
                Size         = if ($script:menuConfigCache) { $script:menuConfigCache.Count } else { 0 }
                FileTracking = if ($script:menuFileTimestamp) { $script:menuFileTimestamp.Count } else { 0 }
            }
            
            $stats.Caches.Strings = @{
                Enabled      = ($null -ne $script:stringsCache)
                Size         = if ($script:stringsCache) { $script:stringsCache.Count } else { 0 }
                FileTracking = if ($script:stringsFileTimestamp) { $script:stringsFileTimestamp.Count } else { 0 }
            }
            
            $stats.Caches.Defaults = @{
                Enabled = ($null -ne $script:defaultsCache)
                Size    = if ($script:defaultsCache) { $script:defaultsCache.Count } else { 0 }
            }
            
            # Add unified cache statistics with EntryCount properties (API contract for tests)
            if ($global:UnifiedCache)
            {
                $stats.Caches.UnifiedConfiguration = @{
                    Enabled = $true
                    Size    = if ($global:UnifiedCache.Configuration) { $global:UnifiedCache.Configuration.Count } else { 0 }
                }
                $stats.Caches.UnifiedDirectoryObjects = @{
                    Enabled = $true
                    Size    = if ($global:UnifiedCache.DirectoryObjects) { $global:UnifiedCache.DirectoryObjects.Count } else { 0 }
                }
                $stats.Caches.UnifiedDevices = @{
                    Enabled = $true
                    Size    = if ($global:UnifiedCache.Devices) { $global:UnifiedCache.Devices.Count } else { 0 }
                }
                
                # Add UnifiedCache object with EntryCount for test API contract
                $stats.UnifiedCache.Configuration = @{
                    EntryCount = if ($global:UnifiedCache.Configuration) { $global:UnifiedCache.Configuration.Count } else { 0 }
                }
                $stats.UnifiedCache.DirectoryObjects = @{
                    EntryCount = if ($global:UnifiedCache.DirectoryObjects) { $global:UnifiedCache.DirectoryObjects.Count } else { 0 }
                }
                $stats.UnifiedCache.Devices = @{
                    EntryCount = if ($global:UnifiedCache.Devices) { $global:UnifiedCache.Devices.Count } else { 0 }
                }
            }
            else
            {
                # Initialize empty UnifiedCache stats if cache doesn't exist yet
                $stats.UnifiedCache.Configuration = @{ EntryCount = 0 }
                $stats.UnifiedCache.DirectoryObjects = @{ EntryCount = 0 }
                $stats.UnifiedCache.Devices = @{ EntryCount = 0 }
            }
            
            if ($ShowDetails)
            {
                Write-Host "=== Cache Statistics ===" -ForegroundColor Cyan
                Write-Host "Initialized: $($stats.Initialized)" -ForegroundColor Gray
                Write-Host "Total Operations - Hits: $($stats.TotalOperations.Hits), Misses: $($stats.TotalOperations.Misses), Clears: $($stats.TotalOperations.Clears)" -ForegroundColor Gray
                Write-Host ""
                foreach ($cacheType in $stats.Caches.Keys)
                {
                    $cache = $stats.Caches[$cacheType]
                    $status = if ($cache.Enabled) { "Enabled" } else { "Disabled" }
                    Write-Host "$cacheType Cache: $status (Size: $($cache.Size))" -ForegroundColor $(if ($cache.Enabled) { "Green" } else { "Yellow" })
                }
            }
            
            return $stats
        }
        'ListCaches'
        {
            Write-Verbose "[$functionName] Listing available caches"
            
            $cacheList = @(
                @{ Name = 'Menu'; Description = 'Menu configuration cache (menu.psd1)'; Variable = '$script:menuConfigCache'; Value = $script:menuConfigCache }
                @{ Name = 'Strings'; Description = 'String resources cache (strings.psd1)'; Variable = '$script:stringsCache'; Value = $script:stringsCache }
                @{ Name = 'Defaults'; Description = 'Application defaults cache'; Variable = '$script:defaultsCache'; Value = $script:defaultsCache }
                @{ Name = 'UnifiedConfiguration'; Description = 'Unified configuration cache'; Variable = '$global:UnifiedCache.Configuration'; Value = if ($global:UnifiedCache) { $global:UnifiedCache.Configuration } else { $null } }
                @{ Name = 'UnifiedDirectoryObjects'; Description = 'Unified directory objects cache (users/groups)'; Variable = '$global:UnifiedCache.DirectoryObjects'; Value = if ($global:UnifiedCache) { $global:UnifiedCache.DirectoryObjects } else { $null } }
                @{ Name = 'UnifiedDevices'; Description = 'Unified devices cache'; Variable = '$global:UnifiedCache.Devices'; Value = if ($global:UnifiedCache) { $global:UnifiedCache.Devices } else { $null } }
            )
            
            Write-Host "=== Available Application Caches ===" -ForegroundColor Cyan
            foreach ($cache in $cacheList)
            {
                $enabled = ($null -ne $cache.Value)
                $size = if ($enabled -and $cache.Value -is [hashtable]) { $cache.Value.Count } elseif ($enabled -and $cache.Value -is [System.Collections.IDictionary]) { $cache.Value.Count } else { 0 }
                Write-Host "• $($cache.Name): $($cache.Description)" -ForegroundColor White
                Write-Host "  Variable: $($cache.Variable)" -ForegroundColor Gray
                Write-Host "  Enabled: $enabled, Size: $size" -ForegroundColor $(if ($enabled) { "Green" } else { "Yellow" })
            }
            
            # Return UnifiedCaches array for API contract
            return @{ 
                Action        = 'ListCaches'
                Caches        = $cacheList
                UnifiedCaches = @('Configuration', 'DirectoryObjects', 'Devices')
                Timestamp     = Get-Date 
            }
        }
        'Monitor'
        {
            Write-Verbose "[$functionName] Displaying cache monitoring information"
            
            $stats = Invoke-CacheManagement -Action GetStatistics
            
            Write-Host "=== Cache Performance Monitor ===" -ForegroundColor Cyan
            Write-Host "Monitoring since: $($stats.Initialized)" -ForegroundColor Gray
            Write-Host "Current time: $($stats.Timestamp)" -ForegroundColor Gray
            Write-Host ""
            
            # Calculate total cache effectiveness
            $totalHits = $stats.TotalOperations.Hits
            $totalMisses = $stats.TotalOperations.Misses
            $totalRequests = $totalHits + $totalMisses
            $hitRate = if ($totalRequests -gt 0) { [math]::Round(($totalHits / $totalRequests) * 100, 2) } else { 0 }
            
            Write-Host "Overall Cache Performance:" -ForegroundColor White
            Write-Host "  Cache Hit Rate: $hitRate% ($totalHits hits / $totalRequests requests)" -ForegroundColor $(if ($hitRate -gt 75) { "Green" } elseif ($hitRate -gt 50) { "Yellow" } else { "Red" })
            Write-Host "  Cache Misses: $totalMisses" -ForegroundColor Gray
            Write-Host "  Total Clears: $($stats.TotalOperations.Clears)" -ForegroundColor Gray
            Write-Host ""
            
            # Show individual cache status
            Write-Host "Cache Status by Type:" -ForegroundColor White
            foreach ($cacheType in $stats.Caches.Keys)
            {
                $cache = $stats.Caches[$cacheType]
                $statusColor = if ($cache.Enabled -and $cache.Size -gt 0) { "Green" } elseif ($cache.Enabled) { "Yellow" } else { "Red" }
                $status = if ($cache.Enabled) { "Active ($($cache.Size) items)" } else { "Inactive" }
                Write-Host "  $cacheType`: $status" -ForegroundColor $statusColor
            }
            
            if ($ShowDetails)
            {
                Write-Host ""
                Write-Host "Detailed Cache Information:" -ForegroundColor White
                
                # Show cache keys if available
                if ($script:menuConfigCache -and $script:menuConfigCache.Count -gt 0)
                {
                    Write-Host "  Menu Cache Keys: $($script:menuConfigCache.Keys -join ', ')" -ForegroundColor Gray
                }
                if ($script:stringsCache -and $script:stringsCache.Count -gt 0)
                {
                    Write-Host "  Strings Cache Keys: $($script:stringsCache.Keys -join ', ')" -ForegroundColor Gray
                }
                if ($script:defaultsCache -and $script:defaultsCache.Count -gt 0)
                {
                    Write-Host "  Defaults Cache: $($script:defaultsCache.Count) entries" -ForegroundColor Gray
                }
                # Show unified cache details
                if ($global:UnifiedCache)
                {
                    if ($global:UnifiedCache.Configuration -and $global:UnifiedCache.Configuration.Count -gt 0)
                    {
                        Write-Host "  Unified Configuration Cache: $($global:UnifiedCache.Configuration.Count) entries" -ForegroundColor Gray
                    }
                    if ($global:UnifiedCache.DirectoryObjects -and $global:UnifiedCache.DirectoryObjects.Count -gt 0)
                    {
                        Write-Host "  Unified Directory Objects Cache: $($global:UnifiedCache.DirectoryObjects.Count) entries" -ForegroundColor Gray
                    }
                    if ($global:UnifiedCache.Devices -and $global:UnifiedCache.Devices.Count -gt 0)
                    {
                        Write-Host "  Unified Devices Cache: $($global:UnifiedCache.Devices.Count) entries" -ForegroundColor Gray
                    }
                }
            }
            
            # Add Status='Success' for API contract
            $stats.Status = 'Success'
            return $stats
        }
        'GetMenuConfiguration'
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Getting cached menu configuration for file: $MenuConfigFile" -LogLevel "Debug"
            
            # Check if we need to cache or reload the configuration
            $cacheKey = "MenuConfig_$MenuConfigFile"
            
            if (-not $script:menuConfigCache)
            {
                $script:menuConfigCache = @{}
                Write-Log -LogFile $LogFile -Module $functionName -Message "Initialized menu configuration cache" -LogLevel "Debug"
            }
            
            $needsReload = $ForceReload -or 
            (-not $script:menuConfigCache.ContainsKey($cacheKey)) -or
            (-not $script:menuConfigCache[$cacheKey])
            
            if ($needsReload)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Loading/reloading menu configuration from: $MenuConfigFile" -LogLevel "Verbose"
                
                try
                {
                    # Load the configuration from file
                    $menuConfig = Get-MenuConfiguration -MenuConfigFile $MenuConfigFile
                    
                    if ($menuConfig)
                    {
                        # Cache the configuration
                        $script:menuConfigCache[$cacheKey] = $menuConfig
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration cached successfully for key: $cacheKey" -LogLevel "Verbose"
                        
                        # Update cache statistics
                        if ($global:CacheStats)
                        {
                            $global:CacheStats.Operations.Misses++
                            $global:CacheStats.CacheTypes.Menu.Misses++
                            $global:CacheStats.CacheTypes.Menu.Size = $script:menuConfigCache.Count
                        }
                    }
                    else
                    {
                        Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load menu configuration from file: $MenuConfigFile" -LogLevel "Warning"
                        return $null
                    }
                }
                catch
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Error loading menu configuration: $_" -LogLevel "Error"
                    return $null
                }
            }
            else
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using cached menu configuration for key: $cacheKey" -LogLevel "Debug"
                
                # Update cache statistics
                if ($global:CacheStats)
                {
                    $global:CacheStats.Operations.Hits++
                    $global:CacheStats.CacheTypes.Menu.Hits++
                }
            }
            
            # Get the cached configuration
            $cachedConfig = $script:menuConfigCache[$cacheKey]
            
            # If no specific menu name requested, return all configurations
            if (-not $MenuName)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Returning full cached configuration with $($cachedConfig.PSObject.Properties.Count) properties" -LogLevel "Debug"
                return $cachedConfig
            }
            
            # Return specific menu configuration
            if ($cachedConfig -and $cachedConfig.PSObject.Properties -and ($cachedConfig.PSObject.Properties.Name -contains $MenuName))
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Found cached configuration for menu: $MenuName" -LogLevel "Debug"
                return $cachedConfig.$MenuName
            }
            else
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration not found for: $MenuName" -LogLevel "Warning"
                return $null
            }
        }
        'SetMenuConfiguration'
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Setting menu configuration in cache for file: $MenuConfigFile" -LogLevel "Debug"
            
            if (-not $MenuConfiguration)
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "No menu configuration provided for caching" -LogLevel "Warning"
                return $null
            }
            
            $cacheKey = "MenuConfig_$MenuConfigFile"
            
            if (-not $script:menuConfigCache)
            {
                $script:menuConfigCache = @{}
                Write-Log -LogFile $LogFile -Module $functionName -Message "Initialized menu configuration cache" -LogLevel "Debug"
            }
            
            try
            {
                # Cache the configuration
                $script:menuConfigCache[$cacheKey] = $MenuConfiguration
                Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration cached successfully for key: $cacheKey" -LogLevel "Verbose"
                
                # Update cache statistics
                if ($global:CacheStats)
                {
                    $global:CacheStats.CacheTypes.Menu.Size = $script:menuConfigCache.Count
                }
                
                return @{ 
                    Action    = 'SetMenuConfiguration'
                    CacheKey  = $cacheKey
                    Success   = $true
                    Timestamp = Get-Date
                }
            }
            catch
            {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Error caching menu configuration: $_" -LogLevel "Error"
                return @{ 
                    Action    = 'SetMenuConfiguration'
                    CacheKey  = $cacheKey
                    Success   = $false
                    Error     = $_.ToString()
                    Timestamp = Get-Date
                }
            }
        }
    }
}