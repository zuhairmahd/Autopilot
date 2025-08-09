function New-ConfigurationFile()
{
    <#
    .SYNOPSIS
        Creates and encrypts a new configuration file with the provided data.
    
    .DESCRIPTION
        Creates a new config.json file with the provided configuration data,
        then encrypts it using the encryption functions.
    
    .PARAMETER ConfigFile
        Path to the configuration file to create.
    
    .PARAMETER ConfigData
        Hashtable containing the configuration data.
    
    .PARAMETER Silent
        If specified, uses default encryption password.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file was created successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,
        
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Creating configuration file: $ConfigFile"
    
    try
    {
        # Ensure the directory exists
        $configDir = Split-Path -Path $ConfigFile -Parent
        if (-not (Test-Path -Path $configDir))
        {
            Write-Verbose "[$functionName] Creating directory: $configDir"
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-SafeLog "Created directory: $configDir" "Information"
        }
        
        # Create the configuration JSON
        $configJson = $ConfigData | ConvertTo-Json -Depth $maxJSONDepth
        
        # Write the configuration to file
        Write-Verbose "[$functionName] Writing configuration to file"
        Set-Content -Path $ConfigFile -Value $configJson -Encoding UTF8 -Force
        Write-SafeLog "Configuration file created: $ConfigFile" "Information"
        
        # Encrypt the file
        if (-not $Silent)
        {
            Write-Host "`n── Encryption Setup ──" -ForegroundColor Cyan
            Write-Host "Your configuration file needs to be encrypted for security." -ForegroundColor White
        }
        
        $encryptionPassword = ""
        if ($Silent)
        {
            # Use a randomly generated GUID as the default encryption password in silent mode
            $encryptionPassword = [guid]::NewGuid().ToString()
            Write-SafeLog "Using randomly generated GUID as encryption password in silent mode" "Information"
        }
        else
        {
            do
            {
                $encryptionPasswordSecure = Read-Host -Prompt "Enter a password to encrypt your configuration file" -AsSecureString
                
                # Validate password is not empty
                if ($encryptionPasswordSecure.Length -eq 0)
                {
                    Write-Host "Encryption password cannot be empty. Please try again." -ForegroundColor Red
                    continue
                }
                
                # Convert to plain text for length validation
                $encryptionPassword = ConvertFrom-SecureString-ToPlainText -SecureString $encryptionPasswordSecure
                
                if ($encryptionPassword.Length -lt 8)
                {
                    Write-Host "Password must be at least 8 characters long. Please try again." -ForegroundColor Red
                    continue
                }
                
                # Get confirmation
                $confirmPasswordSecure = Read-Host -Prompt "Confirm password" -AsSecureString
                $confirmPassword = ConvertFrom-SecureString-ToPlainText -SecureString $confirmPasswordSecure
                
                if ($encryptionPassword -ne $confirmPassword)
                {
                    Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
                    continue
                }
                
                # Clear confirmation password from memory
                $confirmPassword = $null
                
                break
            } while ($true)
        }
        
        # Encrypt the configuration file
        Write-Verbose "[$functionName] Encrypting configuration file"
        $encryptResult = Invoke-JsonFileEncryption -FilePath $ConfigFile -Key $encryptionPassword
        
        if ($encryptResult.Success)
        {
            if (-not $Silent)
            {
                Write-Host "Configuration file encrypted successfully." -ForegroundColor Green
            }
            Write-SafeLog "Configuration file encrypted successfully" "Information"
            
            # Store the password for session use
            $global:UserEncryptionPassword = $encryptionPassword
            $script:UserEncryptionPassword = $encryptionPassword
            
            return $true
        }
        else
        {
            Write-Host "Failed to encrypt configuration file: $($encryptResult.ErrorMessage)" -ForegroundColor Red
            Write-SafeLog "Failed to encrypt configuration file: $($encryptResult.ErrorMessage)" "Error"
            return $false
        }
    }
    catch
    {
        Write-SafeLog "Error creating configuration file: $($_.Exception.Message)" "Error"
        Write-Host "Error creating configuration file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    }
    finally
    {
        # Clear sensitive data from memory
        if ($encryptionPassword)
        {
            Clear-SecureMemory -Variables @("encryptionPassword")
        }
    }
}

