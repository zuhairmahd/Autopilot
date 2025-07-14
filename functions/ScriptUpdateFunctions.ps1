function GetLatestGitlabRelease()
{
    [CmdletBinding()]
    param (
        [string]$ProjectID
    )
    $functionName = $MyInvocation.MyCommand.Name
    $gitlabURL = 'https://git.gao.gov'
    $gitlabAPIEndpoint = "$gitlabURL/api/v4"
    $gitlabAPIProjectEndpoint = "$gitlabAPIEndpoint/projects/$ProjectID"
    $gitlabAPILatestReleaseEndpoint = "$gitlabAPIProjectEndpoint/releases/permalink/latest"
    $returnValue = $null
    Write-Verbose "[$functionName] GitLab URL: $gitlabURL"
    Write-Verbose "[$functionName] GitLab API Endpoint: $gitlabAPIEndpoint"
    Write-Verbose "[$functionName] GitLab API Project Endpoint: $gitlabAPIProjectEndpoint"
    Write-Verbose "[$functionName] GitLab API Latest Release Endpoint: $gitlabAPILatestReleaseEndpoint"
    Write-Verbose "[$functionName] Project ID: $ProjectID"
    Write-Verbose "[$functionName] Attempting to retrieve the latest release from GitLab..."
    Write-Verbose "[$functionName] getting latest release from $gitlabAPILatestReleaseEndpoint"
    $response = Invoke-RestMethod -Uri $gitlabAPILatestReleaseEndpoint -Method Get -ErrorAction SilentlyContinue
    if ($response)
    {
        Write-Verbose "[$functionName] Successfully retrieved the latest release. Tag Name: $($response.tag_name)"
        $returnValue = $response.tag_name
    }
    else 
    {
        Write-Verbose "[$functionName] Failed to retrieve the latest release from GitLab. Trying to get the default branch instead."
        Write-Verbose "[$functionName] Attempting to retrieve project details from: $gitlabAPIProjectEndpoint"
        $response = Invoke-RestMethod -Uri $gitlabAPIProjectEndpoint -Method Get -ErrorAction SilentlyContinue
        if ($response)
        {
            Write-Verbose "[$functionName] Successfully retrieved project details. Default Branch: $($response.default_branch)"
            $returnValue = $response.default_branch
        }
        else
        {
            Write-Verbose "[$functionName] Failed to retrieve project details from GitLab."
        }
    }
    Write-Verbose "[$functionName] Returning value: $returnValue"
    return $returnValue
}

function GetLatestGithubRelease()
{
    [CmdletBinding()]
    param (
        [string]$Repository
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Checking the latest release for Repository: $Repository"
    $url = "https://api.github.com/repos/$Repository/releases/latest"
    Write-Verbose "[$functionName] Requesting URL: $url"
    $response = Invoke-RestMethod -Uri $url -Method Get 
    Write-Verbose "[$functionName] Got response: $($response.tag_name)"
    if (($null -eq $response) -or ($null -eq $response.tag_name ))
    {
        Write-Host "Failed to retrieve the latest release information from GitHub."
        return $null
    }
    return $response.tag_name
}

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

function getFileVersion()
{
    [CmdletBinding()]    
    param(
        [string]$executableFileName
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Executable File Name: $executableFileName"
    if (-not $executableFileName -or -not (Test-Path $executableFileName) -or $executableFileName -match '.ps1')
    {
        Write-Verbose "[$functionName] Executable file name is not provided."
        return $null
    }
    Write-Verbose "[$functionName] Checking if the executable file exists in the current directory."
    if (Test-Path $executableFileName -PathType Leaf -ErrorAction SilentlyContinue)
    {
        Write-Verbose "[$functionName] Found the executable file '$executableFileName'."
        Write-Verbose "[$functionName] Getting the file version."
        $LocalVersion = (Get-Item $executableFileName).VersionInfo.ProductVersion
        Write-Verbose "[$functionName] Local version extracted: $LocalVersion"
        Write-Verbose "[$functionName] Parsing the local version string to System.Version object."
        $localVersion = [System.Version]::Parse($LocalVersion)
        Write-Verbose "[$functionName] Parsed local version: $localVersion"
        Write-Verbose "[$functionName] Returning local version: $localVersion"
        return $localVersion
    }
    else
    {
        Write-Verbose "[$functionName] Executable file '$executableFileName' not found in the current directory."
        return $null
    }
}

function GetUpdates()
{
    param (
        [Parameter(Mandatory = $false)]
        [string]$executableFileName = "$pwd\main.exe",
        [Parameter(Mandatory = $true)]
        [string]$updateURL
    )

    #region define variables and write logs 
    $functionName = $MyInvocation.MyCommand.Name
    $fileName = Split-Path -Path $executableFileName -Leaf
    $updateURL = "$updateURL/$fileName"
    $tempUpdateFile = "$env:TEMP\$fileName"
    Write-Verbose "[$functionName] Executable File Name: $executableFileName"
    Write-Verbose "[$functionName] updateURL: $updateURL"
    #endregion
    if ($executableFileName -notmatch 'exe')
    {
        Write-Verbose "[$functionName] The provided executable file name '$executableFileName' does not match 'exe'."
        return $returnValues.invalidFileType
    }
    
    $localVersion = getFileVersion -executableFileName $executableFileName
    
    #region get the remote version.
    Write-Verbose "[$functionName] Checking whether the temp update file $tempUpdateFile exists."
    if (Test-Path $tempUpdateFile)
    {
        Write-Verbose "[$functionName] Temp update file $tempUpdateFile exists. Removing it."
        Remove-Item -Path $tempUpdateFile -Force
    }
    Write-Verbose "[$functionName] Getting remote file from $updateURL"
    try 
    {
        $response = Invoke-WebRequest -Uri $updateURL -OutFile $tempUpdateFile -Method Get -ErrorAction SilentlyContinue -PassThru
        Write-Verbose "[$functionName] Response received from $($updateURL): $($response.StatusCode)"
    }
    catch 
    {
        Write-Verbose "[$functionName] Response: $($remoteVersionResponse)"
        Write-Verbose "[$functionName] Remote version response content: $($remoteVersionResponse.Content)"
        Write-Verbose "[$functionName] Remote version status code: $($remoteVersionResponse.StatusCode)"
        return $null
    }    
    $remoteVersion = GetFileVersion -executableFileName $tempUpdateFile
    Write-Verbose "[$functionName] remoteVersion = $remoteVersion"
    #endregion
    
    #region compare versions
    Write-Verbose "[$functionName] Comparing local version $localVersion with remote version $remoteVersion"
    if ($remoteVersion -gt $localVersion)
    {
        Write-Verbose "[$functionName] Remote version $remoteVersion is greater than local version $localVersion. Proceeding with update."
        Write-Host "An update is available."
        Write-Host "Current version: $localVersion"
        Write-Host "New version: $remoteVersion"
        Write-Host "Would you like to download the update?"
        $userInput = Read-Host "Type 'yes' to proceed with the update, or 'no' to cancel"
        while ($userInput -notin @('yes', 'no'))
        {
            Write-Host "Invalid input. Please type 'yes' to proceed with the update, or 'no' to cancel."
            #beep
            [console]::beep(1000, 500)
            $userInput = Read-Host
        }
        if ($userInput -eq 'no')
        {
            Write-Host "Update cancelled by user."
            return $returnValues.UpdateCancelledMessage
        }
        Write-Host "Proceeding with the update..."
        $backupFile = Join-Path -Path $env:TEMP -ChildPath "$fileName.bak"
        Write-Verbose "[$functionName] Backing up current $executableFileName to $backupFile."
        try
        {
            Copy-Item -Path $executableFileName -Destination $backupFile -Force
            Write-Verbose "[$functionName] Backup created successfully."
            Write-Verbose "[$functionName] Renaming $executableFileName to $executableFileName.old"
            if (Test-Path "$executableFileName.old")
            {
                Write-Verbose "[$functionName] Old backup file $executableFileName.old already exists. Removing it."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removing old backup file $executableFileName.old" -LogLevel "Information"
                Remove-Item -Path "$executableFileName.old" -Force
                Write-Verbose "[$functionName] Old backup file removed."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Old backup file $executableFileName.old removed" -LogLevel "Information"
            }
            Rename-Item -Path $executableFileName -NewName "$executableFileName.old" -Force
            Write-Verbose "[$functionName] Renamed $executableFileName to $executableFileName.old"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Renamed $executableFileName to $executableFileName.old" -LogLevel "Information"
            Write-Verbose "[$functionName] Copying the update file from $tempUpdateFile to $executableFileName"
            Copy-Item -Path $tempUpdateFile -Destination $executableFileName -Force
            Write-Verbose "[$functionName] Update completed successfully. New version: $remoteVersion"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Update completed successfully. New version: $remoteVersion" -LogLevel "Information"
            Write-Verbose "[$functionName] Removing old executable file $executableFileName.old"
            Remove-Item -Path "$executableFileName.old" -Force
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removed old executable file $executableFileName.old" -LogLevel "Information"
        }
        catch
        {
            Write-Error "[$functionName] Error during update: $($_.Exception.Message)"
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Error during update: $($_.Exception.Message)" -LogLevel "Error"
            Write-Error "Failed to update $executableFileName. Please check the error message above."
            Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extended error message: $_" -LogLevel "Error"
            if ($localVersion -ne (getFileVersion -executableFileName $executableFileName))
            {
                $backupFileName = Split-Path -Path $backupFile -Leaf
                $executableFileParrentFolder = Split-Path -Path $executableFileName -Parent
                Write-Host "Restoring backup from $backupFile to $executableFileName"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Restoring backup from $backupFile to $executableFileName" -LogLevel "Error"
                Copy-Item -Path $backupFile -Destination $executableFileParrentFolder -Force
                Write-Verbose "[$functionName] copied backup file $backupFile to $executableFileParrentFolder directory."
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Copied backup file $backupFile to $executableFileParrentFolder directory." -LogLevel "Error"
                Write-Verbose "[$functionName] Extracted backup file name: $backupFileName"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Extracted backup file name: $backupFileName" -LogLevel "Error"
                Rename-Item -Path $executableFileName -NewName "$executableFileName.tmp" -Force
                Write-Verbose "[$functionName] Renamed $executableFileName to $executableFileName.tmp"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Renamed $executableFileName to $executableFileName.tmp" -LogLevel "Error"
                Rename-Item -Path $backupFileName -NewName $executableFileName -Force
                Write-Verbose "[$functionName] Renamed $backupFileName to $executableFileName"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Renamed $backupFileName to $executableFileName" -LogLevel "Error"
                Write-Host "The update has been rolled back to the previous version."
                Remove-Item -Path "$executableFileName.tmp" -Force
                Write-Verbose "[$functionName] Removed temporary file $executableFileName.tmp"
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removed temporary file $executableFileName.tmp" -LogLevel "Error"
                Write-Host "Please try the update again later."
            }
            #cleanup temp files if they exist.
            if (Test-Path $tempUpdateFile)
            {
                Write-Verbose "[$functionName] Removing temporary update file $tempUpdateFile"
                Remove-Item -Path $tempUpdateFile -Force
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removed temporary update file $tempUpdateFile" -LogLevel "Error"
            }
            #same for the backup file.
            if (Test-Path $backupFile)
            {
                Write-Verbose "[$functionName] Removing backup file $backupFile"
                Remove-Item -Path $backupFile -Force
                Write-Log -LogFile $LogFile -Module "$functionName" -Message "Removed backup file $backupFile" -LogLevel "Error"
            }
            return $false
        }
    }
    else
    {
        Write-Verbose "[$functionName] Local version $localVersion is up to date with remote version $remoteVersion. No update required."
        Write-Host "Current version: $localVersion"
        Write-Host "Remote version: $remoteVersion"
        return $returnValues.UpdateNotNeededMessage
    }
    #endregion
    return $returnValues.UpdateSuccessMessage
}


