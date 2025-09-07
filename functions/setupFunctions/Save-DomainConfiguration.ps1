function Save-DomainConfiguration
{
    <#
    .SYNOPSIS
        Saves domain-specific configuration to a separate PSD1 file.
    
    .DESCRIPTION
        Saves domain configuration to a PowerShell Data File named after the domain (e.g., contoso.com.psd1).
        Creates timestamped backups before modifying existing files.
    
    .PARAMETER DomainName
        The name of the domain to save configuration for.
    
    .PARAMETER DomainConfiguration
        The domain configuration object to save.
    
    .PARAMETER ConfigurationPath
        The directory path where domain configuration files are stored.
        Defaults to the current working directory.
    
    .PARAMETER CreateBackup
        Whether to create a timestamped backup before overwriting existing files.
        Default is $true.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the configuration was saved successfully, $false otherwise.
    
    .EXAMPLE
        $success = Save-DomainConfiguration -DomainName "contoso.com" -DomainConfiguration $config
    
    .NOTES
        Creates the configuration directory if it doesn't exist.
        Uses PowerShell Data File (.psd1) format for optimal performance.
        Maintains PowerShell 5.1 compatibility.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName,
        
        [Parameter(Mandatory = $true)]
        [object]$DomainConfiguration,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath = $pwd,
        
        [Parameter(Mandatory = $false)]
        [bool]$CreateBackup = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Saving domain configuration for: $DomainName"
    Write-Log -LogFile $logFile -Message "Saving domain configuration for: $DomainName" -Module $functionName -LogLevel "Information"
    
    try
    {
        # Ensure configuration directory exists
        if (-not (Test-Path $ConfigurationPath))
        {
            Write-Verbose "[$functionName] Creating configuration directory: $ConfigurationPath"
            New-Item -Path $ConfigurationPath -ItemType Directory -Force | Out-Null
        }
        
        # Construct the domain configuration file path (using .psd1 format)
        $domainConfigFile = Join-Path $ConfigurationPath "$DomainName.psd1"
        Write-Verbose "[$functionName] Domain config file path: $domainConfigFile"
        
        # Create backup if file exists and backup is requested
        if ((Test-Path $domainConfigFile) -and $CreateBackup)
        {
            $backupFile = "$domainConfigFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $domainConfigFile -Destination $backupFile -Force
            Write-Verbose "[$functionName] Created backup: $backupFile"
            Write-Log -LogFile $logFile -Message "Created backup: $backupFile" -Module $functionName -LogLevel "Verbose"
        }
        
        # Save using Export-PowerShellDataFile for PSD1 format
        $exportResult = Export-PowerShellDataFile -InputObject $DomainConfiguration -Path $domainConfigFile
        
        # Verify the file was saved successfully
        if ($exportResult -and (Test-Path $domainConfigFile))
        {
            Write-Verbose "[$functionName] Successfully saved domain configuration to: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Successfully saved domain configuration to: $domainConfigFile" -Module $functionName -LogLevel "Information"
            
            # Validate the saved PSD1
            try
            {
                $verifyContent = Import-PowerShellDataFile -Path $domainConfigFile -ErrorAction Stop
                Write-Verbose "[$functionName] Verified saved PSD1 is valid"
                Write-Log -LogFile $logFile -Message "Verified saved PSD1 is valid for domain: $DomainName" -Module $functionName -LogLevel "Verbose"
                return $true
            }
            catch
            {
                Write-Warning "[$functionName] Saved PSD1 file is invalid: $($_.Exception.Message)"
                Write-Log -LogFile $logFile -Message "Saved PSD1 file is invalid: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
                return $false
            }
        }
        else
        {
            Write-Warning "[$functionName] Failed to save domain configuration file: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Failed to save domain configuration file: $domainConfigFile" -Module $functionName -LogLevel "Warning"
            return $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error saving domain configuration for $DomainName`: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error saving domain configuration for $DomainName`: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        return $false
    }
}