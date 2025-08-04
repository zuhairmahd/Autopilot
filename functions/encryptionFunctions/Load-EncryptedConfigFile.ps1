function Load-EncryptedConfigFile()
{
    <#
    .SYNOPSIS
    Loads and decrypts an encrypted configuration file with retry logic.
    
    .DESCRIPTION
    This function handles the complete process of loading an encrypted configuration file,
    including checking encryption status, prompting for password with retry logic,
    decrypting the file, and returning the configuration content.
    
    .PARAMETER ConfigFile
    Path to the configuration file to load.
    
    .PARAMETER MaxRetries
    Maximum number of password attempts allowed. Defaults to 3.
    
    .PARAMETER UseStoredPassword
    If specified, attempts to use the stored password from $script:UserEncryptionPassword.
    
    .PARAMETER PasswordPrompt
    Custom prompt message for password input.
    
    .OUTPUTS
    System.Object
    Returns an object with Success (boolean), Content (string), and ErrorMessage (string) properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        [int]$MaxRetries = 3,
        [switch]$UseStoredPassword,
        [string]$PasswordPrompt = "Enter your password"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Loading encrypted configuration file: $ConfigFile" -LogLevel "Debug"
    Write-Verbose "[$functionName] Loading encrypted configuration file: $ConfigFile"
    
    $result = @{
        Success      = $false
        Content      = ""
        ErrorMessage = ""
        encrypted    = $false
    }
    
    try
    {
        # Check if file exists
        if (-not (Test-Path $ConfigFile))
        {
            $result.ErrorMessage = "Configuration file not found: $ConfigFile"
            Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
            return $result
        }
        
        # Check encryption status
        $encryptionStatus = Test-FileEncryptionStatus -FilePath $ConfigFile
        
        if (-not $encryptionStatus.IsValidFile)
        {
            $result.ErrorMessage = "Configuration file exists but cannot be read: $($encryptionStatus.ErrorMessage)"
            Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
            return $result
        }
        
        if ($encryptionStatus.IsEncrypted)
        {
            # Write-Host "Please enter your password to continue." -ForegroundColor Cyan
            Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file is encrypted, prompting for password" -LogLevel "Information"
            $result.encrypted = $true
            $retryCount = 0
            $decryptResult = $null
            
            do
            {
                $retryCount++
                Write-Verbose "[$functionName] Password attempt $retryCount of $MaxRetries"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Password attempt $retryCount of $MaxRetries" -LogLevel "Debug"
                
                # Get the password
                $userPassword = $null
                if ($UseStoredPassword -and ($script:UserEncryptionPassword -or $global:UserEncryptionPassword))
                {
                    Write-Verbose "[$functionName] Using stored password from session"
                    $userPassword = if ($script:UserEncryptionPassword) { $script:UserEncryptionPassword } else { $global:UserEncryptionPassword }
                }
                else
                {
                    # Prompt for password
                    $userPasswordSecure = Get-SecurePassword -Message "$PasswordPrompt (Attempt $retryCount of $MaxRetries)"
                    $userPassword = ConvertFrom-SecureString-ToPlainText -SecureString $userPasswordSecure
                }
                
                # Decrypt the file in memory
                $decryptResult = Invoke-JsonFileEncryption -FilePath $ConfigFile -Key $userPassword -Decrypt -InMemoryOnly
                
                if ($decryptResult.Success)
                {
                    Write-Verbose "[$functionName] Configuration file decrypted successfully."
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file decrypted successfully" -LogLevel "Information"
                    $result.Success = $true
                    $result.Content = $decryptResult.Content
                    
                    # Store the password for session use
                    $script:UserEncryptionPassword = $userPassword
                    $global:UserEncryptionPassword = $userPassword
                    break
                }
                else
                {
                    $errorMsg = "Incorrect password"
                    Write-Host $errorMsg -ForegroundColor Red
                    Write-Log -LogFile $LogFile -Module $functionName -Message $errorMsg -LogLevel "Error"
                    
                    if ($retryCount -lt $MaxRetries)
                    {
                        Write-Host "Please try again." -ForegroundColor Yellow
                        if ($MaxRetries - $retryCount -le 2)
                        {
                            Write-Host "Warning: Only $($MaxRetries - $retryCount) attempts left." -ForegroundColor Red
                            Write-Host "If you exceed the maximum number of attempts, the authentication information will be erased." -ForegroundColor Red
                            Write-Log -LogFile $LogFile -Module $functionName -Message "Warning: Only $($MaxRetries - $retryCount) attempts left." -LogLevel "Warning"
                        }
                    }
                }
                
                # Clear the password from memory
                Clear-SecureMemory -Variables @("userPassword")
            } while ($retryCount -lt $MaxRetries -and -not $decryptResult.Success)
            
            if (-not $decryptResult.Success)
            {
                $result.ErrorMessage = "Incorrect password after $MaxRetries attempts"
                Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
                Clear-SecureMemory -ClearScriptVariables
                try 
                {
                    Remove-Item -Path $ConfigFile -Force -ErrorAction SilentlyContinue
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Removed configuration file after decryption failure" -LogLevel "Warning"
                    $result.ErrorMessage += "`n Removed configuration file due to invalid password attempts. `n Contact your administrator for assistance."
                }
                catch
                {
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to remove configuration file after decryption failure: $($_.Exception.Message)" -LogLevel "Error"
                }                
                return $result
            }
        }
        else
        {
            # File is not encrypted - read directly
            Write-Verbose "[$functionName] Configuration file is not encrypted, reading directly"
            $result.Content = Get-Content -Path $ConfigFile -Raw -Encoding UTF8
            $result.Success = $true
            Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file read successfully (unencrypted)" -LogLevel "Information"
        }
        
        return $result
        
    }
    catch
    {
        $result.ErrorMessage = "Error loading configuration file: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message $result.ErrorMessage -LogLevel "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $result
    }
}

