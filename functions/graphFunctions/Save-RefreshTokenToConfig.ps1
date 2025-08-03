function Save-RefreshTokenToConfig()
{
    param($refreshToken, $configFilePath)

    $functionName = $MyInvocation.MyCommand.Name
    $delegatedCredentials = @{}
    $userPassword = $null
    $usingTempConfig = $false
    
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting refresh token save operation" -LogLevel "Information"
    Write-Verbose "[$functionName] Called with configFilePath=$configFilePath, refreshToken provided=$($null -ne $refreshToken)"
    
    if (-not $refreshToken)
    {
        Write-Verbose "[$functionName] No refresh token to save"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No refresh token provided - operation skipped" -LogLevel "Warning"
        return
    }
    
    # First try to use the temporary encrypted config if available to avoid password prompt
    if ($script:TempEncryptedConfig -and $script:TempEncryptionKey)
    {
        Write-Verbose "[$functionName] Using existing temporary encrypted config to avoid password prompt"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Using existing temporary encrypted config to avoid duplicate password prompt" -LogLevel "Information"
        
        # Decrypt the temporary config
        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            Set-Content -Path $tempFile -Value $script:TempEncryptedConfig -Encoding UTF8
            $decryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $script:TempEncryptionKey -Decrypt -InMemoryOnly
            
            if ($decryptResult.Success)
            {
                $config = ConvertFrom-Json $decryptResult.Content
                $usingTempConfig = $true
                $needsEncryption = $true
                Write-Verbose "[$functionName] Successfully obtained config from temporary encrypted config"
            }
            else
            {
                Write-Warning "[$functionName] Failed to decrypt temporary config: $($decryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decrypt temporary config, falling back to disk file: $($decryptResult.ErrorMessage)" -LogLevel "Warning"
            }
        }
        catch
        {
            Write-Warning "[$functionName] Error accessing temporary config: $_"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Error accessing temporary config, falling back to disk file: $_" -LogLevel "Warning"
        }
        finally
        {
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force
            }
        }
    }
    
    # Fall back to reading and decrypting from disk if temporary config is not available
    if (-not $usingTempConfig)
    {
        Write-Verbose "[$functionName] Temporary config not available, reading from disk"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Temporary config not available, reading from disk file" -LogLevel "Debug"
        
        # Read the current config from disk (it should be encrypted)
        try
        {
            $encryptedContent = Get-Content -Raw -Path $configFilePath -ErrorAction Stop
            Write-Verbose "[$functionName] Successfully read config file from disk"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully read config file from disk" -LogLevel "Debug"
        }
        catch
        {
            Write-Error "[$functionName] Failed to read config file: $_"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to read config file: $_" -LogLevel "Error"
            return
        }
        
        # Check if config is encrypted (it should be in the new system)
        $encryptionStatus = Test-FileEncryptionStatus -FilePath $configFilePath
        Write-Log -LogFile $LogFile -Module $functionName -Message "Config file encryption status: $($encryptionStatus.IsEncrypted)" -LogLevel "Debug"
        
        if (-not $encryptionStatus.IsEncrypted)
        {
            Write-Warning "[$functionName] Config file is not encrypted. This may indicate an issue with the encryption system."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Config file is not encrypted - handling for backward compatibility" -LogLevel "Warning"
            # For backward compatibility, handle unencrypted config
            $config = ConvertFrom-Json $encryptedContent
            $needsEncryption = $true
        }
        else
        {
            Write-Verbose "[$functionName] Config file is encrypted. Prompting for password to decrypt for modification."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Config file is encrypted - prompting for password to decrypt for modification" -LogLevel "Debug"
            # Need to get the user's password to decrypt the config file
            $userPasswordSecure = Get-SecurePassword -Message "Enter your password to update the refresh token"
            $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
            
            # Decrypt the config file
            $decryptResult = Invoke-JsonFileEncryption -FilePath $configFilePath -Key $userPassword -Decrypt -InMemoryOnly
            
            if (-not $decryptResult.Success)
            {
                Write-Error "[$functionName] Failed to decrypt config file: $($decryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decrypt config file: $($decryptResult.ErrorMessage)" -LogLevel "Error"
                return
            }
            
            $config = ConvertFrom-Json $decryptResult.Content
            $needsEncryption = $true
        }
    }
    
    # Format scopes
    if ($refreshToken.scope)
    {
        Write-Verbose "[$functionName] Adding scope to new delegatedCredentials"
        $formattedScopes = FormatScopes -scopes $refreshToken.scope -Reverse
        Write-Verbose "[$functionName] Formatted scopes object type: $($formattedScopes.GetType().Name)"
        #If it is not an array, make it int an array
        if (-not ($formattedScopes -is [array]))
        {
            Write-Verbose "[$functionName] Scopes is not an array, converting to array"
            $formattedScopes = @($formattedScopes)
        }
    }
    else
    {
        Write-Verbose "[$functionName] No scopes provided in refresh token, using empty array"
        $formattedScopes = @()
    }

    # Update the config with the new refresh token
    if ($config.delegatedCredentials)
    {
        Write-Verbose "[$functionName] Updating existing delegatedCredentials property"
        $config.delegatedCredentials.refresh_token = $refreshToken.refresh_token
        $config.delegatedCredentials.scope = $formattedScopes
    }
    else
    {
        Write-Verbose "[$functionName] Creating new delegatedCredentials property"
        $delegatedCredentials.refresh_token = $refreshToken.refresh_token
        $delegatedCredentials.scope = $formattedScopes
        $config | Add-Member -MemberType NoteProperty -Name 'delegatedCredentials' -Value $delegatedCredentials
    }

    # Re-encrypt the config and save it
    if ($needsEncryption)
    {
        # If we used temporary config but don't have user password, check if it's available in script variable
        if ($usingTempConfig -and -not $userPassword)
        {
            if ($script:UserEncryptionPassword)
            {
                Write-Verbose "[$functionName] Using cached user password from startup for disk encryption"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Using cached user password from startup - no additional prompt needed" -LogLevel "Information"
                $userPassword = $script:UserEncryptionPassword
            }
            else
            {
                Write-Verbose "[$functionName] Need user password for disk encryption"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting for password to encrypt updated config to disk" -LogLevel "Debug"
                $userPasswordSecure = Get-SecurePassword -Message "Enter your password to save the updated configuration"
                $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
            }
        }
        
        Write-Verbose "[$functionName] Re-encrypting config with refresh token for disk storage"
        # Create a temporary file for the updated config
        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8
            
            # Re-encrypt with the user's password
            $encryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $userPassword
            
            if ($encryptResult.Success)
            {
                Write-Verbose "[$functionName] Config re-encrypted successfully"
                # Move the encrypted temp file to the original location
                Copy-Item -Path $tempFile -Destination $configFilePath -Force
                Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully saved encrypted config to disk" -LogLevel "Information"
            }
            else
            {
                Write-Error "[$functionName] Failed to re-encrypt config: $($encryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to re-encrypt config: $($encryptResult.ErrorMessage)" -LogLevel "Error"
                return
            }
        }
        finally
        {
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force
            }
        }
    }
    else
    {
        # Save the updated config without encryption
        Write-Verbose "[$functionName] Saving refresh token to config file: $configFilePath"
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFilePath -Force
    }
    Write-Verbose "[$functionName] Refresh token saved to config file"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Refresh token operation completed successfully" -LogLevel "Information"
    
    # Always update the temporary encrypted config if it exists to keep it in sync
    if ($script:TempEncryptedConfig -and $script:TempEncryptionKey)
    {
        Write-Verbose "[$functionName] Updating temporary encrypted config with new refresh token"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updating temporary encrypted config to maintain consistency" -LogLevel "Debug"
        try
        {
            # Create a temporary file with the decrypted config
            $tempFile = [System.IO.Path]::GetTempFileName()
            try
            {
                $config | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8
                
                # Re-encrypt with the temporary key
                $tempEncryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $script:TempEncryptionKey -InMemoryOnly
                
                if ($tempEncryptResult.Success)
                {
                    $script:TempEncryptedConfig = $tempEncryptResult.Content
                    Write-Verbose "[$functionName] Successfully updated temporary encrypted config"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully updated temporary encrypted config" -LogLevel "Debug"
                }
                else
                {
                    Write-Warning "[$functionName] Failed to update temporary encrypted config: $($tempEncryptResult.ErrorMessage)"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to update temporary encrypted config: $($tempEncryptResult.ErrorMessage)" -LogLevel "Warning"
                }
            }
            finally
            {
                if (Test-Path $tempFile)
                {
                    Remove-Item $tempFile -Force
                }
            }
        }
        catch
        {
            Write-Warning "[$functionName] Failed to update temporary encrypted config: $_"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to update temporary encrypted config: $_" -LogLevel "Warning"
        }
    }
    else
    {
        Write-Verbose "[$functionName] No temporary encrypted config available to update"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No temporary encrypted config available to update" -LogLevel "Debug"
    }
    
    # Clear the user password from memory
    if ($userPassword)
    {
        Clear-SecureMemory -Variables @("userPassword")
    }
}

