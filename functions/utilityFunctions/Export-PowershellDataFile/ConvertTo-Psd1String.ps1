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
        Write-Verbose "[$functionName] Processing key: $key with value type: $($value.GetType().Name)"
        
        if ($value -is [hashtable] -or $value -is [System.Collections.Specialized.OrderedDictionary])
        {
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
            else
            {
                $result += "@(`n"
                foreach ($item in $value)
                {
                    $result += "$childIndent    "
                    
                    if ($item -is [hashtable] -or $item -is [System.Collections.Specialized.OrderedDictionary])
                    {
                        Write-Verbose "[$functionName] Processing nested $($item.GetType().Name) in array"
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