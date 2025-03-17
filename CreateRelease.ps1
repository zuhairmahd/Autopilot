<#PSScriptInfo
.VERSION 1.0.0
.GUID d973dfdd-190f-48ca-97de-a99d8e9cbd37
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Creates a release package
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES, Microsoft.Graph.Authentication, Microsoft.Graph.Groups', Microsoft.Graph.Identity.DirectoryManagement, WindowsAutoPilotIntune
.EXTERNALSCRIPTDEPENDENCIES, Invoke-TrustedSigning
.REQUIREDSCRIPTS
.SYNOPSIS 
    Creates a release package
.DESCRIPTION 
    This script creates a release package by copying files from the source folder to the release folder, signing the scripts, and creating a manifest file.
.PARAMETER SourceFolder The folder containing the scripts to be copied.
.PARAMETER ReleaseFolder The folder where the release package will be created.
.PARAMETER ManifestFile The path to the manifest file.
.PARAMETER Sign A switch to sign the scripts.
.PARAMETER Copy A switch to copy the files.
.PARAMETER SkipFolderCheck A switch to skip the release folder check.
.EXAMPLE
    .\CreateRelease.ps1 -SourceFolder C:\Scripts -ReleaseFolder C:\Release -ManifestFile C:\Release\manifest.json -Sign
#>


[CmdletBinding()]
param(
    [string]$SourceFolder = $PSScriptRoot,
    [string]$ReleaseFolder = "$($pwd)\Release",
    [string]$ManifestFile = "$ReleaseFolder\manifest.json",
    [switch]$Sign,
    [switch]$Copy,
    [switch]$SkipFolderCheck
)


function SignScripts()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    Write-Verbose "Signing files in $Path"
    $success = $false
    $files = Get-ChildItem -Path $path -Filter *.ps1 -Recurse
    if ($files.Count -eq 0)
    {
        Write-Host "No files found in $Path"
        return $false
    }
    else 
    {
        Write-Host "Found $($files.Count) files in $Path"
    }
    $filesToSign = @()
    foreach ($file in $files)
    {
        Write-Verbose "Processing file: $file"
        #Check if the file is already signed
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue
        if ($signature.Status -eq 'Valid')
        {
            Write-Host "$($file.FullName) is already signed."
        }
        else
        {
            Write-Host "$($file.FullName) is not signed."
            #Add it to the list of files to sign.
            $filesToSign += $file.FullName
        }
    }
    Write-Verbose "Signing $($filesToSign.Count) files..."
    $filesToSign | ForEach-Object { Write-Verbose $_ }
    $filesToSign = $filesToSign -join ','
    $params = @{
        'Endpoint'               = 'https://eus.codesigning.azure.net/'
        'CodeSigningAccountName' = 'zuhairmahd'
        'CertificateProfileName' = 'Cert1'
        'FileDigest'             = 'SHA256'
        'TimestampRfc3161'       = 'http://timestamp.acs.microsoft.com'
        'TimestampDigest'        = 'SHA256'
        files                    = $filesToSign
    }
    Write-Verbose "Signing the following files:"
    $filesToSign | ForEach-Object { Write-Verbose $_ }
    try
    {
        Invoke-TrustedSigning @params
        Write-Host 'Signing process complete.'
        $success = $true
    }
    catch
    {
        $success = $false
        Write-Host 'An error occurred during the signing process.'
        Write-Host $_.Exception.Message
    }
    return $success
}

function CopyFiles()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        [Parameter(Mandatory = $false)]
        [string]$DestinationFolder = "$sourceFolder\Release",
        [Parameter(Mandatory = $false)]
        [string]$FunctionsFolder = "$sourceFolder\functions",
        [string]$exclusionsFile = "$SourceFolder\exclusions.json"
    )
    if (Test-Path -Path $exclusionsFile)
    {
        $filesToExclude = (Get-Content -Path $exclusionsFile | ConvertFrom-Json).exclusions
        Write-Host "Reading $($filesToExclude.Count) exclusions from $($exclusionsFile)..."
    }
    else
    {
        Write-Host "Cannot find the exclusion file $($exclusionsFile)."
        $filesToExclude = @()
    }    
    Write-Verbose "Files to exclude:"
    $filesToExclude | ForEach-Object { Write-Verbose $_ }
    Write-Verbose "Received the following parameters:"
    Write-Verbose "SourceFolder: $SourceFolder"
    Write-Verbose "DestinationFolder: $DestinationFolder"
    Write-Verbose "FunctionsFolder: $FunctionsFolder"
    Write-Verbose "Copying files from $SourceFolder to $DestinationFolder"
    $success = $false

    $scripts = Get-ChildItem -Path "$SourceFolder\*" -Include *.ps1, *.cmd -Force
    $functions = Get-ChildItem -Path "$sourceFolder\functions\*" -Include *.ps1 -Force
    
    if ($scripts.Count -gt 0)
    {
        $filesToCopy = $scripts.FullName
        Write-Host "Copying $($filesToCopy.Count) files from $SourceFolder to $DestinationFolder"
        $filesToCopy | ForEach-Object {
            Write-Verbose "Processing $_"
            #Asign only the name of the file to a variable called filename by using a regex pattern to remove the parent folder and the file extension. 
            $filename = [regex]::Match($_, '([^\\]+)(?=\.\w+$)').Value
            Write-Verbose "Checking if $filename is in the exclusion list."
            if ($filename -notin $filesToExclude)
            {
                Write-Verbose "Copying $filename to $DestinationFolder"
                Copy-Item -Path $_ -Destination $DestinationFolder -Force
            }
            else
            {
                Write-Host "Skipping $filename"
            }
        }
        Write-Host "Copy process complete."
    }
    else
    {
        Write-Host "No scripts found in $SourceFolder"
        $success = $false
    }
    if ($functions.Count -gt 0)
    {
        Write-Host "Found $($functions.Count) files in $SourceFolder\functions"
        $filesToCopy = $functions.FullName
        Write-Host "Copying $($filesToCopy.Count) files from $FunctionsFolder to $DestinationFolder\functions"
        $filesToCopy | ForEach-Object {
            Write-Verbose "Processing $_"
            # Asign only the name of the file to a variable called filename by using a regex pattern to remove the parent folder and the file extension.
            $filename = [regex]::Match($_, '([^\\]+)(?=\.\w+$)').Value
            Write-Verbose "Checking if $filename is in the exclusion list."
            # if the file is not in the exclusion list, copy it.
            if ($filename -notin $filesToExclude)
            {
                Write-Verbose "Copying $_ to $DestinationFolder\functions"
                Copy-Item -Path $_ -Destination $DestinationFolder\functions -Force
            }
            else
            {
                Write-Host "Skipping $filename"
            }
        }
    }
    Write-Host "Copy process complete."
    $success = $true
    return $success
}

function CreateManifest()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$rootFolder,
        [Parameter(Mandatory = $false)]
        [string]$functionsFolder = "$($rootFolder)\functions",
        [Parameter(Mandatory = $false)]
        [string]$ExclusionsFile = "$rootFolder\exclusions.json",
        [Parameter(Mandatory = $true)]
        [string]$ManifestFile
    )
    Write-Verbose "Received the following parameters:"
    Write-Verbose "versionNumber: $versionNumber"
    Write-Verbose "rootFolder: $rootFolder"
    Write-Verbose "functionsFolder: $functionsFolder"
    Write-Verbose "ManifestFile: $ManifestFile"
    $success = $false
    if (Test-Path -Path $ManifestFile)
    {
        Write-Host "Updating $($ManifestFile)..."
    }
    else
    {
        Write-Host "Creating $($ManifestFile)..."
    }
    $version = @{"Functions" = @(); "Scripts" = @(); "Cmds" = @() }
    $version | ConvertTo-Json | Set-Content -Path $ManifestFile -Force
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
                    Write-Verbose "Checking if $($function.BaseName) is in the exclusion list."
                    if ($function.BaseName -notin $filesToExclude) 
                    {
                        Write-Verbose "Getting the version number for $($function.BaseName)"
                        $versionNumber = [regex]::Match((Select-String -Path $function.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)' -Raw), '\d+\.\d+\.\d').Value
                        if (-not $versionNumber)
                        {
                            Write-Warning "No version number found for $($function.BaseName)."
                            $versionNumber = '0.0.0'
                        }
                        Write-Verbose "Computing hash for $($function.BaseName)"
                        $hash = Get-FileHash -Path $function.FullName -Algorithm SHA256
                        Write-Verbose "Adding $($function.BaseName) to $manifestFile"
                        $functions += [ordered]@{"name" = $function.BaseName; "version" = $versionNumber; "hash" = $hash.Hash }
                    }
                }
                Write-Host "Processed $($functions.Count) Functions."
            }
            scripts
            {  
                foreach ($script in $scriptFiles)
                {
                    Write-Verbose "Checking if $($script.BaseName) is in the exclusion list."
                    if ($script.BaseName -notin $filesToExclude)
                    {
                        Write-Verbose "Getting the version number for $($script.BaseName)"
                        $versionNumber = [regex]::Match((Select-String -Path $script.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)' -Raw), '\d+\.\d+\.\d').Value
                        if (-not $versionNumber)
                        {
                            Write-Warning "No version number found for $($script.BaseName)."
                            $versionNumber = '0.0.0'
                        }
                        Write-Verbose "Computing hash for $($script.BaseName)"                        
                        $hash = Get-FileHash -Path $script.FullName -Algorithm SHA256
                        Write-Verbose "Adding $($script.BaseName) to $manifestFile"
                        $scripts += [ordered]@{"name" = $script.BaseName; "version" = $versionNumber; "hash" = $hash.Hash }
                    }
                }
                Write-Host "Processed $($scripts.Count)Scripts."
            }
            cmds
            {  
                foreach ($cmd in $cmdFiles)
                {
                    Write-Verbose "Checking if $($cmd.BaseName) is in the exclusion list."
                    if ($cmd.BaseName -notin $filesToExclude)
                    {
                        Write-Verbose "Getting the version number for $($cmd.BaseName)"
                        $versionNumber = [regex]::Match((Select-String -Path $cmd.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)' -Raw), '\d+\.\d+\.\d').Value
                        if (-not $versionNumber)
                        {
                            Write-Warning "No version number found for $($cmd.BaseName)."
                            $versionNumber = '0.0.0'
                        }
                        Write-Verbose "Computing hash for $($cmd.BaseName)"                        
                        $hash = Get-FileHash -Path $cmd.FullName -Algorithm SHA256
                        Write-Verbose "Adding $($cmd.BaseName) to $manifestFile"
                        $cmds += [ordered]@{"name" = $cmd.BaseName; "version" = $versionNumber; "hash" = $hash.Hash }
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
    $combined = @{"Functions" = $functions; "Scripts" = $scripts; "Cmds" = $cmds }    
    try
    {
        $combined | ConvertTo-Json | Set-Content -Path $ManifestFile -Force    
        Write-Host "Successfully updated $($ManifestFile)"
        if ($copy)
        {
            Write-Host "Successfully copied files to $ReleaseFolder"
        }
        $success = $true
    }
    catch
    {
        Write-Error "Failed to write to $($ManifestFile)"
        $success = $false
    }
    return $success
}

### Main script ###
if (-not $SkipFolderCheck)
{
    if (-not (Test-Path -Path $ReleaseFolder))
    {
        Write-Verbose "Creating $ReleaseFolder"
        New-Item -Path $ReleaseFolder -ItemType Directory -Force | Out-Null
        Write-Verbose "Creating $releaseFolder\functions"
        New-Item -Path "$ReleaseFolder\functions" -ItemType Directory -Force | Out-Null
    }
    else 
    {
        Write-Host "Destination folder $releaseFolder already exists."
        Write-Host "Would you like to delete and start fresh?"
        do
        {
            $response = Read-Host "Enter 'Y' to delete and start fresh or 'N' to exit"
        } until ($response -eq 'Y' -or $response -eq 'N')
        if ($response -eq 'Y')
        {
            Write-Host "Deleting contents of $releaseFolder..."
            Remove-Item -Path $releaseFolder\* -Recurse -Force
            Write-Host "Starting fresh..."
            Write-Verbose "Creating $releaseFolder"
            New-Item -Path $releaseFolder -ItemType Directory -Force | Out-Null
            Write-Verbose "Creating $releaseFolder\functions"
            New-Item -Path "$releaseFolder\functions" -ItemType Directory -Force | Out-Null
        }    
        else 
        {
            Write-Host "Exiting..."
            exit 0  
        }
    }
}
else 
{
    Write-Host "Skipping folder check."
}


if ($sign)
{
    Write-Host "Signing files in release folder..."
    Write-Verbose "Signing files in the following folders:"
    $ReleaseFolder | ForEach-Object { Write-Verbose $_ }
    if (SignScripts -Path $ReleaseFolder)
    {
        Write-Host "Files signed successfully."
    }
    else
    {
        Write-Host "Failed to sign files in $ReleaseFolder"
        Write-Host "Run the script with the -verbose switch for more information."
    }
}
else
{
    {
        Write-Host "Skipping signing process."
    }
}

Write-Host "Creating manifest in $ReleaseFolder"
if (CreateManifest -rootFolder $pwd -ManifestFile $ManifestFile)
{
    Write-Host "Manifest created successfully."
}
else
{
    Write-Host "Failed to create manifest."
    Write-Host "Run the script with the -verbose switch for more information."
}


Write-Host "Copying files and creating release folder."
if (CopyFiles -SourceFolder $PSScriptRoot -DestinationFolder $ReleaseFolder)
{
    Write-Host "Files copied successfully."
}
else
{
    Write-Host "Failed to copy files."
    Write-Host "Run the script with the -verbose switch for more information."
}
