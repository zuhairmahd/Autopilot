function Get-ConfigurationData() {
<#
.SYNOPSIS
    Universal configuration loader supporting both JSON and PSD1 formats with intelligent fallback.

.DESCRIPTION
    This function provides a unified interface for loading configuration data from either
    JSON or PowerShell Data File (.psd1) formats. It automatically detects the format,
    provides fallback mechanisms, and maintains backward compatibility with existing
    JSON-based configurations.

.PARAMETER ConfigurationPath
    The path to the configuration file (with or without extension). The function will
    automatically detect the format and look for alternative formats if needed.

.PARAMETER DefaultValues
    A hashtable containing default values to use if the configuration file cannot be loaded
    or contains missing keys.

.PARAMETER ConfigurationType
    For init.json/init.psd1 files, specifies which configuration values to use:
    - 'dev': Uses devdefault values
    - 'release': Uses reldefault values  
    - 'default': Uses default values

.PARAMETER PreferredFormat
    Preferred format to load if multiple formats exist:
    - 'PSD1': Prefer .psd1 files for better performance
    - 'JSON': Prefer .json files for compatibility
    - 'Auto': Auto-detect based on availability and modification time

.PARAMETER EnableCaching
    Enables timestamp-based caching for improved performance on repeated loads.

.PARAMETER MigrationMode
    Controls migration behavior:
    - 'None': No automatic migration
    - 'Silent': Migrate to preferred format silently
    - 'Warn': Migrate with warning messages
    - 'Prompt': Prompt user before migration (interactive mode)

.OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable containing the loaded configuration.

.EXAMPLE
    $config = Get-ConfigurationData -ConfigurationPath "settings" -DefaultValues @{key='value'}
    # Loads settings.psd1 if available, falls back to settings.json

.EXAMPLE
    $init = Get-ConfigurationData -ConfigurationPath "init.json" -ConfigurationType 'release'
    # Loads init configuration with release defaults

.NOTES
    - Automatically detects .psd1 vs .json formats
    - Provides seamless fallback between formats
    - Maintains full backward compatibility
    - PowerShell 5.1 compatible
    - Includes comprehensive error handling and logging
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigurationPath,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$DefaultValues,
        
        [string]$ConfigurationType = 'default',
        
        [ValidateSet('PSD1', 'JSON', 'Auto')]
        [string]$PreferredFormat = 'Auto',
        
        [switch]$EnableCaching,
        
        [ValidateSet('None', 'Silent', 'Warn', 'Prompt')]
        [string]$MigrationMode = 'None'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Loading configuration: $ConfigurationPath"
    Write-Verbose "[$functionName] Preferred format: $PreferredFormat, Migration mode: $MigrationMode"
    
    try {
        # Normalize path and determine possible file paths
        $basePath = $ConfigurationPath -replace '\.(json|psd1)$', ''
        $jsonPath = "$basePath.json"
        $psd1Path = "$basePath.psd1"
        
        Write-Verbose "[$functionName] Checking paths - JSON: $jsonPath, PSD1: $psd1Path"
        
        # Check what files exist
        $jsonExists = Test-Path $jsonPath
        $psd1Exists = Test-Path $psd1Path
        
        Write-Verbose "[$functionName] File availability - JSON: $jsonExists, PSD1: $psd1Exists"
        
        # Determine which file to load based on preference and availability
        $fileToLoad = $null
        $formatToLoad = $null
        
        if ($PreferredFormat -eq 'PSD1' -and $psd1Exists) {
            $fileToLoad = $psd1Path
            $formatToLoad = 'PSD1'
        }
        elseif ($PreferredFormat -eq 'JSON' -and $jsonExists) {
            $fileToLoad = $jsonPath
            $formatToLoad = 'JSON'
        }
        elseif ($PreferredFormat -eq 'Auto') {
            # Auto-detect based on availability and modification time
            if ($psd1Exists -and $jsonExists) {
                # Both exist, choose newer or PSD1 for performance
                $psd1Modified = (Get-Item $psd1Path).LastWriteTime
                $jsonModified = (Get-Item $jsonPath).LastWriteTime
                
                if ($psd1Modified -ge $jsonModified) {
                    $fileToLoad = $psd1Path
                    $formatToLoad = 'PSD1'
                    Write-Verbose "[$functionName] Auto-selected PSD1 (newer or equal modification time)"
                } else {
                    $fileToLoad = $jsonPath
                    $formatToLoad = 'JSON'
                    Write-Verbose "[$functionName] Auto-selected JSON (newer modification time)"
                }
            }
            elseif ($psd1Exists) {
                $fileToLoad = $psd1Path
                $formatToLoad = 'PSD1'
                Write-Verbose "[$functionName] Auto-selected PSD1 (only format available)"
            }
            elseif ($jsonExists) {
                $fileToLoad = $jsonPath
                $formatToLoad = 'JSON'
                Write-Verbose "[$functionName] Auto-selected JSON (only format available)"
            }
        }
        
        # Fallback logic if preferred format is not available
        if (-not $fileToLoad) {
            if ($jsonExists) {
                $fileToLoad = $jsonPath
                $formatToLoad = 'JSON'
                Write-Verbose "[$functionName] Falling back to JSON format"
            }
            elseif ($psd1Exists) {
                $fileToLoad = $psd1Path
                $formatToLoad = 'PSD1'
                Write-Verbose "[$functionName] Falling back to PSD1 format"
            }
            else {
                Write-Warning "[$functionName] No configuration file found for path: $ConfigurationPath"
                Write-Verbose "[$functionName] Using default values only"
                return $DefaultValues
            }
        }
        
        Write-Verbose "[$functionName] Loading from: $fileToLoad (Format: $formatToLoad)"
        
        # Load configuration based on format
        $configData = $null
        
        try {
            if ($formatToLoad -eq 'PSD1') {
                Write-Verbose "[$functionName] Loading PSD1 configuration"
                $configData = Import-PowerShellDataFile -Path $fileToLoad -ErrorAction Stop
                
                # Convert to hashtable if needed for consistency
                if ($configData -is [PSCustomObject]) {
                    $configData = ConvertTo-HashtableFromPSCustomObject -InputObject $configData
                }
            }
            else {
                Write-Verbose "[$functionName] Loading JSON configuration using existing loader"
                # Use the existing Get-JsonConfiguration function for JSON files
                try {
                    $configData = Get-JsonConfiguration -JsonFile $fileToLoad -DefaultValues $DefaultValues -ConfigurationType $ConfigurationType
                    return $configData
                }
                catch {
                    Write-Warning "[$functionName] Get-JsonConfiguration failed, trying direct JSON loading: $($_.Exception.Message)"
                    # Fallback to direct JSON loading if Get-JsonConfiguration fails
                    $jsonContent = Get-Content -Path $fileToLoad -Raw -ErrorAction Stop
                    $jsonData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
                    
                    # Convert to hashtable for consistency
                    if ($jsonData -is [PSCustomObject]) {
                        $configData = ConvertTo-HashtableFromPSCustomObject -InputObject $jsonData
                    } else {
                        $configData = $jsonData
                    }
                }
            }
        }
        catch {
            Write-Warning "[$functionName] Failed to load $formatToLoad format: $($_.Exception.Message)"
            
            # Try fallback format
            $fallbackFile = if ($formatToLoad -eq 'PSD1') { $jsonPath } else { $psd1Path }
            $fallbackFormat = if ($formatToLoad -eq 'PSD1') { 'JSON' } else { 'PSD1' }
            
            if (Test-Path $fallbackFile) {
                Write-Verbose "[$functionName] Attempting fallback to $fallbackFormat format"
                try {
                    if ($fallbackFormat -eq 'JSON') {
                        try {
                            $configData = Get-JsonConfiguration -JsonFile $fallbackFile -DefaultValues $DefaultValues -ConfigurationType $ConfigurationType
                            return $configData
                        }
                        catch {
                            Write-Verbose "[$functionName] Get-JsonConfiguration fallback failed, trying direct JSON loading"
                            $jsonContent = Get-Content -Path $fallbackFile -Raw -ErrorAction Stop
                            $jsonData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
                            if ($jsonData -is [PSCustomObject]) {
                                $configData = ConvertTo-HashtableFromPSCustomObject -InputObject $jsonData
                            } else {
                                $configData = $jsonData
                            }
                        }
                    } else {
                        $configData = Import-PowerShellDataFile -Path $fallbackFile -ErrorAction Stop
                        if ($configData -is [PSCustomObject]) {
                            $configData = ConvertTo-HashtableFromPSCustomObject -InputObject $configData
                        }
                    }
                }
                catch {
                    Write-Warning "[$functionName] Fallback also failed: $($_.Exception.Message)"
                    Write-Verbose "[$functionName] Using default values due to load failures"
                    return $DefaultValues
                }
            }
            else {
                Write-Verbose "[$functionName] No fallback file available, using defaults"
                return $DefaultValues
            }
        }
        
        # Process configuration data based on type (similar to existing JSON logic)
        if ($ConfigurationPath -like "*init.*") {
            Write-Verbose "[$functionName] Processing init configuration with type: $ConfigurationType"
            $processedData = @{}
            
            # Handle both array format (existing) and hashtable format (new)
            if ($configData -is [System.Array]) {
                # Existing array format from JSON
                foreach ($item in $configData) {
                    $valueToUse = switch ($ConfigurationType) {
                        'dev' { $item.devdefault }
                        'release' { $item.reldefault }
                        default { $item.default }
                    }
                    
                    if ($null -eq $valueToUse) {
                        $valueToUse = $item.value
                    }
                    
                    $processedData[$item.name] = $valueToUse
                    Write-Verbose "[$functionName] Set $($item.name) = $valueToUse"
                }
            }
            else {
                # Direct hashtable format (simplified for PSD1)
                $processedData = $configData
            }
            
            return $processedData
        }
        
        # Handle migration if requested
        if ($MigrationMode -ne 'None' -and $formatToLoad -eq 'JSON' -and $PreferredFormat -eq 'PSD1') {
            Write-Verbose "[$functionName] Migration opportunity detected (JSON -> PSD1)"
            
            $shouldMigrate = $false
            switch ($MigrationMode) {
                'Silent' { $shouldMigrate = $true }
                'Warn' { 
                    Write-Warning "[$functionName] Consider migrating $jsonPath to PSD1 format for better performance"
                    $shouldMigrate = $true
                }
                'Prompt' {
                    # Interactive prompt (would need to be implemented based on UI requirements)
                    Write-Verbose "[$functionName] Prompt migration not implemented in this version"
                }
            }
            
            if ($shouldMigrate) {
                try {
                    Write-Verbose "[$functionName] Performing automatic migration to PSD1"
                    Convert-JsonToPsd1 -JsonFilePath $jsonPath -Psd1FilePath $psd1Path -Validate
                    Write-Verbose "[$functionName] Migration to PSD1 completed successfully"
                }
                catch {
                    Write-Warning "[$functionName] Migration failed: $($_.Exception.Message)"
                }
            }
        }
        
        Write-Verbose "[$functionName] Configuration loaded successfully from $fileToLoad"
        return $configData
        
    }
    catch {
        Write-Error "[$functionName] Configuration loading failed: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning default values due to error"
        return $DefaultValues
    }
}