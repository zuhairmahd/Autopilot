function Convert-Psd1ToJson() {
<#
.SYNOPSIS
    Converts PowerShell Data File (.psd1) format to JSON configuration files.

.DESCRIPTION
    This function provides conversion from .psd1 format back to JSON format with proper
    formatting and validation. Useful for backward compatibility and migration scenarios.

.PARAMETER Psd1FilePath
    The full path to the source .psd1 configuration file.

.PARAMETER JsonFilePath
    The full path where the JSON file should be created. If not specified, uses the same
    path as the .psd1 file with .json extension.

.PARAMETER InputObject
    Hashtable to convert directly without reading from file.

.PARAMETER Validate
    Validates the resulting JSON file can be loaded successfully before saving.

.PARAMETER CreateBackup
    Creates a backup of the original .psd1 file before conversion.

.PARAMETER Depth
    Depth of object serialization for JSON conversion (default: 10).

.OUTPUTS
    System.String
    Returns the path to the created JSON file on success.

.EXAMPLE
    Convert-Psd1ToJson -Psd1FilePath "settings.psd1" -JsonFilePath "settings.json"

.EXAMPLE
    $config = @{ key1 = "value1"; key2 = @("item1", "item2") }
    Convert-Psd1ToJson -InputObject $config -JsonFilePath "config.json"

.NOTES
    - Handles complex nested structures and arrays
    - Preserves data types where possible in JSON
    - PowerShell 5.1 compatible
    - Includes comprehensive error handling and validation
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'FromFile')]
        [string]$Psd1FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$JsonFilePath,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'FromObject')]
        [object]$InputObject,
        
        [switch]$Validate,
        [switch]$CreateBackup,
        [int]$Depth = 10
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting PSD1 to JSON conversion"
    
    try {
        # Load configuration data
        if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
            if (-not (Test-Path $Psd1FilePath)) {
                throw "PSD1 file not found: $Psd1FilePath"
            }
            
            Write-Verbose "[$functionName] Loading PSD1 from file: $Psd1FilePath"
            $configData = Import-PowerShellDataFile -Path $Psd1FilePath -ErrorAction Stop
            
            # Set default output path if not specified
            if (-not $JsonFilePath) {
                $JsonFilePath = $Psd1FilePath -replace '\.psd1$', '.json'
            }
            
            # Create backup if requested
            if ($CreateBackup) {
                $backupPath = $Psd1FilePath + ".backup"
                Copy-Item -Path $Psd1FilePath -Destination $backupPath -Force
                Write-Verbose "[$functionName] Created backup: $backupPath"
            }
        } else {
            $configData = $InputObject
            if (-not $JsonFilePath) {
                throw "JsonFilePath is required when using InputObject parameter"
            }
        }
        
        # Convert to JSON format
        Write-Verbose "[$functionName] Converting to JSON format"
        $jsonContent = $configData | ConvertTo-Json -Depth $Depth
        
        # Validate if requested
        if ($Validate) {
            Write-Verbose "[$functionName] Validating JSON content"
            try {
                # Test the content by trying to load it
                $testLoad = $jsonContent | ConvertFrom-Json
                Write-Verbose "[$functionName] JSON validation successful"
            }
            catch {
                throw "JSON validation failed: $($_.Exception.Message)"
            }
        }
        
        # Save the JSON file
        Write-Verbose "[$functionName] Saving JSON file: $JsonFilePath"
        $jsonContent | Set-Content -Path $JsonFilePath -Encoding UTF8 -ErrorAction Stop
        
        Write-Verbose "[$functionName] Conversion completed successfully"
        return $JsonFilePath
    }
    catch {
        Write-Error "[$functionName] Conversion failed: $($_.Exception.Message)"
        throw
    }
}