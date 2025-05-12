$excludeFields = @('domain', 'name', 'scopes')


function TestIsBase64String
{
    param (
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value))
    {
        return $false
    }
    # A common check: length must be a multiple of 4.
    # And it should not contain characters outside the Base64 character set.
    # This is a basic check; more robust validation might be needed for edge cases.
    if (($Value.Length % 4 -ne 0) -or ($Value -notmatch "^[a-zA-Z0-9+/]*=*$"))
    {
        return $false
    }

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


function isEncrypted
{
    [CmdletBinding()]
    param (
        [psObject]$data
    )
    
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
                    if (TestIsBase64String -Value $prop.Value)
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
                if (TestIsBase64String -Value $InputObject)
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

function DecryptObject
{
    [CmdletBinding()]
    param (
        [object]$encryptedObject,
        [string[]]$excludeFields
    )
    
    function Invoke-RecursiveDecryption
    {
        param (
            [Parameter(ValueFromPipeline)]
            [object]$InputObject,
            [string[]]$ExcludeFields,
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            return $null 
        }
        Write-Verbose "[DECRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[DECRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveDecryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[DECRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
                
                Write-Verbose "[DECRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[DECRYPT] Value type: $($value.GetType().FullName)"
                
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
                
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveDecryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($value -is [string] -and (TestIsBase64String -Value $value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($value))
                            $result[$key] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for key '$key' at path '$currentPropertyPath'. Value: '$value'. Assigning original value."
                            $result[$key] = $value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Hashtable key '$key' is not a decodable string. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
            
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[DECRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[DECRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[decrypt] Property type: $($prop.Value.GetType().FullName)"
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[DECRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[DECRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, attempt to decrypt if it's a string
                {
                    if ($prop.Value -is [string] -and (TestIsBase64String -Value $prop.Value))
                    {
                        Write-Verbose ("[DECRYPT] Attempting to decrypt string value for {0}" -f $currentPropertyPath)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($prop.Value))
                            $result[$prop.Name] = $decodedValue
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPropertyPath, $decodedValue)
                        }
                        catch
                        {
                            Write-Warning "[DECRYPT] Failed to decode Base64 string for property '$($prop.Name)' at path '$currentPropertyPath'. Value: '$($prop.Value)'. Assigning original value."
                            $result[$prop.Name] = $prop.Value # Keep original if not valid Base64 or UTF8
                        }
                    }
                    else
                    {
                        # Not a string, not Base64, or some other primitive type that wasn't encrypted
                        Write-Verbose "[DECRYPT] Property '$($prop.Name)' is not a decodable string. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string element directly in an array)
        elseif ($InputObject -is [string])
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this string) was excluded
            {
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            elseif (TestIsBase64String -Value $InputObject)
            {
                Write-Verbose ("[DECRYPT] Attempting to decrypt primitive string value at path '{0}'" -f $ParentPath)
                try
                {
                    $decodedValuePrim = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
                    Write-Verbose ("[DECRYPT] Decrypted primitive value at path '{0}': {1}" -f $ParentPath, $decodedValuePrim)
                    return $decodedValuePrim
                }
                catch
                {
                    Write-Warning "[DECRYPT] Failed to decode Base64 string for primitive at path '$ParentPath'. Value: '$InputObject'. Returning original value."
                    return $InputObject # Keep original if not valid Base64 or UTF8
                }
            }
            else
            {
                # Not Base64, return as is
                Write-Verbose "[DECRYPT] Primitive string at path '$ParentPath' is not Base64. Returning as-is."
                return $InputObject
            }
        }
        else # Other primitive types (int, bool, etc.) or other object types, return as is
        {
            Write-Verbose "[DECRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not a string or already handled. Returning as-is."
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

function EncryptObject
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
            [string]$ParentPath = "",
            [bool]$ParentIsExcluded = $false # New parameter
        )

        if ($null -eq $InputObject)
        {
            Write-Verbose "[ENCRYPT] InputObject is null at path '$ParentPath'. Returning null."; return $null 
        }
        Write-Verbose "[ENCRYPT] Path: '$ParentPath', ParentIsExcluded: $ParentIsExcluded, Type: $($InputObject.GetType().FullName)"

        if ($InputObject -is [array])
        {
            Write-Verbose "[ENCRYPT] Processing array at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $resultArray = @()
            for ($i = 0; $i -lt $InputObject.Count; $i++)
            {
                $element = $InputObject[$i]
                $currentElementPath = if ($ParentPath)
                {
                    "$ParentPath[$i]" 
                }
                else
                {
                    "[$i]" 
                }
                # Pass ParentIsExcluded status to array elements
                $resultArray += Invoke-RecursiveEncryption -InputObject $element -ExcludeFields $ExcludeFields -ParentPath $currentElementPath -ParentIsExcluded $ParentIsExcluded
            }
            return $resultArray
        }
        elseif ($InputObject -is [hashtable])
        {
            Write-Verbose "[ENCRYPT] Processing hashtable at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            
            # Process hashtable by enumerating through the key-value pairs directly
            foreach ($entry in $InputObject.GetEnumerator())
            {
                $key = $entry.Key
                $value = $entry.Value
                
                Write-Verbose "[ENCRYPT] Processing hashtable key '$key' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Value type: $($value.GetType().FullName)"
                Write-Verbose "[ENCRYPT] Value: $value"
                
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$key" 
                }
                else
                {
                    $key 
                }
                
                $isPropertyItselfExcluded = $ExcludeFields -contains $key
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded

                Write-Verbose "[ENCRYPT] Hashtable key: '$key' at path '$currentPropertyPath'. KeyItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"

                if ($null -eq $value)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' has null value. Assigning null."
                    $result[$key] = $null
                }
                elseif ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$key] = Invoke-RecursiveEncryption -InputObject $value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Hashtable key '$key' is effectively excluded. Assigning original value."
                    $result[$key] = $value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($value -is [string] -or $value -is [int] -or $value -is [bool] -or $value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$key] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, $encodedValue)
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Hashtable key '$key' value type '$($value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$key] = $value
                    }
                }
            }
            
            return $result
        }
        elseif ($InputObject -is [PSCustomObject])
        {
            Write-Verbose "[ENCRYPT] Processing object at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
            $result = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties)
            {
                Write-Verbose "[ENCRYPT] Processing property '$($prop.Name)' at path '$ParentPath'. Inherited ParentIsExcluded: $ParentIsExcluded"
                Write-Verbose "[ENCRYPT] Property type: $($prop.Value.GetType().FullName)"
                if ($prop.Name -in $excludeFields)
                {
                    Write-Verbose "[ENCRYPT] Property value: $($prop.Value)"    
                }
                $currentPropertyPath = if ($ParentPath)
                {
                    "$ParentPath.$($prop.Name)" 
                }
                else
                {
                    $prop.Name 
                }
                $isPropertyItselfExcluded = $ExcludeFields -contains $prop.Name
                $isEffectivelyExcluded = $ParentIsExcluded -or $isPropertyItselfExcluded
                Write-Verbose "[ENCRYPT] Property: '$($prop.Name)' at path '$currentPropertyPath'. PropItselfExcluded: $isPropertyItselfExcluded, ParentIsExcluded: $ParentIsExcluded, EffectiveExcluded: $isEffectivelyExcluded"
                if ($null -eq $prop.Value)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is null. Assigning null."
                    $result[$prop.Name] = $null
                }
                elseif ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                {
                    # Recurse for nested structures, passing the effective exclusion status
                    $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPropertyPath -ParentIsExcluded $isEffectivelyExcluded
                }
                elseif ($isEffectivelyExcluded)
                {
                    Write-Verbose "[ENCRYPT] Property '$($prop.Name)' is effectively excluded. Assigning original value."
                    $result[$prop.Name] = $prop.Value
                }
                else # Not effectively excluded, encrypt appropriate types
                {
                    # Encrypt strings, numbers, booleans. Other complex types not directly handled here will be returned as-is by the final 'else'.
                    if ($prop.Value -is [string] -or $prop.Value -is [int] -or $prop.Value -is [bool] -or $prop.Value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}" -f $currentPropertyPath)
                        $stringValue = $prop.Value.ToString() # Convert boolean/numbers to string before encoding
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        $result[$prop.Name] = $encodedValue
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPropertyPath, 'redacted')
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Property '$($prop.Name)' type '$($prop.Value.GetType().FullName)' not directly encrypted. Assigning original value."
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            return [PSCustomObject]$result
        }
        # Handle standalone primitive types (e.g., a string/number/bool element directly in an array)
        elseif (($InputObject -is [string] -or $InputObject -is [int] -or $InputObject -is [bool] -or $InputObject -is [double]))
        {
            if ($ParentIsExcluded) # If the parent (e.g. an array holding this primitive) was excluded
            {
                Write-Verbose "[ENCRYPT] Primitive value at path '$ParentPath' is part of an excluded parent. Returning as-is."
                return $InputObject
            }
            else
            {
                Write-Verbose ("[ENCRYPT] Encrypting primitive value at path '{0}'" -f $ParentPath)
                $stringValuePrim = $InputObject.ToString()
                $encodedValuePrim = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValuePrim))
                Write-Verbose ("[ENCRYPT] Encrypted primitive value at path '{0}': {1}" -f $ParentPath, $encodedValuePrim)
                return $encodedValuePrim
            }
        }
        else # Other types not explicitly handled (e.g. custom objects not PSCustomObject/hashtable, or other primitive types if any), return as is.
        {
            Write-Verbose "[ENCRYPT] Value type '$($InputObject.GetType().FullName)' at path '$ParentPath' not processed for encryption. Returning as-is."
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

function DecryptAndEncrypt()
{
    param (
        $data,
        [string[]]$excludeFields = $excludeFields,
        [string]$operation
    )
    
    # ### Main script ###
    if ($operation -eq 'encrypt')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is already encrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = EncryptObject -decryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'decrypt')
    {
        if (!(isEncrypted -data $data))
        {
            Write-Host 'The data is already decrypted.'
            Write-Host 'Nothing to do.'
            exit
        }
        $encodedData = DecryptObject -encryptedObject $data -excludeFields $excludeFields
    }
    elseif ($operation -eq 'check')
    {
        if (isEncrypted -data $data)
        {
            Write-Host 'The data is encrypted.'
        }
        else
        {
            Write-Host "The data in $inputFile is not encrypted."
        }
        exit
    }
    else
    {
        Write-Error 'No operation was specified.'
        exit
    }


    #make sure the output file exists.  If so, prompt to overwrite., otherwise create, unless the Force switch is set.
    if (Test-Path $outputFile)
    {
        if ($Force)
        {
            Clear-Content -Path $OutputFile
        }
        else
        {
            $overwrite = Read-Host -Prompt "The file $outputFile already exists.  Do you want to overwrite it? (Y/N)"
            if ($overwrite -eq 'Y')
            {
                Clear-Content -Path $OutputFile
            }
            else
            {
                Write-Host "The file $outputFile was not overwritten.  Exiting."
                exit
            }
        }
    }
    else
    {
        New-Item -Path $OutputFile -ItemType File -Force | Out-Null
    }


    #write the encoded data to the output file if it is not null.
    if ($encodedData)
    {
        Write-Host "Processing data in $inputFile"
        Write-Host "Writing data to $outputFile"
        Write-Verbose "The encoded data is: $($encodedData | ConvertTo-Json)"
        $encodedData | ConvertTo-Json | Set-Content -Path $outputFile -ErrorAction Stop
        Write-Host 'Data processed successfully.'
    }
    else
    {
        Write-Host 'No data was processed.'
        exit
    }
}