function DownloadScriptUpdates() 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$scriptsToUpdate,
        [string]$scriptURI,
        [string]$ScriptRoot
    )
    Write-Verbose "Received ScriptRoot: $ScriptRoot"
    Write-Verbose "Received ScriptURL: $scriptURI"
    foreach ($scriptType in $scriptsToUpdate.Keys)
    {
        Write-Host "Scrypt Type: $scriptType"
    }
}