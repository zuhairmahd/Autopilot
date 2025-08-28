function Setup-TemporaryEncryption()
{
    <#
    .SYNOPSIS
    Sets up temporary encrypted configuration for secure in-memory access.
    
    .DESCRIPTION
    This function creates a temporary encryption key and re-encrypts the configuration
    content for secure in-memory access during the session. This allows configuration
    values to be accessed without repeatedly prompting for the user's password.
    
    .PARAMETER ConfigContent
    The decrypted configuration content to be temporarily encrypted.
    
    .OUTPUTS
    System.Boolean
    Returns $true if temporary encryption was set up successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigContent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Setting up temporary encryption for configuration" -LogLevel "Debug"
    Write-Verbose "[$functionName] Setting up temporary encryption for configuration"
    
    try
    {
        # Generate a random temporary encryption key
        $tempEncryptionKey = [System.Guid]::NewGuid().ToString() + [System.Guid]::NewGuid().ToString()
        Write-Log -LogFile $LogFile -Module $functionName -Message "Generated temporary encryption key" -LogLevel "Debug"
        
        # Create a temporary file to encrypt the content
        $tempFile = [System.IO.Path]::GetTempFileName()
        Write-Log -LogFile $LogFile -Module $functionName -Message "Created temporary file for encryption" -LogLevel "Debug"
        
        try
        {
            Set-Content -Path $tempFile -Value $ConfigContent -Encoding UTF8
            $tempEncryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $tempEncryptionKey -InMemoryOnly
            
            if ($tempEncryptResult.Success)
            {
                Write-Verbose "[$functionName] Content re-encrypted with temporary key for in-memory use"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Content re-encrypted with temporary key for in-memory use" -LogLevel "Debug"
                
                # Store the encrypted content for later use during the session
                $script:TempEncryptedConfig = $tempEncryptResult.Content
                $script:TempEncryptionKey = $tempEncryptionKey
                
                return $true
            }
            else
            {
                Write-Warning "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to re-encrypt content with temporary key: $($tempEncryptResult.ErrorMessage)" -LogLevel "Error"
                return $false
            }
        }
        finally
        {
            # Clean up temporary file
            Write-Verbose "[$functionName] Cleaning up temporary file: $tempFile"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleaning up temporary file: $tempFile" -LogLevel "Debug"
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] Removed temporary file: $tempFile"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Removed temporary file: $tempFile" -LogLevel "Debug"
            }
        }
    }
    catch
    {
        Write-Warning "Error during temporary encryption setup: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error during temporary encryption setup: $($_.Exception.Message)" -LogLevel "Error"
        return $false
    }
    finally
    {
        # Clear the temporary encryption key from memory
        Write-Log -LogFile $LogFile -Module $functionName -Message "Clearing temporary encryption key from memory" -LogLevel "Debug"
        Clear-SecureMemory -Variables @("tempEncryptionKey")
    }
}

