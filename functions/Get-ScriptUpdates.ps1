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
    $scriptVersionRemote = Invoke-RestMethod -Uri $scriptVersionUrl -Method Get
    foreach ($key in $scripts.scripts.PSObject.Properties.Name)
    {
        if ($scriptVersionRemote.scripts.ContainsKey($key))
        {
            Write-Output "For key '$key': in Local versions => '$($scriptVersionRemote[$key])', Remote version => '$($scriptVersionRemote[$key])'"
        }
    }
}
