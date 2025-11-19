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
    
    # Extract token scope from JWT token (scp for delegated, roles for application)
    Write-Verbose "[$functionName] Decoding JWT token to extract scope information"
    $decodedToken = DecodeJwtToken -Token $cachedToken.access_token -raw
    
    # Determine scope based on auth type
    $tokenScope = @()
    if ($decodedToken.scp)
    {
        # Delegated auth - scp is space-separated string
        $tokenScope = $decodedToken.scp -split ' ' | Where-Object { $_ -and $_.Trim() }
        Write-Verbose "[$functionName] Extracted delegated scopes (scp): $($tokenScope -join ', ')"
    }
    elseif ($decodedToken.roles)
    {
        # Application auth - roles is array
        $tokenScope = $decodedToken.roles
        Write-Verbose "[$functionName] Extracted application scopes (roles): $($tokenScope -join ', ')"
    }
    else
    {
        Write-Warning "[$functionName] No scope information found in token (neither scp nor roles claims present)"
    }
    
    Write-Verbose "[$functionName] Successfully extracted token scope: $($tokenScope -join ', ')"
    
    # Add scope to cached token object
    Write-Verbose "[$functionName] Adding scope property to cached token object"
    if (-not $cachedToken.scope)
    {
        Write-Verbose "[$functionName] Scope property not found in cached token, adding it"
        $cachedToken.add('scope', $tokenScope)
    }
    else
    {
        Write-Verbose "[$functionName] Scope property already exists in cached token. Updating with extracted scopes."
        $cachedToken.scope = $tokenScope
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
            # Convert token to JSON
            $tokenJson = $cachedToken | ConvertTo-Json -Depth $maxJSONDepth
            
            # Check if user encryption password is available (same password used for config file)
            if ($script:UserEncryptionPassword -or $global:UserEncryptionPassword)
            {
                $userPassword = if ($script:UserEncryptionPassword) { $script:UserEncryptionPassword } else { $global:UserEncryptionPassword }
                
                Write-Verbose "[$functionName] Encrypting token before saving to file cache"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Encrypting token before saving to file cache" -LogLevel "Debug"
                
                # Create a temporary file for encryption
                $tempFile = [System.IO.Path]::GetTempFileName()
                try
                {
                    Set-Content -Path $tempFile -Value $tokenJson -Encoding UTF8 -NoNewline
                    
                    # Encrypt the token using the user's password (same as config file)
                    # The -InMemoryOnly parameter causes Invoke-JsonFileEncryption to return the encrypted content in memory,
                    # rather than writing it back to the file. A temporary file is still needed because the encryption function
                    # expects a file input.
                    $encryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $userPassword -InMemoryOnly
                    
                    if ($encryptResult.Success)
                    {
                        # Save the encrypted content to the cache file
                        Set-Content -Path $cacheTokenFile -Value $encryptResult.Content -Force -ErrorAction Stop
                        Write-Verbose "[$functionName] Access token encrypted and saved successfully to $cacheTokenFile"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Access token encrypted and saved successfully" -LogLevel "Information"
                    }
                    else
                    {
                        Write-Warning "[$functionName] Failed to encrypt token, saving unencrypted: $($encryptResult.ErrorMessage)"
                        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to encrypt token, saving unencrypted: $($encryptResult.ErrorMessage)" -LogLevel "Warning"
                        Set-Content -Path $cacheTokenFile -Value $tokenJson -Force -ErrorAction Stop
                    }
                }
                finally
                {
                    try
                    {
                        # Overwrite the file with random data before deletion
                        $fileInfo = Get-Item $tempFile
                        $fileLength = $fileInfo.Length
                        if ($fileLength -gt 0)
                        {
                            $randomBytes = New-Object byte[] $fileLength
                            [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($randomBytes)
                            [System.IO.File]::WriteAllBytes($tempFile, $randomBytes)
                        }
                        Remove-Item $tempFile -Force -ErrorAction Stop
                    }
                    catch
                    {
                        Write-Warning "[$functionName] Failed to securely delete temporary file $($tempFile): $_"
                    }
                    if (Test-Path $tempFile)
                    {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }
            else
            {
                Write-Verbose "[$functionName] No user encryption password available, saving token unencrypted"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "No user encryption password available, saving token unencrypted" -LogLevel "Warning"
                Set-Content -Path $cacheTokenFile -Value $tokenJson -Force -ErrorAction Stop
            }
            
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

