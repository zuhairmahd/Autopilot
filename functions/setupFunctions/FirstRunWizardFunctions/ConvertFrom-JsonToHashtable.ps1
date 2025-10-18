function ConvertFrom-JsonToHashtable()
{
    <#
    .SYNOPSIS
        Converts a PSCustomObject (from ConvertFrom-Json) to a hashtable recursively.
    
    .DESCRIPTION
        This function recursively converts PSCustomObject instances to hashtables,
        which is necessary for proper merging operations. Arrays and other types
        are preserved as-is. Optionally supports flattening nested structures
        into a flat hashtable with dot-notation keys.
    
    .PARAMETER JsonObject
        The PSCustomObject to convert to a hashtable.
    
    .PARAMETER Flatten
        If specified, flattens nested objects into a flat hashtable with dot-notation keys.
        For example, {"parent": {"child": "value"}} becomes {"parent.child": "value"}.
    
    .PARAMETER Prefix
        Used internally for recursion when flattening. Specifies the prefix for keys.
    
    .OUTPUTS
        System.Collections.Hashtable or original object type
        Returns a hashtable if input is PSCustomObject, otherwise returns the original object.
    
    .EXAMPLE
        $hashtable = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
        
        Converts a JSON object to a hashtable for merging operations.
    
    .EXAMPLE
        $flatHashtable = ConvertFrom-JsonToHashtable -JsonObject $jsonObject -Flatten
        
        Converts a JSON object to a flat hashtable with dot-notation keys.
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Handles nested objects recursively
        - Preserves arrays and primitive types
        - Supports both structured and flattened output
        - Automatically uses ConfigCore.JsonParser for 3-5x faster parsing when available
        - Falls back to PowerShell implementation if ConfigCore not loaded or parsing fails
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $JsonObject,
        [Parameter(Mandatory = $false)]
        [switch]$Flatten,
        [Parameter(Mandatory = $false)]
        [string]$Prefix = ''
    )
    
    $functionName = $MyInvocation.MyCommand.Name    
    Write-Verbose "[$functionName] Converting object to hashtable (Flatten: $Flatten)"
    Write-Log -logFile $logFile -Module $functionName -Message "Converting object to hashtable (Flatten: $Flatten)"
    
    # Fast path: If ConfigCore is available and input is a JSON string, use C# parser (3-5x faster)
    if ($global:AutopilotDllStatus.ConfigCoreLoaded -and $JsonObject -is [string])
    {
        Write-Verbose "[$functionName] Using ConfigCore JsonParser for 3-5x faster parsing"
        Write-Log -logFile $logFile -Module $functionName -Message "Using ConfigCore JsonParser for fast JSON parsing"
        
        try
        {
            if ($Flatten)
            {
                $result = [Autopilot.ConfigCore.JsonParser]::ParseToHashtableFlattened($JsonObject)
                Write-Verbose "[$functionName] ConfigCore parsed and flattened JSON to $($result.Count) keys"
                return $result
            }
            else
            {
                $result = [Autopilot.ConfigCore.JsonParser]::ParseToHashtable($JsonObject)
                Write-Verbose "[$functionName] ConfigCore parsed JSON to $($result.Count) keys"
                return $result
            }
        }
        catch
        {
            Write-Verbose "[$functionName] ConfigCore JsonParser failed: $($_.Exception.Message), falling back to PowerShell"
            Write-Log -logFile $logFile -Module $functionName -Message "ConfigCore JsonParser failed, using PowerShell fallback: $($_.Exception.Message)" -LogLevel "Warning"
            # Fall through to PowerShell implementation
        }
    }
    
    # Iterative implementation using work stack to avoid stack overflow
    # Work item format: @{Object=$obj; Prefix=$prefix; TargetHash=$hash; TargetKey=$key}
    $workStack = New-Object 'System.Collections.Generic.Stack[object]'
    $rootHash = @{}
    
    # Push initial work item
    $workStack.Push(@{
            Object     = $JsonObject
            Prefix     = $Prefix
            TargetHash = $rootHash
            TargetKey  = $null
        })
    
    Write-Verbose "[$functionName] Starting iterative conversion (Flatten: $Flatten)"
    
    while ($workStack.Count -gt 0)
    {
        $work = $workStack.Pop()
        $obj = $work.Object
        $currentPrefix = $work.Prefix
        $targetHash = $work.TargetHash
        $targetKey = $work.TargetKey
        
        # Handle hashtables and dictionaries
        if ($obj -is [hashtable] -or $obj -is [System.Collections.IDictionary])
        {
            Write-Verbose "[$functionName] Processing hashtable/dictionary with $($obj.Keys.Count) keys"
            
            if ($targetKey)
            {
                # Create new hashtable for nested structure
                $newHash = @{}
                $targetHash[$targetKey] = $newHash
                $targetHash = $newHash
            }
            
            # Process all keys - push them onto stack in reverse order to maintain order
            $keys = @($obj.Keys)
            for ($i = $keys.Count - 1; $i -ge 0; $i--)
            {
                $key = $keys[$i]
                $value = $obj[$key]
                
                $fullKey = if ($Flatten -and $currentPrefix)
                {
                    "$currentPrefix.$key"
                }
                else
                {
                    $key
                }
                
                $isNested = ($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0)
                
                if ($isNested)
                {
                    if ($Flatten)
                    {
                        # Flatten mode: push with extended prefix
                        $workStack.Push(@{
                                Object     = $value
                                Prefix     = $fullKey
                                TargetHash = $targetHash
                                TargetKey  = $null
                            })
                    }
                    else
                    {
                        # Structured mode: push with target key for nesting
                        $workStack.Push(@{
                                Object     = $value
                                Prefix     = $currentPrefix
                                TargetHash = $targetHash
                                TargetKey  = $key
                            })
                    }
                }
                else
                {
                    # Simple value - add directly
                    $targetHash[$fullKey] = $value
                }
            }
        }
        elseif ($obj -is [PSCustomObject])
        {
            Write-Verbose "[$functionName] Processing PSCustomObject with $($obj.PSObject.Properties.Count) properties"
            
            if ($targetKey)
            {
                # Create new hashtable for nested structure
                $newHash = @{}
                $targetHash[$targetKey] = $newHash
                $targetHash = $newHash
            }
            
            # Process all properties - push them onto stack in reverse order
            $properties = @($obj.PSObject.Properties)
            for ($i = $properties.Count - 1; $i -ge 0; $i--)
            {
                $prop = $properties[$i]
                $propName = $prop.Name
                $propValue = $prop.Value
                
                $fullKey = if ($Flatten -and $currentPrefix)
                {
                    "$currentPrefix.$propName"
                }
                else
                {
                    $propName
                }
                
                if ($propValue -is [PSCustomObject])
                {
                    if ($Flatten)
                    {
                        # Flatten mode: push with extended prefix
                        $workStack.Push(@{
                                Object     = $propValue
                                Prefix     = $fullKey
                                TargetHash = $targetHash
                                TargetKey  = $null
                            })
                    }
                    else
                    {
                        # Structured mode: push with target key
                        $workStack.Push(@{
                                Object     = $propValue
                                Prefix     = $currentPrefix
                                TargetHash = $targetHash
                                TargetKey  = $propName
                            })
                    }
                }
                elseif ($propValue -is [System.Array])
                {
                    # Handle arrays - convert PSCustomObjects within
                    Write-Verbose "[$functionName] Converting array property: $propName"
                    $convertedArray = @()
                    foreach ($item in $propValue)
                    {
                        if ($item -is [PSCustomObject])
                        {
                            # For array items, create a temporary conversion
                            # Use a simple recursive call here as arrays are typically shallow
                            $itemStack = New-Object 'System.Collections.Generic.Stack[object]'
                            $itemHash = @{}
                            $itemStack.Push(@{
                                    Object     = $item
                                    Prefix     = ''
                                    TargetHash = $itemHash
                                    TargetKey  = $null
                                })
                            
                            while ($itemStack.Count -gt 0)
                            {
                                $itemWork = $itemStack.Pop()
                                if ($itemWork.Object -is [PSCustomObject])
                                {
                                    $itemWork.Object.PSObject.Properties | ForEach-Object {
                                        if ($_.Value -is [PSCustomObject])
                                        {
                                            $nestedHash = @{}
                                            $itemWork.TargetHash[$_.Name] = $nestedHash
                                            $itemStack.Push(@{
                                                    Object     = $_.Value
                                                    Prefix     = ''
                                                    TargetHash = $nestedHash
                                                    TargetKey  = $null
                                                })
                                        }
                                        else
                                        {
                                            $itemWork.TargetHash[$_.Name] = $_.Value
                                        }
                                    }
                                }
                            }
                            $convertedArray += $itemHash
                        }
                        else
                        {
                            $convertedArray += $item
                        }
                    }
                    $targetHash[$fullKey] = $convertedArray
                }
                else
                {
                    # Simple value
                    $targetHash[$fullKey] = $propValue
                }
            }
        }
        else
        {
            # Simple value
            if ($Flatten -and $currentPrefix)
            {
                $targetHash[$currentPrefix] = $obj
            }
            else
            {
                # Return original object if not a complex type
                return $obj
            }
        }
    }
    
    return $rootHash
}

