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
    if (-not $executableFileName -or -not (Test-Path $executableFileName) -or $executableFileName -match '.ps1')
    {
        Write-Verbose "[$functionName] Executable file name is not provided."
        return $null
    }
    if (Test-Path $executableFileName -PathType Leaf -ErrorAction SilentlyContinue)
    {
        Write-Verbose "[$functionName] Found the local version file."
        Write-Verbose "[$functionName] Getting the local version."
        $LocalVersion = (Get-Item "$RootFolder\$executableFileName").VersionInfo.ProductVersion
        Write-Host "LocalVersion: $LocalVersion"
        $localVersion = [System.Version]::Parse($LocalVersion)
        return $localVersion
    }
    else
    {
        Write-Error "Executable file '$executableFileName' not found in the current directory."
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
    $updateURL = "$updateURL/$executableFileName"
    $tempUpdateFile = "$env:TEMP\$executableFileName"
    Write-Verbose "[$functionName] Executable File Name: $executableFileName"
    Write-Verbose "[$functionName] updateURL: $updateURL"
    #endregion
    
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
        Write-Verbose "[$functionName] Response received from $updateURL."
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
        Write-Host "Remote version $remoteVersion is greater than local version $localVersion. Proceeding with update."
        $backupFile = Join-Path -Path $env:TEMP -ChildPath "$executableFileName.bak"
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
        return $returnValues.UpdateNotNeededMessage
    }
    #endregion
    return $returnValues.UpdateSuccessMessage
}


