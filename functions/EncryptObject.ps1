function EncryptObject()
{
    <#
.SYNOPSIS
    A function to encrypt the values in a hash table.
.DESCRIPTION
    This function will encrypt the values in a hash table. The function will iterate through the properties of the hash table and check if the property is in the exclude list. If the property is in the exclude list, the function will skip the property. If the property is not in the exclude list, the function will encode the value to base64 and add the encoded value to a new hash table.
.EXAMPLE
    Get-EncryptedObject -plainObject $data -excludeFields 'password'
    This will encrypt the values in the data hash table and exclude the password field.
.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
#>
    [CmdletBinding()]
    param (
        [psObject]$plainObject,
        [string[]]$excludeFields
    )
    $encryptedObject = @{}
    foreach ($prop in $plainObject.PSObject.Properties)
    {
        Write-Verbose "The exclude list is $($excludeFields -join ',')"
        Write-Verbose "Checking if $($prop.Name) is in the exclude list."
        if ($excludeFields -contains $prop.Name)
        {
            Write-Verbose "Skipping $($prop.Name) because it is in the exclude list."
            Write-Verbose "Adding the raw entry $($prop.Name) with value $($prop.Value) to the encrypted object."
            $encryptedObject.Add($prop.Name, $prop.Value)
            continue
        }
        Write-Verbose "Encrypting $($prop.Name)."
        $propValue = $prop.Value.ToString()
        # Convert the value to base64 string.
        $encodedValue = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($propValue))
        # Check if the encoding was successful.
        if ($null -ne $encodedValue)
        {
            Write-Verbose "Successfully encrypted $($prop.Name)."
            # Add the encoded dictionary to the hash table.
            $encryptedObject.Add($prop.Name, $encodedValue)
        }
        else
        {
            Write-Verbose "Failed to encrypt $($prop.Name)."
            # Add the raw entry to the hash table.
            $encryptedObject.Add($prop.Name, $propValue)
        }
    }
    if ($encryptedObject)
    {
        return $encryptedObject
    }
    else
    {
        Write-Host 'No values were encrypted.'
        return $null
    }
}
