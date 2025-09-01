function Get-MenuConfiguration()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$MenuName,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.json"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Initialize script-level menu configuration cache if not exists
    if (-not $script:menuConfigCache) {
        $script:menuConfigCache = @{}
        $script:menuFileTimestamp = @{}
        Write-Verbose "[$functionName] Initialized menu configuration cache"
    }
    
    # Create cache key based on file path
    $cacheKey = $MenuConfigFile
    $fileExists = Test-Path $MenuConfigFile
    
    # Check if we have cached data and if file hasn't been modified
    if ($script:menuConfigCache.ContainsKey($cacheKey) -and $fileExists) {
        $currentFileTime = (Get-Item $MenuConfigFile).LastWriteTime
        $cachedFileTime = $script:menuFileTimestamp[$cacheKey]
        
        if ($cachedFileTime -and $currentFileTime -eq $cachedFileTime) {
            Write-Verbose "[$functionName] Using cached menu configuration for: $MenuConfigFile"
            $menuConfig = $script:menuConfigCache[$cacheKey]
            
            # Return specific menu or all configurations based on request
            if (-not $MenuName) {
                return $menuConfig
            } elseif ($menuConfig.PSObject.Properties.Name -contains $MenuName) {
                return $menuConfig.$MenuName
            } else {
                Write-Verbose "[$functionName] Menu configuration not found in cache for: $MenuName"
                return $null
            }
        }
    }
    
    Write-Verbose "[$functionName] Loading menu configuration from file: $MenuConfigFile"
    
    # Check if menu configuration file exists
    if (-not $fileExists)
    {
        Write-Verbose "[$functionName] Menu configuration file not found: $MenuConfigFile"
Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration file not found: $MenuConfigFile, attempting to create with defaults" -LogLevel "Verbose"
        
        # Attempt to create the menu file with defaults
        if (Test-MenuJsonExists -MenuFile $MenuConfigFile -Silent)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully created default menu configuration file" -LogLevel "Information"
        }
        else
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to create default menu configuration file" -LogLevel "Error"
            return $null
        }
    }
    
    try
    {
        # Load menu configuration from file
        $menuConfig = Get-Content -Path $MenuConfigFile -Raw | ConvertFrom-Json
        Write-Verbose "[$functionName] Successfully loaded menu configuration from file"
        
        # Cache the configuration and file timestamp
        $script:menuConfigCache[$cacheKey] = $menuConfig
        $script:menuFileTimestamp[$cacheKey] = (Get-Item $MenuConfigFile).LastWriteTime
        Write-Verbose "[$functionName] Cached menu configuration for: $MenuConfigFile"
        
        # If no specific menu name requested, return all configurations
        if (-not $MenuName)
        {
            Write-Verbose "[$functionName] Returning all menu configurations"
            return $menuConfig
        }
        
        # Return specific menu configuration
        if ($menuConfig.PSObject.Properties.Name -contains $MenuName)
        {
            Write-Verbose "[$functionName] Found configuration for menu: $MenuName"
            return $menuConfig.$MenuName
        }
        else
        {
Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration not found for: $MenuName" -LogLevel "Verbose"
            return $null
        }
    }
    catch
    {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error loading menu configuration: $_" -LogLevel "Error"
        return $null
    }
}