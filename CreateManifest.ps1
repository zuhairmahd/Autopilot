[CmdletBinding()]
param(
    
)

function CreateManifest()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$versionNumber,
        [Parameter(Mandatory = $true)]
        [string]$rootFolder,
        [Parameter(Mandatory = $false)]
        [string]$functionsFolder = "$($pwd)\Functions",
        [Parameter(Mandatory = $false)]
        [string]$inputFile = "$($pwd)\version.json"
    )
    if (Test-Path -Path $inputFile)
    {
        Write-Host "Updating $($inputFile)..."
    }
    else
    {
        Write-Host "Creating $($inputFile)..."
    }
    $version = @{"Functions" = @(); "Scripts" = @(); "Cmds" = @()}
    $version | ConvertTo-Json | Set-Content -Path $inputFile -Force
    $functionFiles = Get-ChildItem -File -Path $functionsFolder -Recurse -Include *.ps1 -Force
    $scriptFiles = Get-ChildItem -Path "$pwd" *.ps1 -Force
    $cmdFiles = Get-ChildItem -File -Path "$pwd" *.cmd -Force
    $fileTypes = @('functions', 'scripts', 'cmds')
    $functions = @()
    $scripts = @()
    $cmds = @()
    
    
    foreach ($filetype in $fileTypes)
    {
        Write-Host "Processing $filetype"
        switch ($filetype)
        {
            functions
            {  
                foreach ($function in $functionFiles)
                {
                    Write-Verbose "$($function.BaseName)"
                    if ($function.BaseName -notin $version.Functions.name)
                    {
                        Write-Verbose "Computing hash for $($function.BaseName)"
                        $hash = Get-FileHash -Path $function.FullName -Algorithm SHA256
                        Write-Verbose "Adding $($function.BaseName) to $inputFile"
                        $functions += [ordered]@{"name" = $function.BaseName; "version" = $versionNumber; "hash" = $hash.Hash }
                    }
                }
                Write-Host "Processed $($functions.Count) Functions."
            }
            scripts
            {  
                foreach ($script in $scriptFiles)
                {
                    Write-Verbose "$($script.BaseName)"
                    if ($script.BaseName -notin $version.Scripts.name)
                    {
Write-Verbose "Computing hash for $($script.BaseName)"                        
                        $hash = Get-FileHash -Path $script.FullName -Algorithm SHA256
                        Write-Verbose "Adding $($script.BaseName) to $inputFile"
                        $scripts += [ordered]@{"name" = $script.BaseName; "version" = $versionNumber; "hash" = $hash.Hash }
                    }
                }
                Write-Host "Processed $($scripts.Count)Scripts."
            }
            cmds
            {  
                foreach ($cmd in $cmdFiles)
                {
                    Write-Verbose "$($cmd.BaseName)"
                    if ($cmd.BaseName -notin $version.Cmds.name)
                    {
Write-Verbose "Computing hash for $($cmd.BaseName)"                        
                        $hash = Get-FileHash -Path $cmd.FullName -Algorithm SHA256
                        Write-Verbose "Adding $($cmd.BaseName) to $inputFile"
                        $cmds += [ordered]@{"name" = $cmd.BaseName; "version" = $versionNumber; "hash" = $hash.Hash}
                    }
                }
                Write-Host "Processed $($cmds.Count) Cmds."
            }
            Default
            {
                Write-Host "Unknown filetype"
            }
        }        
    }
    $combined = @{"Functions" = $functions; "Scripts" = $scripts; "Cmds" = $cmds}    
    return $combined
}

$outputJSON = CreateManifest -versionNumber "1.0.0" -functionsFolder "$($pwd)\Functions" -inputFile "$($pwd)\manifest.json" -rootFolder $PSScriptRoot
$outputJSON | ConvertTo-Json

# $outputJSON | ConvertTo-Json | Set-Content -Path "$($pwd)\manifest.json"