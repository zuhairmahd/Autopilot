Function Get-ScriptUpdates()
{
    [cmdletbinding()]
    param
    (
        [PSCustomObject]$scriptsToUpdate,
        [string]$scriptURI
    )
    $functionsList = @(
        'ConnectToTenant',
        'Get-decryptedObject',
        'Get-DeviceHash',
        'Get-DeviceInfo',
        'Get-requiredModules',
        'Test-ScriptUpdates',
        'Get-ScriptUpdates',
        'Get-USBDriveLetter',
        'Restart-Device'
    )
    $success = $false
    Write-Verbose "The script URI is $scriptURI"
    Write-Verbose "The scripts to update are $($scriptsToUpdate | ConvertTo-Json -Depth 5)"
    Write-Host 'Updating scripts ...'
    foreach ($key in $scriptsToUpdate.Keys)
    {
        if ($key -in $functionsList)
        {
            Write-Verbose "The script $key is a function"
            $scriptPath = $PSScriptRoot + '\functions\' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
        }
        else 
        {
            Write-Verbose "The script $key is a script"
            $scriptPath = $PSScriptRoot + '\' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
        }
        Write-Host "Updating $key to version $($scriptsToUpdate[$key])"
        # Invoke-WebRequest -Uri "$updateURL/$key" -OutFile $scriptPath
        $success = $true
    }
    return $success
}