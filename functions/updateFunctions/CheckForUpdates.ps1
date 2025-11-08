function CheckForUpdates()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$remoteVersionURL,
        [Parameter(Mandatory = $true)]
        [version]$localVersion
    )

    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{
        Version         = $null
        ReleaseDate     = $null
        Hash            = $null
        success         = $false                        
        updateAvailable = $false
        versionsMatch   = $false      
    }
    Write-Verbose "[$functionName] Remote Version URL: $remoteVersionURL"
    Write-Verbose "[$functionName] Getting remote version from $remoteVersionURL"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting remote version from $remoteVersionURL" -LogLevel "Information"
    try 
    {
        $remoteVersionResponse = Invoke-RestMethod -Uri $remoteVersionURL -Method Get -ErrorAction SilentlyContinue -UseBasicParsing
        if (-not $remoteVersionResponse)
        {
            write-log -logFile $LogFile -Module "$functionName" -Message "Failed to retrieve remote version information." -LogLevel "Error"
            throw "Failed to retrieve remote version information."
        }   
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
        if ([System.Version]::Parse($remoteVersionResponse.version) -gt $localVersion)
        {
            Write-Verbose "[$functionName] Update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
            $returnObject.updateAvailable = $true
        }   
        elseif ([System.Version]::Parse($remoteVersionResponse.version) -eq $localVersion)
        {
            Write-Verbose "[$functionName] Versions match. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Versions match. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
            $returnObject.versionsMatch = $true
            $returnObject.updateAvailable = $false
        }                       
        else
        {
            Write-Verbose "[$functionName] No update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
            $returnObject.updateAvailable = $false
            $returnObject.versionsMatch = $false
        }
        Write-Verbose "[$functionName] Success: $($returnObject.success)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Success: $($returnObject.success)" -LogLevel "Information"
        Write-Verbose "[$functionName] Version: $($returnObject.Version)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Version: $($returnObject.Version)" -LogLevel "Information"
        Write-Verbose "[$functionName] Release Date: $($returnObject.ReleaseDate)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Release Date: $($returnObject.ReleaseDate)" -LogLevel "Information"
        Write-Verbose "[$functionName] Hash: $($returnObject.Hash)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Hash: $($returnObject.Hash)" -LogLevel "Information"
        Write-Verbose "[$functionName] Update Available: $($returnObject.updateAvailable)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update Available: $($returnObject.updateAvailable)" -LogLevel "Information"
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
        return $returnObject
    }    
    #endregion
}   

