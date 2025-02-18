function Test-ScriptUpdates()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$updateURL,
        [Parameter(Mandatory = $True)]
        [string]$scriptVersionURL,
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$scripts
    )
    $scriptsToUpdate = @{}
    $scriptVersionRemote = Invoke-RestMethod -Uri $scriptVersionURL -Method Get
    foreach ($key in $scripts.PSObject.Properties.Name)
    {
        $localScriptName = $key
        Write-Verbose "Checking for updates for $localScriptName"
        $localScriptVersion = [System.Version]::new($scripts.$localScriptName)
        Write-Verbose "Local version: $localScriptVersion"
        $remoteScriptVersion = [System.Version]::new($scriptVersionRemote.$localScriptName)
        Write-Verbose "Remote version: $remoteScriptVersion"
        if ($localScriptVersion -lt $remoteScriptVersion)
        {
            Write-Verbose "$localScriptName needs to be updated to version $remoteScriptVersion"
            $scriptsToUpdate.Add($localScriptName, $remoteScriptVersion)
        }
    }
    if ($scriptsToUpdate.count -gt 0)
    {
        Write-Host "$($scriptsToUpdate.count) modules are out of date."
    }
    else 
    {
        Write-Host 'All modules are up to date.'
    }
    return $scriptsToUpdate
}

