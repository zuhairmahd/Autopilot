function ConvertTo-HashtableFromPSCustomObject()
{
    <#
    .SYNOPSIS
        Recursively converts PSCustomObject to hashtable for PowerShell 5.1 compatibility.
    #>
    [CmdletBinding()]
    param([object]$InputObject)
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting conversion of PSCustomObject to hashtable"    
    write-log -logFile $logFile -module $functionName -message "Starting conversion of PSCustomObject to hashtable"
    if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary])
    {
        Write-Verbose "[$functionName] Input $InputObject is already a hashtable, returning as-is with the following keys:"
        write-log -logFile $logFile -module $functionName -message "Input $InputObject is already a hashtable, returning as-is with the following keys:"
        $InputObject.Keys | ForEach-Object { Write-Verbose "[$functionName] Hashtable key: $_" }
        return $InputObject
    }
    elseif ($InputObject -is [PSCustomObject])
    {
        Write-Verbose "[$functionName] Converting PSCustomObject $InputObject to hashtable with the following keys:"
        write-log -logFile $logFile -module $functionName -message "Converting PSCustomObject $InputObject to hashtable with the following keys:"
        $InputObject.PSObject.Properties | ForEach-Object { Write-Verbose "[$functionName] PSCustomObject property: $($_.Name)" }   
        $hashtable = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties)
        {
            # Only process NoteProperty members, skip system properties
            if ($property.MemberType -eq 'NoteProperty')
            {
                Write-Verbose "[$functionName] Processing property: $($property.Name)"
                write-log -logFile $logFile -module $functionName -message "Processing property: $($property.Name)"             
                if ($property.Value -is [PSCustomObject])
                {
                    Write-Verbose "[$functionName] Recursively converting property: $($property.Name)"
                    write-log -logFile $logFile -module $functionName -message "Recursively converting property: $($property.Name)" 
                    $hashtable[$property.Name] = ConvertTo-HashtableFromPSCustomObject -InputObject $property.Value
                }
                elseif ($property.Value -is [System.Array])
                {
                    Write-Verbose "[$functionName] Processing array property: $($property.Name)"    
                    write-log -logFile $logFile -module $functionName -message "Processing array property: $($property.Name)" 
                    $hashtable[$property.Name] = @()
                    foreach ($item in $property.Value)
                    {
                        Write-Verbose "[$functionName] Processing array item $item"
                        write-log -logFile $logFile -module $functionName -message "Processing array item $item"                        
                        if ($item -is [PSCustomObject])
                        {
                            Write-Verbose "[$functionName] Recursively converting array item $item"
                            write-log -logFile $logFile -module $functionName -message "Recursively converting array item $item"        
                            $hashtable[$property.Name] += ConvertTo-HashtableFromPSCustomObject -InputObject $item
                        }
                        else
                        {
                            Write-Verbose "[$functionName] Adding array item $item"
                            write-log -logFile $logFile -module $functionName -message "Adding array item $item"                    
                            $hashtable[$property.Name] += $item
                        }
                    }
                }
                else
                {
                    Write-Verbose "[$functionName] Adding property: $($property.Name)"
                    write-log -logFile $logFile -module $functionName -message "Adding property: $($property.Name)"     
                    $hashtable[$property.Name] = $property.Value
                }
            }
            else
            {
                Write-Verbose "[$functionName] Skipping non-NoteProperty: $($property.Name) (Type: $($property.MemberType))"
                write-log -logFile $logFile -module $functionName -message "Skipping non-NoteProperty: $($property.Name) (Type: $($property.MemberType))"   
            }
        }
        return $hashtable
    }
    elseif ($InputObject -is [System.Array])
    {
        Write-Verbose "[$functionName] Processing array input $InputObject"
        write-log -logFile $logFile -module $functionName -message "Processing array input $InputObject"
        $array = @()
        foreach ($item in $InputObject)
        {
            Write-Verbose "[$functionName] Processing array item $item"
            write-log -logFile $logFile -module $functionName -message "Processing array item $item"    
            if ($item -is [PSCustomObject])
            {
                Write-Verbose "[$functionName] Recursively converting array item $item"
                write-log -logFile $logFile -module $functionName -message "Recursively converting array item $item"
                $array += ConvertTo-HashtableFromPSCustomObject -InputObject $item
            }
            else
            {
                Write-Verbose "[$functionName] Adding array item $item"
                write-log -logFile $logFile -module $functionName -message "Adding array item $item"
                $array += $item
            }
        }
        return $array
    }
    else
    {
        Write-Verbose "[$functionName] Input is neither PSCustomObject nor array, returning as-is"
        write-log -logFile $logFile -module $functionName -message "Input is neither PSCustomObject nor array, returning as-is"         
        return $InputObject
    }
}

