function GetLatestGitlabRelease()
{
    [CmdletBinding()]
    param (
        [string]$ProjectID
    )
    $gitlabURL = 'https://git.gao.gov'
    $gitlabAPIEndpoint = "$gitlabURL/api/v4"
    $gitlabAPIProjectEndpoint = "$gitlabAPIEndpoint/projects/$ProjectID"
    $gitlabAPILatestReleaseEndpoint = "$gitlabAPIProjectEndpoint/releases/permalink/latest"
    $returnValue = $null
    Write-Verbose "GitLab URL: $gitlabURL"
    Write-Verbose "GitLab API Endpoint: $gitlabAPIEndpoint"
    Write-Verbose "GitLab API Project Endpoint: $gitlabAPIProjectEndpoint"
    Write-Verbose "GitLab API Latest Release Endpoint: $gitlabAPILatestReleaseEndpoint"
    Write-Verbose "Project ID: $ProjectID"
    Write-Verbose 'Attempting to retrieve the latest release from GitLab...'
    Write-Verbose "getting latest release from $gitlabAPILatestReleaseEndpoint"
    $response = Invoke-RestMethod -Uri $gitlabAPILatestReleaseEndpoint -Method Get -ErrorAction SilentlyContinue
    if ($response)
    {
        Write-Verbose "Successfully retrieved the latest release. Tag Name: $($response.tag_name)"
        $returnValue = $response.tag_name
    }
    else 
    {
        Write-Verbose 'Failed to retrieve the latest release from GitLab. Trying to get the default branch instead.'
        Write-Verbose "Attempting to retrieve project details from: $gitlabAPIProjectEndpoint"
        $response = Invoke-RestMethod -Uri $gitlabAPIProjectEndpoint -Method Get -ErrorAction SilentlyContinue
        if ($response)
        {
            Write-Verbose "Successfully retrieved project details. Default Branch: $($response.default_branch)"
            $returnValue = $response.default_branch
        }
        else
        {
            Write-Verbose 'Failed to retrieve project details from GitLab.'
        }
    }
    Write-Verbose "Returning value: $returnValue"
    return $returnValue
}

function GetLatestGithubRelease()
{
    [CmdletBinding()]
    param (
        [string]$Repository
    )
    Write-Verbose "Checking the latest release for Repository: $Repository"
    $url = "https://api.github.com/repos/$Repository/releases/latest"
    Write-Verbose "Requesting URL: $url"
    $response = Invoke-RestMethod -Uri $url -Method Get 
    Write-Verbose "Got response: $($response.tag_name)"
    if (($null -eq $response) -or ($null -eq $response.tag_name ))
    {
        Write-Host "Failed to retrieve the latest release information from GitHub."
        return $null
    }
    return $response.tag_name
}

function CheckForScriptUpdates
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$RemoteManifestPath,
        [Parameter(Mandatory = $True)]
        [System.Object[]]$LocalManifestContent,
        [string]$Application = $Application
    )

    #write verbose record of all parameters passed to the function.
    Write-Verbose "RemoteManifestPath: $RemoteManifestPath"
    Write-Verbose "LocalManifestContent: $($LocalManifestContent | ConvertTo-Json -Depth 10)"
    Write-Verbose "Local manifest functions: $($LocalManifestContent.functions.count)."
    Write-Verbose "Local manifest scripts: $($LocalManifestContent.scripts.Count)"
    Write-Verbose "Local manifest cmds: $($LocalManifestContent.cmds.count)."
    Write-Verbose "Local manifest configurations: $($LocalManifestContent.configurations.count)."
    $updatedManifestContent = @{
        $application = @{
            "Functions"      = @()
            "Scripts"        = @()
            "Cmds"           = @()
            "configurations" = @()
        }
    }   
    
    Write-Verbose "Retrieving remote manifest from $RemoteManifestPath"
    if ($psVersionTable.PSVersion.Major -eq 5 -and $psVersionTable.PSVersion.Minor -eq 1)
    {
        Write-Verbose "PS Version is 5.1."
        $response = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get -UseBasicParsing
        if ($response.gettype().name -eq 'string') 
        {
            Write-Verbose "Response is a string. Attempting to parse as JSON."
            $response = $response.Substring(1, $response.Length - 2)
            Write-Verbose "Removed first and last characters from response..."
            # Unescape any escaped quotes
            $response = $response -replace '\\\"', '"'
            Write-Verbose "Removed double quotes..."
            # Unescape any escaped newlines
            $response = $response -replace '\\r\\n', "`r`n"
            Write-Verbose "Removed single quotes..."
        }
        Write-Verbose "Attempting to convert response to JSON."
        $remoteManifestContent = ($response | ConvertFrom-Json).$Application
        #Check if the conversion worked.
        if ($response.gettype().name -ne 'string') 
        {
            Write-Verbose "Looks like it may have worked."
            Write-Verbose "Attempting to continue..."
        }
        else
        {
            Write-Verbose "Failed to convert response to JSON."
            Write-Verbose "This will likely result in an error."
        }
    }
    else 
    {
        Write-Verbose "The running version of Powershell is $($psVersionTable.PSVersion.Major).$($psVersionTable.PSVersion.Minor)."
        $response = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get 
    }
    Write-Verbose "Read $($LocalManifestContent.functions.count) functions, $($LocalManifestContent.scripts.count) scripts, $($LocalManifestContent.cmds.count) cmds and $($LocalManifestContent.configurations.count) configurations from the local manifest."
    Write-Verbose "Read $($remoteManifestContent.functions.count) functions, $($remoteManifestContent.scripts.count) scripts, $($remoteManifestContent.cmds.count) cmds and $($remoteManifestContent.configurations.count) configurations from the remote manifest."
    foreach ($type in $remoteManifestContent.PSObject.Properties)
    {
        Write-Verbose "Processing $($type.Value.count) $($type.Name)"
        switch ($type.Name)
        {
            functions
            {
                $fileExtension = 'ps1'
            }
            scripts
            {
                $fileExtension = 'ps1'
            }
            cmds
            {
                $fileExtension = 'cmd'
            }
        }
        foreach ($remoteItem in $remoteManifestContent.$($type.Name))
        {
            $localItem = $LocalManifestContent.$($type.Name) | Where-Object { $_.name -eq $remoteItem.name }
            Write-Verbose 'comparing items:'
            Write-Verbose "Local item name: $($localItem.name).$fileExtension"
            Write-Verbose "Local item version: $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build)"
            Write-Verbose "Remote item name: $($remoteItem.name).$fileExtension"
            Write-Verbose "Remote item version: $($remoteItem.version.major).$($remoteItem.version.minor).$($remoteItem.version.build)"
            $remoteItemVersion = New-Object System.Version -ArgumentList (
                $remoteItem.version.Major,
                $remoteItem.version.Minor,
                $remoteItem.version.Build,
                [Math]::Max($remoteItem.version.Revision, 0)
            )
            $localItemVersion = New-Object System.Version -ArgumentList (
                $localItem.version.Major,
                $localItem.version.Minor,
                $localItem.version.Build,
                [Math]::Max($localItem.version.Revision, 0)
            )
            Write-Verbose "Variable declaration for local item version: $localItemVersion"
            Write-Verbose "Variable declaration for remote item version: $remoteItemVersion"
            if ($null -eq $localItem)
            {
                Write-Verbose "Script $($remoteItem.name) not found in local manifest. Adding to updated manifest and queuing for download."
                $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'add' }
            }
            elseif ($localItemVersion -lt $remoteItemVersion )
            {
                Write-Verbose "Updating script $($remoteItem.name) from version $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build) to version $($remoteItem.version.major).$($remoteItem.version.minor).$($remoteItem.version.build)"
                $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'update' }
            }
            else
            {
                Write-Verbose "script $($remoteItem.name) with version $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build) is up to date."
                # $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'none' }
            }
        }
    }
    Write-Verbose "Updated manifest content: $($updatedManifestContent | ConvertTo-Json -Depth 10)"
    if ($updatedManifestContent.functions.count -eq 0 -and $updatedManifestContent.scripts.count -eq 0 -and $updatedManifestContent.cmds.count -eq 0 -and $updatedManifestContent.configurations.count -eq 0)
    {
        Write-Verbose "No updates found. Returning empty array."
        $updatedManifestContent = @()
    }
    else
    {
        Write-Verbose "Updated manifest content: $($updatedManifestContent.functions.count) functions, $($updatedManifestContent.scripts.count) scripts, $($updatedManifestContent.cmds.count) cmds and $($updatedManifestContent.configurations.count) configurations."
        $remoteManifestContent | ConvertTo-Json -Depth 10 | Set-Content -Path remoteManifest.json
    }
    return $updatedManifestContent
}

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

function DownloadScriptUpdates() 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [system.object[]]$scriptsToUpdate,
        [Parameter(Mandatory = $true)]
        [string]$scriptURI,
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot
    )
    $success = $true
    $categories = @('functions', 'scripts', 'cmds', 'configurations')
    $statusCodes = @()
    $tempFolder = "$ScriptRoot\temp"
    $localManifest = "manifest.json"
    $remoteManifest = "remoteManifest.json"
    Write-Verbose "Received ScriptRoot: $ScriptRoot"
    Write-Verbose "Received ScriptURI: $scriptURI"
    Write-Verbose "Received ScriptsToUpdate: $($scriptsToUpdate | ConvertTo-Json -Depth 5)"
    Write-Host "Downloading $($scriptsToUpdate.functions.count) functions, $($scriptsToUpdate.scripts.count) scripts, and $($scriptsToUpdate.cmds.count) cmds from the remote manifest." 
    
    #Check if the temp folder exists, if not create it.  If it exists, delete it and create it again.
    if (Test-Path $tempFolder)
    {
        Write-Verbose "Deleting temp folder $tempFolder"
        Remove-Item -Path $tempFolder -Recurse -Force
    }
    # Create the temp folder.
    Write-Verbose "Creating temp folder $tempFolder"
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
    Write-Verbose "Create functions folder in $tempFolder\functions"
    New-Item -Path "$tempFolder\functions" -ItemType Directory -Force | Out-Null
    Write-Verbose "Created temp folder $tempFolder and function folder $tempFolder\functions"
    
    foreach ($category in $categories)
    {
        $items = $scriptsToUpdate.$category
        Write-Verbose "Processing $($items.Count) $category"
        foreach ($item in $items)
        {
            Write-Verbose "Processing file: $($item.name)"
            switch ($category)
            {
                functions
                {
                    $extension = 'ps1'
                    $fullFunctionName = "$($item.Name).$extension"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath "functions\$fullFunctionName"
                    Write-Host "Downloading function $($fullFunctionName):"
                    Write-Verbose "Remote URL: $($scriptURI)/functions/$fullFunctionName"
                    Write-Verbose "File path: $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/functions/$fullFunctionName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullFunctionName to $tempFilePath" -ForegroundColor Green
                        Write-Verbose "The status code is $($response.StatusCode)"
                    }
                    else
                    {
                        Write-Host "Failed to download $fullFunctionName. Status code: $($response.StatusCode)" -ForegroundColor Red
                    }
                }
                scripts
                {
                    $extension = 'ps1'
                    $fullScriptName = "$($item.Name).$extension"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath $fullScriptName
                    Write-Host "Downloading script $($fullScriptName):"
                    Write-Verbose "Remote URL: $($scriptURI)/$fullScriptName"
                    Write-Verbose "File path: $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullScriptName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullScriptName to $tempFilePath" -ForegroundColor Green
                        Write-Verbose "The status code is $($response.StatusCode)"
                    }
                    else
                    {
                        Write-Host "Failed to download $fullScriptName. Status code: $($response.StatusCode)" -ForegroundColor Red
                    }
                }
                cmds
                {
                    $extension = 'cmd'
                    $fullCmdName = "$($item.Name).$extension"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath $fullCmdName
                    Write-Host "Downloading file $($fullCmdName):"
                    Write-Verbose "Remote URL: $($scriptURI)/$fullcmdName"
                    Write-Verbose "File path: $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullCmdName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullCmdName to $tempFilePath" -ForegroundColor Green
                        Write-Verbose "The status code is $($response.StatusCode)"
                    }
                    else
                    {
                        Write-Host "Failed to download $fullCmdName. Status code: $($response.StatusCode)" -ForegroundColor Red
                    }
                }
                'configurations'
                {
                    $extension = 'json'
                    $fullCmdName = "$($item.Name).$extension"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath $fullCmdName
                    Write-Host "Downloading file $($fullCmdName):"
                    Write-Verbose "Remote URL: $($scriptURI)/$fullCmdName"
                    Write-Verbose "File path: $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullCmdName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullCmdName to $tempFilePath" -ForegroundColor Green
                        Write-Verbose "The status code is $($response.StatusCode)"
                    }
                    else
                    {
                        Write-Host "Failed to download $fullCmdName. Status code: $($response.StatusCode)" -ForegroundColor Red
                    }
                }
            }
            $statusCodes += @{
                filename = $fullCmdName; statuscode = $response.StatusCode 
            }
        }
    }
    # Check if all files were downloaded successfully.
    Write-Host "Verifying downloaded files."
    foreach ($statusCode in $statusCodes)
    {
        Write-Verbose "Verifying file ($statusCode.filename) with status code: $($statusCode.statuscode)"
        if ($statusCode.statuscode -ne 200)
        {
            $success = $false
            Write-Host "Failed to download file $($statusCode.filename). Status code: $($statusCode.statuscode)" -ForegroundColor Red
        }
        else 
        {
            Write-Verbose "Successfully downloaded file $($statusCode.filename)." -ForegroundColor Green
        }
    }
    if ($success -eq $true)
    {
        Write-Host "All files downloaded successfully." -ForegroundColor Green
        Write-Host "Updating the local manifest."
        Remove-Item "$ScriptRoot\$localManifest" -Force
        Rename-Item "$ScriptRoot\$remoteManifest" -NewName "$localManifest"
        Write-Verbose "Creating temporary manifest file."
        $scriptsToUpdate | ConvertTo-Json | Set-Content "$tempFolder\$localManifest"
        Write-Host "Copying files..."
        if (CopyFiles -SourceFolder $tempFolder -DestinationFolder $ScriptRoot -manifestFile $tempFolder\$localManifest)
        {
            Write-Host "Files copied successfully."
            Write-Verbose "Cleaning up temp folder."
            Remove-Item -Path $tempFolder -Recurse -Force
        }
        else
        {
            Write-Host "Failed to copy files." -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "Failed to download one or more files. Please check the logs." -ForegroundColor Red
    }
    return $success
}
