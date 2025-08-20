function Test-SettingsJsonExists()
{
    <#
    .SYNOPSIS
        Ensures that settings.json exists with default values.
    
    .DESCRIPTION
        Checks if settings.json exists, and if not, creates it with comprehensive default values
        from the centralized Get-ApplicationDefaults function. Domain configurations are now
        handled by separate domain files and are not included in the main settings.json.
    
    .PARAMETER SettingsFile
        Path to the settings.json file.
    
    .PARAMETER Silent
        If specified, skips confirmation prompts.
    
    .PARAMETER AuthType
        The authentication type to use for default auth configuration.
    
    .PARAMETER IsDelegated
        Whether to use delegated permissions by default.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the file exists or was created successfully, $false otherwise.
    
    .NOTES
        - Uses centralized Get-ApplicationDefaults function as single source of truth
        - Domain configurations are now handled by separate domain files
        - Eliminates duplicate default value definitions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsFile,
        [switch]$Silent,
        [string]$AuthType = "Delegated",
        [bool]$IsDelegated = $true
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Ensuring settings.json exists: $SettingsFile"
    Write-SafeLog "Ensuring settings.json exists: $SettingsFile" "Information"
    try
    {
        # Get comprehensive default settings structure from centralized source of truth
        # This eliminates duplicate default value definitions
        Write-Verbose "[$functionName] Getting default settings from centralized Get-ApplicationDefaults function"
        Write-SafeLog "Getting default settings from centralized source" "Information"
        
        # Use centralized defaults - single source of truth
        # Get version from global variable if available, otherwise use default
        $versionString = if ($global:version -and $global:version.version)
        {
            $global:version.version.toString()
        }
        elseif ($version -and $version.version)
        {
            $version.version.toString()
        }
        else
        {
            "1.3.0.0"  # Default version
        }
        Write-Verbose "[$functionName] Using version: $versionString"
        Write-SafeLog "Using version: $versionString" "Information"
        
        $defaultSettings = Get-ApplicationDefaults -DefaultType "Settings" -Version $versionString
        if (-not $defaultSettings)
        {
            Write-Verbose "[$functionName] Failed to get defaults from centralized function, creating fallback"
            Write-SafeLog "Failed to get defaults from centralized function, using fallback" "Warning"
            
            # Fallback minimal structure in case centralized function fails
            $defaultSettings = @{
                description    = "This is the configuration file for the Intune Helpdesk script. It contains the settings for the script to run correctly."
                version        = $versionString
                auth           = Get-ApplicationDefaults -DefaultType "Auth"
                globalSettings = Get-ApplicationDefaults -DefaultType "Global"
            }
        }
        
        Write-Verbose "[$functionName] Using centralized default settings structure"
        Write-SafeLog "Using centralized default settings structure" "Information"
        
        # Note: Domain configurations are now handled by separate domain files
        # The domains section is no longer included in the main settings.json default structure
        # This eliminates the need for the $DomainName parameter in default settings creation
        if (Test-Path -Path $SettingsFile)
        {
            Write-Verbose "[$functionName] Settings file exists, checking for missing default values: $SettingsFile"
            Write-SafeLog "Settings file exists, checking for updates: $SettingsFile" "Information"
            try
            {
                # Load existing settings
                $existingSettings = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
                # Convert JSON object to hashtable for merging
                $existingHashtable = @{}
                $existingSettings.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [PSCustomObject])
                    {
                        $existingHashtable[$_.Name] = ConvertFrom-JsonToHashtable -JsonObject $_.Value
                    }
                    else
                    {
                        $existingHashtable[$_.Name] = $_.Value
                    }
                }
                # Merge defaults into existing configuration
                $mergedSettings = Merge-ConfigurationDefaults -ExistingConfig $existingHashtable -DefaultConfig $defaultSettings
                if ($null -ne $mergedSettings)
                {
                    Write-Verbose "[$functionName] Merging default settings into existing configuration"
                    Write-SafeLog "Merging default settings into existing configuration" "Information"
                    $mergedJson = ConvertTo-OrderedJson -InputObject $mergedSettings -Depth $maxJSONDepth
                    Set-Content -Path $SettingsFile -Value $mergedJson -Encoding UTF8 -Force
                    Write-Verbose "[$functionName] Updated settings.json with missing default values"
                    Write-SafeLog "Updated settings.json with missing default values" "Information"
                    if (-not $Silent)
                    {
                        Write-Host "Settings file updated with new default values." -ForegroundColor Green
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Settings file is up-to-date"
                }
                return $true
            }
            catch
            {
                Write-Verbose "[$functionName] Error processing existing settings file: $($_.Exception.Message)"
                Write-SafeLog "Error processing existing settings file: $($_.Exception.Message)" "Warning"
                # Continue with creating new file as fallback
            }
        }
        if (-not $Silent)
        {
            Write-Host "`n── Settings Configuration ──" -ForegroundColor Cyan
            Write-Host "Creating default settings.json file..." -ForegroundColor White
        }
        
        # File doesn't exist, create it with default settings
        if (-not $Silent)
        {
            Write-Host "Creating default settings.json file..." -ForegroundColor White
        }
        
        # Convert to JSON with proper ordering and write to file
        $settingsJson = ConvertTo-OrderedJson -InputObject $defaultSettings -Depth $maxJSONDepth
        Set-Content -Path $SettingsFile -Value $settingsJson -Encoding UTF8 -Force
        Write-Verbose "[$functionName] Created comprehensive settings.json with requiredScopes"
        
        $success = $true
        
        if ($success)
        {
            Write-Host "Settings file created successfully." -ForegroundColor Green
            Write-SafeLog "Settings file created successfully: $SettingsFile" "Information"
            return $true
        }
        else
        {
            Write-Host "Failed to create settings file." -ForegroundColor Red
            Write-SafeLog "Failed to create settings file: $SettingsFile" "Error"
            return $false
        }
        
    }
    catch
    {
        Write-SafeLog "Error ensuring settings.json exists: $($_.Exception.Message)" "Error"
        Write-Host "Error creating settings file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $false
    }
}

