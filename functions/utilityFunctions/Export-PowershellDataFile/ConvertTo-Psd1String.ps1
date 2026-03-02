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
    Write-Verbose "[$functionName] Starting conversion of $($Configuration |Out-String) to PSD1 string with indent level $IndentLevel and child indent '$childIndent'"
    Write-Log -logFile $logFile -module $functionName -message "Starting conversion of configuration to PSD1 string with indent level $IndentLevel, child indent '$childIndent'"
    # Validate input type
    if (-not ($Configuration -is [hashtable] -or $Configuration -is [System.Collections.Specialized.OrderedDictionary]))
    {
        Write-Verbose "[$functionName] Invalid configuration type: $($Configuration.GetType().Name)"
        Write-Log -logFile $logFile -module $functionName -message "Invalid configuration type: $($Configuration.GetType().Name)" -logLevel Error
        throw "Configuration must be a hashtable or ordered dictionary, got: $($Configuration.GetType().Name)"
    }

    Write-Verbose "[$functionName] Converting $($Configuration.GetType().Name) to PSD1 string at indent level $IndentLevel, child indent '$childIndent'"
    Write-Verbose "[$functionName] Configuration object $($Configuration |Out-String) with keys:"
    $Configuration.Keys | ForEach-Object { Write-Verbose "[$functionName] Key: $_" }
    # Handle empty hashtables
    if ($Configuration.Keys.Count -eq 0)
    {
        Write-Verbose "[$functionName] Empty hashtable detected"
        Write-Log -logFile $logFile -module $functionName -message "Empty hashtable detected" -logLevel Warning
        return "@{}"
    }

    foreach ($key in $Configuration.Keys)
    {
        $value = $Configuration[$key]
        Write-Verbose "[$functionName] Processing key: $key with value $value and type: $($value.GetType().Name)"
        Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with value $value and type: $($value.GetType().Name)"
        # Skip null keys
        if ($null -eq $key)
        {
            Write-Verbose "[$functionName] Skipping null key"
            Write-Log -logFile $logFile -module $functionName -message "Skipping null key"
            continue
        }

        # Validate key name for PowerShell compatibility
        $validKey = $key
        if ($key -match '[\s\-\.]' -or $key -match '^[0-9]')
        {
            $validKey = "'$key'"
            Write-Verbose "[$functionName] Key '$key' requires quotes for PowerShell compatibility"
            Write-Log -logFile $logFile -module $functionName -message "Key '$key' requires quotes for PowerShell compatibility"
        }

        $result += "$childIndent$validKey = "

        # Handle null values first before trying to access GetType()
        if ($null -eq $value)
        {
            Write-Verbose "[$functionName] Processing key: $key with null value"
            Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with null value"
            $result += '$null'
        }
        elseif ($value -is [hashtable] -or $value -is [System.Collections.Specialized.OrderedDictionary])
        {
            Write-Verbose "[$functionName] Processing key: $key with value $value and type: $($value.GetType().Name)"
            Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with value $value and type: $($value.GetType().Name)"
            Write-Verbose "[$functionName] Processing nested $($value.GetType().Name)"
            Write-Log -logFile $logFile -module $functionName -message "Processing nested $($value.GetType().Name)"
            $result += (ConvertTo-Psd1String -Configuration $value -IndentLevel ($IndentLevel + 1))
        }
        elseif ($value -is [System.Array])
        {
            Write-Verbose "[$functionName] Processing array with $($value.Count) items"
            Write-Log -logFile $logFile -module $functionName -message "Processing array with $($value.Count) items"
            if ($value.Count -eq 0)
            {
                Write-Verbose "[$functionName] Processing empty array"
                Write-Log -logFile $logFile -module $functionName -message "Processing empty array"
                $result += "@()"
            }
            elseif ($value.Count -eq 1)
            {
                # Single-item arrays use @() syntax (not ,@() which creates nested arrays)
                Write-Verbose "[$functionName] Processing single-item array"
                Write-Log -logFile $logFile -module $functionName -message "Processing single-item array"
                $result += "@("
                $item = $value[0]

                if ($null -eq $item)
                {
                    Write-Verbose "[$functionName] Processing null item in single-item array"
                    Write-Log -logFile $logFile -module $functionName -message "Processing null item in single-item array"
                    $result += '$null'
                }
                elseif ($item -is [string])
                {
                    Write-Verbose "[$functionName] Processing string in single-item array: $item"
                    Write-Log -logFile $logFile -module $functionName -message "Processing string in single-item array: $item"
                    $escapedItem = $item -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
                    $result += "'$escapedItem'"
                    Write-Verbose "[$functionName] Escaped string in single-item array: $escapedItem"
                    Write-Log -logFile $logFile -module $functionName -message "Escaped string in single-item array: $escapedItem"
                }
                elseif ($item -is [bool])
                {
                    $result += if ($item)
                    {
                        '$true'
                    }
                    else
                    {
                        '$false'
                    }
                    Write-Verbose "[$functionName] Processing boolean in single-item array: $item"
                    Write-Log -logFile $logFile -module $functionName -message "Processing boolean in single-item array: $item"
                }
                elseif ($item -is [int] -or $item -is [long] -or $item -is [double] -or $item -is [float])
                {
                    Write-Verbose "[$functionName] Processing numeric in single-item array: $item"
                    Write-Log -logFile $logFile -module $functionName -message "Processing numeric in single-item array: $item"
                    $result += $item.ToString()
                }
                elseif ($item -is [hashtable] -or $item -is [System.Collections.Specialized.OrderedDictionary])
                {
                    Write-Verbose "[$functionName] Processing nested $($item.GetType().Name) in single-item array"
                    Write-Log -logFile $logFile -module $functionName -message "Processing nested $($item.GetType().Name) in single-item array"
                    $result += (ConvertTo-Psd1String -Configuration $item -IndentLevel ($IndentLevel + 1))
                }
                elseif ($item -is [PSCustomObject])
                {
                    Write-Verbose "[$functionName] Processing PSCustomObject in single-item array - converting to hashtable first"
                    Write-Log -logFile $logFile -module $functionName -message "Processing PSCustomObject in single-item array - converting to hashtable first"
                    $itemAsHashtable = ConvertTo-HashtableFromPSCustomObject -InputObject $item
                    $result += (ConvertTo-Psd1String -Configuration $itemAsHashtable -IndentLevel ($IndentLevel + 1))
                }
                else
                {
                    Write-Verbose "[$functionName] Processing other type in single-item array: $($item.GetType().Name)"
                    Write-Log -logFile $logFile -module $functionName -message "Processing other type in single-item array: $($item.GetType().Name)"
                    $result += "'$($item.ToString())'"
                }
                $result += ")"
            }
            else
            {
                Write-Verbose "[$functionName] Processing multi-item array"
                Write-Log -logFile $logFile -module $functionName -message "Processing multi-item array"
                $result += "@(`n"
                foreach ($item in $value)
                {
                    $result += "$childIndent    "
                    Write-Verbose "[$functionName] Processing array item: $item"
                    Write-Log -logFile $logFile -module $functionName -message "Processing array item: $item"
                    if ($null -eq $item)
                    {
                        Write-Verbose "[$functionName] Processing null item in array"
                        Write-Log -logFile $logFile -module $functionName -message "Processing null item in array"
                        $result += '$null'
                    }
                    elseif ($item -is [hashtable] -or $item -is [System.Collections.Specialized.OrderedDictionary])
                    {
                        Write-Verbose "[$functionName] Processing nested $($item.GetType().Name) in array"
                        Write-Log -logFile $logFile -module $functionName -message "Processing nested $($item.GetType().Name) in array"
                        $result += (ConvertTo-Psd1String -Configuration $item -IndentLevel ($IndentLevel + 2))
                    }
                    elseif ($item -is [PSCustomObject])
                    {
                        Write-Verbose "[$functionName] Processing PSCustomObject in array - converting to hashtable first"
                        Write-Log -logFile $logFile -module $functionName -message "Processing PSCustomObject in array - converting to hashtable first"
                        $itemAsHashtable = ConvertTo-HashtableFromPSCustomObject -InputObject $item
                        $result += (ConvertTo-Psd1String -Configuration $itemAsHashtable -IndentLevel ($IndentLevel + 2))
                    }
                    elseif ($item -is [string])
                    {
                        Write-Verbose "[$functionName] Processing string in array: $item"
                        Write-Log -logFile $logFile -module $functionName -message "Processing string in array: $item"
                        # Enhanced string escaping for PowerShell compatibility
                        $escapedItem = $item -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
                        $result += "'$escapedItem'"
                        Write-Verbose "[$functionName] Escaped string in array: $escapedItem"
                        Write-Log -logFile $logFile -module $functionName -message "Escaped string in array: $escapedItem"
                    }
                    elseif ($item -is [bool])
                    {
                        $result += if ($item)
                        {
                            '$true'
                        }
                        else
                        {
                            '$false'
                        }
                        Write-Verbose "[$functionName] Processing boolean in array: $item"
                        Write-Log -logFile $logFile -module $functionName -message "Processing boolean in array: $item"
                    }
                    elseif ($item -is [int] -or $item -is [long] -or $item -is [double] -or $item -is [float])
                    {
                        Write-Verbose "[$functionName] Processing numeric in array: $item"
                        Write-Log -logFile $logFile -module $functionName -message "Processing numeric  in array: $item"
                        $result += $item.ToString()
                    }
                    else
                    {
                        Write-Verbose "[$functionName] Processing other type in array: $($item.GetType().Name)"
                        Write-Log -logFile $logFile -module $functionName -message "Processing other type in array: $($item.GetType().Name)"
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
            Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with value type: String"
            # Enhanced string escaping for PowerShell compatibility
            $escapedValue = $value -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
            $result += "'$escapedValue'"
            Write-Verbose "[$functionName] Escaped string value: $escapedValue"
            Write-Log -logFile $logFile -module $functionName -message "Escaped string value: $escapedValue"
        }
        elseif ($value -is [bool])
        {
            Write-Verbose "[$functionName] Processing key: $key with value type: Boolean"
            Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with value type: Boolean"
            $result += if ($value)
            {
                '$true'
            }
            else
            {
                '$false'
            }
        }
        elseif ($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [float])
        {
            Write-Verbose "[$functionName] Processing key: $key with numeric value type: $($value.GetType().Name)"
            Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with numeric value type: $($value.GetType().Name)"
            $result += $value.ToString()
        }
        elseif ($value -is [datetime])
        {
            Write-Verbose "[$functionName] Processing key: $key with datetime value"
            Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with datetime value"
            $result += "'$($value.ToString('o'))'"  # ISO 8601 format
        }
        else
        {
            Write-Verbose "[$functionName] Processing key: $key with other type: $($value.GetType().Name)"
            Write-Log -logFile $logFile -module $functionName -message "Processing key: $key with other type: $($value.GetType().Name)"
            # Convert to string and escape
            $stringValue = $value.ToString() -replace "'", "''" -replace "`n", "``n" -replace "`r", "``r" -replace "`t", "``t"
            Write-Verbose "[$functionName] Escaped string value: $stringValue"
            Write-Log -logFile $logFile -module $functionName -message "Escaped string value: $stringValue"
            $result += "'$stringValue'"
        }

        $result += "`n"
    }
    $result += "$indent}"
    Write-Verbose "[$functionName] Finished converting hashtable to PSD1 string at indent level $IndentLevel"
    Write-Log -logFile $logFile -module $functionName -message "Finished converting hashtable to PSD1 string at indent level $IndentLevel"
    return $result
}