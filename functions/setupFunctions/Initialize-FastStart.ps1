function Initialize-FastStart()
{
    <#
    .SYNOPSIS
    Initializes fast start configuration by loading and validating required configuration files.

    .DESCRIPTION
    The Initialize-FastStart function loads multiple configuration files needed for fast start initialization.
    It validates that all required files are present and contain expected properties, then returns a hashtable
    with the loaded configuration data and a success status indicating whether all validations passed.

    .PARAMETER InitFile
    The path to the initialization configuration file containing auth, globalSettings, repoInfo, requiredScopes, and cacheSettings.

    .PARAMETER stringsFile
    The path to the strings configuration file containing UI strings and messages.

    .PARAMETER menuFile
    The path to the menu configuration file containing menu definitions.

    .PARAMETER menuCacheFile
    The path to the menu cache file (JSON format) containing cached menu data.

    .PARAMETER domain
    The domain parameter (passed but not currently used in the function).

    .PARAMETER ScriptPath
    The script path parameter (passed but not currently used in the function).

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable containing:
    - auth: Authentication configuration from InitFile
    - globalSettings: Global settings from InitFile
    - localSettings: Domain-specific settings from domain file
    - RepoInfo: Repository information from InitFile
    - RequiredScopes: Required OAuth scopes from InitFile
    - CacheSettings: Cache settings from InitFile
    - menu: Menu configuration from menu file
    - menus: Menu cache from JSON file
    - strings: String resources from strings file
    - allFilesLoaded: Boolean indicating if all required files were successfully loaded
    - Success: Boolean indicating if all validations passed

    .EXAMPLE
    $config = Initialize-FastStart -InitFile ".\config\init.psd1" -stringsFile ".\config\strings.psd1" -menuFile ".\config\menu.psd1" -menuCacheFile ".\cache\menu.json" -domain "contoso.com" -ScriptPath "C:\scripts"

    .NOTES
    If menuCacheFileValid is false, the function still returns Success as true if all other validations pass but sets the value of allFilesLoaded to false unless the -strictValidation switch is set.
    #>
    [CmdletBinding()]
    param(
        [string]$InitFile,
        [string]$stringsFile,
        [string]$menuFile,
        [string]$menuCacheFile,
        [string]$domain,
        [string]$ScriptPath,
        [switch]$strictValidation
    )

    $functionName = $MyInvocation.MyCommand.Name
    $domainFilePath = Join-Path -Path $ScriptPath -ChildPath "$domain.psd1"
    Write-Verbose "[$functionName] Starting fast start initialization with parameters; InitFile: $InitFile, stringsFile: $stringsFile, menuFile: $menuFile, menuCacheFile: $menuCacheFile, domain: $domain, ScriptPath: $ScriptPath, StrictValidation: $strictValidation"
    Write-Verbose "[$functionName] Domain file path: $domainFilePath    "
    Write-Log -logFile $logFile -module $functionName -message "Starting fast start initialization with parameters; InitFile: $InitFile, stringsFile: $stringsFile, menuFile: $menuFile, menuCacheFile: $menuCacheFile, domain: $domain, ScriptPath: $ScriptPath, DomainFilePath: $domainFilePath, StrictValidation: $strictValidation"
    $filesLoaded = $true
    Write-Log -logFile $logFile -module $functionName -message "Attempting fast start configuration load."
    Write-Verbose "[$functionName] Attempting fast start configuration load."
    if (Test-Path $InitFile)
    {
        Write-Log -logFile $logFile -module $functionName -message "Loading init file: $InitFile"
        Write-Verbose "[$functionName] Loading init file: $InitFile"
        $initContent = Import-PowerShellDataFile -Path $InitFile
    }
    else
    {
        $filesLoaded = $false
        Write-Log -logFile $logFile -module $functionName -message "Init file not found: $InitFile"
        Write-Verbose "[$functionName] Init file not found: $InitFile"
    }
    if (Test-Path $stringsFile)
    {
        Write-Log -logFile $logFile -module $functionName -message "Loading strings file: $stringsFile"
        Write-Verbose "[$functionName] Loading strings file: $stringsFile"
        $stringContent = Import-PowerShellDataFile -Path $stringsFile
    }
    else
    {
        $filesLoaded = $false
        Write-Log -logFile $logFile -module $functionName -message "Strings file not found: $stringsFile"
        Write-Verbose "[$functionName] Strings file not found: $stringsFile"
    }
    if (Test-Path $domainFilePath)
    {
        Write-Log -logFile $logFile -module $functionName -message "Loading domain settings file: $domainFilePath"
        Write-Verbose "[$functionName] Loading domain settings file: $domainFilePath"
        $domainContent = Import-PowerShellDataFile -Path $domainFilePath
    }
    else
    {
        $filesLoaded = $false
        Write-Log -logFile $logFile -module $functionName -message "Domain settings file not found: $domainFilePath"
        Write-Verbose "[$functionName] Domain settings file not found: $domainFilePath"
    }
    if (Test-Path $menuFile)
    {
        Write-Log -logFile $logFile -module $functionName -message "Loading menu file: $menuFile"
        Write-Verbose "[$functionName] Loading menu file: $menuFile"
        $menuContent = Import-PowerShellDataFile -Path $menuFile
    }
    else
    {
        $filesLoaded = $false
        Write-Log -logFile $logFile -module $functionName -message "Menu file not found: $menuFile"
        Write-Verbose "[$functionName] Menu file not found: $menuFile"
    }
    if (Test-Path $menuCacheFile)
    {
        Write-Log -logFile $logFile -module $functionName -message "Menu cache file found: $menuCacheFile"
        Write-Verbose "[$functionName] Menu cache file found: $menuCacheFile"
        $menuCache = Get-Content -Path $menuCacheFile -ErrorAction SilentlyContinue -Force | ConvertFrom-Json
    }
    else
    {
        if ($strictValidation)
        {
            Write-Verbose "[$functionName] Strict validation enabled - marking filesLoaded as false due to missing menu cache file."
            Write-Log -logFile $logFile -module $functionName -message "Strict validation enabled - marking filesLoaded as false due to missing menu cache file."
            $filesLoaded = $false
        }
        else
        {
            Write-Log -logFile $logFile -module $functionName -message "Menu cache file not found: $menuCacheFile, but continuing due to non-strict validation.         "
            Write-Verbose "[$functionName] Menu cache file not found: $menuCacheFile, but continuing due to non-strict validation. "
        }
    }
    # Validate fastStart configuration completeness
    Write-Verbose "[$functionName] FastStart validation: filesLoaded=$filesLoaded"
    Write-Log -logFile $logFile -module $functionName -message "FastStart validation: filesLoaded=$filesLoaded"
    # Check each required property and log what's missing
    $authValid = $null -ne $initContent.auth
    $globalSettingsValid = $null -ne $initContent.globalSettings
    $repoInfoValid = $null -ne $initContent.repoInfo
    $requiredScopesValid = $null -ne $initContent.requiredScopes
    $cacheSettingsValid = $null -ne $initContent.cacheSettings
    $domainContentValid = $null -ne $domainContent
    $menuContentValid = $null -ne $menuContent
    $stringContentValid = $null -ne $stringContent
    $menuCacheFileValid = $null -ne $menuCache
    Write-Verbose "[$functionName] FastStart property validation: auth=$authValid, globalSettings=$globalSettingsValid, repoInfo=$repoInfoValid, requiredScopes=$requiredScopesValid, cacheSettings=$cacheSettingsValid, domain=$domainContentValid, menu=$menuContentValid, strings=$stringContentValid, menuCacheFile=$menuCacheFileValid"
    Write-Log -logFile $logFile -module $functionName -message "FastStart property validation: auth=$authValid, globalSettings=$globalSettingsValid, repoInfo=$repoInfoValid, requiredScopes=$requiredScopesValid, cacheSettings=$cacheSettingsValid, domain=$domainContentValid, menu=$menuContentValid, strings=$stringContentValid, menuCacheFile=$menuCacheFileValid        "
    if (-not $authValid)
    {
        Write-Verbose "[$functionName] FastStart: auth is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: auth is null"
    }
    if (-not $globalSettingsValid)
    {
        Write-Verbose "[$functionName] FastStart: globalSettings is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: globalSettings is null"
    }
    if (-not $repoInfoValid)
    {
        Write-Verbose "[$functionName] FastStart: repoInfo is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: repoInfo is null"
    }
    if (-not $requiredScopesValid)
    {
        Write-Verbose "[$functionName] FastStart: requiredScopes is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: requiredScopes is null"
    }
    if (-not $cacheSettingsValid)
    {
        Write-Verbose "[$functionName] FastStart: cacheSettings is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: cacheSettings is null"
    }
    if (-not $domainContentValid)
    {
        Write-Verbose "[$functionName] FastStart: domainContent is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: domainContent is null"
    }
    if (-not $menuContentValid)
    {
        Write-Verbose "[$functionName] FastStart: menuContent is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: menuContent is null"
    }
    if (-not $stringContentValid)
    {
        Write-Verbose "[$functionName] FastStart: stringContent is null"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: stringContent is null"
    }
    if (-not $menuCacheFileValid)
    {
        Write-Verbose "[$functionName] FastStart: menuCacheFile not found"
        Write-Log -logFile $logFile -module $functionName -message "FastStart: menuCacheFile not found"
    }

    $configResult = @{
        auth           = $initContent.auth
        globalSettings = $initContent.globalSettings
        localSettings  = $domainContent
        RepoInfo       = $initContent.repoInfo
        RequiredScopes = $initContent.requiredScopes
        CacheSettings  = $initContent.cacheSettings
        menu           = $menuContent
        menus          = $menuCache
        strings        = $stringContent
        allFilesLoaded = $filesLoaded
        Success        = if ($strictValidation)
        {
            $filesLoaded -and $authValid -and $globalSettingsValid -and $repoInfoValid -and $requiredScopesValid -and $cacheSettingsValid -and $domainContentValid -and $menuContentValid -and $stringContentValid -and $menuCacheFileValid
        }
        else
        {
            $authValid -and $globalSettingsValid -and $repoInfoValid -and $requiredScopesValid -and $cacheSettingsValid -and $domainContentValid -and $menuContentValid -and $stringContentValid
        }
    }
    return $configResult
}