function Initialize-ApplicationConfiguration()
{
    <#
    .SYNOPSIS
        Initializes application configuration from settings files with automatic defaults merging.
    
    .DESCRIPTION
        Centralized function to handle configuration loading and initialization. Validates and loads
        settings.psd1, strings.psd1, and menu.psd1 files, processes auth configuration, global settings,
        and domain-specific settings. Automatically merges missing keys from defaults, preserving
        command-line overrides. Creates configuration files with defaults if they don't exist.
        
        The function performs batch file validation for performance, processes configurations through
        specialized initializers, and saves changes back to disk when missing keys are merged.
    
    .PARAMETER InitFile
        Path to the settings.psd1 file. If the file doesn't exist, it will be created with defaults.
    
    .PARAMETER StringsFile
        Path to the strings.psd1 file. If the file doesn't exist, it will be created with defaults.
    
    .PARAMETER menuFile
        Path to the menu.psd1 file. If the file doesn't exist, it will be created with defaults.
    
    .PARAMETER Domain
        The domain name for configuration defaults (e.g., "contoso.com").
    
    .PARAMETER BoundParameters
        Hashtable of parameters passed from the calling script to preserve command-line overrides.
        These parameters take precedence over configuration file values.
    
    .OUTPUTS
        Hashtable containing:
        - Auth: Auth configuration hashtable with delegated/authType/scope settings
        - GlobalSettings: Global settings hashtable (merged with defaults if missing keys detected)
        - LocalSettings: Local/domain-specific settings hashtable (merged with defaults if missing keys detected)
        - Strings: Strings configuration hashtable with all UI text (merged with defaults if missing keys detected)
        - Menu: Menu configuration hashtable with all menu structures (merged with defaults if missing keys detected)
        - RequiredScopes: Merged and deduplicated scopes array from auth and domain configurations
        - Success: Boolean indicating success ($true) or failure ($false)
        - ErrorMessage: String containing error message if Success is $false, empty string otherwise
    
    .EXAMPLE
        $config = Initialize-ApplicationConfiguration -InitFile "C:\config\settings.psd1" `
            -StringsFile "C:\config\strings.psd1" -menuFile "C:\config\menu.psd1" `
            -Domain "contoso.com" -BoundParameters $PSBoundParameters
        
        if ($config.Success) {
            $auth = $config.Auth
            $settings = $config.GlobalSettings
            $localSettings = $config.LocalSettings
            $strings = $config.Strings
            $menu = $config.Menu
            $scopes = $config.RequiredScopes
        }
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
    Write-Log -logFile $logFile -module $functionName -Message "Initializing application configuration" -logLevel "Information"
    Write-Verbose "[$functionName] Initializing application configuration"
    Write-Log -logFile $logFile -module $functionName -Message "InitFile: $InitFile" -logLevel "Verbose"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    Write-Log -logFile $logFile -module $functionName -Message "StringsFile: $StringsFile" -logLevel "Verbose"
    Write-Verbose "[$functionName] StringsFile: $StringsFile"
    Write-Log -logFile $logFile -module $functionName -Message "Domain: $Domain" -logLevel "Verbose"
    Write-Verbose "[$functionName] Domain: $Domain"
    Write-Log -logFile $logFile -module $functionName -Message "MenuFile: $menuFile" -logLevel "Verbose"
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
            Strings        = @{}
            Menu           = @{}
            RequiredScopes = @()
            Success        = $false
            ErrorMessage   = ""
        }
        
        # Step 1: Ensure configuration files exist with defaults
        Write-Log -logFile $logFile -module $functionName -Message "Ensuring configuration files exist with defaults" -logLevel "Information"
        Write-Verbose "[$functionName] Ensuring configuration files exist with defaults"
        $configResult = Initialize-ConfigurationFiles -InitFile $InitFile -StringsFile $StringsFile -menuFile $menuFile -Domain $Domain
        if (-not $configResult.Success)
        {
            $result.ErrorMessage = $configResult.ErrorMessage
            Write-Log -logFile $logFile -module $functionName -Message "Configuration file initialization failed: $($result.ErrorMessage)" -logLevel "Error"
            Write-Verbose "[$functionName] Configuration file initialization failed: $($result.ErrorMessage)"
            return $result
        }
        Write-Log -logFile $logFile -module $functionName -Message "Configuration files validated successfully" -logLevel "Information"
        Write-Verbose "[$functionName] Configuration files validated successfully"
        
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
            Write-Log -logFile $logFile -module $functionName -Message "Loading configuration from $InitFile" -logLevel "Information"
            Write-Verbose "[$functionName] Loading configuration from $InitFile"
            try
            {
                # Load configuration content
                $initFileContent = Import-PowerShellDataFile -Path $InitFile
                Write-Log -logFile $logFile -module $functionName -Message "Successfully loaded configuration file" -logLevel "Verbose"
                Write-Verbose "[$functionName] Successfully loaded configuration file"
                
                # Step 3: Process auth configuration
                Write-Log -logFile $logFile -module $functionName -Message "Processing auth configuration" -logLevel "Information"
                Write-Verbose "[$functionName] Processing auth configuration"
                $authResult = Initialize-AuthConfiguration -AuthConfiguration $initFileContent.auth -BoundParameters $BoundParameters
                $result.Auth = $authResult.Auth
                Write-Log -logFile $logFile -module $functionName -Message "Auth configuration processed (Changed: $($authResult.Changed))" -logLevel "Verbose"
                Write-Verbose "[$functionName] Auth configuration processed (Changed: $($authResult.Changed))"
                
                # Step 4: Process global settings
                Write-Log -logFile $logFile -module $functionName -Message "Processing global settings" -logLevel "Information"
                Write-Verbose "[$functionName] Processing global settings"
                $globalResult = Initialize-GlobalSettings -GlobalConfigData $initFileContent.globalSettings -BoundParameters $BoundParameters
                $result.GlobalSettings = $globalResult.GlobalSettings
                Write-Log -logFile $logFile -module $functionName -Message "Global settings processed (Changed: $($globalResult.Changed))" -logLevel "Verbose"
                Write-Verbose "[$functionName] Global settings processed (Changed: $($globalResult.Changed))"
                
                # Step 5: Process domain-specific settings
                Write-Log -logFile $logFile -module $functionName -Message "Processing domain-specific settings for: $Domain" -logLevel "Information"
                Write-Verbose "[$functionName] Processing domain-specific settings for: $Domain"
                $configurationPath = Split-Path -Parent $InitFile
                $localResult = Initialize-LocalSettings -InitFileContent $initFileContent -Domain $Domain -BoundParameters $BoundParameters -GlobalSettings $result.GlobalSettings -ConfigurationPath $configurationPath
                $result.LocalSettings = $localResult.LocalSettings
                Write-Log -logFile $logFile -module $functionName -Message "Domain-specific settings processed (Changed: $($localResult.Changed))" -logLevel "Verbose"
                Write-Verbose "[$functionName] Domain-specific settings processed (Changed: $($localResult.Changed))"
                
                # Step 6: Save configuration files if any changes were made (centralized save logic)
                $globalChanged = $globalResult.Changed -eq $true
                $localChanged = $localResult.Changed -eq $true
                $authChanged = $authResult.Changed -eq $true
                if ($globalChanged -or $localChanged -or $authChanged)
                {
                    Write-Verbose "[$functionName] Configuration changes detected - saving files (Global: $globalChanged, Local: $localChanged, Auth: $authChanged)"
                    Write-Log -logFile $logFile -module $functionName -Message "Configuration changes detected - saving files (Global: $globalChanged, Local: $localChanged, Auth: $authChanged)" -logLevel "Information"
                    # Save main settings file if global settings changed
                    if ($globalChanged -or $authChanged)
                    {
                        try
                        {
                            # Update the global settings and auth sections in the main configuration
                            if ($globalChanged)
                            {
                                $initFileContent.globalSettings = $globalResult.GlobalSettings
                            }
                            if ($authChanged)
                            {
                                $initFileContent.auth = $authResult.Auth
                            }

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
                                if ($Error.Count -gt 0 -and $Error[0] -ne $null)
                                {
                                    Write-Warning "[$functionName] Export-PowerShellDataFile error details: $($Error[0].ToString())"
                                    Write-Log -logFile $logFile -module $functionName -Message "Export-PowerShellDataFile error details: $($Error[0].ToString())" -logLevel "Warning"
                                }
                            }
                        }
                        catch
                        {
                            Write-Warning "[$functionName] Error saving merged global settings: $($_.Exception.Message)"
                            Write-Log -logFile $logFile -module $functionName -Message "Error saving merged global settings: $($_.Exception.Message)" -logLevel "Warning"
                        }
                    }
                    
                    # Save domain configuration file if local settings changed
                    if ($localChanged)
                    {
                        try
                        {
                            Write-Verbose "[$functionName] Saving merged domain configuration for: $Domain"
                            Write-Log -logFile $logFile -module $functionName -Message "Saving merged domain configuration for: $Domain" -logLevel "Information"
                            
                            $saveResult = Save-DomainConfiguration -DomainName $localResult.Domain -DomainConfiguration $localResult.LocalSettings -ConfigurationPath $localResult.ConfigurationPath -CreateBackup $true
                            if ($saveResult)
                            {
                                Write-Verbose "[$functionName] Successfully saved merged domain configuration for: $Domain"
                                Write-Log -logFile $logFile -module $functionName -Message "Successfully saved merged domain configuration for: $Domain" -logLevel "Information"
                            }
                            else
                            {
                                $errorDetail = ""
                                if ($Error.Count -gt 0 -and $Error[0] -ne $null)
                                {
                                    $errorDetail = $Error[0].Exception.Message
                                }
                                $errorMsg = "Failed to save merged domain configuration for: $Domain"
                                if ($errorDetail)
                                {
                                    $errorMsg += " - Error: $errorDetail"
                                }
                                Write-Warning "[$functionName] $errorMsg"
                                Write-Log -logFile $logFile -module $functionName -Message $errorMsg -logLevel "Warning"
                            }
                        }
                        catch
                        {
                            Write-Warning "[$functionName] Error saving merged domain configuration: $($_.Exception.Message)"
                            Write-Log -logFile $logFile -module $functionName -Message "Error saving merged domain configuration: $($_.Exception.Message)" -logLevel "Warning"
                        }
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] No configuration changes detected - skipping file save"
                    Write-Log -logFile $logFile -module $functionName -Message "No configuration changes detected - skipping file save" -logLevel "Verbose"
                }
                
                # Step 7: Process and merge scopes
                Write-Log -logFile $logFile -module $functionName -Message "Processing and merging required scopes" -logLevel "Information"
                Write-Verbose "[$functionName] Processing and merging required scopes"
                $scopeResult = Initialize-RequiredScopes -InitFileContent $initFileContent -Domain $Domain
                $result.RequiredScopes = $scopeResult.RequiredScopes
                Write-Log -logFile $logFile -module $functionName -Message "Merged $($result.RequiredScopes.Count) unique scopes" -logLevel "Verbose"
                Write-Verbose "[$functionName] Merged $($result.RequiredScopes.Count) unique scopes"
                
                # Step 8: Process strings configuration
                Write-Log -logFile $logFile -module $functionName -Message "Processing strings configuration" -logLevel "Information"
                Write-Verbose "[$functionName] Processing strings configuration"
                $stringsResult = Initialize-StringsConfiguration -StringsFilePath $StringsFile
                $result.Strings = $stringsResult.Strings
                Write-Log -logFile $logFile -module $functionName -Message "Strings configuration processed (Changed: $($stringsResult.Changed))" -logLevel "Verbose"
                Write-Verbose "[$functionName] Strings configuration processed (Changed: $($stringsResult.Changed))"
                
                # Step 9: Process menu configuration
                Write-Log -logFile $logFile -module $functionName -Message "Processing menu configuration" -logLevel "Information"
                Write-Verbose "[$functionName] Processing menu configuration"
                $menuResult = Initialize-MenuConfiguration -MenuFilePath $menuFile
                $result.Menu = $menuResult.Menu
                Write-Log -logFile $logFile -module $functionName -Message "Menu configuration processed (Changed: $($menuResult.Changed))" -logLevel "Verbose"
                Write-Verbose "[$functionName] Menu configuration processed (Changed: $($menuResult.Changed))"
                
                # Step 10: Save strings and menu files if changes were made
                if ($stringsResult.Changed)
                {
                    try
                    {
                        Write-Verbose "[$functionName] Saving merged strings configuration"
                        Write-Log -logFile $logFile -module $functionName -Message "Saving merged strings configuration" -logLevel "Information"
                        
                        # Create backup before saving
                        $backupFile = "$StringsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                        Copy-Item -Path $StringsFile -Destination $backupFile -Force
                        Write-Verbose "[$functionName] Created backup: $backupFile"
                        Write-Log -logFile $logFile -module $functionName -Message "Created backup: $backupFile" -logLevel "Verbose"
                        
                        # Save the updated strings configuration
                        $exportResult = Export-PowerShellDataFile -InputObject $stringsResult.Strings -Path $StringsFile -Force -Validate
                        if ($exportResult)
                        {
                            Write-Verbose "[$functionName] Successfully saved merged strings to: $StringsFile"
                            Write-Log -logFile $logFile -module $functionName -Message "Successfully saved merged strings to: $StringsFile" -logLevel "Information"
                        }
                        else
                        {
                            Write-Warning "[$functionName] Failed to save merged strings"
                            Write-Log -logFile $logFile -module $functionName -Message "Failed to save merged strings" -logLevel "Warning"
                        }
                    }
                    catch
                    {
                        Write-Warning "[$functionName] Error saving merged strings: $($_.Exception.Message)"
                        Write-Log -logFile $logFile -module $functionName -Message "Error saving merged strings: $($_.Exception.Message)" -logLevel "Warning"
                    }
                }
                
                if ($menuResult.Changed)
                {
                    try
                    {
                        Write-Verbose "[$functionName] Saving merged menu configuration"
                        Write-Log -logFile $logFile -module $functionName -Message "Saving merged menu configuration" -logLevel "Information"
                        
                        # Create backup before saving
                        $backupFile = "$menuFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                        Copy-Item -Path $menuFile -Destination $backupFile -Force
                        Write-Verbose "[$functionName] Created backup: $backupFile"
                        Write-Log -logFile $logFile -module $functionName -Message "Created backup: $backupFile" -logLevel "Verbose"
                        
                        # Save the updated menu configuration
                        $exportResult = Export-PowerShellDataFile -InputObject $menuResult.Menu -Path $menuFile -Force -Validate
                        if ($exportResult)
                        {
                            Write-Verbose "[$functionName] Successfully saved merged menu to: $menuFile"
                            Write-Log -logFile $logFile -module $functionName -Message "Successfully saved merged menu to: $menuFile" -logLevel "Information"
                        }
                        else
                        {
                            Write-Warning "[$functionName] Failed to save merged menu"
                            Write-Log -logFile $logFile -module $functionName -Message "Failed to save merged menu" -logLevel "Warning"
                        }
                    }
                    catch
                    {
                        Write-Warning "[$functionName] Error saving merged menu: $($_.Exception.Message)"
                        Write-Log -logFile $logFile -module $functionName -Message "Error saving merged menu: $($_.Exception.Message)" -logLevel "Warning"
                    }
                }
            }
            catch
            {
                $result.ErrorMessage = "Error loading configuration from $InitFile`: $($_.Exception.Message)"
                Write-Log -logFile $logFile -module $functionName -Message $result.ErrorMessage -logLevel "Error"
                Write-Verbose "[$functionName] $($result.ErrorMessage)"
                return $result
            }
        }
        else
        {
            Write-Log -logFile $logFile -module $functionName -Message "Settings file not found, using default configuration" -logLevel "Warning"
            Write-Verbose "[$functionName] Settings file not found, using default configuration"
            
            # Use default auth configuration when no settings file exists
            $result.Auth = @{
                delegated = $true
                authType  = "PublicAuthFlow"
                scope     = @("offline_access", "openid", "Device.ReadWrite.All")
            }
            Write-Log -logFile $logFile -module $functionName -Message "Using default auth configuration" -logLevel "Verbose"
            Write-Verbose "[$functionName] Using default auth configuration"
            
            # Initialize empty collections for other settings
            $result.GlobalSettings = @{}
            $result.LocalSettings = @{}
            $result.RequiredScopes = @()
            Write-Log -logFile $logFile -module $functionName -Message "Initialized empty settings collections" -logLevel "Verbose"
            Write-Verbose "[$functionName] Initialized empty settings collections"
            
            # Process strings configuration even without settings file
            Write-Log -logFile $logFile -module $functionName -Message "Processing strings configuration" -logLevel "Information"
            Write-Verbose "[$functionName] Processing strings configuration"
            $stringsResult = Initialize-StringsConfiguration -StringsFilePath $StringsFile
            $result.Strings = $stringsResult.Strings
            Write-Log -logFile $logFile -module $functionName -Message "Strings configuration processed (Changed: $($stringsResult.Changed))" -logLevel "Verbose"
            Write-Verbose "[$functionName] Strings configuration processed (Changed: $($stringsResult.Changed))"
            
            # Process menu configuration even without settings file
            Write-Log -logFile $logFile -module $functionName -Message "Processing menu configuration" -logLevel "Information"
            Write-Verbose "[$functionName] Processing menu configuration"
            $menuResult = Initialize-MenuConfiguration -MenuFilePath $menuFile
            $result.Menu = $menuResult.Menu
            Write-Log -logFile $logFile -module $functionName -Message "Menu configuration processed (Changed: $($menuResult.Changed))" -logLevel "Verbose"
            Write-Verbose "[$functionName] Menu configuration processed (Changed: $($menuResult.Changed))"
        }
        
        $result.Success = $true
        Write-Log -logFile $logFile -module $functionName -Message "Configuration initialization completed successfully" -logLevel "Information"
        Write-Verbose "[$functionName] Configuration initialization completed successfully"
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Unexpected error during configuration initialization: $($_.Exception.Message)"
        Write-Log -logFile $logFile -module $functionName -Message $result.ErrorMessage -logLevel "Error"
        Write-Verbose "[$functionName] $($result.ErrorMessage)"
        return $result
    }
}
