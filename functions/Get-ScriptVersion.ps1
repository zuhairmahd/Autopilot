Function Get-ScriptVersion()
{
    [cmdletbinding()]
    param
    (
        [string]$versionURL,
        [string]$scriptURI
    )
    $newVersion = $false    
    $latestVersion = Invoke-RestMethod -Uri $versionURL
    $local = [System.Version]::new($localVersion)
    $latest = [System.Version]::new($latestVersion)
    if ($local -lt $latest)
    {
        Write-Verbose "Script has been updated, please download the latest version from $scriptURI" -ForegroundColor Red
        $newVersion = $true
    }
    return $newVersion
}

