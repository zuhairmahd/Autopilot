    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$versionNumber,
        [Parameter(Mandatory = $true)]
        [string]$outputFile
    )

    $functionsFolder = "$($pwd)\Functions"
    $functionFiles = Get-ChildItem -File -Path $functionsFolder -Recurse -Include *.ps1 -Force
    $scriptFiles = Get-ChildItem -Path "$pwd" *.ps1 -Force
    $cmdFiles = Get-ChildItem -file -Path "$pwd" *.cmd -Force
    $version = Get-Content -Raw -Path version.json | ConvertFrom-Json
    $functions = @()
    $scripts = @()
    $cmds = @()

    foreach ($category in $version.PSObject.Properties)
    {
        Write-Host "Processing category: $($category.Name)"
        switch ($category.Name) 
        {
            Functions 
            { 
                Write-Host "The  category is $($category.Name)"
                foreach ($function in $category.Value.PSObject.Properties)
                {
                    Write-Host "Processing function: $($function.Name)"
                    #Add the function name and version to the functions array
                    Write-Host "Function name: $($function.Name)"
                    Write-Host "Version: $versionNumber"
                    $functions += @{"Name" = $function.Name; "Version" = $versionNumber}
                }
            }
            Scripts
            { 
                Write-Host "This is a script" 
                foreach ($script in $category.Value.PSObject.Properties)
                {
                    Write-Host "Processing script: $($script.Name)"
                    #Add the script name and version to the scripts array
                    Write-Host "Script name: $($script.Name)"
                    Write-Host "Version: $versionNumber"
                    $scripts += @{"Name" = $script.Name; "Version" = $versionNumber}
                }
            }
            Cmds 
            { 
                Write-Host "This is a cmd" 
                foreach ($cmd in $category.Value.PSObject.Properties)
                {
                    Write-Host "Processing cmd: $($cmd.Name)"
                    #Add the cmd name and version to the cmds array
                    Write-Host "Cmd name: $($cmd.Name)"
                    Write-Host "Version: $versionNumber"
                    $cmds += @{"Name" = $cmd.Name; "Version" = $versionNumber}
                }
            }
            default
            {
                Write-Host "None of the above." 
            }
        }
    }



foreach ($file in $functionFiles)
{
    Write-Host "Processing function: $($file.baseName)"
    Write-Host "Checking if $($file.baseName) exists in the functions list."
    if ($functions.Name -notcontains $file.baseName)
    {
        Write-Host "Function $($file.baseName) does not exist in the functions list. Adding..."
        $functions += @{"Name" = $file.baseName; "Version" = $versionNumber}
    }
    else 
    {
        Write-Host "Function $($file.baseName) already exists in the functions list"
    }
}

foreach ($file in $scriptFiles)
{
    Write-Host "Processing script: $($file.baseName)"
    Write-Host "Checking if $($file.baseName) exists in $($scripts.Name)"
    if ($scripts.Name -notcontains $file.baseName)
    {
        Write-Host "Script $($file.baseName) does not exist in the scripts list. Adding..."
        $scripts += @{"Name" = $file.baseName; "Version" = $versionNumber}
    }
    else 
    {
        Write-Host "Script $($file.baseName) already exists in the scripts list"
    }
}

foreach ($file in $cmdFiles)
{
    Write-Host "Checking if $($file.baseName) exists in the cmds list."
    if ($cmds.Name -notcontains $file.baseName)
    {
        Write-Host "Cmd $($file.baseName) does not exist in the cmds list. Adding..."
        $cmds += @{"Name" = $file.baseName; "Version" = $versionNumber}
    }
    else 
    {
        Write-Host "Cmd $($file.baseName) already exists in the cmds list"
    }
}

$combined = @{"Functions" = $functions; "Scripts" = $scripts; "Cmds" = $cmds} 
$combined | ConvertTo-Json | Out-File -FilePath $outputFile -Force