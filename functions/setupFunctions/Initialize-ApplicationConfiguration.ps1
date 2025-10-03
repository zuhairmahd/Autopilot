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
    
    .PARAMETER BoundParameters
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
        [hashtable]$BoundParameters = @{}
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Initializing application configuration"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    Write-Verbose "[$functionName] StringsFile: $StringsFile"
    Write-Verbose "[$functionName] Domain: $Domain"
    Write-Verbose "[$functionName] MenuFile: $menuFile"

    # Ensure required merging functions are available
    if (-not (Get-Command "Merge-ConfigurationDefaults" -ErrorAction SilentlyContinue))
    {
        Write-Warning "[$functionName] Merge-ConfigurationDefaults function not available - settings merging will be skipped"
        Write-Log -logFile $logFile -module $functionName -Message "Merge-ConfigurationDefaults function not available - settings merging will be skipped" -logLevel "Warning"
    }
    
    if (-not (Get-Command "Merge-SettingsWithDefaults" -ErrorAction SilentlyContinue))
    {
        Write-Warning "[$functionName] Merge-SettingsWithDefaults function not available - settings merging will be skipped"
        Write-Log -logFile $logFile -module $functionName -Message "Merge-SettingsWithDefaults function not available - settings merging will be skipped" -logLevel "Warning"
    }

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
                $authResult = Initialize-AuthConfiguration -AuthConfiguration $initFileContent.auth -PSBoundParameters $BoundParameters
                $result.Auth = $authResult.Auth
                
                # Step 4: Process global settings
                $globalResult = Initialize-GlobalSettings -GlobalConfigData $initFileContent.globalSettings -PSBoundParameters $BoundParameters -processConfigOverwrite
                $result.GlobalSettings = $globalResult.GlobalSettings
                
                # Save merged global settings back to main settings file if changes were made
                if ($globalResult.GlobalSettings -and $globalResult.GlobalSettings.Count -gt 0)
                {
                    Write-Verbose "[$functionName] Saving merged global settings back to main settings file"
                    Write-Log -logFile $logFile -module $functionName -Message "Saving merged global settings back to main settings file" -logLevel "Information"
                    
                    try
                    {
                        # Update the global settings section in the main configuration
                        $initFileContent.globalSettings = $globalResult.GlobalSettings
                        
                        # Create backup before saving
                        $backupFile = "$InitFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                        Copy-Item -Path $InitFile -Destination $backupFile -Force
                        Write-Verbose "[$functionName] Created backup: $backupFile"
                        Write-Log -logFile $logFile -module $functionName -Message "Created backup: $backupFile" -logLevel "Verbose"
                        
                        # Save the updated configuration using Export-PowerShellDataFile
                        $exportResult = Export-PowerShellDataFile -InputObject $initFileContent -Path $InitFile -Force -Validate
                        if ($exportResult)
                        {
                            Write-Verbose "[$functionName] Successfully saved merged global settings to: $InitFile"
                            Write-Log -logFile $logFile -module $functionName -Message "Successfully saved merged global settings to: $InitFile" -logLevel "Information"
                        }
                        else
                        {
                            Write-Warning "[$functionName] Failed to save merged global settings"
                            Write-Log -logFile $logFile -module $functionName -Message "Failed to save merged global settings" -logLevel "Warning"
                        }
                    }
                    catch
                    {
                        Write-Warning "[$functionName] Error saving merged global settings: $($_.Exception.Message)"
                        Write-Log -logFile $logFile -module $functionName -Message "Error saving merged global settings: $($_.Exception.Message)" -logLevel "Warning"
                    }
                }
                
                # Step 5: Process domain-specific settings
                $configurationPath = Split-Path -Parent $InitFile
                $localResult = Initialize-LocalSettings -InitFileContent $initFileContent -Domain $Domain -PSBoundParameters $BoundParameters -GlobalSettings $result.GlobalSettings -ConfigurationPath $configurationPath 
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
