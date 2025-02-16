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
            $updateURL = $scriptURI + '/functions/' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
            Write-Verbose "The update URL is $updateURL"
        }
        else 
        {
            Write-Verbose "The script $key is a script"
            $scriptPath = $PSScriptRoot + '\' + $key + '.ps1'
            $updateURL = $scriptURI + '/' + $key + '.ps1'
            Write-Verbose "The script path is $scriptPath"
            Write-Verbose "The update URL is $updateURL"
        }
        Write-Host "Updating $key to version $($scriptsToUpdate[$key])." 
        Write-Host "Fetching from $updateURL"
        try
        {
            $response = Invoke-WebRequest -Uri $updateURL -OutFile $scriptPath -Method Get
            $StatusCode = $Response.StatusCode
            Write-Host "The status code is $StatusCode"
            $success = $true
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }
        Write-Host "The status code is $StatusCode"
    }
    if ($success)
    {
        Write-Verbose "updating script version from $updateURL/version.json"
        try
        {
            $response = Invoke-WebRequest -Uri "$scriptURI/version.json" -OutFile $PSScriptRoot\version.json -Method Get
            $StatusCode = $Response.StatusCode  
            Write-Verbose "The status code is $StatusCode"
        }
        catch
        {
            $StatusCode = $_.Exception.Response.StatusCode.value__
        }   
    }
    return $success
}