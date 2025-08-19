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
    
    # Handle hashtables and dictionaries
    if ($JsonObject -is [hashtable] -or $JsonObject -is [System.Collections.IDictionary])
    {
        Write-Verbose "[$functionName] Detected hashtable/dictionary"
        Write-Log -logFile $logFile -Module $functionName -Message "Detected hashtable/dictionary"
        $hashtable = @{}
        foreach ($key in $JsonObject.Keys)
        {
            $fullKey = if ($Flatten -and $Prefix)
            {
                "$Prefix.$key" 
            }
            else
            {
                $key 
            }
            $value = $JsonObject[$key]
            
            if ($Flatten -and (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                ($value -is [PSCustomObject] -and $value.PSObject.Properties.Count -gt 0)))
            {
                Write-Verbose "[$functionName] Found nested object at key: $fullKey, flattening"
                $nestedFlat = ConvertFrom-JsonToHashtable -JsonObject $value -Flatten -Prefix $fullKey
                foreach ($nestedKey in $nestedFlat.Keys)
                {
                    $hashtable[$nestedKey] = $nestedFlat[$nestedKey]
                }
            }
            elseif (-not $Flatten -and (($value -is [hashtable]) -or ($value -is [System.Collections.IDictionary]) -or 
                     ($value -is [PSCustomObject])))
            {
                # Preserve structure - recursively convert but don't flatten
                Write-Verbose "[$functionName] Recursively converting nested object: $key"
                $hashtable[$key] = ConvertFrom-JsonToHashtable -JsonObject $value
            }
            else
            {
                Write-Verbose "[$functionName] Adding $(if ($Flatten) {'flat'} else {'structured'}) key: $fullKey"
                $hashtable[$fullKey] = $value
            }
        }
        return $hashtable
    }
    elseif ($JsonObject -is [PSCustomObject])
    {
        Write-Verbose "[$functionName] Detected PSCustomObject"
        Write-Log -logFile $logFile -Module $functionName -Message "Detected PSCustomObject"
        Write-Verbose "[$functionName] Converting properties to hashtable"
        Write-Log -logFile $logFile -Module $functionName -Message "Converting properties to hashtable"
        $hashtable = @{}
        $JsonObject.PSObject.Properties | ForEach-Object {
            $fullKey = if ($Flatten -and $Prefix)
            {
                "$Prefix.$($_.Name)" 
            }
            else
            {
                $_.Name 
            }
            
            if ($_.Value -is [PSCustomObject])
            {
                if ($Flatten)
                {
                    # Flatten nested PSCustomObjects
                    Write-Verbose "[$functionName] Flattening nested PSCustomObject: $fullKey"
                    Write-Log -logFile $logFile -Module $functionName -Message "Flattening nested PSCustomObject: $fullKey"
                    $nestedFlat = ConvertFrom-JsonToHashtable -JsonObject $_.Value -Flatten -Prefix $fullKey
                    foreach ($nestedKey in $nestedFlat.Keys)
                    {
                        $hashtable[$nestedKey] = $nestedFlat[$nestedKey]
                    }
                }
                else
                {
                    # Recursively convert nested PSCustomObjects while preserving structure
                    Write-Verbose "[$functionName] Recursively converting nested PSCustomObject: $($_.Name)"
                    Write-Log -logFile $logFile -Module $functionName -Message "Recursively converting nested PSCustomObject: $($_.Name)"
                    $hashtable[$_.Name] = ConvertFrom-JsonToHashtable -JsonObject $_.Value
                }
            }
            elseif ($_.Value -is [System.Array])
            {
                # Handle arrays - check if they contain PSCustomObjects
                Write-Verbose "[$functionName] Converting array property: $($_.Name)"
                Write-Log -logFile $logFile -Module $functionName -Message "Converting array property: $($_.Name)"
                $convertedArray = @()
                foreach ($item in $_.Value)
                {
                    if ($item -is [PSCustomObject])
                    {
                        Write-Verbose "[$functionName] Recursively converting nested PSCustomObject in array: $($_.Name)"
                        Write-Log -logFile $logFile -Module $functionName -Message "Recursively converting nested PSCustomObject in array: $($_.Name)"
                        $convertedArray += ConvertFrom-JsonToHashtable -JsonObject $item -Flatten:$Flatten -Prefix $Prefix
                    }
                    else
                    {
                        # Preserve non-PSCustomObject items as-is
                        Write-Verbose "[$functionName] Preserving non-PSCustomObject item in array: $($_.Name)"
                        Write-Log -logFile $logFile -Module $functionName -Message "Preserving non-PSCustomObject item in array: $($_.Name)"
                        $convertedArray += $item
                    }
                }
                $hashtable[$fullKey] = $convertedArray
            }
            else
            {
                $hashtable[$fullKey] = $_.Value
            }
        }
        return $hashtable
    }
    else
    {
        # If it's a simple value and we're flattening with a prefix, return as hashtable
        if ($Flatten -and $Prefix)
        {
            Write-Verbose "[$functionName] Creating flat hashtable for simple value with prefix: $Prefix"
            $flatHash = @{}
            $flatHash[$Prefix] = $JsonObject
            return $flatHash
        }
        else
        {
            Write-Verbose "[$functionName] Input is not a PSCustomObject or hashtable, returning original object"
            Write-Log -logFile $logFile -Module $functionName -Message "Input is not a PSCustomObject or hashtable, returning original object"
            return $JsonObject
        }
    }
}

