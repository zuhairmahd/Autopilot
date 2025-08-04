function Get-DecryptedConfigValue()
{
    <#
    .SYNOPSIS
    Retrieves a configuration value from the temporarily encrypted configuration.
    
    .DESCRIPTION
    This function decrypts the temporary configuration and retrieves a specific value.
    This is used during runtime to access configuration values without keeping them in plain text.
    
    .PARAMETER PropertyPath
    The path to the property to retrieve (e.g., "auth.AppId").
    
    .OUTPUTS
    Returns the decrypted configuration value.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PropertyPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Retrieving config value for path: $PropertyPath" -LogLevel "Debug"
    Write-Verbose "[$functionName] Retrieving config value for path: $PropertyPath"
    
    if (-not $script:TempEncryptedConfig -or -not $script:TempEncryptionKey)
    {
        Write-Error "No temporary encrypted configuration available"
        Write-Log -LogFile $LogFile -Module $functionName -Message "No temporary encrypted configuration available" -LogLevel "Error"
        return $null
    }
    
    # Create a temporary file to decrypt
    $tempFile = [System.IO.Path]::GetTempFileName()
    Write-Log -LogFile $LogFile -Module $functionName -Message "Created temporary file for decryption" -LogLevel "Debug"
    
    try
    {
        Set-Content -Path $tempFile -Value $script:TempEncryptedConfig -Encoding UTF8
        
        # Decrypt the content
        $decryptResult = Invoke-JsonFileEncryption -FilePath $tempFile -Key $script:TempEncryptionKey -Decrypt -InMemoryOnly
        
        if ($decryptResult.Success)
        {
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully decrypted configuration for property access" -LogLevel "Debug"
            $config = ConvertFrom-Json $decryptResult.Content
            
            # Navigate the property path
            $pathParts = $PropertyPath.Split('.')
            $current = $config
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Navigating property path with $($pathParts.Length) segments" -LogLevel "Debug"
            
            foreach ($part in $pathParts)
            {
                if ($current.PSObject.Properties.Name -contains $part)
                {
                    $current = $current.$part
                }
                else
                {
                    Write-Verbose "[$functionName] Property path '$PropertyPath' not found in configuration"
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Property path '$PropertyPath' not found in configuration" -LogLevel "debug"
                    return $null
                }
            }
            
            Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully retrieved configuration value for path: $PropertyPath" -LogLevel "Debug"
            return $current
        }
        else
        {
            Write-Error "Failed to decrypt temporary configuration: $($decryptResult.ErrorMessage)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to decrypt temporary configuration: $($decryptResult.ErrorMessage)" -LogLevel "Error"
            return $null
        }
    }
    finally
    {
        # Clean up temporary file
        if (Test-Path $tempFile)
        {
            Remove-Item $tempFile -Force
            Write-Log -LogFile $LogFile -Module $functionName -Message "Cleaned up temporary file" -LogLevel "Debug"
        }
    }
}

