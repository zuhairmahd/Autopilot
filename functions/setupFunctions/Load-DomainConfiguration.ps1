function Load-DomainConfiguration
{
    <#
    .SYNOPSIS
        Loads domain-specific configuration from a separate JSON file.
    
    .DESCRIPTION
        Loads domain configuration from a file named after the domain (e.g., contoso.com.json).
        If the file doesn't exist, creates it with default settings based on global settings
        and empty inclusion/exclusion groups.
    
    .PARAMETER DomainName
        The name of the domain to load configuration for.
    
    .PARAMETER GlobalSettings
        The global settings to use as defaults when creating a new domain file.
    
    .PARAMETER ConfigurationPath
        The directory path where domain configuration files are stored.
        Defaults to the same directory as settings.json.
    
    .OUTPUTS
        System.Object
        Returns a PSCustomObject containing:
        - groupsToInclude: Array of groups to include
        - groupsToExclude: Array of groups to exclude  
        - settings: Hashtable of domain-specific settings
        - additionalScopes: Array of additional scopes (if any)
    
    .EXAMPLE
        $domainConfig = Load-DomainConfiguration -DomainName "contoso.com" -GlobalSettings $globalSettings
    
    .NOTES
        Creates the domain configuration file if it doesn't exist.
        Uses global settings as defaults for new domain configurations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$GlobalSettings = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath = $pwd
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Loading domain configuration for: $DomainName"
    Write-Log -LogFile $logFile -Message "Loading domain configuration for: $DomainName" -Module $functionName -LogLevel "Information"
    
    try
    {
        # Construct the domain configuration file path
        $domainConfigFile = Join-Path $ConfigurationPath "$DomainName.json"
        Write-Verbose "[$functionName] Domain config file path: $domainConfigFile"
        
        if (Test-Path $domainConfigFile)
        {
            Write-Verbose "[$functionName] Loading existing domain configuration from: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Loading existing domain configuration from: $domainConfigFile" -Module $functionName -LogLevel "Verbose"
            
            try
            {
                $domainContent = Get-Content -Path $domainConfigFile -Raw | ConvertFrom-Json
                Write-Verbose "[$functionName] Successfully loaded domain configuration for $DomainName"
                Write-Log -LogFile $logFile -Message "Successfully loaded domain configuration for $DomainName" -Module $functionName -LogLevel "Information"
                return $domainContent
            }
            catch
            {
                Write-Warning "[$functionName] Failed to parse domain configuration file: $domainConfigFile. Error: $($_.Exception.Message)"
                Write-Log -LogFile $logFile -Message "Failed to parse domain configuration file: $domainConfigFile. Error: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
                
                # Fall through to create new configuration
            }
        }
        
        # Create new domain configuration with defaults from centralized source
        Write-Verbose "[$functionName] Creating new domain configuration for: $DomainName"
        Write-Log -LogFile $logFile -Message "Creating new domain configuration for: $DomainName" -Module $functionName -LogLevel "Information"
        
        # Get default domain structure from centralized source
        try {
            $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
            if (-not $domainDefaults) {
                Write-Warning "[$functionName] Failed to get domain defaults from centralized source, using fallback"
                Write-Log -LogFile $logFile -Message "Failed to get domain defaults from centralized source, using fallback" -Module $functionName -LogLevel "Warning"
                
                # Fallback to minimal structure
                $domainDefaults = @{
                    groupsToInclude = @()
                    groupsToExclude = @()
                    settings = $GlobalSettings.Clone()
                    additionalScopes = @()
                }
            }
        } catch {
            Write-Warning "[$functionName] Error getting centralized defaults: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Error getting centralized defaults: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
            
            # Fallback to minimal structure
            $domainDefaults = @{
                groupsToInclude = @()
                groupsToExclude = @()
                settings = $GlobalSettings.Clone()
                additionalScopes = @()
            }
        }
        
        # Merge global settings with domain defaults if global settings provided
        if ($GlobalSettings -and $GlobalSettings.Count -gt 0) {
            # Merge global settings into domain settings defaults
            foreach ($key in $GlobalSettings.Keys) {
                $domainDefaults.settings[$key] = $GlobalSettings[$key]
            }
        }
        
        # Ensure domain name is set correctly
        $domainDefaults.settings.domain = $DomainName
        
        # Convert to PSCustomObject for consistent behavior, but use hashtable for settings for mutability
        $defaultDomainConfig = [PSCustomObject]@{
            groupsToInclude = $domainDefaults.groupsToInclude
            groupsToExclude = $domainDefaults.groupsToExclude
            settings = $domainDefaults.settings  # Keep as hashtable for mutability
            additionalScopes = $domainDefaults.additionalScopes
        }
        
        # Save the new configuration
        $success = Save-DomainConfiguration -DomainName $DomainName -DomainConfiguration $defaultDomainConfig -ConfigurationPath $ConfigurationPath
        if ($success)
        {
            Write-Verbose "[$functionName] Created new domain configuration file: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Created new domain configuration file: $domainConfigFile" -Module $functionName -LogLevel "Information"
        }
        else
        {
            Write-Warning "[$functionName] Failed to save new domain configuration to: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Failed to save new domain configuration to: $domainConfigFile" -Module $functionName -LogLevel "Warning"
        }
        
        return $defaultDomainConfig
    }
    catch
    {
        Write-Warning "[$functionName] Error loading domain configuration for $DomainName`: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error loading domain configuration for $DomainName`: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        
        # Return minimal default configuration
        return [PSCustomObject]@{
            groupsToInclude = @()
            groupsToExclude = @()
            settings = [PSCustomObject]@{ domain = $DomainName }
            additionalScopes = @()
        }
    }
}