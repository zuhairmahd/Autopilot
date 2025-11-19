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
                        # Clean up temporary file
                        if (Test-Path $tempFile)
                        {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue | Out-Null
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

