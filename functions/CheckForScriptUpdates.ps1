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
    $updatedManifestContent = @()
    Write-Verbose "Retrieving remote manifest from $RemoteManifestPath"
    $remoteManifestContent = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get
    Write-Verbose "Read $($LocalManifestContent.functions.count) functions, $($LocalManifestContent.scripts.count) scripts, and $($LocalManifestContent.cmds.count) cmds from the local manifest."
    Write-Verbose "Read $($remoteManifestContent.functions.count) functions, $($remoteManifestContent.scripts.count) scripts, and $($remoteManifestContent.cmds.count) cmds from the remote manifest."
    foreach ($type in $remoteManifestContent.PSObject.Properties)
    {
        Write-Verbose "Processing $($type.Value.count) $($type.Name)"
        $updatedManifestContent += $type.name
        foreach ($remoteItem in $remoteManifestContent.$($type.Name))
        {
            $localItem = $LocalManifestContent.$($type.Name) | Where-Object { $_.name -eq $remoteItem.name }
            Write-Verbose "Comparing the remote item $($remoteItem.name) withthe the local item $($localItem.name)"
            if ($null -eq $localItem)
            {
                Write-Verbose "Function $($remoteItem.name) not found in local manifest. Adding to updated manifest."
                $updatedManifestContent += $type.name[$remoteItem]
                $updatedManifestContent[-1] | Add-Member -MemberType NoteProperty -Name 'Method' -Value 'Add'
            }
            elseif ($localItem.name.version -lt $remoteItem.name.version)
            {
                Write-Verbose "Updating function $($remoteItem.name) from version $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build) to version $($remoteItem.version.major).$($remoteItem.version.minor).$($remoteItem.version.build)"
                $updatedManifestContent += "$type.name.$remoteItem"
                $updatedManifestContent[-1] | Add-Member -MemberType NoteProperty -Name 'Method' -Value 'Update'
            }
            else
            {
                Write-Verbose "Function $($remoteItem.name) version $($localItem.version.major).$($localItem.version.minor).$($localItem.version.build) is up to date"
                $updatedManifestContent += $remoteItem
                $updatedManifestContent[-1] | Add-Member -MemberType NoteProperty -Name 'operation' -Value 'None' -Force
            }
        }
    }
    return $updatedManifestContent
}

