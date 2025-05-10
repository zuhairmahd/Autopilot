function Test-IsBase64String()
{
    param (
        [string]$Value
    )
    
    try
    {
        $null = [Convert]::FromBase64String($Value)
        return $true
    }
    catch
    {
        return $false
    }
}


function isEncrypted()
{
    [CmdletBinding()]
    param (
        [psObject]$data
    )
    
    # Using global Test-IsBase64String function
    
    function CountEncryptionStatus
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject
        )
        
        $result = [PSCustomObject]@{
            EncryptedCount   = 0
            UnencryptedCount = 0
        }
        
        if ($null -eq $InputObject)
        {
            return $result
        }
        
        if ($InputObject -is [array])
        {
            foreach ($item in $InputObject)
            {
                $itemStatus = CountEncryptionStatus -InputObject $item
                $result.EncryptedCount += $itemStatus.EncryptedCount
                $result.UnencryptedCount += $itemStatus.UnencryptedCount
            }
        }
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    $nestedStatus = CountEncryptionStatus -InputObject $prop.Value
                    $result.EncryptedCount += $nestedStatus.EncryptedCount
                    $result.UnencryptedCount += $nestedStatus.UnencryptedCount
                }
                elseif ($prop.Value -is [string] -and $prop.Value.Length -gt 0)
                {
                    Write-Verbose "Checking if the value of $($prop.Name) is encrypted."
                    if (Test-IsBase64String -Value $prop.Value)
                    {
                        Write-Verbose "The value of $($prop.Name) is encrypted."
                        $result.EncryptedCount++
                    }
                    else
                    {
                        Write-Verbose "The value of $($prop.Name) is not encrypted."
                        $result.UnencryptedCount++
                    }
                }
                else
                {
                    Write-Verbose "The value of $($prop.Name) is not a string, skipping."
                    $result.UnencryptedCount++
                }
            }
        }
        else
        {
            if ($InputObject -is [string] -and $InputObject.Length -gt 0)
            {
                if (Test-IsBase64String -Value $InputObject)
                {
                    $result.EncryptedCount++
                }
                else
                {
                    $result.UnencryptedCount++
                }
            }
            else
            {
                $result.UnencryptedCount++
            }
        }
        
        return $result
    }
    
    $isEncrypted = $false
    Write-Verbose 'Checking if the data is encrypted.'
    
    $encryptionStatus = CountEncryptionStatus -InputObject $data
    $encryptedCount = $encryptionStatus.EncryptedCount
    $unencryptedCount = $encryptionStatus.UnencryptedCount
    
    Write-Verbose "The number of encrypted values is $encryptedCount"
    Write-Verbose "The number of unencrypted values is $unencryptedCount"
    
    # If the number of encrypted values is greater than the number of unencrypted values, the data is encrypted.
    if ($encryptedCount -gt $unencryptedCount -and $encryptedCount -gt 0)
    {
        $isEncrypted = $true
    }
    
    Write-Verbose "The data is encrypted: $isEncrypted"
    return $isEncrypted
}

function DecryptObject()
{
    [CmdletBinding()]
    param (
        [object]$encryptedObject,
        [string[]]$excludeFields
    )
    
    # Using global Test-IsBase64String function
    
    function Invoke-RecursiveDecryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = ""
        )
        
        if ($null -eq $InputObject)
        {
            return $null
        }
        
        # Handle array type
        if ($InputObject -is [array])
        {
            $resultArray = @()
            foreach ($item in $InputObject)
            {
                $decryptedItem = Invoke-RecursiveDecryption -InputObject $item -ExcludeFields $ExcludeFields -ParentPath $ParentPath
                $resultArray += $decryptedItem
            }
            return $resultArray
        }
        # Handle object type
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            $result = [ordered]@{}
            
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                $currentPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                Write-Verbose "Processing property: $currentPath"
                
                $isExcluded = $ExcludeFields -contains $prop.Name
                if ($isExcluded)
                {
                    Write-Verbose "Property $($prop.Name) is in exclude list, skipping decryption."
                    
                    # For excluded fields, still process any nested objects/arrays but don't decrypt the value itself
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                    {
                        $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    else
                    {
                        $result[$prop.Name] = $prop.Value
                    }
                }
                else
                {
                    # Process based on value type
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable])
                    {
                        $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [array])
                    {
                        $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [string] -and (Test-IsBase64String -Value $prop.Value))
                    {
                        Write-Verbose "Decrypting string value for $currentPath"
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($prop.Value))
                            $result[$prop.Name] = $decodedValue
                            Write-Verbose "Decrypted value: $decodedValue"
                        }
                        catch
                        {
                            Write-Verbose "Failed to decrypt value for $currentPath, keeping as is"
                            $result[$prop.Name] = $prop.Value
                        }
                    }
                    else
                    {
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            
            return [PSCustomObject]$result
        }
        # Handle string (potential base64)
        elseif ($InputObject -is [string] -and (Test-IsBase64String -Value $InputObject))
        {
            try
            {
                $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
                return $decodedValue
            }
            catch
            {
                return $InputObject
            }
        }
        # Return as is for everything else
        else
        {
            return $InputObject
        }
    }
    
    $result = Invoke-RecursiveDecryption -InputObject $encryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were decrypted.'
        return $null
    }
    
    Write-Verbose "Decryption complete"
    return $result
}

function EncryptObject()
{
    [CmdletBinding()]
    param (
        [object]$decryptedObject,
        [string[]]$excludeFields
    )
    
    function Invoke-RecursiveEncryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = ""
        )
        
        if ($null -eq $InputObject)
        {
            return $null
        }
        
        # Handle array type
        if ($InputObject -is [array])
        {
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $currentPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                $encryptedItem = Invoke-RecursiveEncryption -InputObject $InputObject[$i] -ExcludeFields $ExcludeFields -ParentPath $currentPath
                $resultArray += $encryptedItem
            }
            return $resultArray
        }
        # Handle object type
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            $result = [ordered]@{}
            
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                $currentPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                Write-Verbose "Processing property: $currentPath"
                
                $isExcluded = $ExcludeFields -contains $prop.Name
                if ($isExcluded)
                {
                    Write-Verbose "Property $($prop.Name) is in exclude list, skipping encryption."
                    
                    # For excluded fields, still process any nested objects/arrays but don't encrypt the value itself
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                    {
                        $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    else
                    {
                        $result[$prop.Name] = $prop.Value
                    }
                }
                else
                {
                    # Process based on value type
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable])
                    {
                        $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [array])
                    {
                        $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [string] -or $prop.Value -is [int] -or $prop.Value -is [bool] -or $prop.Value -is [double])
                    {
                        Write-Verbose "Encrypting value for $currentPath"
                        $stringValue = $prop.Value.ToString()
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$prop.Name] = $encodedValue
                    }
                    else
                    {
                        # For other types, keep as is
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            
            return [PSCustomObject]$result
        }
        # Handle primitive types (strings, numbers, booleans)
        elseif ($InputObject -is [string] -or $InputObject -is [int] -or $InputObject -is [bool] -or $InputObject -is [double])
        {
            $stringValue = $InputObject.ToString()
            return [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
        }
        # Return as is for everything else
        else
        {
            return $InputObject
        }
    }
    
    $result = Invoke-RecursiveEncryption -InputObject $decryptedObject -ExcludeFields $excludeFields
    
    if ($null -eq $result)
    {
        Write-Error 'No values were encrypted.'
        return $null
    }
    
    Write-Verbose "Encryption complete"
    return $result
}
