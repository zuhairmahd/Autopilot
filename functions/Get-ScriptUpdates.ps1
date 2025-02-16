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
    $scriptsToUpdate = @{}
    $functionsList = @(
        'ConnectToTenant',
        'Get-decryptedObject',
        'Get-DeviceHash',
        'Get-DeviceInfo',
        'Get-requiredModules',
        'Get-ScriptUpdates',
        'Get-ScriptVersion',
        'Get-USBDriveLetter',
        'Restart-Device'
    )
    $scriptVersionRemote = Invoke-RestMethod -Uri $scriptVersionURL -Method Get
    foreach ($key in $scripts.PSObject.Properties.Name)
    {
        $localScriptName = $key
        Write-Host "Checking for updates for $localScriptName"
        $localScriptVersion = $scripts.$localScriptName
        Write-Host "Local version: $localScriptVersion"
        $remoteScriptVersion = $scriptVersionRemote.$localScriptName
        Write-Host "Remote version: $remoteScriptVersion"
        if ($localScriptVersion -ne $remoteScriptVersion)
        {
            $scriptsToUpdate.Add($localScriptName, $remoteScriptVersion)
        }
    }
    if ($scriptsToUpdate.Count -gt 0)
    {
        Write-Host 'The following scripts need to be updated:'
        foreach ($key in $scriptsToUpdate.Keys)
        {
            Write-Host "$key to version $($scriptsToUpdate[$key])"
        }
        Write-Host 'Would you like to update these scripts? (Y/N)'
        $response = Read-Host
        if ($response -eq 'Y')
        {
            foreach ($key in $scriptsToUpdate.Keys)
            {
                if ($key -in $functionsList)
                {
                    $scriptPath = $PSScriptRoot + '\functions\' + $key
                }
                else 
                {
                    $scriptPath = $PSScriptRoot + '\' + $key
                }
                Write-Host "Updating $key to version $($scriptsToUpdate[$key])"
                Write-Host "the path is $scriptPath"
                # Invoke-WebRequest -Uri "$updateURL/$key" -OutFile $scriptPath
            }
        }
    }
    else
    {
        Write-Host 'All scripts are up to date.'
    }
}
