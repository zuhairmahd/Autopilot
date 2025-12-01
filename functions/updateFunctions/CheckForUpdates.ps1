function CheckForUpdates()
{
    <#
    .SYNOPSIS
    Checks if a newer version of the application is available remotely.

    .DESCRIPTION
    This function compares the local executable version with the remote version by retrieving
    version information from a specified URL. It validates the executable file, retrieves
    both local and remote version information, and determines if an update is available.
    The function returns detailed version comparison information including hashes and release dates.

    .PARAMETER remoteVersionURL
    The URL to retrieve remote version information from. This parameter is mandatory.

    .PARAMETER executableFileName
    The name of the local executable file to check. Must have .exe extension. This parameter is mandatory.

    .OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable with properties:
    - localVersion: Local version object
    - remoteVersion: Remote version object
    - version: Version string
    - ReleaseDate: Release date of remote version
    - Hash: Hash of remote version
    - success: Boolean indicating successful version check
    - updateAvailable: Boolean indicating if update is available
    - versionsMatch: Boolean indicating if versions match

    .EXAMPLE
    $updateInfo = CheckForUpdates -remoteVersionURL "https://example.com/version.json" -executableFileName "main.exe"
    if ($updateInfo.updateAvailable) {
        Write-Host "Update available: $($updateInfo.remoteVersion)"
    }

    .NOTES
    Automatically corrects file extension to .exe if not provided.
    Compares version objects using System.Version comparison.
    Includes comprehensive error handling and logging.
    Compatible with PowerShell 5.1.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$remoteVersionURL,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$executableFileName
    )

    $functionName = $MyInvocation.MyCommand.Name
    $returnObject = @{
        localVersion    = $null
        remoteVersion   = $null      
        version         = $null  
        ReleaseDate     = $null
        releaseNotes    = $null    
        Hash            = $null
        success         = $false                        
        updateAvailable = $false
        versionsMatch   = $false      
    }
    if ($executableFileName -notmatch 'exe')
    {
        Write-Verbose "[$functionName] The provided executable file name '$executableFileName' does not match 'exe'."
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "The provided executable file name '$executableFileName' does not match 'exe'. Checking for similar executable." -LogLevel "Warning"
        #replace whatever the extension of $executableFileName with .exe
        $executableFileName = [System.IO.Path]::ChangeExtension($executableFileName, ".exe")
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executable filename resolved to $executableFileName" -LogLevel "Information"
        if (-not (Test-Path $executableFileName))
        {
            Write-Verbose "[$functionName] No similar executable found."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No similar executable found." -LogLevel "Warning"
            return $returnObject
        }
        Write-Verbose "[$functionName] Found similar executable: $executableFileName"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Found similar executable: $executableFileName" -LogLevel "Information"        
    }
    Write-Verbose "[$functionName] Executable File Name: $executableFileName"
    Write-Log -LogFile $LogFile -Module "$functionName" -Message "Executable File Name: $executableFileName" -LogLevel "Information"
    try 
    {
        [version]$localVersion = (get-FileVersion -executableFileName $executableFileName).version
        if ($null -ne $localVersion         )
        {
            Write-Verbose "[$functionName] Local Version: $($localVersion | Out-String)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Local Version: $($localVersion | Out-String)" -LogLevel "Information"
        }
        else
        {
            Write-Verbose "[$functionName] Failed to retrieve local version information."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Failed to retrieve local version information." -LogLevel "Error"
            return $returnObject        
        }               
        Write-Verbose "[$functionName] Remote Version URL: $remoteVersionURL"
        Write-Verbose "[$functionName] Getting remote version from $remoteVersionURL"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Getting remote version from $remoteVersionURL" -LogLevel "Information"
        $remoteVersionResponse = Invoke-RestMethod -Uri $remoteVersionURL -Method Get -ErrorAction SilentlyContinue -UseBasicParsing
        write-log -logFile $LogFile -Module "$functionName" -Message "Remote version response: $($remoteVersionResponse | Out-String)" -LogLevel "Debug"                    
        Write-Verbose "[$functionName] Remote version response: $($remoteVersionResponse | Out-String)"     
        if (-not $remoteVersionResponse)
        {
            write-log -logFile $LogFile -Module "$functionName" -Message "Failed to retrieve remote version information." -LogLevel "Error"
            Write-Verbose "[$functionName] Failed to retrieve remote version information."                  
            return $returnObject
        }
        Write-Log -logFile $LogFile -Module "$functionName" -Message "Remote version response: $($remoteVersionResponse | Out-String)" -LogLevel "Debug"                    
        Write-Verbose "[$functionName] Remote version response: $($remoteVersionResponse | Out-String)"     
        $returnObject.remoteVersion = [System.Version]::Parse($remoteVersionResponse.version)
        $returnObject.localVersion = $localVersion
        $returnObject.ReleaseDate = [datetime]::Parse($remoteVersionResponse.date).ToLocalTime()
        $returnObject.releaseNotes = $remoteVersionResponse.releaseNotes
        $returnObject.hash = $remoteVersionResponse.hash
        $returnObject.success = ($null -ne $returnObject.remoteVersion -and $null -ne $returnObject.localVersion -and $null -ne $returnObject.ReleaseDate -and $null -ne $returnObject.hash)
        if ($returnObject.remoteVersion -gt $returnObject.localVersion)
        {
            Write-Verbose "[$functionName] Update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
            $returnObject.updateAvailable = $true
            $returnObject.versionsMatch = $false
            $returnObject.version = $returnObject.remoteVersion
        }   
        elseif ($returnObject.remoteVersion -eq $returnObject.localVersion)
        {
            Write-Verbose "[$functionName] Versions match. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Versions match. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
            $returnObject.versionsMatch = $true
            $returnObject.version = $localVersion
        }                       
        else
        {
            Write-Verbose "[$functionName] No update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "No update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
            $returnObject.updateAvailable = $false
            $returnObject.versionsMatch = $false
            $returnObject.version = $localVersion               
        }
        Write-Verbose "[$functionName] Success: $($returnObject.success)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Success: $($returnObject.success)" -LogLevel "Information"
        Write-Verbose "[$functionName] Version: $($returnObject.localVersion)"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Version: $($returnObject.localVersion)" -LogLevel "Information"
        Write-Verbose "[$functionName] Release Date: $($returnObject.ReleaseDate)"
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
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error: $($_.Exception.Message)" -LogLevel "Error"
        $returnObject.localVersion = $localVersion
        $returnObject.remoteVersion = $null
        $returnObject.Version = $null
        $returnObject.ReleaseDate = $null
        $returnObject.Hash = $null
        $returnObject.success = $false
        $returnObject.updateAvailable = $false
        $returnObject.versionsMatch = $false
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error: $($_.Exception.Message)" -LogLevel "Error"
        return $returnObject
    }    
}

