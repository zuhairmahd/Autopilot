function Save-TokenToCache()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$cachedToken,
        [Parameter(Mandatory = $true)]
        [ValidateSet('file', 'memory')]
        [string]$cacheType,
        [string]$cacheTokenFile,
        [string]$cacheFolder
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting token cache save operation"
    Write-Verbose "[$functionName] Cache type: $cacheType"
    # Extract token scope from JWT token roles
    Write-Verbose "[$functionName] Decoding JWT token to extract roles/scope"
    
    Write-Verbose "[$functionName] Successfully extracted token scope: $($tokenScope -join ', ')"
    # Add scope to cached token object
    Write-Verbose "[$functionName] Adding scope property to cached token object"
    if (-not $cachedToken.scope)
    {
        Write-Verbose "[$functionName] Scope property not found in cached token, adding it"
        $cachedToken.add('scope', (DecodeJwtToken -Token $cachedToken.access_token -raw).roles)
    }
    else
    {
        Write-Verbose "[$functionName] Scope property already exists in cached token. Applying proper formatting."
        $cachedToken.scope = FormatScopes -scopes $cachedToken.scope -Reverse
    }
    
    # Save access token according to cache type
    if ($cacheType -eq 'memory')
    {
        Write-Verbose "[$functionName] Saving access token to memory cache"
        
        # Initialize global memory cache if it doesn't exist
        if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
        {
            Write-Verbose "[$functionName] Initializing global memory cache"
            New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
        }
        
        # Save to memory cache
        $Global:MemoryCache['accessToken'] = $cachedToken
        Write-Verbose "[$functionName] Token successfully saved to memory cache"
        
        # Debug: Log what was actually saved
        if ($Global:MemoryCache['accessToken'].scope)
        {
            Write-Verbose "[$functionName] Verified scope is accessible: $($Global:MemoryCache['accessToken'].scope -join ', ')"
        }
        else
        {
            Write-Warning "[$functionName] Scope property not found in saved token"
        }
    }
    else
    {
        Write-Verbose "[$functionName] Saving access token to cache file: $cacheTokenFile"
        
        if (-not (Test-Path -Path $cacheFolder))
        {
            Write-Verbose "[$functionName] Creating cache folder: $cacheFolder"
            New-Item -Path $cacheFolder -ItemType Directory -Force | Out-Null
        }
        
        try
        {
            $cachedToken | ConvertTo-Json -Depth $maxJSONDepth | Set-Content -Path $cacheTokenFile -Force -ErrorAction Stop
            Write-Verbose "[$functionName] Access token successfully saved to $cacheTokenFile"
        }
        catch
        {
            Write-Error "[$functionName] Failed to save token to cache file: $_"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to save token to cache file: $_" -LogLevel "Error"
            throw
        }
    }
}

