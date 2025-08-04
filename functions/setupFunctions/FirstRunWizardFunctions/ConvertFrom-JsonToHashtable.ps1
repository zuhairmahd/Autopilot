function ConvertFrom-JsonToHashtable()
{
    <#
    .SYNOPSIS
        Converts a PSCustomObject (from ConvertFrom-Json) to a hashtable recursively.
    
    .DESCRIPTION
        This function recursively converts PSCustomObject instances to hashtables,
        which is necessary for proper merging operations. Arrays and other types
        are preserved as-is.
    
    .PARAMETER JsonObject
        The PSCustomObject to convert to a hashtable.
    
    .OUTPUTS
        System.Collections.Hashtable or original object type
        Returns a hashtable if input is PSCustomObject, otherwise returns the original object.
    
    .EXAMPLE
        $hashtable = ConvertFrom-JsonToHashtable -JsonObject $jsonObject
        
        Converts a JSON object to a hashtable for merging operations.
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Handles nested objects recursively
        - Preserves arrays and primitive types
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $JsonObject
    )
    
    $functionName = $MyInvocation.MyCommand.Name    
    Write-Verbose "[$functionName] Converting JSON object to hashtable"
    Write-Log -logFile $logFile -Module $functionName -Message "Converting JSON object to hashtable"
    if ($JsonObject -is [PSCustomObject])
    {
        Write-Verbose "[$functionName] Detected PSCustomObject"
        Write-Log -logFile $logFile -Module $functionName -Message "Detected PSCustomObject"
        Write-Verbose "[$functionName] Converting properties to hashtable"
        Write-Log -logFile $logFile -Module $functionName -Message "Converting properties to hashtable"
        $hashtable = @{}
        $JsonObject.PSObject.Properties | ForEach-Object {
            if ($_.Value -is [PSCustomObject])
            {
                # Recursively convert nested PSCustomObjects
                Write-Verbose "[$functionName] Recursively converting nested PSCustomObject: $($_.Name)"
                Write-Log -logFile $logFile -Module $functionName -Message "Recursively converting nested PSCustomObject: $($_.Name)"
                $hashtable[$_.Name] = ConvertFrom-JsonToHashtable -JsonObject $_.Value
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
                        $convertedArray += ConvertFrom-JsonToHashtable -JsonObject $item
                    }
                    else
                    {
                        # Preserve non-PSCustomObject items as-is
                        Write-Verbose "[$functionName] Preserving non-PSCustomObject item in array: $($_.Name)"
                        Write-Log -logFile $logFile -Module $functionName -Message "Preserving non-PSCustomObject item in array: $($_.Name)"
                        $convertedArray += $item
                    }
                }
                $hashtable[$_.Name] = $convertedArray
            }
            else
            {
                $hashtable[$_.Name] = $_.Value
            }
        }
        return $hashtable
    }
    else
    {
        Write-Verbose "[$functionName] Input is not a PSCustomObject, returning original object"
        Write-Log -logFile $logFile -Module $functionName -Message "Input is not a PSCustomObject, returning original object"
        return $JsonObject
    }
}

