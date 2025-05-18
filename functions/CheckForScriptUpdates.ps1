<#
.SYNOPSIS
Checks for updates to scripts by comparing a local manifest with a remote manifest.

.DESCRIPTION
The CheckForScriptUpdates function retrieves a remote manifest and compares it with the local manifest content. It identifies scripts that are missing, outdated, or up-to-date. If updates are found, it generates an updated manifest and optionally writes the remote manifest to a file.

.PARAMETER RemoteManifestPath
The URL or path to the remote manifest file.

.PARAMETER LocalManifestContent
The content of the local manifest as an array of objects.

.EXAMPLE
CheckForScriptUpdates -RemoteManifestPath "https://example.com/manifest.json" -LocalManifestContent $localManifest
Compares the local manifest with the remote manifest at the specified URL and returns an updated manifest if changes are detected.

.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
GUID: 4b825dc2-8a00-3a93-830e-4b00e8b8d8a1
Date: April 5, 2025
#>


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
