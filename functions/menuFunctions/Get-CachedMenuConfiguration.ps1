function Get-CachedMenuConfiguration()
{
    <#
    .SYNOPSIS
        Gets cached menu configuration using unified cache management.
    
    .DESCRIPTION
        Retrieves menu configuration from cache using the unified Invoke-CacheManagement system.
        This function now serves as a wrapper around the centralized cache management.
    
    .PARAMETER MenuName
        Optional specific menu name to retrieve
        
    .PARAMETER MenuConfigFile
        Path to menu configuration file (defaults to menu.json in current directory)
        
    .PARAMETER ForceReload
        Force reload of menu configuration from file
        
    .OUTPUTS
        PSCustomObject - Menu configuration object or specific menu
        
    .EXAMPLE
        $config = Get-CachedMenuConfiguration
        
    .EXAMPLE
        $mainMenu = Get-CachedMenuConfiguration -MenuName "mainMenu"
        
    .NOTES
        - Now uses unified Invoke-CacheManagement for consistency
        - Maintains backward compatibility with existing callers
        - Provides extensive logging for troubleshooting
    #>
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
    Write-Log -LogFile $LogFile -Module $functionName -Message "Getting cached menu configuration via unified cache management" -LogLevel "Debug"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Parameters - MenuName: '$MenuName', MenuConfigFile: '$MenuConfigFile', ForceReload: $ForceReload" -LogLevel "Debug"
    
    try {
        # Use unified cache management system
        $result = Invoke-CacheManagement -Action GetMenuConfiguration -MenuName $MenuName -MenuConfigFile $MenuConfigFile -ForceReload:$ForceReload
        
        if ($result) {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully retrieved menu configuration via unified cache management" -LogLevel "Verbose"
            if ($MenuName) {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Returning specific menu configuration for: $MenuName" -LogLevel "Debug"
            } else {
                Write-Log -LogFile $LogFile -Module $functionName -Message "Returning full menu configuration with $($result.PSObject.Properties.Count) properties" -LogLevel "Debug"
            }
        } else {
            Write-Log -LogFile $LogFile -Module $functionName -Message "No menu configuration returned from unified cache management" -LogLevel "Warning"
        }
        
        return $result
    }
    catch {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error using unified cache management: $_" -LogLevel "Error"
        return $null
    }
}

function Clear-MenuConfigurationCache()
{
    <#
    .SYNOPSIS
        Clears menu configuration cache using unified cache management.
    
    .DESCRIPTION
        Clears the menu configuration cache using the centralized Invoke-CacheManagement system.
        This function now serves as a wrapper around the centralized cache management.
        
    .OUTPUTS
        Hashtable - Result of cache clear operation
        
    .EXAMPLE
        Clear-MenuConfigurationCache
        
    .NOTES
        - Now uses unified Invoke-CacheManagement for consistency
        - Maintains backward compatibility with existing callers
        - Provides extensive logging for troubleshooting
    #>
    [CmdletBinding()]
    param()
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Clearing menu configuration cache via unified cache management" -LogLevel "Debug"
    
    try {
        # Use unified cache management system
        $result = Invoke-CacheManagement -Action ClearSpecific -CacheType Menu
        
        if ($result -and $result.Cleared) {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully cleared menu configuration cache via unified cache management" -LogLevel "Information"
        } else {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration cache was already empty or not found" -LogLevel "Information"
        }
        
        return $result
    }
    catch {
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error clearing menu configuration cache: $_" -LogLevel "Error"
        return @{ Success = $false; Error = $_.ToString() }
    }
}