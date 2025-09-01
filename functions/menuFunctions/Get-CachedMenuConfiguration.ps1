function Get-CachedMenuConfiguration()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$MenuName,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.json",
        [Parameter(Mandatory = $false)]
        [switch]$ForceReload
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Check if we need to cache or reload the configuration
    $cacheKey = "MenuConfig_$MenuConfigFile"
    
    if (-not $script:MenuConfigurationCache) {
        $script:MenuConfigurationCache = @{}
    }
    
    $needsReload = $ForceReload -or 
                  (-not $script:MenuConfigurationCache.ContainsKey($cacheKey)) -or
                  (-not $script:MenuConfigurationCache[$cacheKey])
    
    if ($needsReload) {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Loading/reloading menu configuration from: $MenuConfigFile" -LogLevel "Debug"
        
        try {
            # Load the configuration from file
            $menuConfig = Get-MenuConfiguration -MenuConfigFile $MenuConfigFile
            
            if ($menuConfig) {
                # Cache the configuration
                $script:MenuConfigurationCache[$cacheKey] = $menuConfig
                Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration cached successfully" -LogLevel "Debug"
            }
            else {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to load menu configuration" -LogLevel "Warning"
                return $null
            }
        }
        catch {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Error loading menu configuration: $_" -LogLevel "Error"
            return $null
        }
    }
    else {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using cached menu configuration" -LogLevel "Debug"
    }
    
    # Get the cached configuration
    $cachedConfig = $script:MenuConfigurationCache[$cacheKey]
    
    # If no specific menu name requested, return all configurations
    if (-not $MenuName) {
        Write-Verbose "[$functionName] Returning full cached configuration"
        return $cachedConfig
    }
    
    # Return specific menu configuration
    if ($cachedConfig -and $cachedConfig.PSObject.Properties.Name -contains $MenuName) {
        Write-Verbose "[$functionName] Found cached configuration for menu: $MenuName"
        return $cachedConfig.$MenuName
    }
    else {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration not found for: $MenuName" -LogLevel "Warning"
        return $null
    }
}

function Clear-MenuConfigurationCache()
{
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Clearing menu configuration cache" -LogLevel "Debug"
    
    if ($script:MenuConfigurationCache) {
        $script:MenuConfigurationCache.Clear()
    }
    else {
        $script:MenuConfigurationCache = @{}
    }
}