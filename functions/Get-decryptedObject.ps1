function Get-decryptedObject()
<#
.SYNOPSIS
    A function to decrypt the values in a hash table.
.DESCRIPTION
    This function will decrypt the values in a hash table.  The function will iterate through the properties of the hash table and check if the property is in the exclude list.  If the property is in the exclude list, the function will skip the property.  If the property is not in the exclude list, the function will decode the value from base 64 and add the decoded value to a new hash table.
.EXAMPLE
    Get-decryptedObject -encryptedObject $data -excludeFields 'password'
    This will decrypt the values in the data hash table and exclude the password field.
#>
{
    [CmdletBinding()]
    param (
        [psObject]$encryptedObject,
        [string[]]$excludeFields
    )
    $decryptedObject = @{}
    foreach ($prop in $encryptedObject.PSObject.Properties)
    {
        Write-Verbose "The exclude list is $($excludeFields -join ',')"
        Write-Verbose "Checking if $($prop.Name) is in the exclude list."
        if ($excludeFields -contains $prop.Name)
        {
            Write-Verbose "Skipping $($prop.Name) because it is in the exclude list."
            Write-Verbose "Adding the raw entry $($prop.Name) with value $($prop.Value) to the decrypted object."            
            $decryptedObject.Add($prop.Name, $prop.Value)
            continue
        }
        Write-Verbose "Decrypting $($prop.Name) with value $($prop.Value)"
        $propValue = $prop.Value.ToString()
        #convert the value from base 64 to a regular string.
        $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($propValue))
        Write-Verbose "The unencrypted value for $($prop.Name) is $decodedValue"
        #add the decoded dictionary to the hash table.
        $decryptedObject.Add($prop.Name, $decodedValue)
    }
    if ($decryptedObject)
    {
        Write-Verbose "The decoded data is: $($decodedData | ConvertTo-Json)"
        return $decryptedObject
    }
    else
    {
        Write-Host 'No values were decrypted.'
        return $null
    }
}

