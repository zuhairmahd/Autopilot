function GetUpdates()
{
    param (
        $returnValues = $returnValues,
        [Parameter(Mandatory = $false)]
        [string]$RootFolder,
        [Parameter(Mandatory = $false)]
        [string]$LocalVersion = $null,
        [Parameter(Mandatory = $true)]
        [string]$remoteVersionURL,
        [Parameter(Mandatory = $true)]
        [string]$updateURL
    )
    #region write a verbose log of received parameters.
    Write-Verbose "RootFolder: $RootFolder"
    Write-Verbose "LocalVersion: $LocalVersion"
    Write-Verbose "remoteVersionURL: $remoteVersionURL"
    Write-Verbose "updateURL: $updateURL"
    #endregion

    #region get local version
    Write-Verbose "Checking if we received a local version."
    if ($null -eq $LocalVersion -or $LocalVersion -eq '')
    {
        Write-Verbose "LocalVersion is null or empty. Attempting to get the local version from the version file."
        # Get the local version from the version file
        $localVersionFile = "$RootFolder\version.txt"
        if (Test-Path $localVersionFile)
        {
            Write-Verbose "Local version file found at $localVersionFile. Reading version."
            $LocalVersion = Get-Content -Path $localVersionFile -Force
        }
        else
        {
            Write-Verbose "Local version file not found at $localVersionFile."
            Write-Verbose "Attempting to get version number from the script."
            $versionString = Select-String -Path "$rootFolder\register.ps1" -Pattern '.VERSION\s*(\d+\.\d+\.\d)'
            Write-Verbose "Version string returned from script: $versionString"
            if ($versionString)
            {
                $LocalVersion = [regex]::Match($versionString, '\d+\.\d+\.\d').Value
                Write-Verbose "Local version extracted from script: $LocalVersion"
            }
            else
            {
                Write-Host "Failed to get local version from version file or script. Please provide a valid local version."
                return
            }
        }
    }
    else 
    {
        Write-Verbose "LocalVersion provided in variable. Using provided local version: $LocalVersion"
    }
    Write-Host "LocalVersion: $LocalVersion"
    $localVersion = [System.Version]::Parse($LocalVersion)
    #endregion

    #region get the remote version.
    Write-Verbose "Getting remote version from $remoteVersionURL"
    try 
    {
        $remoteVersionResponse = Invoke-WebRequest -Uri $remoteVersionURL -Method Get -ErrorAction Stop
    }
    catch 
    {
        Write-Verbose "Remote version response: $($remoteVersionResponse.Content)"
        Write-Verbose "Remote version status code: $($remoteVersionResponse.StatusCode)"
        return $null
        Write-Verbose "Response: $($remoteVersionResponse)"
        #Try to get the version number from the remote script.
        Write-Verbose "Attempting to get version number from the remote script."
        Write-Verbose "Making a web request to $updateURL/register.ps1"
        $versionString = Invoke-WebRequest -Uri "$updateURL/register.ps1" -Method Get -UseBasicParsing -ErrorAction Stop
        Write-Verbose "Status code: $($versionString.StatusCode)"
        if ($versionString.StatusCode -ne 200)
        {
            Write-Verbose "Failed to get remote version from $updateURL. Status code: $($versionString.StatusCode)"
            Write-Verbose "Response: $($versionString.Content)"
            return
        }
        $versionString = $versionString.Content | Select-String -Pattern '.VERSION\s*(\d+\.\d+\.\d)'
        if ($versionString)
        {
            $remoteVersion = [regex]::Match($versionString, '\d+\.\d+\.\d').Value
            Write-Verbose "Remote version extracted from script: $remoteVersion"
        }
        else
        {
            Write-Host "Failed to get remote version from response. Please provide a valid remote version."
            return
        }
    }
    $remoteVersion = $remoteVersionResponse.content
    Write-Verbose "remoteVersion = $remoteVersion"
    Write-Verbose "Returned remote version: $remoteVersion"
    Write-Verbose "Found remote version string: $remoteVersion"
    Write-Host "Remote version: $remoteVersion"
    if ($null -eq $remoteVersion -or $remoteVersion -eq '')
    {
        Write-Host "Failed to get remote version from response. Please provide a valid remote version."
        return
    }
    $remoteVersion = [regex]::Match($remoteVersion, '\d+\.\d+\.\d').Value
    Write-Verbose "processed remote version: $remoteVersion"
    #convert the content to a version object.
    $remoteVersion = [System.Version]::Parse($remoteVersion)
    #endregion
    
    #region compare versions
    Write-Verbose "Comparing local version $localVersion with remote version $remoteVersion"
    if ($remoteVersion -gt $localVersion)
    {
        Write-Verbose "Remote version $remoteVersion is greater than local version $localVersion. Proceeding with update."
        Write-Host "An update is available to version $remoteVersion. Downloading update from $updateURL."
        #make a backup of register.exe.
        $backupFile = Join-Path -Path $RootFolder -ChildPath "register.exe.bak"
        if (Test-Path $backupFile)
        {
            Write-Host "Backup file already exists. Deleting old backup file."
            Remove-Item -Path $backupFile -Force
        }
        Write-Host "Backing up current register.exe to $backupFile."
        Copy-Item -Path "$RootFolder\register.exe" -Destination $backupFile -Force
        #download the update file.
        $updateFile = Join-Path -Path $RootFolder -ChildPath "register.exe"
        $response = Invoke-WebRequest -Uri $updateURL -OutFile $updateFile -Method Get -ErrorAction Stop -PassThru
        #check the return code.
        if ($response.StatusCode -ne 200)
        {
            Write-Host "Failed to download update from $updateURL. Status code: $($response.StatusCode)"
            return $returnValues.UpdateFailedMessage
        }
        else
        {
            Write-Verbose "Update downloaded successfully to $updateFile."
            return $returnValues.UpdateSuccessMessage
        }
    }
    else
    {
        Write-Verbose "Local version $localVersion is up to date with remote version $remoteVersion. No update required."
        return $returnValues.UpdateNotNeededMessage
    }
    #endregion
}