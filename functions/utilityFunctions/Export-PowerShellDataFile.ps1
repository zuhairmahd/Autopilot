function Export-PowerShellDataFile ()
{
    <#
.SYNOPSIS
    Converts JSON configuration files to PowerShell Data File (.psd1) format.

.DESCRIPTION
    This function provides robust conversion from JSON format to .psd1 format with proper
    escaping, validation, and error handling. It maintains data integrity while optimizing
    for PowerShell native loading performance.

.PARAMETER JsonFilePath
    The full path to the source JSON configuration file.

.PARAMETER Psd1FilePath
    The full path where the .psd1 file should be created. If not specified, uses the same
    path as the JSON file with .psd1 extension.

.PARAMETER InputObject
    Hashtable or PSCustomObject to convert directly without reading from file.

.PARAMETER Validate
    Validates the resulting .psd1 file can be loaded successfully before saving.

.PARAMETER CreateBackup
    Creates a backup of the original JSON file before conversion.

.OUTPUTS
    System.String
    Returns the path to the created .psd1 file on success.

.EXAMPLE
    Convert-JsonToPsd1 -JsonFilePath "settings.json" -Psd1FilePath "settings.psd1"

.EXAMPLE
    $config = @{ key1 = "value1"; key2 = @("item1", "item2") }
    Convert-JsonToPsd1 -InputObject $config -Psd1FilePath "config.psd1"

.NOTES
    - Handles complex nested structures and arrays
    - Preserves data types where possible
    - PowerShell 5.1 compatible
    - Includes comprehensive error handling and validation
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'FromFile')]
        [string]$JsonFilePath,
        [Parameter(Mandatory = $false)]
        [string]$Path,
        [Parameter(Mandatory = $false, ParameterSetName = 'FromObject', ValueFromPipeline = $true)]
        [object]$InputObject,
        [switch]$Validate,
        [switch]$CreateBackup
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting JSON to PSD1 conversion"
    
    try
    {
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
            
            # Set default output path if not specified
            if (-not $Psd1FilePath)
            {
                $Psd1FilePath = $JsonFilePath -replace '\.json$', '.psd1'
            }
            
            # Create backup if requested
            if ($CreateBackup)
            {
                $backupPath = $JsonFilePath + ".backup"
                Copy-Item -Path $JsonFilePath -Destination $backupPath -Force
                Write-Verbose "[$functionName] Created backup: $backupPath"
            }
        }
        else
        {
            $configData = $InputObject
            if (-not $Psd1FilePath)
            {
                throw "Psd1FilePath is required when using InputObject parameter"
            }
        }
        
        # Convert to hashtable if PSCustomObject
        if ($configData -is [PSCustomObject])
        {
            $configData = ConvertTo-HashtableFromPSCustomObject -InputObject $configData
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
                throw "PSD1 validation failed: $($_.Exception.Message)"
            }
        }
        
        # Save the PSD1 file
        Write-Verbose "[$functionName] Saving PSD1 file: $Psd1FilePath"
        $psd1Content | Set-Content -Path $Psd1FilePath -Encoding UTF8 -ErrorAction Stop
        
        Write-Verbose "[$functionName] Conversion completed successfully"
        return $Psd1FilePath
    }
    catch
    {
        Write-Error "[$functionName] Conversion failed: $($_.Exception.Message)"
        throw
    }
}

function ConvertTo-HashtableFromPSCustomObject()
{
    <#
    .SYNOPSIS
        Recursively converts PSCustomObject to hashtable for PowerShell 5.1 compatibility.
    #>
    param([object]$InputObject)
    
    if ($InputObject -is [PSCustomObject])
    {
        $hashtable = @{}
        foreach ($property in $InputObject.PSObject.Properties)
        {
            if ($property.Value -is [PSCustomObject])
            {
                $hashtable[$property.Name] = ConvertTo-HashtableFromPSCustomObject -InputObject $property.Value
            }
            elseif ($property.Value -is [System.Array])
            {
                $hashtable[$property.Name] = @()
                foreach ($item in $property.Value)
                {
                    if ($item -is [PSCustomObject])
                    {
                        $hashtable[$property.Name] += ConvertTo-HashtableFromPSCustomObject -InputObject $item
                    }
                    else
                    {
                        $hashtable[$property.Name] += $item
                    }
                }
            }
            else
            {
                $hashtable[$property.Name] = $property.Value
            }
        }
        return $hashtable
    }
    elseif ($InputObject -is [System.Array])
    {
        $array = @()
        foreach ($item in $InputObject)
        {
            if ($item -is [PSCustomObject])
            {
                $array += ConvertTo-HashtableFromPSCustomObject -InputObject $item
            }
            else
            {
                $array += $item
            }
        }
        return $array
    }
    else
    {
        return $InputObject
    }
}

function ConvertTo-Psd1String()
{
    <#
    .SYNOPSIS
        Converts a hashtable to properly formatted PSD1 string content.
    #>
    param(
        [hashtable]$Configuration,
        [int]$IndentLevel = 0
    )
    
    $indent = "    " * $IndentLevel
    $childIndent = "    " * ($IndentLevel + 1)
    $result = "@{`n"
    
    foreach ($key in $Configuration.Keys)
    {
        $value = $Configuration[$key]
        $result += "$childIndent$key = "
        
        if ($value -is [hashtable])
        {
            $result += (ConvertTo-Psd1String -Configuration $value -IndentLevel ($IndentLevel + 1))
        }
        elseif ($value -is [System.Array])
        {
            $result += "@(`n"
            foreach ($item in $value)
            {
                if ($item -is [hashtable])
                {
                    $result += "$childIndent    " + (ConvertTo-Psd1String -Configuration $item -IndentLevel ($IndentLevel + 2)) + ",`n"
                }
                elseif ($item -is [string])
                {
                    $escapedItem = $item -replace "'", "''"
                    $result += "$childIndent    '$escapedItem',`n"
                }
                else
                {
                    $result += "$childIndent    $item,`n"
                }
            }
            $result = $result.TrimEnd(",`n") + "`n$childIndent)"
        }
        elseif ($value -is [string])
        {
            $escapedValue = $value -replace "'", "''"
            $result += "'$escapedValue'"
        }
        elseif ($value -is [bool])
        {
            $result += if ($value)
            {
                '$true' 
            }
            else
            {
                '$false' 
            }
        }
        elseif ($null -eq $value)
        {
            $result += '$null'
        }
        else
        {
            $result += $value
        }
        
        $result += "`n"
    }
    
    $result += "$indent}"
    return $result
}