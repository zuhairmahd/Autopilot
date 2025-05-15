function isEncrypted()
{ 
    [CmdletBinding()]
    param (
        [psObject]$data
    )
    $functionName = $MyInvocation.MyCommand.Name
    $isEncrypted = $false
    $encryptedCount = 0
    $unencryptedCount = 0
    Write-Verbose "[$functionName] Checking if the data is encrypted."
    foreach ($prop in $data.PSObject.Properties)
    {
        Write-Verbose "[$functionName] Checking if the value of $($prop.Name) is encrypted."
        if ($(try
                {
                    $null = [Convert]::FromBase64String($prop.Value); $true 
                }
                catch
                {
                    $false 
                }))
        {
            Write-Verbose "[$functionName] The value for $($prop.Name) is encrypted."
            $encryptedCount++
        }
        else
        {
            Write-Verbose "[$functionName] The value for $($prop.Name) is not encrypted."
            $unencryptedCount++
        }
    }
    Write-Verbose "[$functionName] The number of encrypted values is $encryptedCount"
    Write-Verbose "[$functionName] The number of unencrypted values is $unencryptedCount"
    #If the number of encrypted values is greater than the number of unencrypted values, the data is encrypted.
    if ($encryptedCount -gt $unencryptedCount)
    {
        $isEncrypted = $true
    }
    Write-Verbose "[$functionName] The data is encrypted: $isEncrypted"
    return $isEncrypted
}
