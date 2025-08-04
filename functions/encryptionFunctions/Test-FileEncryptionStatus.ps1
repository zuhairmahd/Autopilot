function Test-FileEncryptionStatus()
{
    <#
    .SYNOPSIS
    Tests whether a JSON file is encrypted or not.
    
    .DESCRIPTION
    This function examines a file to determine if it contains encrypted content.
    It checks if the file content is valid Base64 (indicating encryption) or valid JSON (indicating unencrypted).
    
    .PARAMETER FilePath
    The path to the file to check.
    
    .OUTPUTS
    Returns a hashtable with the following properties:
    - IsEncrypted: Boolean indicating if the file is encrypted
    - IsValidFile: Boolean indicating if the file exists and is readable
    - FileContent: The raw content of the file (for debugging)
    - ErrorMessage: Any error encountered during the check
    
    .EXAMPLE
    $status = Test-FileEncryptionStatus -FilePath "C:\config.json"
    if ($status.IsEncrypted) {
        Write-Host "File is encrypted"
    } else {
        Write-Host "File is not encrypted"
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Log -LogFile $LogFile -Module $functionName -Message "Starting file encryption status check for: $FilePath" -LogLevel "Debug"
    Write-Verbose "[$functionName] Checking encryption status of file: $FilePath"
    
    # Initialize result object
    $result = @{
        IsEncrypted  = $false
        IsValidFile  = $false
        FileContent  = $null
        ErrorMessage = $null
    }
    
    try
    {
        # Check if file exists
        if (-not (Test-Path $FilePath))
        {
            $result.ErrorMessage = "File does not exist: $FilePath"
            Write-Verbose "[$functionName] File not found: $FilePath"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File not found: $FilePath" -LogLevel "Error"
            return $result
        }
        
        # Read file content
        $fileContent = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
        $result.FileContent = $fileContent
        $result.IsValidFile = $true
        
        Write-Log -LogFile $LogFile -Module $functionName -Message "Successfully read file. Content length: $($fileContent.Length) characters" -LogLevel "Debug"
        
        if ([string]::IsNullOrWhiteSpace($fileContent))
        {
            $result.ErrorMessage = "File is empty or contains only whitespace"
            Write-Verbose "[$functionName] File is empty: $FilePath"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is empty or contains only whitespace" -LogLevel "Warning"
            return $result
        }
        
        Write-Verbose "[$functionName] File content length: $($fileContent.Length) characters"
        
        # First, try to parse as JSON (unencrypted)
        try
        {
            $null = ConvertFrom-Json $fileContent -ErrorAction Stop
            $result.IsEncrypted = $false
            Write-Verbose "[$functionName] File contains valid JSON - not encrypted"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File contains valid JSON - not encrypted" -LogLevel "Debug"
            return $result
        }
        catch
        {
            Write-Verbose "[$functionName] File is not valid JSON, checking if it's encrypted..."
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is not valid JSON, checking if it's encrypted" -LogLevel "Debug"
        }
        
        # If not JSON, check if it's Base64 encoded (encrypted)
        try
        {
            $decodedBytes = [Convert]::FromBase64String($fileContent.Trim())
            if ($decodedBytes.Length -ge 16)
            {
                # Minimum size for IV + some encrypted content
                $result.IsEncrypted = $true
                Write-Verbose "[$functionName] File contains valid Base64 with sufficient length - appears encrypted"
                Write-Log -LogFile $LogFile -Module $functionName -Message "File contains valid Base64 with sufficient length - appears encrypted" -LogLevel "Debug"
                return $result
            }
            else
            {
                $result.ErrorMessage = "File appears to be Base64 but is too short to be properly encrypted"
                Write-Verbose "[$functionName] Base64 data too short for encryption"
                Write-Log -LogFile $LogFile -Module $functionName -Message "Base64 data too short for encryption" -LogLevel "Warning"
                return $result
            }
        }
        catch
        {
            $result.ErrorMessage = "File is neither valid JSON nor valid Base64 - unknown format"
            Write-Verbose "[$functionName] File is not valid Base64 either: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module $functionName -Message "File is neither valid JSON nor valid Base64 - unknown format" -LogLevel "Warning"
            return $result
        }
    }
    catch
    {
        $result.ErrorMessage = "Error reading file: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Error reading file: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error reading file: $($_.Exception.Message)" -LogLevel "Error"
        return $result
    }
}

