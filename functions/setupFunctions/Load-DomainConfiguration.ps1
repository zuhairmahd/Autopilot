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
    Write-Log -LogFile $logFile -Message "Starting domain configuration load for: $DomainName" -Module $functionName -LogLevel "Information"
    Write-Log -LogFile $logFile -Message "Configuration path: $ConfigurationPath" -Module $functionName -LogLevel "Verbose"
    Write-Log -LogFile $logFile -Message "Global settings provided: $($GlobalSettings.Count) properties" -Module $functionName -LogLevel "Verbose"
    
    try
    {
        # Construct the domain configuration file path
        $domainConfigFile = Join-Path $ConfigurationPath "$DomainName.json"
        Write-Verbose "[$functionName] Domain config file path: $domainConfigFile"
        Write-Log -LogFile $logFile -Message "Domain config file path: $domainConfigFile" -Module $functionName -LogLevel "Verbose"
        
        if (Test-Path $domainConfigFile)
        {
            Write-Verbose "[$functionName] Loading existing domain configuration from: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Loading existing domain configuration from: $domainConfigFile" -Module $functionName -LogLevel "Information"
            
            try
            {
                $domainContent = Get-Content -Path $domainConfigFile -Raw | ConvertFrom-Json
                Write-Verbose "[$functionName] Successfully loaded domain configuration for $DomainName"
                Write-Log -LogFile $logFile -Message "Successfully loaded domain configuration for $DomainName" -Module $functionName -LogLevel "Information"
                
                # Validate the loaded configuration structure
                Write-Log -LogFile $logFile -Message "Validating loaded domain configuration structure..." -Module $functionName -LogLevel "Verbose"
                Write-Verbose "[$functionName] Validating loaded domain configuration structure..."
                
                $isValid = $true
                $validationErrors = @()
                
                if (-not $domainContent.PSObject.Properties.Name -contains 'settings') {
                    $validationErrors += "Missing 'settings' property"
                    $isValid = $false
                }
                
                if (-not $domainContent.PSObject.Properties.Name -contains 'groupsToInclude') {
                    $validationErrors += "Missing 'groupsToInclude' property"
                    $isValid = $false
                }
                
                if (-not $domainContent.PSObject.Properties.Name -contains 'groupsToExclude') {
                    $validationErrors += "Missing 'groupsToExclude' property"
                    $isValid = $false
                }
                
                if ($isValid) {
                    Write-Log -LogFile $logFile -Message "Domain configuration validation passed" -Module $functionName -LogLevel "Verbose"
                    Write-Verbose "[$functionName] Domain configuration validation passed"
                } else {
                    Write-Log -LogFile $logFile -Message "Domain configuration validation failed: $($validationErrors -join ', ')" -Module $functionName -LogLevel "Warning"
                    Write-Verbose "[$functionName] Domain configuration validation failed: $($validationErrors -join ', ')"
                    # Continue anyway, as we'll fix missing properties below
                }
                
                return $domainContent
            }
            catch
            {
                Write-Warning "[$functionName] Failed to parse domain configuration file: $domainConfigFile. Error: $($_.Exception.Message)"
                Write-Log -LogFile $logFile -Message "Failed to parse domain configuration file: $domainConfigFile. Error: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
                Write-Log -LogFile $logFile -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -Module $functionName -LogLevel "Debug"
                
                # Fall through to create new configuration
            }
        }
        else
        {
            Write-Log -LogFile $logFile -Message "Domain configuration file does not exist: $domainConfigFile" -Module $functionName -LogLevel "Information"
            Write-Verbose "[$functionName] Domain configuration file does not exist: $domainConfigFile"
        }
        
        # Create new domain configuration with defaults from centralized source
        Write-Verbose "[$functionName] Creating new domain configuration for: $DomainName"
        Write-Log -LogFile $logFile -Message "Creating new domain configuration for: $DomainName" -Module $functionName -LogLevel "Information"
        
        # Get default domain structure from centralized source
        Write-Log -LogFile $logFile -Message "Attempting to get domain defaults from centralized source" -Module $functionName -LogLevel "Verbose"
        Write-Verbose "[$functionName] Attempting to get domain defaults from centralized source"
        
        try {
            $domainDefaults = Get-ApplicationDefaults -DefaultType "Domain" -DomainName $DomainName
            if (-not $domainDefaults) {
                Write-Warning "[$functionName] Failed to get domain defaults from centralized source, using fallback"
                Write-Log -LogFile $logFile -Message "Failed to get domain defaults from centralized source, using fallback" -Module $functionName -LogLevel "Warning"
                
                # Fallback to minimal structure
                Write-Log -LogFile $logFile -Message "Creating fallback domain structure" -Module $functionName -LogLevel "Verbose"
                $domainDefaults = @{
                    groupsToInclude = @()
                    groupsToExclude = @()
                    settings = if ($GlobalSettings -and $GlobalSettings.Count -gt 0) { $GlobalSettings.Clone() } else { @{ domain = $DomainName } }
                    additionalScopes = @()
                }
            } else {
                Write-Log -LogFile $logFile -Message "Successfully retrieved domain defaults from centralized source" -Module $functionName -LogLevel "Verbose"
                Write-Verbose "[$functionName] Successfully retrieved domain defaults from centralized source"
                Write-Log -LogFile $logFile -Message "Domain defaults structure: $($domainDefaults.Keys -join ', ')" -Module $functionName -LogLevel "Debug"
            }
        } catch {
            Write-Warning "[$functionName] Error getting centralized defaults: $($_.Exception.Message)"
            Write-Log -LogFile $logFile -Message "Error getting centralized defaults: $($_.Exception.Message)" -Module $functionName -LogLevel "Warning"
            Write-Log -LogFile $logFile -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -Module $functionName -LogLevel "Debug"
            
            # Fallback to minimal structure
            Write-Log -LogFile $logFile -Message "Creating fallback domain structure due to error" -Module $functionName -LogLevel "Warning"
            $domainDefaults = @{
                groupsToInclude = @()
                groupsToExclude = @()
                settings = if ($GlobalSettings -and $GlobalSettings.Count -gt 0) { $GlobalSettings.Clone() } else { @{ domain = $DomainName } }
                additionalScopes = @()
            }
        }
        
        # Merge global settings with domain defaults if global settings provided
        if ($GlobalSettings -and $GlobalSettings.Count -gt 0) {
            Write-Log -LogFile $logFile -Message "Merging $($GlobalSettings.Count) global settings into domain defaults" -Module $functionName -LogLevel "Verbose"
            Write-Verbose "[$functionName] Merging $($GlobalSettings.Count) global settings into domain defaults"
            
            # Ensure settings is a hashtable for merging
            if ($domainDefaults.settings -isnot [hashtable]) {
                Write-Log -LogFile $logFile -Message "Converting domain settings to hashtable for merging" -Module $functionName -LogLevel "Verbose"
                $tempSettings = @{}
                if ($domainDefaults.settings) {
                    $domainDefaults.settings.PSObject.Properties | ForEach-Object {
                        $tempSettings[$_.Name] = $_.Value
                    }
                }
                $domainDefaults.settings = $tempSettings
            }
            
            # Merge global settings into domain settings defaults
            foreach ($key in $GlobalSettings.Keys) {
                $domainDefaults.settings[$key] = $GlobalSettings[$key]
                Write-Log -LogFile $logFile -Message "Merged global setting: $key = $($GlobalSettings[$key])" -Module $functionName -LogLevel "Debug"
            }
            
            Write-Log -LogFile $logFile -Message "Global settings merge completed" -Module $functionName -LogLevel "Verbose"
        } else {
            Write-Log -LogFile $logFile -Message "No global settings provided for merging" -Module $functionName -LogLevel "Verbose"
        }
        
        # Ensure domain name is set correctly
        $domainDefaults.settings.domain = $DomainName
        Write-Log -LogFile $logFile -Message "Set domain name in settings: $DomainName" -Module $functionName -LogLevel "Verbose"
        
        # Convert to PSCustomObject for consistent behavior, but use hashtable for settings for mutability
        Write-Log -LogFile $logFile -Message "Creating domain configuration object with structure validation" -Module $functionName -LogLevel "Verbose"
        
        # Explicitly create empty arrays to ensure they're preserved  
        $defaultDomainConfig = [PSCustomObject]@{
            groupsToInclude = [System.Array]@()
            groupsToExclude = [System.Array]@()
            settings = $domainDefaults.settings  # Keep as hashtable for mutability
            additionalScopes = [System.Array]@()
        }
        
        # If domain defaults have non-empty arrays, use them
        if ($domainDefaults.groupsToInclude -and $domainDefaults.groupsToInclude.Count -gt 0) {
            $defaultDomainConfig.groupsToInclude = [System.Array]$domainDefaults.groupsToInclude
        }
        if ($domainDefaults.groupsToExclude -and $domainDefaults.groupsToExclude.Count -gt 0) {
            $defaultDomainConfig.groupsToExclude = [System.Array]$domainDefaults.groupsToExclude
        }
        if ($domainDefaults.additionalScopes -and $domainDefaults.additionalScopes.Count -gt 0) {
            $defaultDomainConfig.additionalScopes = [System.Array]$domainDefaults.additionalScopes
        }
        
        Write-Log -LogFile $logFile -Message "Domain configuration object created with properties: $($defaultDomainConfig.PSObject.Properties.Name -join ', ')" -Module $functionName -LogLevel "Verbose"
        Write-Log -LogFile $logFile -Message "Settings count: $($defaultDomainConfig.settings.Count)" -Module $functionName -LogLevel "Verbose"
        
        # Save the new configuration
        Write-Log -LogFile $logFile -Message "Attempting to save new domain configuration" -Module $functionName -LogLevel "Verbose"
        $success = Save-DomainConfiguration -DomainName $DomainName -DomainConfiguration $defaultDomainConfig -ConfigurationPath $ConfigurationPath
        if ($success)
        {
            Write-Verbose "[$functionName] Created new domain configuration file: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Successfully created new domain configuration file: $domainConfigFile" -Module $functionName -LogLevel "Information"
        }
        else
        {
            Write-Warning "[$functionName] Failed to save new domain configuration to: $domainConfigFile"
            Write-Log -LogFile $logFile -Message "Failed to save new domain configuration to: $domainConfigFile" -Module $functionName -LogLevel "Error"
        }
        
        return $defaultDomainConfig
    }
    catch
    {
        Write-Warning "[$functionName] Error loading domain configuration for $DomainName`: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error loading domain configuration for $DomainName`: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        Write-Log -LogFile $logFile -Message "Full error details: $($_.Exception | Format-List * | Out-String)" -Module $functionName -LogLevel "Debug"
        
        # Return minimal default configuration as fallback
        Write-Log -LogFile $logFile -Message "Returning minimal fallback configuration due to error" -Module $functionName -LogLevel "Warning"
        return [PSCustomObject]@{
            groupsToInclude = @()
            groupsToExclude = @()
            settings = [PSCustomObject]@{ domain = $DomainName }
            additionalScopes = @()
        }
    }
}