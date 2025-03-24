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
    $categories = @('functions', 'scripts', 'cmds')
    $tempFolder = "$ScriptRoot\temp"
    Write-Verbose "Received ScriptRoot: $ScriptRoot"
    Write-Verbose "Received ScriptURI: $scriptURI"
    Write-Debug "Received ScriptsToUpdate: $($scriptsToUpdate | ConvertTo-Json -Depth 5)"
    Write-Host "Downloading $($scriptsToUpdate.functions.count) functions, $($scriptsToUpdate.scripts.count) scripts, and $($scriptsToUpdate.cmds.count) cmds from the remote manifest." 
    
    #Check if the temp folder exists, if not create it.  If it exists, delete it and create it again.
    if (Test-Path $tempFolder)
    {
        Write-Verbose "Deleting temp folder $tempFolder"
        Remove-Item -Path $tempFolder -Recurse -Force
    }
    # Create the temp folder.
    Write-Verbose "Creating temp folder $tempFolder"
    New-Item -Path $tempFolder -ItemType Directory | Out-Null
    Write-Verbose "Created temp folder $tempFolder"
    
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
                    $localPath = Join-Path -Path $ScriptRoot -ChildPath "functions\$fullFunctionName"
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath "functions\$fullFunctionName"
                    Write-Host "Downloading a temporary copy of function $fullFunctionName from $($scriptURI)/$fullFunctionName to $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullFunctionName" -OutFile $tempFolderPath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullFunctionName to $localPath" -ForegroundColor Green
                        $success = $true
                    }
                    else
                    {
                        Write-Host "Failed to download $fullFunctionName. Status code: $($response.StatusCode)" -ForegroundColor Red
                        $success = $false
                    }
                }
                scripts
                {
                    $extension = 'ps1'
                    $fullScriptName = "$($item.Name).$extension"
                    $localPath = Join-Path -Path $ScriptRoot -ChildPath $fullScriptName
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath $fullScriptName
                    Write-Host "Downloading a temporary copy of script $fullScriptName from $($scriptURI)/$fullScriptName to $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullScriptName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullScriptName to $localPath" -ForegroundColor Green
                        $success = $true
                    }
                    else
                    {
                        Write-Host "Failed to download $fullScriptName. Status code: $($response.StatusCode)" -ForegroundColor Red
                        $success = $false
                    }
                }
                cmds
                {
                    $extension = 'cmd'
                    $fullCmdName = "$($item.Name).$extension"
                    $localPath = Join-Path -Path $ScriptRoot -ChildPath $fullCmdName
                    $tempFilePath = Join-Path -Path $tempFolder -ChildPath $fullCmdName
                    Write-Host "Downloading a temporary copy of cmd $fullCmdName from $($scriptURI)/$fullCmdName to $tempFilePath"
                    $response = Invoke-WebRequest -Uri "$scriptURI/$fullCmdName" -OutFile $tempFilePath -UseBasicParsing -Method Get -PassThru
                    if ($response.StatusCode -eq 200)
                    {
                        Write-Host "Successfully downloaded $fullCmdName to $localPath" -ForegroundColor Green
                        $success = $true
                    }
                    else
                    {
                        Write-Host "Failed to download $fullCmdName. Status code: $($response.StatusCode)" -ForegroundColor Red
                        $success = $false
                    }
                }
            }
            if ($success -eq $false)
            {
                break 
            }
        }
    }

    if ($success -eq $true)
    {
        Write-Host "All files downloaded successfully. Moving files to the script root." -ForegroundColor Green
        Get-ChildItem -Path $tempFolder -Recurse | Move-Item -Destination $ScriptRoot -Force
        Remove-Item -Path $tempFolder -Recurse -Force
    }
    else
    {
        Write-Host "Failed to download one or more files. Please check the logs." -ForegroundColor Red
    }
    return $success
}