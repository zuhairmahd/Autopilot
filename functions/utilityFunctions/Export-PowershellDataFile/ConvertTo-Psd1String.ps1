function ConvertTo-Psd1String()
{
    <#
    .SYNOPSIS
        Converts a hashtable or ordered dictionary to properly formatted PSD1 string content with enhanced error handling.
    #>
    [CmdletBinding()]
    param(
        [object]$Configuration,
        [int]$IndentLevel = 0
    )
    $functionName = $MyInvocation.MyCommand.Name
    $indent = "    " * $IndentLevel
    $childIndent = "    " * ($IndentLevel + 1)
    $result = "@{`n"
    
    # Validate input type
    if (-not ($Configuration -is [hashtable] -or $Configuration -is [System.Collections.Specialized.OrderedDictionary]))
    {
        throw "Configuration must be a hashtable or ordered dictionary, got: $($Configuration.GetType().Name)"
    }
    
    Write-Verbose "[$functionName] Converting $($Configuration.GetType().Name) to PSD1 string at indent level $IndentLevel"
    
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
        
        # Handle null values first before trying to access GetType()
        if ($null -eq $value)
        {
            Write-Verbose "[$functionName] Processing key: $key with null value"
            $result += '$null'
        }
        elseif ($value -is [hashtable] -or $value -is [System.Collections.Specialized.OrderedDictionary])
        {
            Write-Verbose "[$functionName] Processing key: $key with value type: $($value.GetType().Name)"
            Write-Verbose "[$functionName] Processing nested $($value.GetType().Name)"
            $result += (ConvertTo-Psd1String -Configuration $value -IndentLevel ($IndentLevel + 1))
        }
        elseif ($value -is [System.Array])
        {
            Write-Verbose "[$functionName] Processing array with $($value.Count) items"
            if ($value.Count -eq 0)
            {
                $result += "@()"
            }
            elseif ($value.Count -eq 1)
            {
                # Force single-item arrays to remain arrays using ,@() syntax
                Write-Verbose "[$functionName] Processing single-item array (forcing array type)"
                $result += ",@("
                $item = $value[0]
                
                if ($null -eq $item)
                {
                    Write-Verbose "[$functionName] Processing null item in single-item array"
                    $result += '$null'
                }
                elseif ($item -is [hashtable] -or $item -is [System.Collections.Specialized.OrderedDictionary])
                {
                    Write-Verbose "[$functionName] Processing nested $($item.GetType().Name) in single-item array"
                    $result += (ConvertTo-Psd1String -Configuration $item -IndentLevel ($IndentLevel + 1))
                }
                elseif ($item -is [PSCustomObject])
                {
                    Write-Verbose "[$functionName] Processing PSCustomObject in single-item array - converting to hashtable first"
                    $itemAsHashtable = ConvertTo-HashtableFromPSCustomObject -InputObject $item
                    $result += (ConvertTo-Psd1String -Configuration $itemAsHashtable -IndentLevel ($IndentLevel + 1))
                }
                elseif ($item -is [string])
                {
                    Write-Verbose "[$functionName] Processing string in single-item array: $item"
                    $escapedItem = $item -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
                    $result += "'$escapedItem'"
                }
                elseif ($item -is [bool])
                {
                    $result += if ($item) { '$true' } else { '$false' }
                }
                elseif ($item -is [int] -or $item -is [long] -or $item -is [double] -or $item -is [float])
                {
                    $result += $item.ToString()
                }
                else
                {
                    Write-Verbose "[$functionName] Processing other type in single-item array: $($item.GetType().Name)"
                    $result += "'$($item.ToString())'"
                }
                $result += ")"
            }
            else
            {
                $result += "@(`n"
                foreach ($item in $value)
                {
                    $result += "$childIndent    "
                    
                    if ($null -eq $item)
                    {
                        Write-Verbose "[$functionName] Processing null item in array"
                        $result += '$null'
                    }
                    elseif ($item -is [hashtable] -or $item -is [System.Collections.Specialized.OrderedDictionary])
                    {
                        Write-Verbose "[$functionName] Processing nested $($item.GetType().Name) in array"
                        $result += (ConvertTo-Psd1String -Configuration $item -IndentLevel ($IndentLevel + 2))
                    }
                    elseif ($item -is [PSCustomObject])
                    {
                        Write-Verbose "[$functionName] Processing PSCustomObject in array - converting to hashtable first"
                        $itemAsHashtable = ConvertTo-HashtableFromPSCustomObject -InputObject $item
                        $result += (ConvertTo-Psd1String -Configuration $itemAsHashtable -IndentLevel ($IndentLevel + 2))
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
            Write-Verbose "[$functionName] Processing key: $key with value type: String"
            # Enhanced string escaping for PowerShell compatibility
            $escapedValue = $value -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
            $result += "'$escapedValue'"
        }
        elseif ($value -is [bool])
        {
            Write-Verbose "[$functionName] Processing key: $key with value type: Boolean"
            $result += if ($value) { '$true' } else { '$false' }
        }
        elseif ($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [float])
        {
            Write-Verbose "[$functionName] Processing key: $key with numeric value type: $($value.GetType().Name)"
            $result += $value.ToString()
        }
        elseif ($value -is [datetime])
        {
            Write-Verbose "[$functionName] Processing key: $key with datetime value"
            $result += "'$($value.ToString('o'))'"  # ISO 8601 format
        }
        else
        {
            Write-Verbose "[$functionName] Processing key: $key with other type: $($value.GetType().Name)"
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