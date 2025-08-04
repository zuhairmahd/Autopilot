function Get-CachedTokenObject()
{
    [CmdletBinding()]
    param(
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$domain
    )
    $functionName = $MyInvocation.MyCommand.Name
    switch ($cacheType)
    {
        'memory'
        {
            Write-Verbose "[$functionName] Checking memory cache for access token"
            
            # Initialize memory cache if it doesn't exist
            if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
            {
                Write-Verbose "[$functionName] Initializing memory cache"
                New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
            }
            
            if ($Global:MemoryCache.ContainsKey('accessToken'))
            {
                $tokenObject = $Global:MemoryCache['accessToken']
                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in memory cache for domain: $domain"
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] Memory cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                }
            }
            else
            {
                Write-Verbose "[$functionName] No token found in memory cache"
            }
            return $null
        }
        
        'file'
        {
            Write-Verbose "[$functionName] Checking file cache for access token: $cacheTokenFile"
            
            if (-not (Test-Path -Path $cacheTokenFile))
            {
                Write-Verbose "[$functionName] Cache file not found: $cacheTokenFile"
                return $null
            }
            
            try
            {
                $tokenObject = Get-Content -Path $cacheTokenFile -Raw -Force | ConvertFrom-Json
                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in file cache for domain: $domain"
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] File cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                }
            }
            catch
            {
                Write-Warning "[$functionName] Failed to read cache file: $_"
                Write-Verbose "[$functionName] Cache file may be corrupted or invalid"
            }
            return $null
        }
        default
        {
            Write-Error "[$functionName] Invalid cache type: $cacheType. Use 'file' or 'memory'."
            return $null
        }
    }
}

