function DownloadScriptUpdates() 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$scriptsToUpdate,
        [Parameter(Mandatory = $true)]
        [string]$scriptURI,
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot
    )

    $manifest = $scriptsToUpdate | ConvertFrom-Json
    Write-Verbose "Received ScriptRoot: $ScriptRoot"
    Write-Verbose "Received $($manifest.functions.count) functions, $($manifest.scripts.count) scripts, and $($manifest.cmds.count) cmds from the remote manifest."    
    foreach ($type in $manifest.PSObject.Properties)
    {
        Write-Host "Processing $($type.Value.count) $($type.Name)"
        foreach ($item in $manifest.$($type.Name))
        {
            Write-Verbose "Processing $($item.name)"
            switch ($type.Name)
            {
                functions
                {
                    Write-Verbose "This file' has the method $($item.method)"
                    if ($item.method -ne 'none')
                    {
                        $extension = 'ps1'
                        $fullFunctionName = "$($item.Name).$extension"
                        $localPath = Join-Path -Path $ScriptRoot -ChildPath "functions\$fullFunctionName"
                        Write-Host "Downloading function $fullFunctionName from $($scriptURI)/$fullFunctionName to $localPath"
                        # Invoke-WebRequest -Uri "$scriptURI/$fullFunctionName" -OutFile $localPath -UseBasicParsing -method Get -passThru -ErrorAction Stop
                    }
                    else
                    {
                        Write-Host "Function $($item.name).ps1 is up to date. Skipping download."
                    }
                }
                scripts
                {
                    Write-Verbose "This file's has the method $($item.method)"
                    if ($item.method -ne 'none')
                    {
                        $extension = 'ps1'
                        $fullScriptName = "$($item.Name).$extension"
                        $localPath = Join-Path -Path $ScriptRoot -ChildPath $fullScriptName
                        Write-Host "Downloading script $fullScriptName from $($scriptURI)/$fullScriptName to $localPath"
                        # Invoke-WebRequest -Uri "$scriptURI/$fullScriptName" -OutFile $localPath -UseBasicParsing -method Get -passThru -ErrorAction Stop
                    }
                    else
                    {
                        Write-Host "Script $($item.name).ps1 is up to date. Skipping download."
                    }
                }
                cmds
                {
                    Write-Verbose "This file's has the method $($item.method)"
                    if ($item.method -ne 'none')
                    {
                        $extension = 'cmd'
                        $fullCmdName = "$($item.Name).$extension"
                        $localPath = Join-Path -Path $ScriptRoot -ChildPath $fullCmdName
                        Write-Host "Downloading cmd $fullCmdName from $($scriptURI)/$fullCmdName to $localPath"
                        # Invoke-WebRequest -Uri "$scriptURI/$fullCmdName" -OutFile $localPath -UseBasicParsing -method Get -passThru -ErrorAction Stop
                    }
                    else
                    {
                        Write-Host "Cmd $($item.name).cmd is up to date. Skipping download."
                    }
                }
            }
        }
    }
}

