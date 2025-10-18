function Export-PowerShellDataFile ()
{
    <#
.SYNOPSIS
    Exports PowerShell data structures to PowerShell Data File (.psd1) format with comprehensive validation.

.DESCRIPTION
    This function provides robust export of hashtables and objects to .psd1 format with proper
    escaping, validation, and error handling. It maintains data integrity while optimizing
    for PowerShell native loading performance and handles edge cases properly.

.PARAMETER JsonFilePath
    The full path to the source JSON configuration file (for legacy conversion).

.PARAMETER Path
    The full path where the .psd1 file should be created.

.PARAMETER InputObject
    Hashtable or PSCustomObject to convert directly without reading from file.

.PARAMETER Validate
    Validates the resulting .psd1 file can be loaded successfully before saving.

.PARAMETER CreateBackup
    Creates a backup of an existing file before overwriting.

.PARAMETER Force
    Overwrites existing files without prompting.

.OUTPUTS
    System.String
    Returns the path to the created .psd1 file on success.

.EXAMPLE
    Export-PowerShellDataFile -InputObject $config -Path "config.psd1"

.EXAMPLE
    $settings = @{ key1 = "value1"; key2 = @("item1", "item2") }
    Export-PowerShellDataFile -InputObject $settings -Path "settings.psd1" -Validate

.NOTES
    - Handles complex nested structures and arrays with proper formatting
    - Preserves data types where possible
    - PowerShell 5.1 compatible
    - Includes comprehensive error handling and validation
    - Enhanced string escaping for special characters and newlines
    - Supports numeric types, dates, and edge cases
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'FromFile')]
        [string]$JsonFilePath,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $false, ParameterSetName = 'FromObject', ValueFromPipeline = $true)]
        [object]$InputObject,
        [switch]$Validate,
        [switch]$CreateBackup,
        [switch]$Force
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting data export to PSD1 format"
    
    try
    {
        # Validate parameters
        if (-not $Path)
        {
            throw "Path parameter is required"
        }
        
        # Ensure directory exists
        $directory = Split-Path -Path $Path -Parent
        if ($directory -and -not (Test-Path $directory))
        {
            Write-Verbose "[$functionName] Creating directory: $directory"
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        
        # Check if file exists and handle accordingly
        if ((Test-Path $Path) -and -not $Force)
        {
            if ($CreateBackup)
            {
                $backupPath = $Path + ".backup"
                Write-Verbose "[$functionName] Creating backup: $backupPath"
                Copy-Item -Path $Path -Destination $backupPath -Force
            }
            else
            {
                throw "File already exists: $Path. Use -Force to overwrite or -CreateBackup to backup first."
            }
        }
        
        # Load configuration data
        if ($PSCmdlet.ParameterSetName -eq 'FromFile')
        {
            if (-not (Test-Path $JsonFilePath))
            {
                throw "JSON file not found: $JsonFilePath"
            }
            
            Write-Verbose "[$functionName] Loading JSON from file: $JsonFilePath"
            $jsonContent = Get-Content -Path $JsonFilePath -Raw -ErrorAction Stop
            $configData = $jsonContent | ConvertFrom-Json -ErrorAction Stop
            
            # Create backup if requested
            if ($CreateBackup)
            {
                $backupPath = $JsonFilePath + ".backup"
                Copy-Item -Path $JsonFilePath -Destination $backupPath -Force
                Write-Verbose "[$functionName] Created JSON backup: $backupPath"
            }
        }
        else
        {
            if ($null -eq $InputObject)
            {
                throw "InputObject cannot be null"
            }
            $configData = $InputObject
        }
        
        # Debug the input type
        Write-Verbose "[$functionName] InputObject type: $($configData.GetType().FullName)"
        Write-Verbose "[$functionName] InputObject is PSCustomObject: $($configData -is [PSCustomObject])"
        Write-Verbose "[$functionName] InputObject is Hashtable: $($configData -is [hashtable])"
        Write-Verbose "[$functionName] InputObject is OrderedDictionary: $($configData -is [System.Collections.Specialized.OrderedDictionary])"
        
        # Convert to hashtable if PSCustomObject (check hashtable and OrderedDictionary FIRST since PowerShell considers hashtables as both)
        if ($configData -is [hashtable] -or $configData -is [System.Collections.Specialized.OrderedDictionary])
        {
            Write-Verbose "[$functionName] InputObject is a $($configData.GetType().Name)"
            # No conversion needed
        }
        elseif ($configData -is [PSCustomObject])
        {
            Write-Verbose "[$functionName] Converting PSCustomObject to hashtable"
            $configData = ConvertTo-HashtableFromPSCustomObject -InputObject $configData
        }
        else
        {
            throw "InputObject must be a hashtable, ordered dictionary, or PSCustomObject, got: $($configData.GetType().Name)"
        }
        
        # Convert to PSD1 format
        Write-Verbose "[$functionName] Converting to PSD1 format"
        $psd1Content = ConvertTo-Psd1String -Configuration $configData
        
        # Validate if requested
        if ($Validate)
        {
            Write-Verbose "[$functionName] Validating PSD1 content"
            try
            {
                # Test the content by trying to load it
                $tempFile = [System.IO.Path]::GetTempFileName()
                $psd1Content | Set-Content -Path $tempFile -Encoding UTF8
                $testLoad = Import-PowerShellDataFile -Path $tempFile
                Remove-Item -Path $tempFile -Force | Out-Null
                Write-Verbose "[$functionName] PSD1 validation successful"
            }
            catch
            {
                if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force | Out-Null }
                throw "PSD1 validation failed: $($_.Exception.Message)"
            }
        }
        
        # Save the PSD1 file
        Write-Verbose "[$functionName] Saving PSD1 file: $Path"
        $psd1Content | Set-Content -Path $Path -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "[$functionName] Export completed successfully to $Path"
        return $Path
    }
    catch
    {
        Write-Error "[$functionName] Export failed: $($_.Exception.Message)"
        throw
    }
}
