function Get-ScriptUpdates()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string]$configFile = 'config.json'
    )

    $scriptVersion = '1.0.0'
    $scriptName = 'Register-Device.ps1'
    $scriptPath = $PSScriptRoot + '\' + $scriptName
    $scriptUrl = 'https://raw.githubusercontent.com/microsoftgraph/powershell-intune-samples/main/DeviceManagement/Register-Device.ps1'
    $scriptVersionUrl = 'https://raw.githubusercontent.com/microsoftgraph/powershell-intune-samples/main/DeviceManagement/VERSION'
    $scriptVersionRemote = Invoke-RestMethod -Uri $scriptVersionUrl -Method Get
    $scriptVersionRemote = $scriptVersionRemote.Trim()

    if ($scriptVersion -ne $scriptVersionRemote)
    {
        Write-Host "A new version of $scriptName is available. Current version is $scriptVersion. The latest version is $scriptVersionRemote." -ForegroundColor Yellow
        Write-Host 'Do you want to download the latest version?' -ForegroundColor Yellow
        $response = Read-Host 'Enter Y to download or N to skip'
        if ($response -eq 'Y')
        {
            Write-Host "Downloading $scriptName from $scriptUrl"
            Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath
            Write-Host 'Download complete.'
        }
    }
    else
    {
        Write-Host "The script $scriptName is up to date." -ForegroundColor Green
    }
}