function Get-CachedDeviceEnrollmentStatus()
{
    <#
    .SYNOPSIS
        Retrieves device enrollment status with unified cache support.
    
    .DESCRIPTION
        Gets device enrollment status from Graph API with automatic caching via
        the unified cache management system. Supports cache refresh on demand.
    
    .PARAMETER SerialNumber
        Device serial number to look up
    
    .PARAMETER AccessToken
        Access token for Graph API authentication
    
    .PARAMETER Settings
        Settings object containing cache configuration
    
    .PARAMETER flushCache
        Forces a refresh of cached enrollment state
    
    .NOTES
        Migrated to unified cache management system
        Uses Devices cache type with automatic expiration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        $Settings = $global:settings,
        [switch]$flushCache
    )
    $functionName = $MyInvocation.MyCommand.Name
    
    # Build cache key
    $cacheKey = "enrollment:$SerialNumber"
    
    # Try to get cached data (unless flushCache is specified)
    if (-not $flushCache)
    {
        $cachedState = Get-CachedData -CacheType 'Devices' -Key $cacheKey -Settings $Settings
        
        if ($null -ne $cachedState)
        {
            Write-Verbose "[$functionName] Cache hit for serial number: $SerialNumber. Returning cached enrollment state."
            Write-Host "Using cached enrollment state for serial number: $SerialNumber" -ForegroundColor Cyan
            return $cachedState
        }
    }
    
    # Cache miss or refresh requested - fetch from API
    Write-Verbose "[$functionName] Cache miss for serial number: $SerialNumber. Fetching from API."
    $enrollmentState = Get-DeviceEnrollmentStatus -serialNumber $SerialNumber -AccessToken $AccessToken -Settings $Settings
    
    if ($enrollmentState)
    {
        # Store in unified cache
        $metadata = @{
            SerialNumber = $SerialNumber
        }
        $cached = Set-CachedData -CacheType 'Devices' -Key $cacheKey -Data $enrollmentState -Metadata $metadata -Settings $Settings
        if ($cached)
        {
            Write-Verbose "[$functionName] Cached enrollment state for serial number: $SerialNumber."
        }
    }
    else
    {
        Write-Verbose "[$functionName] No enrollment state found for serial number: $SerialNumber. Not caching."
    }
    
    return $enrollmentState
}

