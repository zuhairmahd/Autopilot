function Invoke-PasswordChangeProcess()
{
    <#
    .SYNOPSIS
    Prompts user to change their decryption password and re-encrypts the config file.
    
    .DESCRIPTION
    This function handles the password change process when auth.changePWOnNextStart is true.
    It prompts the user for a new password, re-encrypts the config file with the new password,
    and updates the settings.psd1 file to set changePWOnNextStart to false.
    
    .PARAMETER ConfigFile
    Path to the encrypted configuration file to re-encrypt.
    
    .PARAMETER ConfigContent
    The decrypted configuration content to re-encrypt.
    
    .PARAMETER SettingsFile
    Path to the settings.psd1 file to update.
    
    .PARAMETER NewPassword
    Optional parameter for testing - if provided, skips interactive password prompt.
    .PARAMETER setInitialPassword
    If specified, skips the change password prompts
    
    .OUTPUTS
    System.Boolean
    Returns $true if password change was successful, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile,
        [Parameter(Mandatory = $true)]
        [string]$ConfigContent,
        [Parameter(Mandatory = $true)]
        [string]$SettingsFile,
        [Parameter(Mandatory = $false)]
        [string]$NewPassword,
        [switch]$setInitialPassword
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting password change process" -LogLevel "Verbose"
    if (-not ($setInitialPassword))
    {
        Write-Host "`nPassword Change Required" -ForegroundColor Yellow
        Write-Host "=" * 50 -ForegroundColor Yellow
        Write-Host "Your administrator has requested that you change your decryption password." -ForegroundColor Cyan
    }    
    Write-Host "Please enter a new password to secure your configuration file." -ForegroundColor Cyan
    Write-Host ""
    
    try
    {
        # Get new password - either from parameter (for testing) or prompt user
        if ($NewPassword)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Using provided password for testing" -LogLevel "Debug"
            $newPassword = $NewPassword
        }
        else
        {
            # Prompt for new password with confirmation
            Write-Log -LogFile $LogFile -Module $functionName -Message "Prompting user for new password" -LogLevel "Debug"
            $newPasswordSecure = Get-SecurePassword -Message "Enter your new encryption password" -RequireConfirmation -MinLength 8
            $newPassword = ConvertFrom-SecureString-ToPlainText -SecureString $newPasswordSecure
        }
        
        # Create backup of config file
        $backupPath = "$ConfigFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Creating backup at: $backupPath" -LogLevel "Debug"
        Copy-Item -Path $ConfigFile -Destination $backupPath -Force
        Write-Verbose "[$functionName] Backup created at: $backupPath"
        
        # Re-encrypt the config file with new password
        Write-Host "Re-encrypting configuration file with new password..." -ForegroundColor Cyan
        Write-Log -LogFile $LogFile -Module $functionName -Message "Re-encrypting config file with new password" -LogLevel "Information"
        
        # First write the unencrypted content to a temp file
        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            Set-Content -Path $tempFile -Value $ConfigContent -Encoding UTF8 -NoNewline
            
            # Encrypt with new password
            $encryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $newPassword
            
            if ($encryptResult.Success)
            {
                # Copy encrypted content to original config file
                $encryptedContent = Get-Content -Path $tempFile -Raw -Encoding UTF8
                Set-Content -Path $ConfigFile -Value $encryptedContent -Encoding UTF8 -NoNewline
                
                Write-Host "Configuration file re-encrypted successfully" -ForegroundColor Green
                Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file re-encrypted successfully" -LogLevel "Information"
            }
            else
            {
                Write-Host "Failed to re-encrypt configuration file: $($encryptResult.ErrorMessage)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to re-encrypt configuration file: $($encryptResult.ErrorMessage)" -LogLevel "Error"
                
                # Restore backup
                Copy-Item -Path $backupPath -Destination $ConfigFile -Force
                return $false
            }
        }
        finally
        {
            # Clean up temp file
            if (Test-Path $tempFile)
            {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Update settings.psd1 to set changePWOnNextStart to false
        Write-Host "Updating settings..." -ForegroundColor Cyan
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updating settings.psd1 to disable changePWOnNextStart" -LogLevel "Information"
        
        if (Test-Path $SettingsFile)
        {
            try
            {
                $settings = Import-PowerShellDataFile -Path $SettingsFile
                
                # Update the changePWOnNextStart setting
                if ($settings.auth -and $null -ne $settings.auth.changePWOnNextStart)
                {
                    $settings.auth.changePWOnNextStart = $false
                    # Write updated settings back to file
                    $settings | Export-PowerShellDataFile -Path $SettingsFile
                    Write-Host "Settings updated successfully" -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Settings.psd1 updated successfully - changePWOnNextStart set to false" -LogLevel "Information"
                }
                else
                {
                    Write-Warning "changePWOnNextStart setting not found in auth section"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "changePWOnNextStart setting not found in auth section" -LogLevel "Verbose"
                }
            }
            catch
            {
                Write-Host "Failed to update settings file: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to update settings file: $($_.Exception.Message)" -LogLevel "Error"
                return $false
            }
        }
        else
        {
            Write-Warning "Settings file not found: $SettingsFile"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Verbose"
        }
        # Update stored password in session
        Write-Log -LogFile $LogFile -Module $functionName -Message "Updating session password variables" -LogLevel "Debug"
        $script:UserEncryptionPassword = $newPassword
        $global:UserEncryptionPassword = $newPassword
        # Clean up the new password from memory
        Clear-SecureMemory -Variables @("newPassword")
        # Remove backup file if everything succeeded
        if (Test-Path $backupPath)
        {
            Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
            Write-Log -LogFile $LogFile -Module $functionName -Message "Backup file cleaned up" -LogLevel "Debug"
        }
        if (-not ($setInitialPassword))
        {
            Write-Host "Password change completed successfully!" -ForegroundColor Green
            Write-Log -LogFile $LogFile -Module $functionName -Message "Password change completed successfully" -LogLevel "Information"
        }
        Write-Host "Your configuration file is now secured with your new password." -ForegroundColor Cyan
        Write-Host ""
        Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file secured with new password" -LogLevel "Information"
        return $true
    }
    catch
    {
        Write-Host "Password change failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -LogFile $LogFile -Module $functionName -Message "Password change failed: $($_.Exception.Message)" -LogLevel "Error"
        
        # Restore backup if it exists
        if (Test-Path $backupPath)
        {
            Copy-Item -Path $backupPath -Destination $ConfigFile -Force
            Write-Host "Configuration file restored from backup" -ForegroundColor Yellow
            Write-Log -LogFile $LogFile -Module $functionName -Message "Configuration file restored from backup" -LogLevel "Information"
        }
        
        # Clear sensitive data from memory
        Clear-SecureMemory -Variables @("newPassword")
        
        return $false
    }
}

