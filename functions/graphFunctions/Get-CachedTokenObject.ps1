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
            write-log -LogFile $LogFile -Module "$functionName" -Message "Checking memory cache for access token" -LogLevel "Verbose"        
            # Initialize memory cache if it doesn't exist
            if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
            {
                Write-Verbose "[$functionName] Initializing memory cache"
                write-log -LogFile $LogFile -Module "$functionName" -Message "Initializing memory cache" -LogLevel "Verbose"                                
                New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
            }
            
            if ($Global:MemoryCache.ContainsKey('accessToken'))
            {
                write-log -LogFile $LogFile -Module "$functionName" -Message "Found token in memory cache"
                Write-Verbose "[$functionName] Found token in memory cache"     
                $tokenObject = $Global:MemoryCache['accessToken']
                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in memory cache for domain: $domain"
                    write-log -LogFile $LogFile -Module "$functionName" -Message "Found matching token in memory cache for domain: $domain"
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] Memory cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                    write-log -LogFile $LogFile -Module "$functionName" -Message "Memory cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                }
            }
            else
            {
                Write-Verbose "[$functionName] No token found in memory cache"
                write-log -LogFile $LogFile -Module "$functionName" -Message "No token found in memory cache"                       
            }
            return $null
        }
        
        'file'
        {
            Write-Verbose "[$functionName] Checking file cache for access token: $cacheTokenFile"
            write-log -LogFile $LogFile -Module "$functionName" -Message "Checking file cache for access token: $cacheTokenFile"
            if (-not (Test-Path -Path $cacheTokenFile))
            {
                Write-Verbose "[$functionName] Cache file not found: $cacheTokenFile"
                write-log -LogFile $LogFile -Module "$functionName" -Message "Cache file not found: $cacheTokenFile" -LogLevel "Warning"            
                return $null
            }
            
            try
            {
                write-log -LogFile $LogFile -Module "$functionName" -Message "Reading token from file cache: $cacheTokenFile"               
                Write-Verbose "[$functionName] Reading token from file cache: $cacheTokenFile"
                $tokenObject = Get-Content -Path $cacheTokenFile -Raw -Force | ConvertFrom-Json
                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in file cache for domain: $domain"
                    write-log -LogFile $LogFile -Module "$functionName" -Message "Found matching token in file cache for domain: $domain"                           
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] File cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                    write-log -LogFile $LogFile -Module "$functionName" -Message "File cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"                
                }
            }
            catch
            {
                Write-Warning "[$functionName] Failed to read cache file: $_"
                Write-Verbose "[$functionName] Cache file may be corrupted or invalid"
                write-log -LogFile $LogFile -Module "$functionName" -Message "Failed to read cache file: $_" -LogLevel "Warning"                        
            }
            return $null
        }
        default
        {
            Write-Error "[$functionName] Invalid cache type: $cacheType. Use 'file' or 'memory'."
            write-log -LogFile $LogFile -Module "$functionName" -Message "Invalid cache type: $cacheType. Use 'file' or 'memory'." -LogLevel "Error"                                
            return $null
        }
    }
}

