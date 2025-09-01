function Get-DomainConfigurationFromFiles()
{
    <#
    .SYNOPSIS
        Loads domain configuration from separate domain configuration files.
    
    .DESCRIPTION
        Retrieves domain-specific configuration from separate JSON files, creating
        a new configuration with defaults if the file doesn't exist. This function
        supports the separate domain configuration file architecture.
    
    .PARAMETER DomainName
        The name of the domain to load configuration for.
    
    .PARAMETER GlobalSettings
        Global settings hashtable to merge with domain settings if needed.
    
    .PARAMETER ConfigurationPath
        The directory path where domain configuration files are stored.
        Defaults to the current working directory.
    
    .OUTPUTS
        System.Object
        Returns the domain configuration object, or creates a new one with defaults if not found.
    
    .EXAMPLE
        $domainConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -ConfigurationPath "."
    
    .EXAMPLE
        $domainConfig = Get-DomainConfigurationFromFiles -DomainName "fabrikam.com" -GlobalSettings $globalSettings -ConfigurationPath "."
    
    .NOTES
        - Creates domain configuration files with defaults if they don't exist
        - Maintains PowerShell 5.1 compatibility
        - Supports both hashtable and PSCustomObject configurations
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName,
        [Parameter(Mandatory = $false)]
        [hashtable]$GlobalSettings = @{},
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath = $pwd,
        [Parameter(Mandatory = $false)]
        [switch]$LazyLoad = $false
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Performance Optimization Phase 2: Lazy Loading Support
    if ($LazyLoad) {
        Write-Verbose "[$functionName] Lazy loading mode: returning minimal configuration for domain: $DomainName"
        return @{
            settings = @{ 
                domain = $DomainName
                lazyLoaded = $true
                configurationPath = $ConfigurationPath
            }
            loaded = $false
            _domainName = $DomainName
            _configurationPath = $ConfigurationPath
            _globalSettings = $GlobalSettings
        }
    }
    
    Write-Verbose "[$functionName] Full loading domain configuration for: $DomainName"
    Write-Log -LogFile $logFile -Message "Loading domain configuration for: $DomainName" -Module $functionName -LogLevel "Information"
    
    try
    {
        # Construct the expected filename for this domain
        $domainConfigFile = Join-Path $ConfigurationPath "$DomainName.json"
        
        Write-Verbose "[$functionName] Looking for domain config file: $domainConfigFile"
        
        if (Test-Path $domainConfigFile)
        {
            Write-Verbose "[$functionName] Found existing domain configuration file"
Write-Log -LogFile $logFile -Message "Found existing domain configuration file: $domainConfigFile" -Module $functionName -LogLevel "Verbose"
            
            # Load existing configuration
            $domainConfig = Get-Content -Path $domainConfigFile -Raw | ConvertFrom-Json
            
            Write-Log -LogFile $logFile -Message "Successfully loaded domain configuration for $DomainName" -Module $functionName -LogLevel "Information"
            
            return $domainConfig
        }
        else
        {
Write-Log -LogFile $logFile -Message "Domain configuration file not found, creating new configuration with defaults" -Module $functionName -LogLevel "Verbose"
            
            # Create new domain configuration with defaults
            $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
            
            # Create the configuration object
            $newDomainConfig = [PSCustomObject]@{
                groupsToInclude  = $domainDefaults.groupsToInclude
                groupsToExclude  = $domainDefaults.groupsToExclude
                settings         = $domainDefaults.settings
                additionalScopes = $domainDefaults.additionalScopes
            }
            
            # Save the new configuration
            $newDomainConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $domainConfigFile -Force
            
            Write-Log -LogFile $logFile -Message "Created new domain configuration file: $domainConfigFile" -Module $functionName -LogLevel "Information"
            
            return $newDomainConfig
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error loading domain configuration for $DomainName : $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error loading domain configuration for $DomainName : $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        
        # Return a minimal default configuration
        $fallbackConfig = [PSCustomObject]@{
            groupsToInclude  = @()
            groupsToExclude  = @()
            settings         = @{
                domain = $DomainName
            }
            additionalScopes = @()
        }
        
        return $fallbackConfig
    }
}

function Invoke-LazyDomainConfigurationLoad()
{
    <#
    .SYNOPSIS
        Loads the full domain configuration from a lazy-loaded configuration object.
    
    .DESCRIPTION
        This function is part of the Performance Optimization Phase 2 implementation.
        It converts a lazy-loaded domain configuration into a full configuration
        by loading the actual configuration data from files.
    
    .PARAMETER LazyConfiguration
        The lazy-loaded configuration object returned by Get-DomainConfigurationFromFiles -LazyLoad
    
    .OUTPUTS
        System.Object
        Returns the fully loaded domain configuration object.
    
    .EXAMPLE
        $lazyConfig = Get-DomainConfigurationFromFiles -DomainName "contoso.com" -LazyLoad
        $fullConfig = Invoke-LazyDomainConfigurationLoad -LazyConfiguration $lazyConfig
    
    .NOTES
        - Only needed when lazy loading is used during startup optimization
        - Maintains compatibility with existing domain configuration structure
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory = $true)]
        $LazyConfiguration
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Validate that this is a lazy-loaded configuration
    if (-not $LazyConfiguration.settings.lazyLoaded) {
        Write-Verbose "[$functionName] Configuration is already fully loaded"
        return $LazyConfiguration
    }
    
    Write-Verbose "[$functionName] Loading full configuration for lazy-loaded domain: $($LazyConfiguration._domainName)"
    
    # Load the full configuration using the stored parameters
    return Get-DomainConfigurationFromFiles -DomainName $LazyConfiguration._domainName -GlobalSettings $LazyConfiguration._globalSettings -ConfigurationPath $LazyConfiguration._configurationPath
}