function Initialize-ApplicationConfiguration()
{
    <#
    .SYNOPSIS
        Initializes application configuration from settings files or defaults.
    
    .DESCRIPTION
        Centralized function to handle configuration loading, including settings.psd1 and strings.psd1 
        file validation, auth configuration processing, and scope merging. Eliminates code duplication
        and provides robust error handling.
    
    .PARAMETER InitFile
        Path to the settings.psd1 file.
    
    .PARAMETER StringsFile
        Path to the strings.psd1 file.
    
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
        [Parameter(Mandatory = $true)]
        [string]$menuFile,
        [string]$Domain = "contoso.com",
        [hashtable]$PSBoundParameters = @{}
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Initializing application configuration"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    Write-Verbose "[$functionName] StringsFile: $StringsFile"
    Write-Verbose "[$functionName] Domain: $Domain"
    Write-Verbose "[$functionName] MenuFile: $menuFile"

    # Helper function for batched file validation (Performance Optimization Phase 2)
    function Test-ConfigurationFilesExist() 
    {
        [CmdletBinding()]
        param (
            [array]$FilesToCheck
        )
        $functionName = $MyInvocation.MyCommand.Name
        $validationResults = @{}
        $existingCount = 0
        $missingCount = 0
        
        Write-Verbose "[$functionName] Batch validating $($FilesToCheck.Count) configuration files"
        Write-Log -logFile $logFile -module $functionName -Message "Batch validating $($FilesToCheck.Count) configuration files" -logLevel "Information"
        foreach ($file in $FilesToCheck)
        {
            Write-Verbose "[$functionName] Checking $($file.Path)"
            Write-Log -logFile $logFile -module $functionName -Message "Checking $($file.Path)" -logLevel "Verbose"
            $exists = Test-Path -Path $file.Path
            Write-Log -logFile $logFile -module $functionName -Message "File $($file.Path) exists: $exists" -logLevel "Verbose"
            $validationResults[$file.Type] = @{
                Path   = $file.Path
                Exists = $exists
                Type   = $file.Type
            }
            
            if ($exists)
            {
                $existingCount++
            }
            else
            {
                $missingCount++
            }
        }
        
        Write-Verbose "[$functionName] File validation complete: $existingCount existing, $missingCount missing"
        Write-Log -logFile $logFile -module $functionName -Message "File validation complete: $existingCount existing, $missingCount missing" -logLevel "Information"
        return $validationResults
    }
    
    try
    {
        # Initialize result object
        $result = @{
            Auth           = @{}
            GlobalSettings = @{}
            LocalSettings  = @{}
            RequiredScopes = @()
            Success        = $false
            ErrorMessage   = ""
        }
        
        # Step 1: Ensure configuration files exist with defaults
        $configResult = Initialize-ConfigurationFiles -InitFile $InitFile -StringsFile $StringsFile -menuFile $menuFile -Domain $Domain
        if (-not $configResult.Success)
        {
            $result.ErrorMessage = $configResult.ErrorMessage
            return $result
        }
        
        # Step 2: Batch validate critical configuration files (Performance Optimization Phase 2)
        $filesToValidate = @(
            @{ Path = $InitFile; Type = "Settings" }
            @{ Path = $StringsFile; Type = "Strings" }
            @{ Path = $menuFile ; Type = "Menu" }
        )
        
        $fileValidation = Test-ConfigurationFilesExist $filesToValidate
        
        # Step 3: Load and process configuration if settings.psd1 exists
        if ($fileValidation["Settings"].Exists)
        {
            Write-Verbose "[$functionName] Loading configuration from $InitFile"
            try
            {
                # Load configuration content
                $initFileContent = Import-PowerShellDataFile -Path $InitFile
                
                # Step 3: Process auth configuration
                $authResult = Initialize-AuthConfiguration -AuthConfiguration $initFileContent.auth -PSBoundParameters $PSBoundParameters
                $result.Auth = $authResult.Auth
                
                # Step 4: Process global settings
                $globalResult = Initialize-GlobalSettings -GlobalConfigData $initFileContent.globalSettings -PSBoundParameters $PSBoundParameters -processConfigOverwrite
                $result.GlobalSettings = $globalResult.GlobalSettings
                
                # Step 5: Process domain-specific settings
                $configurationPath = Split-Path -Parent $InitFile
                $localResult = Initialize-LocalSettings -InitFileContent $initFileContent -Domain $Domain -PSBoundParameters $PSBoundParameters -GlobalSettings $result.GlobalSettings -ConfigurationPath $configurationPath 
                $result.LocalSettings = $localResult.LocalSettings
                
                # Step 6: Process and merge scopes
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
                authType  = "PublicAuthFlow"
                scope     = @("offline_access", "openid", "Device.ReadWrite.All")
            }
            
            # Initialize empty collections for other settings
            $result.GlobalSettings = @{}
            $result.LocalSettings = @{}
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
