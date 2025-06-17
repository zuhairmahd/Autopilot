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

function GetUpdates()
{
    param (
        $returnValues = $returnValues,
        [Parameter(Mandatory = $false)]
        [string]$RootFolder,
        [Parameter(Mandatory = $false)]
        [string]$executableFileName = 'main.exe',
        [Parameter(Mandatory = $true)]
        [string]$remoteVersionURL,
        [Parameter(Mandatory = $true)]
        [string]$updateURL
    )
    $functionName = $MyInvocation.MyCommand.Name
    #region write a verbose log of received parameters.
    Write-Verbose "[$functionName] RootFolder: $RootFolder"
    Write-Verbose "[$functionName] remoteVersionURL: $remoteVersionURL"
    Write-Verbose "[$functionName] updateURL: $updateURL"
    #endregion

    #region get local version
    Write-Verbose "[$functionName] Getting the local version."
    $LocalVersion = (Get-Item "$RootFolder\$executableFileName").VersionInfo.ProductVersion
    Write-Host "LocalVersion: $LocalVersion"
    $localVersion = [System.Version]::Parse($LocalVersion)
    #endregion

    #region get the remote version.
    Write-Verbose "[$functionName] Getting remote version from $remoteVersionURL"
    try 
    {
        $remoteVersionResponse = Invoke-WebRequest -Uri $remoteVersionURL -Method Get -ErrorAction Stop
    }
    catch 
    {
        Write-Verbose "[$functionName] Response: $($remoteVersionResponse)"
        Write-Verbose "[$functionName] Remote version response content: $($remoteVersionResponse.Content)"
        Write-Verbose "[$functionName] Remote version status code: $($remoteVersionResponse.StatusCode)"
        return $null
    }    
    Write-Verbose "[$functionName] Returned remote version response: $remoteVersion"
    $remoteVersion = $remoteVersionResponse.content
    Write-Verbose "[$functionName] remoteVersion = $remoteVersion"
    if ($null -eq $remoteVersion -or $remoteVersion -eq '')
    {
        Write-Host "Failed to get remote version from response. Please provide a valid remote version."
        return $null
    }
    $remoteVersion = [regex]::Match($remoteVersion, '\d+\.\d+\.\d').Value
    Write-Verbose "[$functionName] processed remote version: $remoteVersion"
    $remoteVersion = [System.Version]::Parse($remoteVersion)
    #endregion
    
    #region compare versions
    Write-Verbose "[$functionName] Comparing local version $localVersion with remote version $remoteVersion"
    if ($remoteVersion -gt $localVersion)
    {
        Write-Verbose "[$functionName] Remote version $remoteVersion is greater than local version $localVersion. Proceeding with update."
        Write-Host "An update is available to version $remoteVersion. Downloading update from $updateURL."
        #make a backup of the executable
        $backupFile = Join-Path -Path $RootFolder -ChildPath "$executableFileName.bak"
        if (Test-Path $backupFile)
        {
            Write-Host "Backup file already exists. Deleting old backup file."
            Remove-Item -Path $backupFile -Force
        }
        Write-Host "Backing up current $executableFileName to $backupFile."
        Copy-Item -Path "$RootFolder\$executableFileName" -Destination $backupFile -Force
        #download the update file.
        $updateFile = Join-Path -Path $RootFolder -ChildPath $executableFileName
        $response = Invoke-WebRequest -Uri $updateURL -OutFile $updateFile -Method Get -ErrorAction Stop -PassThru
        #check the return code.
        if ($response.StatusCode -ne 200)
        {
            Write-Host "Failed to download update from $updateURL. Status code: $($response.StatusCode)"
            return $returnValues.UpdateFailedMessage
        }
        else
        {
            Write-Verbose "[$functionName] Update downloaded successfully to $updateFile."
            return $returnValues.UpdateSuccessMessage
        }
    }
    else
    {
        Write-Verbose "[$functionName] Local version $localVersion is up to date with remote version $remoteVersion. No update required."
        return $returnValues.UpdateNotNeededMessage
    }
    #endregion
}
