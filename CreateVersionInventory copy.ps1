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
                        Write-Verbose "Adding $($function.BaseName) to $inputFile"
                        #Get the file hash.
                        $hash = Get-FileHash -Path $function.FullName -Algorithm SHA256
                        $functions += @{"name" = $function.BaseName; "version" = $versionNumber; "hash" = $hash.Hash }
                    }
                }
            }
            scripts
            {  
                foreach ($script in $scriptFiles)
                {
                    Write-Verbose "$($script.BaseName)"
                    if ($script.BaseName -notin $version.Scripts.name)
                    {
                        Write-Verbose "Adding $($script.BaseName) to $inputFile"
                        #Get the file hash.
                        $hash = Get-FileHash -Path $script.FullName -Algorithm SHA256
                        $scripts += @{"name" = $script.BaseName; "version" = $versionNumber; "hash" = $hash.Hash }
                    }
                }
            }
            cmds
            {  
                foreach ($cmd in $cmdFiles)
                {
                    Write-Verbose "$($cmd.BaseName)"
                    if ($cmd.BaseName -notin $version.Cmds.name)
                    {
                        Write-Verbose "Adding $($cmd.BaseName) to $inputFile"
                        #Get the file hash.
                        $hash = Get-FileHash -Path $cmd.FullName -Algorithm SHA256
                        $cmds += @{"name" = $cmd.BaseName; "version" = $versionNumber; "hash" = $hash.Hash}
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
    $combined = @{"Functions" = $functions; "Scripts" = $scripts; "Cmds" = $cmds}    
    return $combined
}

$outputJSON = CreateVersionInventory -versionNumber "1.0.0" -functionsFolder "$($pwd)\Functions" -inputFile "$($pwd)\version.json" -rootFolder $PSScriptRoot
$outputJSON | ConvertTo-Json | Set-Content -Path "$($pwd)\version1.json"