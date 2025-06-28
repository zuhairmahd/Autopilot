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
        Write-Host "Backing up current $executableFileName to $backupFile."
        try
        {
            Copy-Item -Path $executableFileName -Destination $backupFile -Force
            Write-Host "Backup created successfully."
            Write-Host "Renaming $executableFileName to $executableFileName.old"
            Rename-Item -Path $executableFileName -NewName "$executableFileName.old" -Force
            Write-Host "Copying the update file from $tempUpdateFile to $executableFileName"
            Copy-Item -Path $tempUpdateFile -Destination $executableFileName -Force
        }
        catch
        {
            Write-Error "Failed to update $executableFileName. Please check the error message above."
            Write-Host "Restoring backup from $backupFile to $executableFileName"
            Copy-Item -Path $backupFile -Destination $executableFileName -Force
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


