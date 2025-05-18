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
