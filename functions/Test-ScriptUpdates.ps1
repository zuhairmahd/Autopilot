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
        [PSCustomObject]$scripts,
        [Parameter(Mandatory = $True)]
        [string]$PSScriptRoot
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
    Write-Host "Refreshing updated script version from $scriptVersionURL"
    try
    {
        $response = Invoke-WebRequest -Uri $scriptVersionURL -OutFile $PSScriptRoot\version.json -Method Get -PassThru
        $StatusCode = $Response.StatusCode  
        Write-Verbose "The status code is $StatusCode"
        if ($StatusCode -eq 200)
        {
            Write-Host 'The script version file has been refreshed successfully.'
        }
        else
        {
            Write-Host 'Could not refresh the script version file.'
            Write-Host "The server returned Status code: $StatusCode"
        }
    }
    catch
    {
        $StatusCode = $_.Exception.Response.StatusCode.value__
    }   
    Write-Verbose "Scripts to update: $($scriptsToUpdate.count)"
    return $scriptsToUpdate
}
