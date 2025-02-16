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
        Write-Host "Checking for updates for $localScriptName"
        $localScriptVersion = [System.Version]::new($scripts.$localScriptName)
        Write-Host "Local version: $localScriptVersion"
        $remoteScriptVersion = [System.Version]::new($scriptVersionRemote.$localScriptName)
        Write-Host "Remote version: $remoteScriptVersion"
        if ($localScriptVersion -lt $remoteScriptVersion)
        {
            Write-Host "$localScriptName needs to be updated to version $remoteScriptVersion"
            $scriptsToUpdate.Add($localScriptName, $remoteScriptVersion)
        }
    }
    Write-Verbose "Scripts to update: $scriptsToUpdate.count"
    if ($scriptsToUpdate.Count -gt 0)
    {
        return $scriptsToUpdate
    }
    else
    {
        return $null
    }
}
