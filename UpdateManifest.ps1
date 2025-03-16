function ReadManifest()
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
    
    Write-Host "Read $($version.functions.Count) functions, $($version.scripts.Count) scripts and $($version.cmds.Count) command files from version.json"
    foreach ($category in $version.PSObject.Properties)
    {
        Write-Host "Processing $($category.Value.Count) $($category.Name)s"
        switch ($category.Name) 
        {
            Functions 
            { 
                Write-Verbose "The  category is $($category.Name)"
                foreach ($function in $category.Value)
                {
                    Write-Verbose "Processing function: $($function.Name)"
                    Write-Verbose "Checking if $($function.Name) exists in the files list."
                    if ($functionFiles.baseName -contains $function.Name)
                    {
                        Write-Verbose "Function $($function.Name) exists in the functions list. Adding to array..."
                        $functions += @{"Name" = $function.Name; "Version" = $function.Version}
                    }
                    else 
                    {
                        Write-Host "Function $($function.Name) does not exist in the functions list. Removing..."
                        $removedFunctions += @{"Name" = $function.Name; "Version" = $function.Version}
                    }
                }
            }
            Scripts
            { 
                Write-Verbose "The  category is $($category.Name)"
                foreach ($script in $category.Value)
                {
                    Write-Verbose "Processing script: $($script.Name)"
                    Write-Verbose "Checking if $($script.Name) exists in the scripts list."
                    if ($scriptFiles.baseName -contains $script.Name)
                    {
                        Write-Verbose "Script $($script.Name) exists in the scripts list. Adding to array..."
                        $scripts += @{"Name" = $script.Name; "Version" = $script.Version}
                    }
                    else 
                    {
                        Write-Host "Script $($script.Name) does not exist in the scripts list. Removing..."
                        $removedScripts += @{"Name" = $script.Name; "Version" = $script.Version}
                    }
                }
            }
            Cmds 
            { 
                Write-Verbose "The  category is $($category.Name)"
                foreach ($cmd in $category.Value)
                {
                    Write-Verbose "Processing cmd: $($cmd.Name)"
                    Write-Verbose "Checking if $($cmd.Name) exists in the cmds list."
                    if ($cmdFiles.baseName -contains $cmd.Name)
                    {
                        Write-Verbose "Cmd $($cmd.Name) exists in the cmds list. Adding to array..."
                        $cmds += @{"Name" = $cmd.Name; "Version" = $cmd.Version}
                    }
                    else 
                    {
                        Write-Host "Cmd $($cmd.Name) does not exist in the cmds list. Removing..."
                        $removedCmds += @{"Name" = $cmd.Name; "Version" = $cmd.Version}
                    }
                }
            }
            default
            {
                Write-Verbose "None of the above." 
            }
        }
    }
    
    Write-Host "Added $($functions.Count) functions, $($scripts.Count) scripts and $($cmds.Count) command files."
    Write-Host "Removed $($removedFunctions.Count) functions, $($removedScripts.Count) scripts and $($removedCmds.Count) command files."
    Write-Verbose "Writing $($functions.Count) functions, $($scripts.Count) scripts and $($cmds.Count) command files to $outputFile."
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
                    Write-Verbose "$($function.BaseName)"
                    if ($function.BaseName -notin $version.Functions.name)
                    {
                        Write-Verbose "Adding $($function.BaseName) to the version.json file."
                        $functions += @{"name" = $function.BaseName; "version" = $versionNumber }
                    }
                    else
                    {
                        Write-Verbose "The function is in the list."
                    }
                }
            }
            scripts
            {  
                Write-Verbose "$filetype is a script"
                foreach ($script in $scriptFiles)
                {
                    Write-Verbose "$($script.BaseName)"
                    if ($script.BaseName -notin $version.Scripts.name)
                    {
                        Write-Verbose "Adding $($script.BaseName) to the version.json file."
                        $scripts += @{"name" = $script.BaseName; "version" = $versionNumber }
                    }
                    else
                    {
                        Write-Verbose "The script is in the list."
                    }
                }
            }
            cmds
            {  
                Write-Verbose "$filetype is a cmd"
                foreach ($cmd in $cmdFiles)
                {
                    Write-Verbose "$($cmd.BaseName)"
                    if ($cmd.BaseName -notin $version.Cmds.name)
                    {
                        Write-Verbose "Adding $($cmd.BaseName) to the version.json file."
                        $cmds += @{"name" = $cmd.BaseName; "version" = $versionNumber }
                    }
                    else
                    {
                        Write-Verbose "The cmd is in the list."
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

$outputJSON = CreateVersionInventory -versionNumber "1.0.0" -functionsFolder "$($pwd)\Functions" -inputFile "$($pwd)\version1.json" -rootFolder $PSScriptRoot
$outputJSON |ConvertTo-Json
# $outputJSON | ConvertTo-Json | Set-Content -Path "$($pwd)\version1.json"