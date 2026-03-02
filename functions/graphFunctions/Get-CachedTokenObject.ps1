function Get-CachedTokenObject()
{
    <#
    .SYNOPSIS
    Retrieves a cached access token object from memory or file cache.

    .DESCRIPTION
    This function retrieves a cached access token for a specified domain from either memory
    or file-based cache storage. For memory cache, it initializes the global cache if needed
    and validates the domain matches. For file cache, it reads and deserializes the JSON token
    file. The function includes error handling and validation of cache data.

    .PARAMETER cacheType
    The cache storage type: 'memory' or 'file'.

    .PARAMETER cacheTokenFile
    The path to the cache token file (required for file-based caching).

    .PARAMETER domain
    The domain/tenant identifier to match against the cached token.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the cached token object if found and valid for the domain, otherwise $null.

    .EXAMPLE
    $token = Get-CachedTokenObject -cacheType 'memory' -domain "contoso.com"
    $token = Get-CachedTokenObject -cacheType 'file' -cacheTokenFile $cachePath -domain "contoso.com"

    .NOTES
    Memory cache uses global $MemoryCache hashtable with 'accessToken' key.
    File cache reads JSON from cacheTokenFile path.
    Validates domain matches before returning cached token.
    Returns $null if cache doesn't exist, is empty, or domain doesn't match.
    Compatible with PowerShell 5.1.
    #>
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
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking memory cache for access token" -LogLevel "Verbose"
            # Initialize memory cache if it doesn't exist
            if (-not (Get-Variable -Name 'MemoryCache' -Scope Global -ErrorAction SilentlyContinue))
            {
                Write-Verbose "[$functionName] Initializing memory cache"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Initializing memory cache" -LogLevel "Verbose"
                New-Variable -Name 'MemoryCache' -Scope Global -Value @{} -Force
            }

            if ($Global:MemoryCache.ContainsKey('accessToken'))
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found token in memory cache"
                Write-Verbose "[$functionName] Found token in memory cache"
                $tokenObject = $Global:MemoryCache['accessToken']
                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in memory cache for domain: $domain"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found matching token in memory cache for domain: $domain"
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] Memory cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Memory cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                }
            }
            else
            {
                Write-Verbose "[$functionName] No token found in memory cache"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "No token found in memory cache"
            }
            return $null
        }

        'file'
        {
            Write-Verbose "[$functionName] Checking file cache for access token: $cacheTokenFile"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Checking file cache for access token: $cacheTokenFile"
            if (-not (Test-Path -Path $cacheTokenFile))
            {
                Write-Verbose "[$functionName] Cache file not found: $cacheTokenFile"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Cache file not found: $cacheTokenFile" -LogLevel "Warning"
                return $null
            }

            try
            {
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Reading token from file cache: $cacheTokenFile"
                Write-Verbose "[$functionName] Reading token from file cache: $cacheTokenFile"

                $tokenContent = Get-Content -Path $cacheTokenFile -Raw -Force

                # Check if the content is encrypted (base64 encoded)
                $isEncrypted = $false
                try
                {
                    # Try to parse as JSON first - if it fails, it's likely encrypted
                    $null = ConvertFrom-Json $tokenContent -ErrorAction Stop
                    Write-Verbose "[$functionName] Token appears to be unencrypted JSON"
                }
                catch
                {
                    # Not JSON, likely encrypted
                    $isEncrypted = $true
                    Write-Verbose "[$functionName] Token appears to be encrypted"
                }

                # If encrypted and we have the user's password, decrypt it
                if ($isEncrypted -and ($script:UserEncryptionPassword -or $global:UserEncryptionPassword))
                {
                    $userPassword = if ($script:UserEncryptionPassword) { $script:UserEncryptionPassword } else { $global:UserEncryptionPassword }

                    Write-Verbose "[$functionName] Decrypting token from file cache"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Decrypting token from file cache" -LogLevel "Debug"

                    # Create a temporary file for decryption
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try
                    {
                        Set-Content -Path $tempFile -Value $tokenContent -Encoding UTF8 -NoNewline

                        # Decrypt the token using the user's password (same as config file)
                        $decryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $userPassword -Decrypt -InMemoryOnly

                        if ($decryptResult.Success)
                        {
                            Write-Verbose "[$functionName] Token decrypted successfully"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Token decrypted successfully" -LogLevel "Information"
                            $tokenContent = $decryptResult.Content
                        }
                        else
                        {
                            Write-Warning "[$functionName] Failed to decrypt token (wrong password or corrupted file)"
                            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to decrypt token: $($decryptResult.ErrorMessage)" -LogLevel "Warning"
                            return $null
                        }
                    }
                    finally
                    {
                        # Securely overwrite and clean up temporary file
                        if (Test-Path $tempFile)
                        {
                            try {
                                $fileInfo = Get-Item $tempFile
                                $fileSize = $fileInfo.Length
                                if ($fileSize -gt 0) {
                                    $randomBytes = New-Object byte[] $fileSize
                                    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
                                    [System.IO.File]::WriteAllBytes($tempFile, $randomBytes)
                                }
                            } catch {
                                # Ignore errors during overwrite
                            }
                            try {
                                $fileInfo = Get-Item $tempFile
                                $fileSize = $fileInfo.Length
                                if ($fileSize -gt 0) {
                                    $randomBytes = New-Object byte[] $fileSize
                                    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
                                    [System.IO.File]::WriteAllBytes($tempFile, $randomBytes)
                                }
                            } catch {
                                # Ignore errors during overwrite
                            }
                            try
                            {
                                # Overwrite the file with random data before deletion to prevent recovery.
                                $fileInfo = Get-Item $tempFile
                                if ($fileInfo.Length -gt 0)
                                {
                                    $randomBytes = New-Object byte[] $fileInfo.Length
                                    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
                                    [System.IO.File]::WriteAllBytes($tempFile, $randomBytes)
                                }
                                Remove-Item $tempFile -Force -ErrorAction Stop
                            }
                            catch
                            {
                                Write-Warning "[$functionName] Failed to securely delete temporary file '$($tempFile)'. Attempting regular deletion."
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                        }
                    }
                }
                elseif ($isEncrypted -and -not ($script:UserEncryptionPassword -or $global:UserEncryptionPassword))
                {
                    Write-Warning "[$functionName] Token is encrypted but no user password is available"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Token is encrypted but no user password is available" -LogLevel "Warning"
                    return $null
                }

                # Parse the token JSON
                $tokenObject = ConvertFrom-Json $tokenContent

                if ($tokenObject.domain -eq $domain)
                {
                    Write-Verbose "[$functionName] Found matching token in file cache for domain: $domain"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found matching token in file cache for domain: $domain"
                    return $tokenObject
                }
                else
                {
                    Write-Verbose "[$functionName] File cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                    Write-Log -LogFile $LogFile -Module "$functionName" -Message "File cache token domain ($($tokenObject.domain)) doesn't match requested domain ($domain)"
                }
            }
            catch
            {
                Write-Warning "[$functionName] Failed to read cache file: $_"
                Write-Verbose "[$functionName] Cache file may be corrupted or invalid"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to read cache file: $_" -LogLevel "Warning"
            }
            return $null
        }
        default
        {
            Write-Error "[$functionName] Invalid cache type: $cacheType. Use 'file' or 'memory'."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Invalid cache type: $cacheType. Use 'file' or 'memory'." -LogLevel "Error"
            return $null
        }
    }
}

