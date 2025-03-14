function CreateVersionInventory()
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
    
    #If the input file does not exist, create it.
    if (-not (Test-Path -Path $inputFile))
    {
        Write-Host "Creating version.json file..."
        $version = @{"Functions" = @(); "Scripts" = @(); "Cmds" = @()}
        $version | ConvertTo-Json | Set-Content -Path $inputFile
    }
    else
    {
        Write-Host "Version.json file already exists."
    }
    
    $version = Get-Content -Raw -Path $inputFile | ConvertFrom-Json
    $functionFiles = Get-ChildItem -File -Path $functionsFolder -Recurse -Include *.ps1 -Force
    $scriptFiles = Get-ChildItem -Path "$pwd" *.ps1 -Force
    $cmdFiles = Get-ChildItem -File -Path "$pwd" *.cmd -Force
    $fileTypes = @('functions', 'scripts', 'cmds')
    $functions = @()
    $scripts = @()
    $cmds = @()
    $removedFunctions = @()
    $removedScripts = @()
    $removedCmds = @()
    foreach ($filetype in $fileTypes)
    {
        Write-Host "Checking $filetype"
        Write-Host "We have $($version.$filetype.Count) $filetype in the version.json file."
        switch ($filetype)
        {
            functions
            {  
                Write-Host "Processing functions..."
                foreach ($function in $functionFiles)
                {
                    Write-Host "$($function.BaseName)"
                    if ($function.BaseName -notin $version.Functions.name)
                    {
                        Write-Host "Adding $($function.BaseName) to the version.json file."
                        $functions += @{"name" = $function.BaseName; "version" = $versionNumber }
                    }
                    else
                    {
                        Write-Host "The function is in the list."
                    }
                }
                # Add new functions to version.json
            }
            scripts
            {  
                Write-Host "$filetype is a script"
                foreach ($script in $scriptFiles)
                {
                    Write-Host "$($script.BaseName)"
                    if ($script.BaseName -notin $version.Scripts.name)
                    {
                        Write-Host "Adding $($script.BaseName) to the version.json file."
                        $scripts += @{"name" = $script.BaseName; "version" = $versionNumber }
                    }
                    else
                    {
                        Write-Host "The script is in the list."
                    }
                }
            }
            cmds
            {  
                Write-Host "$filetype is a cmd"
                foreach ($cmd in $cmdFiles)
                {
                    Write-Host "$($cmd.BaseName)"
                    if ($cmd.BaseName -notin $version.Cmds.name)
                    {
                        Write-Host "Adding $($cmd.BaseName) to the version.json file."
                        $cmds += @{"name" = $cmd.BaseName; "version" = $versionNumber }
                    }
                    else
                    {
                        Write-Host "The cmd is in the list."
                    }
                }
            }
            Default
            {
                Write-Host "Unknown filetype"
            }
        }        
    }
    Write-Host "Functions: $($functions.Count)"
    Write-Host "Scripts: $($scripts.Count)"
    Write-Host "Cmds: $($cmds.Count)"
    $version | ConvertTo-Json | Set-Content -Path $inputFile
    return 0
}

$outputJSON = CreateVersionInventory -versionNumber "1.0.0" -functionsFolder "$($pwd)\Functions" -inputFile "$($pwd)\version.json" -rootFolder $PSScriptRoot
# $outputJSON | ConvertTo-Json | Set-Content -Path "$($pwd)\version.json"