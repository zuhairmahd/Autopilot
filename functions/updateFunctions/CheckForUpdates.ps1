function CheckForUpdates()
{
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
    if ($null -ne $localVersion         )
    {
        Write-Verbose "[$functionName] Local Version: $localVersion"
        Write-Log -LogFile $LogFile -Module "$functionName" -Message "Local Version: $localVersion" -LogLevel "Information"
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
    try 
    {
        $remoteVersionResponse = Invoke-RestMethod -Uri $remoteVersionURL -Method Get -ErrorAction SilentlyContinue -UseBasicParsing
        write-log -logFile $LogFile -Module "$functionName" -Message "Remote version response: $($remoteVersionResponse | Out-String)" -LogLevel "Debug"                    
        Write-Verbose "[$functionName] Remote version response: $($remoteVersionResponse | Out-String)"     
        if (-not $remoteVersionResponse)
        {
            write-log -logFile $LogFile -Module "$functionName" -Message "Failed to retrieve remote version information." -LogLevel "Error"
            Write-Verbose "[$functionName] Failed to retrieve remote version information."                  
            throw "Failed to retrieve remote version information."
            Write-Log -logFile $LogFile -Module "$functionName" -Message "Remote version response: $($remoteVersionResponse | Out-String)" -LogLevel "Debug"                    
            Write-Verbose "[$functionName] Remote version response: $($remoteVersionResponse | Out-String)"     
            if (-not $remoteVersionResponse)
            {
                Write-Log -logFile $LogFile -Module "$functionName" -Message "Failed to retrieve remote version information." -LogLevel "Error"
                Write-Verbose "[$functionName] Failed to retrieve remote version information."
                remoteVersion = [System.Version]::Parse($remoteVersionResponse.version)
                ReleaseDate = $remoteVersionResponse.date
                Hash = $remoteVersionResponse.hash
                success = $true
            }       
            if ([System.Version]::Parse($remoteVersionResponse.version) -gt $localVersion)
            {
                Write-Verbose "[$functionName] Update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update available. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
                $returnObject.updateAvailable = $true
                $returnObject.versionsMatch = $false
                $returnObject.version = $remoteVersionResponse.version          
            }   
            elseif ([System.Version]::Parse($remoteVersionResponse.version) -eq $localVersion)
            {
                Write-Verbose "[$functionName] Versions match. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Versions match. Remote version: $($remoteVersionResponse.version), Local version: $($localVersion)" -LogLevel "Information"         
                $returnObject.versionsMatch = $true
                $returnObject.version = $remoteVersionResponse.version
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
            $returnObject.version = $localVersion
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

