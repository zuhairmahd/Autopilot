function CheckForScriptUpdates()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$RemoteManifestPath,
        [Parameter(Mandatory = $True)]
        [System.Object[]]$LocalManifestContent
    )

    $updatedManifestContent = @{'Functions' = @(); 'Scripts' = @(); 'Cmds' = @() }
    Write-Verbose "Retrieving remote manifest from $RemoteManifestPath"
    $remoteManifestContent = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get
    Write-Verbose "Read $($LocalManifestContent.functions.count) functions, $($LocalManifestContent.scripts.count) scripts, and $($LocalManifestContent.cmds.count) cmds from the local manifest."
    Write-Verbose "Read $($remoteManifestContent.functions.count) functions, $($remoteManifestContent.scripts.count) scripts, and $($remoteManifestContent.cmds.count) cmds from the remote manifest."

    foreach ($type in $remoteManifestContent.PSObject.Properties)
    {
        Write-Verbose "Processing $($type.Value.count) $($type.Name)"
        foreach ($remoteItem in $remoteManifestContent.$($type.Name))
        {
            $localItem = $LocalManifestContent.$($type.Name) | Where-Object { $_.name -eq $remoteItem.name }
            Write-Verbose "Comparing the remote item $($remoteItem.name) withthe the local item $($localItem.name)"
            if ($null -eq $localItem)
            {
                Write-Verbose "Script $($remoteItem.name) not found in local manifest. Adding to updated manifest."
                updatedManifestContent.$($type.Name) += [ordered]@ { Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'add' }
            }
            elseif ($localItem.name.version -lt $remoteItem.name.version)
            {
                Write-Verbose "Updating script $($remoteItem.name) from version $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build) to version $($remoteItem.version.major).$($remoteItem.version.minor).$($remoteItem.version.build)"
                $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'update' }
            }
            else
            {
                Write-Verbose "Function $($remoteItem.name) version $($localItem.version) is up to date"
                $updatedManifestContent.$($type.Name) += [ordered]@{ Name = $remoteItem.name; Version = $remoteItem.version; hash = $remoteItem.hash; method = 'none' }
            }
        }
    }
    Write-Verbose "Returning updated manifest content."
    return $updatedManifestContent | ConvertTo-Json -Depth 10
}

