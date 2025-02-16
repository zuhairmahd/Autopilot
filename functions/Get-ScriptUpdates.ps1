function Get-ScriptUpdates()
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
    # $scriptPath = $PSScriptRoot + '\' + $scriptName
    $scriptVersionRemote = @{}
    $scriptVersionRemote = Invoke-RestMethod -Uri $scriptVersionURL -Method Get
    foreach ($key in $scripts.PSObject.Properties.Name)
    {
        $localScriptName = $key
        Write-Host "Checking for updates for $localScriptName"
        $localScriptVersion = $scripts.$localScriptName
        Write-Host "Local version: $localScriptVersion"
        $remoteScriptVersion = $scriptVersionRemote.$localScriptName
        Write-Host "Remote version: $remoteScriptVersion"

    }
}
