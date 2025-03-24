
[CmdletBinding(DefaultParameterSetName = 'Default')]
param ()

#import functions.
$functionsFolder = "$pwd\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose "Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}


#define variables.
$manifest = Get-Content -Path "$pwd\manifest.json" | ConvertFrom-Json 
$repo = 'zuhairmahd/Autopilot'
# $latestRelease = GetLatestGithubRelease -Repository $repo -verbose
$latestRelease = 'main'
$repoSourceCodeURL = "https://raw.githubusercontent.com/$repo/$latestRelease"
$remoteManifestPath = "$repoSourceCodeURL/manifest.json"
#write a verbose log of all the variables.
Write-Verbose "Manifest: $($manifest)"
Write-Verbose "Latest Release: $latestRelease"
Write-Verbose "Repo Source Code URL: $repoSourceCodeURL"
Write-Verbose "Remote Manifest Path: $remoteManifestPath"

$remoteManifest = CheckForScriptUpdates -RemoteManifestPath $remoteManifestPath -LocalManifestContent $manifest
$global:r = $remoteManifest
Write-Host "Returned $($remoteManifest.functions.count) functions, $($remoteManifest.scripts.count) scripts, and $($remoteManifest.cmds.count) cmds."

DownloadScriptUpdates -ScriptsToUpdate $remoteManifest -ScriptURI $repoSourceCodeURL -ScriptRoot $PSScriptRoot -verbose
