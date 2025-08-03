function CheckForUpdates()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$remoteVersionURL
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Remote Version URL: $remoteVersionURL"
    Write-Verbose "[$functionName] Getting remote version from $remoteVersionURL"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting remote version from $remoteVersionURL" -LogLevel "Information"
    try 
    {
        $remoteVersionResponse = Invoke-WebRequest -Uri $remoteVersionURL -Method Get -ErrorAction SilentlyContinue -UseBasicParsing
        Write-Verbose "[$functionName] Response received from $($remoteVersionURL): $($remoteVersionResponse.StatusCode)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response received from $($remoteVersionURL): $($remoteVersionResponse.StatusCode)" -LogLevel "Information"
        $remoteVersion = ($remoteVersionResponse.Content | ConvertFrom-Json).version
    }
    catch 
    {
        Write-Verbose "[$functionName] Response: $($remoteVersionResponse)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response: $($remoteVersionResponse)" -LogLevel "Error"
        Write-Verbose "[$functionName] Remote version status code: $($remoteVersionResponse.StatusCode)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Remote version status code: $($remoteVersionResponse.StatusCode)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error: $($_.Exception.Message)" -LogLevel "Error"
        return $remoteVersionResponse.StatusCode, $false
    }    
    Write-Verbose "[$functionName] Returned remote version response: $remoteVersion"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Returned remote version response: $remoteVersion" -LogLevel "Information"
    $remoteVersion = [System.Version]::Parse($remoteVersion)
    return $remoteVersion, $true
    #endregion
}   

