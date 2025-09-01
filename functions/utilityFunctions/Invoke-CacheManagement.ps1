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
        - 'Clear': Clear all caches
        - 'ClearSpecific': Clear specific cache type
        - 'GetStatistics': Get cache usage statistics
        - 'ListCaches': List all available caches
        - 'Monitor': Display cache monitoring information
    
    .PARAMETER CacheType
        Specific cache type for ClearSpecific action:
        - 'Menu': Menu configuration cache
        - 'Strings': String resources cache
        - 'Groups': Entra ID groups cache
        - 'Users': Entra ID users cache
        - 'Devices': Device ID cache
        - 'Defaults': Application defaults cache
    
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
        [ValidateSet('Clear', 'ClearSpecific', 'GetStatistics', 'ListCaches', 'Monitor')]
        [string]$Action,
        
        [ValidateSet('Menu', 'Strings', 'Groups', 'Users', 'Devices', 'Defaults')]
        [string]$CacheType,
        
        [switch]$ShowDetails
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Cache management action: $Action"
    
    # Initialize cache tracking if not exists
    if (-not $global:CacheStats) {
        $global:CacheStats = @{
            Initialized = Get-Date
            Operations = @{
                Hits = 0
                Misses = 0
                Clears = 0
            }
            CacheTypes = @{
                Menu = @{ Hits = 0; Misses = 0; Size = 0 }
                Strings = @{ Hits = 0; Misses = 0; Size = 0 }
                Groups = @{ Hits = 0; Misses = 0; Size = 0 }
                Users = @{ Hits = 0; Misses = 0; Size = 0 }
                Devices = @{ Hits = 0; Misses = 0; Size = 0 }
                Defaults = @{ Hits = 0; Misses = 0; Size = 0 }
            }
        }
        Write-Verbose "[$functionName] Initialized cache statistics tracking"
    }
    
    switch ($Action) {
        'Clear' {
            Write-Verbose "[$functionName] Clearing all application caches"
            $clearedCaches = 0
            
            # Clear menu configuration cache
            if ($script:menuConfigCache) {
                $script:menuConfigCache.Clear()
                $script:menuFileTimestamp.Clear()
                $clearedCaches++
                Write-Verbose "[$functionName] Cleared menu configuration cache"
            }
            
            # Clear strings cache
            if ($script:stringsCache) {
                $script:stringsCache.Clear()
                $script:stringsFileTimestamp.Clear()
                $clearedCaches++
                Write-Verbose "[$functionName] Cleared strings cache"
            }
            
            # Clear Graph API caches
            if ($global:GroupCache) {
                $global:GroupCache.Clear()
                $clearedCaches++
                Write-Verbose "[$functionName] Cleared groups cache"
            }
            
            if ($global:UserCache) {
                $global:UserCache.Clear()
                $clearedCaches++
                Write-Verbose "[$functionName] Cleared users cache"
            }
            
            if ($global:DeviceIdCache) {
                $global:DeviceIdCache.Clear()
                $clearedCaches++
                Write-Verbose "[$functionName] Cleared device ID cache"
            }
            
            # Clear defaults cache
            if ($script:defaultsCache) {
                $script:defaultsCache.Clear()
                $clearedCaches++
                Write-Verbose "[$functionName] Cleared application defaults cache"
            }
            
            $global:CacheStats.Operations.Clears++
            Write-Host "Cleared $clearedCaches cache(s)" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared $clearedCaches application caches" -LogLevel "Information"
            
            return @{ Action = 'Clear'; CachesCleared = $clearedCaches; Timestamp = Get-Date }
        }
        
        'ClearSpecific' {
            if (-not $CacheType) {
                Write-Warning "[$functionName] CacheType parameter required for ClearSpecific action"
                return $null
            }
            
            Write-Verbose "[$functionName] Clearing specific cache: $CacheType"
            $cleared = $false
            
            switch ($CacheType) {
                'Menu' {
                    if ($script:menuConfigCache) {
                        $script:menuConfigCache.Clear()
                        $script:menuFileTimestamp.Clear()
                        $cleared = $true
                    }
                }
                'Strings' {
                    if ($script:stringsCache) {
                        $script:stringsCache.Clear()
                        $script:stringsFileTimestamp.Clear()
                        $cleared = $true
                    }
                }
                'Groups' {
                    if ($global:GroupCache) {
                        $global:GroupCache.Clear()
                        $cleared = $true
                    }
                }
                'Users' {
                    if ($global:UserCache) {
                        $global:UserCache.Clear()
                        $cleared = $true
                    }
                }
                'Devices' {
                    if ($global:DeviceIdCache) {
                        $global:DeviceIdCache.Clear()
                        $cleared = $true
                    }
                }
                'Defaults' {
                    if ($script:defaultsCache) {
                        $script:defaultsCache.Clear()
                        $cleared = $true
                    }
                }
            }
            
            if ($cleared) {
                Write-Host "Cleared $CacheType cache" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module $functionName -Message "Cleared $CacheType cache" -LogLevel "Information"
                return @{ Action = 'ClearSpecific'; CacheType = $CacheType; Cleared = $true; Timestamp = Get-Date }
            } else {
                Write-Host "$CacheType cache not found or already empty" -ForegroundColor Yellow
                return @{ Action = 'ClearSpecific'; CacheType = $CacheType; Cleared = $false; Timestamp = Get-Date }
            }
        }
        
        'GetStatistics' {
            Write-Verbose "[$functionName] Gathering cache statistics"
            
            $stats = @{
                Action = 'GetStatistics'
                Timestamp = Get-Date
                Initialized = $global:CacheStats.Initialized
                TotalOperations = $global:CacheStats.Operations
                Caches = @{}
            }
            
            # Get current cache sizes
            $stats.Caches.Menu = @{
                Enabled = ($script:menuConfigCache -ne $null)
                Size = if ($script:menuConfigCache) { $script:menuConfigCache.Count } else { 0 }
                FileTracking = if ($script:menuFileTimestamp) { $script:menuFileTimestamp.Count } else { 0 }
            }
            
            $stats.Caches.Strings = @{
                Enabled = ($script:stringsCache -ne $null)
                Size = if ($script:stringsCache) { $script:stringsCache.Count } else { 0 }
                FileTracking = if ($script:stringsFileTimestamp) { $script:stringsFileTimestamp.Count } else { 0 }
            }
            
            $stats.Caches.Groups = @{
                Enabled = ($global:GroupCache -ne $null)
                Size = if ($global:GroupCache) { $global:GroupCache.Count } else { 0 }
            }
            
            $stats.Caches.Users = @{
                Enabled = ($global:UserCache -ne $null)
                Size = if ($global:UserCache) { $global:UserCache.Count } else { 0 }
            }
            
            $stats.Caches.Devices = @{
                Enabled = ($global:DeviceIdCache -ne $null)
                Size = if ($global:DeviceIdCache) { $global:DeviceIdCache.Count } else { 0 }
            }
            
            $stats.Caches.Defaults = @{
                Enabled = ($script:defaultsCache -ne $null)
                Size = if ($script:defaultsCache) { $script:defaultsCache.Count } else { 0 }
            }
            
            if ($ShowDetails) {
                Write-Host "=== Cache Statistics ===" -ForegroundColor Cyan
                Write-Host "Initialized: $($stats.Initialized)" -ForegroundColor Gray
                Write-Host "Total Operations - Hits: $($stats.TotalOperations.Hits), Misses: $($stats.TotalOperations.Misses), Clears: $($stats.TotalOperations.Clears)" -ForegroundColor Gray
                Write-Host ""
                foreach ($cacheType in $stats.Caches.Keys) {
                    $cache = $stats.Caches[$cacheType]
                    $status = if ($cache.Enabled) { "Enabled" } else { "Disabled" }
                    Write-Host "$cacheType Cache: $status (Size: $($cache.Size))" -ForegroundColor $(if ($cache.Enabled) { "Green" } else { "Yellow" })
                }
            }
            
            return $stats
        }
        
        'ListCaches' {
            Write-Verbose "[$functionName] Listing available caches"
            
            $cacheList = @(
                @{ Name = 'Menu'; Description = 'Menu configuration cache (menu.json)'; Variable = '$script:menuConfigCache' }
                @{ Name = 'Strings'; Description = 'String resources cache (strings.json)'; Variable = '$script:stringsCache' }
                @{ Name = 'Groups'; Description = 'Entra ID groups cache'; Variable = '$global:GroupCache' }
                @{ Name = 'Users'; Description = 'Entra ID users cache'; Variable = '$global:UserCache' }
                @{ Name = 'Devices'; Description = 'Device ID lookup cache'; Variable = '$global:DeviceIdCache' }
                @{ Name = 'Defaults'; Description = 'Application defaults cache'; Variable = '$script:defaultsCache' }
            )
            
            Write-Host "=== Available Application Caches ===" -ForegroundColor Cyan
            foreach ($cache in $cacheList) {
                Write-Host "• $($cache.Name): $($cache.Description)" -ForegroundColor White
                Write-Host "  Variable: $($cache.Variable)" -ForegroundColor Gray
            }
            
            return @{ Action = 'ListCaches'; Caches = $cacheList; Timestamp = Get-Date }
        }
        
        'Monitor' {
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
            foreach ($cacheType in $stats.Caches.Keys) {
                $cache = $stats.Caches[$cacheType]
                $statusColor = if ($cache.Enabled -and $cache.Size -gt 0) { "Green" } elseif ($cache.Enabled) { "Yellow" } else { "Red" }
                $status = if ($cache.Enabled) { "Active ($($cache.Size) items)" } else { "Inactive" }
                Write-Host "  $cacheType`: $status" -ForegroundColor $statusColor
            }
            
            if ($ShowDetails) {
                Write-Host ""
                Write-Host "Detailed Cache Information:" -ForegroundColor White
                
                # Show cache keys if available
                if ($script:menuConfigCache -and $script:menuConfigCache.Count -gt 0) {
                    Write-Host "  Menu Cache Keys: $($script:menuConfigCache.Keys -join ', ')" -ForegroundColor Gray
                }
                if ($script:stringsCache -and $script:stringsCache.Count -gt 0) {
                    Write-Host "  Strings Cache Keys: $($script:stringsCache.Keys -join ', ')" -ForegroundColor Gray
                }
                if ($global:GroupCache -and $global:GroupCache.Count -gt 0) {
                    Write-Host "  Groups Cache: $($global:GroupCache.Count) entries" -ForegroundColor Gray
                }
                if ($global:UserCache -and $global:UserCache.Count -gt 0) {
                    Write-Host "  Users Cache: $($global:UserCache.Count) entries" -ForegroundColor Gray
                }
                if ($global:DeviceIdCache -and $global:DeviceIdCache.Count -gt 0) {
                    Write-Host "  Device Cache: $($global:DeviceIdCache.Count) entries" -ForegroundColor Gray
                }
                if ($script:defaultsCache -and $script:defaultsCache.Count -gt 0) {
                    Write-Host "  Defaults Cache: $($script:defaultsCache.Count) entries" -ForegroundColor Gray
                }
            }
            
            return $stats
        }
    }
}