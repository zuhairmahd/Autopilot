function Migrate-DomainsToSeparateFiles
{
    <#
    .SYNOPSIS
        Migrates domain configurations from settings.json to separate domain files.
    
    .DESCRIPTION
        Extracts domain configurations from the main settings.json file and creates
        separate JSON files for each domain. This provides backward compatibility
        for existing installations while transitioning to the new file structure.
    
    .PARAMETER SettingsFile
        Path to the main settings.json file.
    
    .PARAMETER ConfigurationPath
        The directory path where domain configuration files should be created.
        Defaults to the same directory as settings.json.
    
    .PARAMETER RemoveFromSettings
        Whether to remove the domains section from settings.json after migration.
        Default is $true.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable with migration results:
        - Success: Boolean indicating overall success
        - MigratedDomains: Array of domain names that were migrated
        - FailedDomains: Array of domain names that failed to migrate
        - ErrorMessages: Array of error messages
    
    .EXAMPLE
        $result = Migrate-DomainsToSeparateFiles -SettingsFile "settings.json"
    
    .NOTES
        Creates backups before modifying files.
        Preserves all domain configuration including groups and settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsFile,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath = $null,
        
        [Parameter(Mandatory = $false)]
        [bool]$RemoveFromSettings = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
Write-Log -LogFile $logFile -Message "Starting domain migration from: $SettingsFile" -Module $functionName -LogLevel "Verbose"
    
    # Initialize result object
    $result = @{
        Success = $false
        MigratedDomains = @()
        FailedDomains = @()
        ErrorMessages = @()
    }
    
    try
    {
        # Default configuration path to same directory as settings file
        if (-not $ConfigurationPath)
        {
            $ConfigurationPath = Split-Path $SettingsFile -Parent
        }
        
        # Check if settings file exists
        if (-not (Test-Path $SettingsFile))
        {
            $errorMsg = "Settings file not found: $SettingsFile"
            Write-Warning "[$functionName] $errorMsg"
            Write-Log -LogFile $logFile -Message $errorMsg -Module $functionName -LogLevel "Warning"
            $result.ErrorMessages += $errorMsg
            return $result
        }
        
        # Load settings file
        Write-Verbose "[$functionName] Loading settings from: $SettingsFile"
        $settingsContent = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
        
        # Check if domains section exists
        if (-not $settingsContent.domains)
        {
Write-Log -LogFile $logFile -Message "No domains section found in settings file - migration not needed" -Module $functionName -LogLevel "Verbose"
            $result.Success = $true
            return $result
        }
        
        $domainNames = $settingsContent.domains.PSObject.Properties.Name
Write-Log -LogFile $logFile -Message "Found $($domainNames.Count) domains to migrate: $($domainNames -join ', ')" -Module $functionName -LogLevel "Verbose"
        
        # Migrate each domain
        foreach ($domainName in $domainNames)
        {
            try
            {
                Write-Verbose "[$functionName] Migrating domain: $domainName"
                $domainConfig = $settingsContent.domains.$domainName
                
                # Ensure the domain configuration has all required properties
                $migratedConfig = [PSCustomObject]@{
                    groupsToInclude = if ($domainConfig.groupsToInclude) { $domainConfig.groupsToInclude } else { @() }
                    groupsToExclude = if ($domainConfig.groupsToExclude) { $domainConfig.groupsToExclude } else { @() }
                    settings = if ($domainConfig.settings) { $domainConfig.settings } else { [PSCustomObject]@{} }
                    additionalScopes = if ($domainConfig.additionalScopes) { $domainConfig.additionalScopes } else { @() }
                }
                
                # Save the domain configuration to separate file
                $saveSuccess = Save-DomainConfiguration -DomainName $domainName -DomainConfiguration $migratedConfig -ConfigurationPath $ConfigurationPath
                
                if ($saveSuccess)
                {
                    $result.MigratedDomains += $domainName
                    Write-Log -LogFile $logFile -Message "Successfully migrated domain: $domainName" -Module $functionName -LogLevel "Information"
                }
                else
                {
                    $result.FailedDomains += $domainName
                    $errorMsg = "Failed to save migrated domain: $domainName"
                    $result.ErrorMessages += $errorMsg
                    Write-Warning "[$functionName] $errorMsg"
                    Write-Log -LogFile $logFile -Message $errorMsg -Module $functionName -LogLevel "Warning"
                }
            }
            catch
            {
                $result.FailedDomains += $domainName
                $errorMsg = "Error migrating domain $domainName`: $($_.Exception.Message)"
                $result.ErrorMessages += $errorMsg
                Write-Warning "[$functionName] $errorMsg"
                Write-Log -LogFile $logFile -Message $errorMsg -Module $functionName -LogLevel "Error"
            }
        }
        
        # Remove domains section from settings.json if requested and all domains migrated successfully
        if ($RemoveFromSettings -and $result.FailedDomains.Count -eq 0 -and $result.MigratedDomains.Count -gt 0)
        {
            try
            {
                Write-Verbose "[$functionName] Removing domains section from settings.json"
                
                # Create backup of settings file
                $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item -Path $SettingsFile -Destination $backupFile -Force
                Write-Log -LogFile $logFile -Message "Created settings backup: $backupFile" -Module $functionName -LogLevel "Verbose"
                
                # Remove domains property from settings object
                $settingsContent.PSObject.Properties.Remove('domains')
                
                # Save updated settings file
                $updatedJson = $settingsContent | ConvertTo-Json -Depth 10
                $updatedJson | Out-File -FilePath $SettingsFile -Encoding UTF8 -Force
                
                Write-Log -LogFile $logFile -Message "Successfully removed domains section from settings.json" -Module $functionName -LogLevel "Information"
            }
            catch
            {
                $errorMsg = "Error removing domains section from settings.json: $($_.Exception.Message)"
                $result.ErrorMessages += $errorMsg
                Write-Warning "[$functionName] $errorMsg"
                Write-Log -LogFile $logFile -Message $errorMsg -Module $functionName -LogLevel "Warning"
            }
        }
        
        # Set overall success based on results
        $result.Success = ($result.FailedDomains.Count -eq 0)
        
        Write-Log -LogFile $logFile -Message "Migration completed. Migrated: $($result.MigratedDomains.Count), Failed: $($result.FailedDomains.Count)" -Module $functionName -LogLevel "Information"
        
        return $result
    }
    catch
    {
        $errorMsg = "Unexpected error during domain migration: $($_.Exception.Message)"
        $result.ErrorMessages += $errorMsg
        Write-Warning "[$functionName] $errorMsg"
        Write-Log -LogFile $logFile -Message $errorMsg -Module $functionName -LogLevel "Error"
        return $result
    }
}