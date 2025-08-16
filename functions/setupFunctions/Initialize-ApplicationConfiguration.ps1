function Initialize-ApplicationConfiguration
{
    <#
    .SYNOPSIS
        Initializes application configuration from settings files or defaults.
    
    .DESCRIPTION
        Centralized function to handle configuration loading, including settings.json and strings.json 
        file validation, auth configuration processing, and scope merging. Eliminates code duplication
        and provides robust error handling.
    
    .PARAMETER InitFile
        Path to the settings.json file.
    
    .PARAMETER StringsFile
        Path to the strings.json file.
    
    .PARAMETER Domain
        The domain name for configuration defaults.
    
    .PARAMETER PSBoundParameters
        Parameters passed from the calling script to preserve command-line overrides.
    
    .PARAMETER LogFile
        Path to the log file for logging.
    
    .PARAMETER ScriptName
        Name of the calling script for logging.
    
    .OUTPUTS
        Hashtable containing:
        - Auth: Auth configuration hashtable
        - GlobalSettings: Global settings hashtable  
        - LocalSettings: Local/domain settings hashtable
        - Menus: Menu configuration array
        - RequiredScopes: Merged and deduplicated scopes array
        - Success: Boolean indicating success/failure
        - ErrorMessage: Error message if Success is false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InitFile,
        
        [Parameter(Mandatory = $true)]
        [string]$StringsFile,
        
        [string]$Domain = "contoso.com",
        
        [hashtable]$PSBoundParameters = @{},
        
        [string]$LogFile,
        
        [string]$ScriptName = "Initialize-ApplicationConfiguration"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Initializing application configuration"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    Write-Verbose "[$functionName] StringsFile: $StringsFile"
    Write-Verbose "[$functionName] Domain: $Domain"
    
    try
    {
        # Initialize result object
        $result = @{
            Auth = @{}
            GlobalSettings = @{}
            LocalSettings = @{}
            Menus = @()
            RequiredScopes = @()
            Success = $false
            ErrorMessage = ""
        }
        
        # Step 1: Ensure configuration files exist with defaults
        $configResult = Initialize-ConfigurationFiles -InitFile $InitFile -StringsFile $StringsFile -Domain $Domain
        if (-not $configResult.Success)
        {
            $result.ErrorMessage = $configResult.ErrorMessage
            return $result
        }
        
        # Step 2: Load and process configuration if settings.json exists
        if (Test-Path -Path $InitFile)
        {
            Write-Verbose "[$functionName] Loading configuration from $InitFile"
            
            try
            {
                # Load configuration content
                $initFileContent = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
                
                # Step 3: Process auth configuration
                $authResult = Initialize-AuthConfiguration -AuthConfiguration $initFileContent.auth -PSBoundParameters $PSBoundParameters
                $result.Auth = $authResult.Auth
                
                # Step 4: Process global settings
                $globalResult = Initialize-GlobalSettings -GlobalConfigData $initFileContent.globalSettings -PSBoundParameters $PSBoundParameters
                $result.GlobalSettings = $globalResult.GlobalSettings
                
                # Step 5: Process domain-specific settings
                $localResult = Initialize-LocalSettings -InitFileContent $initFileContent -Domain $Domain -PSBoundParameters $PSBoundParameters
                $result.LocalSettings = $localResult.LocalSettings
                
                # Step 6: Load menus
                $result.Menus = $initFileContent.menus
                Write-Verbose "[$functionName] Loaded $($result.Menus.Count) menus from $InitFile"
                
                # Step 7: Process and merge scopes
                $scopeResult = Initialize-RequiredScopes -InitFileContent $initFileContent -Domain $Domain
                $result.RequiredScopes = $scopeResult.RequiredScopes
                
            }
            catch
            {
                $result.ErrorMessage = "Error loading configuration from $InitFile`: $($_.Exception.Message)"
                Write-Verbose "[$functionName] $($result.ErrorMessage)"
                return $result
            }
        }
        else
        {
            Write-Verbose "[$functionName] Settings file not found, using default configuration"
            
            # Use default auth configuration when no settings file exists
            $result.Auth = @{
                delegated = $true
                authType = "PublicAuthFlow"
                scope = @("offline_access", "openid", "Device.ReadWrite.All")
            }
            
            # Initialize empty collections for other settings
            $result.GlobalSettings = @{}
            $result.LocalSettings = @{}
            $result.Menus = @()
            $result.RequiredScopes = @()
        }
        
        $result.Success = $true
        Write-Verbose "[$functionName] Configuration initialization completed successfully"
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Unexpected error during configuration initialization: $($_.Exception.Message)"
        Write-Verbose "[$functionName] $($result.ErrorMessage)"
        return $result
    }
}

function Initialize-ConfigurationFiles
{
    <#
    .SYNOPSIS
        Ensures configuration files exist with proper defaults.
    #>
    [CmdletBinding()]
    param(
        [string]$InitFile,
        [string]$StringsFile,
        [string]$Domain
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $result = @{ Success = $false; ErrorMessage = "" }
    
    try
    {
        # Ensure settings.json exists with defaults
        Write-Verbose "[$functionName] Ensuring settings.json exists with defaults"
        $settingsCreated = Test-SettingsJsonExists -SettingsFile $InitFile -Silent -DomainName $Domain
        if (-not $settingsCreated)
        {
            $result.ErrorMessage = "Failed to create or validate settings.json file"
            return $result
        }
        
        # Ensure strings.json exists with defaults
        Write-Verbose "[$functionName] Ensuring strings.json exists with defaults"
        $stringsCreated = Test-StringsJsonExists -StringsFile $StringsFile -Silent
        if (-not $stringsCreated)
        {
            $result.ErrorMessage = "Failed to create or validate strings.json file"
            return $result
        }
        
        $result.Success = $true
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Error ensuring configuration files exist: $($_.Exception.Message)"
        return $result
    }
}

function Initialize-AuthConfiguration
{
    <#
    .SYNOPSIS
        Processes auth configuration from settings file.
    #>
    [CmdletBinding()]
    param(
        [object]$AuthConfiguration,
        [hashtable]$PSBoundParameters
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $auth = @{}
    
    if ($null -eq $AuthConfiguration)
    {
        Write-Verbose "[$functionName] No auth configuration found, using defaults"
        return @{ Auth = $auth }
    }
    
    Write-Verbose "[$functionName] Processing auth configuration"
    foreach ($key in $AuthConfiguration.PSObject.Properties.Name)
    {
        Write-Verbose "[$functionName] Processing auth key: $key"
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $AuthConfiguration.$key)
        {
            if ($AuthConfiguration.$key -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($AuthConfiguration.$key)
                $auth.add($key, $keyBooleanValue)
                Write-Verbose "[$functionName] Set $key to boolean value: $keyBooleanValue"
            }
            else
            {
                $auth.add($key, $AuthConfiguration.$key)
                Write-Verbose "[$functionName] Set $key to string value: $($AuthConfiguration.$key)"
            }
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $auth.add($key, $PSBoundParameters[$key])
            Write-Verbose "[$functionName] Used command-line parameter for $key`: $($PSBoundParameters[$key])"
        }
    }
    
    return @{ Auth = $auth }
}

function Initialize-GlobalSettings
{
    <#
    .SYNOPSIS
        Processes global settings from configuration file.
    #>
    [CmdletBinding()]
    param(
        [object]$GlobalConfigData,
        [hashtable]$PSBoundParameters
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $globalSettings = @{}
    
    if ($null -eq $GlobalConfigData)
    {
        Write-Verbose "[$functionName] No global settings found"
        return @{ GlobalSettings = $globalSettings }
    }
    
    Write-Verbose "[$functionName] Processing $($GlobalConfigData.PSObject.Properties.Name.count) global settings"
    foreach ($key in $GlobalConfigData.PSObject.Properties.Name)
    {
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $GlobalConfigData.$key)
        {
            if ($GlobalConfigData.$key -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($GlobalConfigData.$key)
                $globalSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$functionName] Set global $key to boolean: $keyBooleanValue"
            }
            else
            {
                $globalSettings.add($key, $GlobalConfigData.$key)
                Write-Verbose "[$functionName] Set global $key to: $($GlobalConfigData.$key)"
            }
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $globalSettings.add($key, $PSBoundParameters[$key])
            Write-Verbose "[$functionName] Used command-line override for global $key"
        }
    }
    
    return @{ GlobalSettings = $globalSettings }
}

function Initialize-LocalSettings
{
    <#
    .SYNOPSIS
        Processes domain-specific settings from configuration file.
    #>
    [CmdletBinding()]
    param(
        [object]$InitFileContent,
        [string]$Domain,
        [hashtable]$PSBoundParameters
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $localSettings = @{}
    
    if ($null -eq $InitFileContent.domains -or $null -eq $InitFileContent.domains.$Domain)
    {
        Write-Verbose "[$functionName] No domain-specific settings found for $Domain"
        return @{ LocalSettings = $localSettings }
    }
    
    $localConfigData = $InitFileContent.domains.$Domain.settings
    if ($null -eq $localConfigData)
    {
        Write-Verbose "[$functionName] No settings object found for domain $Domain"
        return @{ LocalSettings = $localSettings }
    }
    
    Write-Verbose "[$functionName] Processing domain settings for $Domain"
    foreach ($key in $localConfigData.PSObject.Properties.Name)
    {
        if ($PSBoundParameters.ContainsKey($key) -eq $false -and $null -ne $localConfigData.$key)
        {
            if ($localConfigData.$key -in ('true', 'false'))
            {
                $keyBooleanValue = [bool]::Parse($localConfigData.$key)
                $localSettings.add($key, $keyBooleanValue)
                Write-Verbose "[$functionName] Set local $key to boolean: $keyBooleanValue"
            }
            else
            {
                $localSettings.add($key, $localConfigData.$key)
                Write-Verbose "[$functionName] Set local $key to: $($localConfigData.$key)"
            }
        }
        elseif ($PSBoundParameters.ContainsKey($key))
        {
            $localSettings.add($key, $PSBoundParameters[$key])
            Write-Verbose "[$functionName] Used command-line override for local $key"
        }
    }
    
    return @{ LocalSettings = $localSettings }
}

function Initialize-RequiredScopes
{
    <#
    .SYNOPSIS
        Processes and merges required scopes from configuration.
    #>
    [CmdletBinding()]
    param(
        [object]$InitFileContent,
        [string]$Domain
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Get basic scopes from configuration
    $basicScopes = $InitFileContent.requiredScopes
    if ($null -eq $basicScopes) 
    { 
        Write-Verbose "[$functionName] No basic scopes found, initializing as empty array"
        $basicScopes = @() 
    }
    
    # Get additional scopes for the domain
    $additionalScopes = $null
    if ($InitFileContent.domains -and $InitFileContent.domains.$Domain)
    {
        $additionalScopes = $InitFileContent.domains.$Domain.additionalScopes
    }
    
    if ($null -eq $additionalScopes) 
    { 
        Write-Verbose "[$functionName] No additional scopes found for $Domain, initializing as empty array"
        $additionalScopes = @() 
    }
    
    # Ensure arrays and merge
    $basicScopes = @($basicScopes)
    $additionalScopes = @($additionalScopes)
    
    Write-Verbose "[$functionName] Basic scopes: $($basicScopes.Count), Additional scopes: $($additionalScopes.Count)"
    
    # Merge and deduplicate
    $allScopes = @($basicScopes) + @($additionalScopes)
    $requiredScopes = $allScopes | Group-Object -Property Scope | ForEach-Object { $_.Group | Select-Object -First 1 }
    
    Write-Verbose "[$functionName] Merged scopes - Total unique: $($requiredScopes.Count)"
    
    return @{ RequiredScopes = $requiredScopes }
}