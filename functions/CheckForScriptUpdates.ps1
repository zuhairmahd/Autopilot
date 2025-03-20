function CheckForScriptUpdates()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True)]
        [string]$RemoteManifestPath,
        [Parameter(Mandatory = $True)]
        [System.Object[]]$LocalManifestContent
    )
    #write a verbose log of all received parameters
    Write-Verbose 'Received the following parameters:'
    Write-Verbose "RemoteManifestPath: $RemoteManifestPath"
    Write-Verbose "LocalManifestContent: $($LocalManifestContent | Out-String)"
    #Read the remote manifest.
    $remoteManifest = Invoke-RestMethod -Uri $RemoteManifestPath -Method Get
    Write-Host $remoteManifest
}

$manifestContent = Get-Content -Path "$PSScriptRoot\..\Manifest.json" -Raw | ConvertFrom-Json
CheckForScriptUpdates -RemoteManifestPath 'https://raw.githubusercontent.com/zuhairmahd/Autopilot/v2.2/manifest.json' -LocalManifestContent $manifestContent
