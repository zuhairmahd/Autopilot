function CheckForUpdates()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$remoteVersionURL
    )

    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{}
    Write-Verbose "[$functionName] Remote Version URL: $remoteVersionURL"
    Write-Verbose "[$functionName] Getting remote version from $remoteVersionURL"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting remote version from $remoteVersionURL" -LogLevel "Information"
    try 
    {
        $remoteVersionResponse = Invoke-RestMethod -Uri $remoteVersionURL -Method Get -ErrorAction SilentlyContinue -UseBasicParsing
        #convert $remoteVersionResponse.date to a datetime object in local time.
        $remoteVersionResponse.date = [datetime]::Parse($remoteVersionResponse.date).ToLocalTime()
        Write-Verbose "[$functionName] Response received from $($remoteVersionURL): $($remoteVersionResponse.StatusCode)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response received from $($remoteVersionURL): $($remoteVersionResponse.StatusCode)" -LogLevel "Information"
        $returnObject = @{
            Version     = [System.Version]::Parse($remoteVersionResponse.version)
            ReleaseDate = $remoteVersionResponse.date
            Hash        = $remoteVersionResponse.hash
            success     = $true
        }       
        Write-Verbose "[$functionName] Success: $($returnObject.success)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Success: $($returnObject.success)" -LogLevel "Information"
        Write-Verbose "[$functionName] Version: $($returnObject.Version)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Version: $($returnObject.Version)" -LogLevel "Information"
        Write-Verbose "[$functionName] Release Date: $($returnObject.ReleaseDate)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Release Date: $($returnObject.ReleaseDate)" -LogLevel "Information"
        Write-Verbose "[$functionName] Hash: $($returnObject.Hash)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Hash: $($returnObject.Hash)" -LogLevel "Information"
        return $returnObject
    }
    catch 
    {
        Write-Verbose "[$functionName] Response: $($remoteVersionResponse)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Response: $($remoteVersionResponse)" -LogLevel "Error"
        Write-Verbose "[$functionName] Remote version status code: $($remoteVersionResponse.StatusCode)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Remote version status code: $($remoteVersionResponse.StatusCode)" -LogLevel "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error: $($_.Exception.Message)" -LogLevel "Error"
        return $null
    }    
    #endregion
}   

