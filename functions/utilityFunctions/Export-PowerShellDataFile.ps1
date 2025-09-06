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
        
        # Convert to hashtable if PSCustomObject
        if ($configData -is [PSCustomObject])
        {
            Write-Verbose "[$functionName] Converting PSCustomObject to hashtable"
            $configData = ConvertTo-HashtableFromPSCustomObject -InputObject $configData
        }
        elseif ($configData -isnot [hashtable])
        {
            throw "InputObject must be a hashtable or PSCustomObject, got: $($configData.GetType().Name)"
        }
        else
        {
            Write-Verbose "[$functionName] InputObject is already a hashtable"
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
                Remove-Item -Path $tempFile -Force
                Write-Verbose "[$functionName] PSD1 validation successful"
            }
            catch
            {
                if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force }
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

function ConvertTo-HashtableFromPSCustomObject()
{
    <#
    .SYNOPSIS
        Recursively converts PSCustomObject to hashtable for PowerShell 5.1 compatibility.
    #>
    [CmdletBinding()]
    param([object]$InputObject)
    $functionName = $MyInvocation.MyCommand.Name
    if ($InputObject -is [PSCustomObject])
    {
        Write-Verbose "[$functionName] Converting PSCustomObject to hashtable"
        $hashtable = @{}
        foreach ($property in $InputObject.PSObject.Properties)
        {
            # Skip system properties that aren't data
            if ($property.Name -in @('IsReadOnly', 'IsFixedSize', 'IsSynchronized', 'Keys', 'Values', 'SyncRoot', 'Count'))
            {
                Write-Verbose "[$functionName] Skipping system property: $($property.Name)"
                continue
            }
            
            Write-Verbose "[$functionName] Processing property: $($property.Name)"
            if ($property.Value -is [PSCustomObject])
            {
                Write-Verbose "[$functionName] Recursively converting property: $($property.Name)"
                $hashtable[$property.Name] = ConvertTo-HashtableFromPSCustomObject -InputObject $property.Value
            }
            elseif ($property.Value -is [System.Array])
            {
                Write-Verbose "[$functionName] Processing array property: $($property.Name)"    
                $hashtable[$property.Name] = @()
                foreach ($item in $property.Value)
                {
                    Write-Verbose "[$functionName] Processing array item $item"
                    if ($item -is [PSCustomObject])
                    {
                        Write-Verbose "[$functionName] Recursively converting array item $item"
                        $hashtable[$property.Name] += ConvertTo-HashtableFromPSCustomObject -InputObject $item
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Adding array item $item"
                        $hashtable[$property.Name] += $item
                    }
                }
            }
            else
            {
                Write-Verbose "[$functionName] Adding property: $($property.Name)"
                $hashtable[$property.Name] = $property.Value
            }
        }
        return $hashtable
    }
    elseif ($InputObject -is [hashtable])
    {
        Write-Verbose "[$functionName] Input is already a hashtable, returning as-is"
        return $InputObject
    }
    elseif ($InputObject -is [System.Array])
    {
        Write-Verbose "[$functionName] Processing array input"
        $array = @()
        foreach ($item in $InputObject)
        {
            Write-Verbose "[$functionName] Processing array item $item"
            if ($item -is [PSCustomObject])
            {
                Write-Verbose "[$functionName] Recursively converting array item $item"
                $array += ConvertTo-HashtableFromPSCustomObject -InputObject $item
            }
            else
            {
                Write-Verbose "[$functionName] Adding array item $item"
                $array += $item
            }
        }
        return $array
    }
    else
    {
        Write-Verbose "[$functionName] Input is neither PSCustomObject nor array, returning as-is"
        return $InputObject
    }
}

function ConvertTo-Psd1String()
{
    <#
    .SYNOPSIS
        Converts a hashtable to properly formatted PSD1 string content with enhanced error handling.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration,
        [int]$IndentLevel = 0
    )
    $functionName = $MyInvocation.MyCommand.Name
    $indent = "    " * $IndentLevel
    $childIndent = "    " * ($IndentLevel + 1)
    $result = "@{`n"
    Write-Verbose "[$functionName] Converting hashtable to PSD1 string at indent level $IndentLevel"
    
    # Handle empty hashtables
    if ($Configuration.Keys.Count -eq 0)
    {
        Write-Verbose "[$functionName] Empty hashtable detected"
        return "@{}"
    }
    
    foreach ($key in $Configuration.Keys)
    {
        $value = $Configuration[$key]
        
        # Skip null keys
        if ($null -eq $key)
        {
            Write-Verbose "[$functionName] Skipping null key"
            continue
        }
        
        # Validate key name for PowerShell compatibility
        $validKey = $key
        if ($key -match '[\s\-\.]' -or $key -match '^[0-9]')
        {
            $validKey = "'$key'"
            Write-Verbose "[$functionName] Key '$key' requires quotes for PowerShell compatibility"
        }
        
        $result += "$childIndent$validKey = "
        Write-Verbose "[$functionName] Processing key: $key with value type: $($value.GetType().Name)"
        
        if ($value -is [hashtable])
        {
            Write-Verbose "[$functionName] Processing nested hashtable"
            $result += (ConvertTo-Psd1String -Configuration $value -IndentLevel ($IndentLevel + 1))
        }
        elseif ($value -is [System.Array])
        {
            Write-Verbose "[$functionName] Processing array with $($value.Count) items"
            if ($value.Count -eq 0)
            {
                $result += "@()"
            }
            else
            {
                $result += "@(`n"
                foreach ($item in $value)
                {
                    $result += "$childIndent    "
                    
                    if ($item -is [hashtable])
                    {
                        Write-Verbose "[$functionName] Processing nested hashtable in array"
                        $result += (ConvertTo-Psd1String -Configuration $item -IndentLevel ($IndentLevel + 2))
                    }
                    elseif ($item -is [string])
                    {
                        Write-Verbose "[$functionName] Processing string in array: $item"
                        # Enhanced string escaping for PowerShell compatibility
                        $escapedItem = $item -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
                        $result += "'$escapedItem'"
                    }
                    elseif ($item -is [bool])
                    {
                        $result += if ($item) { '$true' } else { '$false' }
                    }
                    elseif ($null -eq $item)
                    {
                        $result += '$null'
                    }
                    elseif ($item -is [int] -or $item -is [long] -or $item -is [double] -or $item -is [float])
                    {
                        $result += $item.ToString()
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Processing other type in array: $($item.GetType().Name)"
                        $result += "'$($item.ToString())'"
                    }
                    
                    $result += ",`n"
                }
                $result = $result.TrimEnd(",`n") + "`n$childIndent)"
            }
        }
        elseif ($value -is [string])
        {
            Write-Verbose "[$functionName] Processing string: $value"
            # Enhanced string escaping for PowerShell compatibility
            $escapedValue = $value -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
            $result += "'$escapedValue'"
        }
        elseif ($value -is [bool])
        {
            Write-Verbose "[$functionName] Processing boolean: $value"  
            $result += if ($value) { '$true' } else { '$false' }
        }
        elseif ($null -eq $value)
        {
            Write-Verbose "[$functionName] Processing null value"
            $result += '$null'
        }
        elseif ($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [float])
        {
            Write-Verbose "[$functionName] Processing numeric value: $value"
            $result += $value.ToString()
        }
        elseif ($value -is [datetime])
        {
            Write-Verbose "[$functionName] Processing datetime value: $value"
            $result += "'$($value.ToString('o'))'"  # ISO 8601 format
        }
        else
        {
            Write-Verbose "[$functionName] Processing other type: $($value.GetType().Name)"
            # Convert to string and escape
            $stringValue = $value.ToString() -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
            $result += "'$stringValue'"
        }
        
        $result += "`n"
    }
    $result += "$indent}"
    Write-Verbose "[$functionName] Finished converting hashtable to PSD1 string at indent level $IndentLevel"
    return $result
}