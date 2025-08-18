function Save-DomainConfiguration
{
    <#
    .SYNOPSIS
        Saves domain-specific configuration to a separate JSON file.
    
    .DESCRIPTION
        Saves domain configuration to a file named after the domain (e.g., contoso.com.json).
        Creates timestamped backups before modifying existing files.
    
    .PARAMETER DomainName
        The name of the domain to save configuration for.
    
    .PARAMETER DomainConfiguration
        The domain configuration object to save.
    
    .PARAMETER ConfigurationPath
        The directory path where domain configuration files are stored.
        Defaults to the same directory as settings.json.
    
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
        Uses UTF-8 encoding for the JSON file.
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
        
        # Construct the domain configuration file path
        $domainConfigFile = Join-Path $ConfigurationPath "$DomainName.json"
        Write-Verbose "[$functionName] Domain config file path: $domainConfigFile"
        
        # Create backup if file exists and backup is requested
        if ((Test-Path $domainConfigFile) -and $CreateBackup)
        {
            $backupFile = "$domainConfigFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $domainConfigFile -Destination $backupFile -Force
            Write-Verbose "[$functionName] Created backup: $backupFile"
            Write-Log -LogFile $logFile -Message "Created backup: $backupFile" -Module $functionName -LogLevel "Verbose"
        }
        
        # Convert configuration to JSON with proper formatting
        $jsonContent = $DomainConfiguration | ConvertTo-Json -Depth 10
        
        # Save to file
        $jsonContent | Out-File -FilePath $domainConfigFile -Encoding UTF8 -Force
        
        # Verify the file was saved successfully
        if (Test-Path $domainConfigFile)
        {
            Write-Verbose "[$functionName] Successfully saved domain configuration to: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Successfully saved domain configuration to: $domainConfigFile" -Module $functionName -LogLevel "Information"
            
            # Validate the saved JSON
            try
            {
                $verifyContent = Get-Content -Path $domainConfigFile -Raw | ConvertFrom-Json
                Write-Verbose "[$functionName] Verified saved JSON is valid"
                Write-Log -LogFile $logFile -Message "Verified saved JSON is valid for domain: $DomainName" -Module $functionName -LogLevel "Verbose"
                return $true
            }
            catch
            {
                Write-Warning "[$functionName] Saved JSON file is invalid: $($_.Exception.Message)"
                Write-Log -LogFile $logFile -Message "Saved JSON file is invalid: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
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