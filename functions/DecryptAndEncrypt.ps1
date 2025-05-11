$excludeFields = @('domain', 'name', 'scopes')
function TestIsBase64String
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
            [string[]]$ExcludeFields = @('domain', 'appName', 'name'),
            [string]$ParentPath = ""
        )
    
        if ($null -eq $InputObject)
        {
            return $null
        }
    
        # Check if current path is in excluded fields or parent path is excluded
        $isPathExcluded = $false
        if ($ParentPath)
        {
            Write-Verbose "[DECRYPT] Extracting base property from '$ParentPath'"
            # Extract the base property name from the parent path
            $baseProperty = $ParentPath -replace '.*\.' -replace '\[\d+\].*$'
            Write-Verbose "[DECRYPT] Base property is '$baseProperty'"
            $isPathExcluded = $ExcludeFields -contains $baseProperty
            Write-Verbose "[DECRYPT] Path '$ParentPath' (base: '$baseProperty') is excluded: $isPathExcluded"
        }
    
        # Handle array type
        if ($InputObject -is [array])
        {
            Write-Verbose "[DECRYPT] Processing array of $($InputObject.Count) elements at path '$ParentPath' (excluded: $isPathExcluded)"
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
                Write-Verbose "[DECRYPT] Processing array element $i at path '$currentPath' (excluded: $isPathExcluded)"
                $decryptedItem = Invoke-RecursiveDecryption -InputObject $InputObject[$i] -ExcludeFields $ExcludeFields -ParentPath $currentPath
                $resultArray += $decryptedItem
            }
            Write-Verbose "[DECRYPT] Finished processing array at path '$ParentPath'"
            return $resultArray
        }
        # Handle object type
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            Write-Verbose "[DECRYPT] Processing object at path '$ParentPath' (excluded: $isPathExcluded)"
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
                Write-Verbose "[DECRYPT] Processing property: $currentPath"
                # Check if this property is excluded directly or via parent
                $isExcluded = $ExcludeFields -contains $prop.Name -or $isPathExcluded
                Write-Verbose "[DECRYPT] Property '$($prop.Name)' isExcluded: $isExcluded (parent excluded: $isPathExcluded)"
                if ($isExcluded)
                {
                    Write-Verbose "[DECRYPT] Property $($prop.Name) is in exclude list or within excluded parent, skipping decryption."
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                    {
                        Write-Verbose "[DECRYPT] Recursing into excluded property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    else
                    {
                        Write-Verbose "[DECRYPT] Assigning excluded value for property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = $prop.Value
                    }
                }
                else
                {
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable])
                    {
                        Write-Verbose "[DECRYPT] Recursing into object property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [array])
                    {
                        Write-Verbose "[DECRYPT] Recursing into array property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = Invoke-RecursiveDecryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [string] -and (Test-IsBase64String -Value $prop.Value))
                    {
                        Write-Verbose ("[DECRYPT] Decrypting string value for {0}: {1}" -f $currentPath, $prop.Value)
                        try
                        {
                            $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($prop.Value))
                            Write-Verbose ("[DECRYPT] Decrypted value for {0}: {1}" -f $currentPath, $decodedValue)
                            $result[$prop.Name] = $decodedValue
                        }
                        catch
                        {
                            Write-Verbose "[DECRYPT] Failed to decrypt value for $currentPath, keeping as is"
                            $result[$prop.Name] = $prop.Value
                        }
                    }
                    else
                    {
                        Write-Verbose "[DECRYPT] Assigning non-decrypted value for property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            Write-Verbose "[DECRYPT] Finished processing object at path '$ParentPath'"
            return [PSCustomObject]$result
        }
        # Handle string (potential base64) - but skip if in excluded path
        elseif ($InputObject -is [string] -and (Test-IsBase64String -Value $InputObject) -and !$isPathExcluded)
        {
            Write-Verbose ("[DECRYPT] Decrypting primitive value at path '{0}': {1}" -f $ParentPath, $InputObject)
            try
            {
                $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($InputObject))
                Write-Verbose ("[DECRYPT] Decrypted primitive value at path '{0}': {1}" -f $ParentPath, $decodedValue)
                return $decodedValue
            }
            catch
            {
                Write-Verbose "[DECRYPT] Failed to decrypt primitive value at path '$ParentPath', keeping as is"
                return $InputObject
            }
        }
        # Return as is for everything else or if excluded
        else
        {
            Write-Verbose "[DECRYPT] Returning value as-is at path '$ParentPath' (excluded: $isPathExcluded)"
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
            [string]$ParentPath = ""
        )
        
        if ($null -eq $InputObject)
        {
            return $null
        }
        #log verbose the type of the inputobject.
        Write-Verbose "The type of the input object is $($InputObject.GetType().FullName)"

        # Check if current path is in excluded fields or parent path is excluded
        $isPathExcluded = $false
        if ($ParentPath)
        {
            Write-Verbose "[ENCRYPT] Extracting base property from '$ParentPath'"
            # Extract the base property name from the parent path (handles both array.property and property.subproperty patterns)
            $baseProperty = $ParentPath -replace '.*\.' -replace '\[\d+\].*$'
            Write-Verbose "[ENCRYPT] Base property is '$baseProperty'"
            $isPathExcluded = $ExcludeFields -contains $baseProperty
            Write-Verbose "[ENCRYPT] Path '$ParentPath' (base: '$baseProperty') is excluded: $isPathExcluded"
        }

        # Handle array type
        if ($InputObject -is [array])
        {
            Write-Verbose "[ENCRYPT] Processing array at path '$ParentPath' (excluded: $isPathExcluded)"
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
                Write-Verbose "[ENCRYPT] Processing array element $i at path '$currentPath' (excluded: $isPathExcluded)"
                # Pass the current exclusion status to child elements
                $encryptedItem = Invoke-RecursiveEncryption -InputObject $InputObject[$i] -ExcludeFields $ExcludeFields -ParentPath $currentPath
                $resultArray += $encryptedItem
            }
            Write-Verbose "[ENCRYPT] Finished processing array at path '$ParentPath'"
            return $resultArray
        }
        # Handle object type
        elseif ($InputObject -is [PSCustomObject] -or $InputObject -is [hashtable])
        {
            Write-Verbose "[ENCRYPT] Processing object at path '$ParentPath' (excluded: $isPathExcluded)"
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
                Write-Verbose "[ENCRYPT] Processing property: $currentPath"
            
                # Check if this property is excluded directly or via parent
                $isExcluded = $ExcludeFields -contains $prop.Name -or $isPathExcluded
                Write-Verbose "[ENCRYPT] Property '$($prop.Name)' isExcluded: $isExcluded (parent excluded: $isPathExcluded)"
                if ($isExcluded)
                {
                    Write-Verbose "[ENCRYPT] Property $($prop.Name) is in exclude list or within excluded parent, skipping encryption."
                    # For excluded fields, still process any nested objects/arrays but don't encrypt the value itself
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable] -or $prop.Value -is [array])
                    {
                        Write-Verbose "[ENCRYPT] Recursing into excluded property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Assigning excluded value for property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = $prop.Value
                    }
                }
                else
                {
                    # Process based on value type
                    if ($prop.Value -is [PSCustomObject] -or $prop.Value -is [hashtable])
                    {
                        Write-Verbose "[ENCRYPT] Recursing into object property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [array])
                    {
                        Write-Verbose "[ENCRYPT] Recursing into array property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = Invoke-RecursiveEncryption -InputObject $prop.Value -ExcludeFields $ExcludeFields -ParentPath $currentPath
                    }
                    elseif ($prop.Value -is [string] -or $prop.Value -is [int] -or $prop.Value -is [bool] -or $prop.Value -is [double])
                    {
                        Write-Verbose ("[ENCRYPT] Encrypting value for {0}: {1}" -f $currentPath, $prop.Value)
                        $stringValue = $prop.Value.ToString()
                        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
                        Write-Verbose ("[ENCRYPT] Encrypted value for {0}: {1}" -f $currentPath, $encodedValue)
                        $result[$prop.Name] = $encodedValue
                    }
                    else
                    {
                        Write-Verbose "[ENCRYPT] Assigning non-encrypted value for property '$($prop.Name)' at path '$currentPath'"
                        $result[$prop.Name] = $prop.Value
                    }
                }
            }
            Write-Verbose "[ENCRYPT] Finished processing object at path '$ParentPath'"
            return [PSCustomObject]$result
        }
        # Handle primitive types (strings, numbers, booleans) - but skip if in excluded path
        elseif (($InputObject -is [string] -or $InputObject -is [int] -or $InputObject -is [bool] -or $InputObject -is [double]) -and !$isPathExcluded)
        {
            Write-Verbose ("[ENCRYPT] Encrypting primitive value at path '{0}': {1}" -f $ParentPath, $InputObject)
            $stringValue = $InputObject.ToString()
            $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringValue))
            Write-Verbose ("[ENCRYPT] Encrypted primitive value at path '{0}': {1}" -f $ParentPath, $encodedValue)
            return $encodedValue
        }
        # Return as is for everything else or if excluded
        else
        {
            Write-Verbose "[ENCRYPT] Returning value as-is at path '$ParentPath' (excluded: $isPathExcluded)"
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