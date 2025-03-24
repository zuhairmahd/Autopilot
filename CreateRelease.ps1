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
.PARAMETER SourceFolder The folder containing the scripts to be copied. Defaults to the script root folder.
.PARAMETER ReleaseFolder The folder where the release package will be created. Defaults to a "Release" folder in the current working directory.
.PARAMETER ManifestFile The path to the manifest file. Defaults to "manifest.json" in the release folder.
.PARAMETER Sign A switch to sign the scripts in the specified folders.
.PARAMETER Copy A switch to copy the files from the source folder to the release folder.
.PARAMETER Manifest A switch to create or update the manifest file.
.PARAMETER Overwrite A switch to overwrite the release folder if it already exists.
.PARAMETER FullRelease A switch to perform all actions: signing, copying, and manifest creation.
.EXAMPLE
    .\CreateRelease.ps1 -SourceFolder C:\Scripts -ReleaseFolder C:\Release -ManifestFile C:\Release\manifest.json -Sign -Copy -Manifest
    Creates a release package by signing the scripts in the specified folders, copying the files from the source folder to the release folder, and creating a manifest file.
.EXAMPLE
    .\CreateRelease.ps1 -SourceFolder C:\Scripts -ReleaseFolder C:\Release -ManifestFile C:\Release\manifest.json -FullRelease
    Creates a release package by signing the scripts in the specified folders, copying the files from the source folder to the release folder, and creating a manifest file.
    .NOTES
#>


[CmdletBinding()]
param(
    [string]$SourceFolder = $PSScriptRoot,
    [string]$ReleaseFolder = "$($pwd)\Release",
    [string]$ManifestFile = "$releaseFolder\manifest.json",
    [switch]$Sign,
    [switch]$Copy,
    [switch]$Manifest,
    [switch]$Overwrite,
    [switch]$FullRelease,
    [switch]$Secrets
)

$foldersToSign = @(
    $PSScriptRoot,
    "$PSScriptRoot\functions"
)

Write-Verbose 'Received the following parameters:'
Write-Verbose "SourceFolder: $SourceFolder"
Write-Verbose "ReleaseFolder: $ReleaseFolder"
Write-Verbose "ManifestFile: $ManifestFile"
Write-Verbose 'The following switches were passed:'
Write-Verbose "Sign: $Sign"
Write-Verbose "Copy: $Copy"
Write-Verbose "Overwrite: $Overwrite"
Write-Verbose "FullRelease: $FullRelease"
Write-Verbose "Secrets: $Secrets"

if (-not ($Copy -or $Sign -or $Manifest -or $FullRelease -or $Secrets))
{
    throw 'At least one of the following switches must be provided: -Copy, -Sign, -Manifest, -Secrets or -FullRelease.'
}

function CopySecrets()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder
    )
    
    Write-Verbose 'Received the following parameters:'
    Write-Verbose "SourceFolder: $SourceFolder"
    Write-Verbose "DestinationFolder: $DestinationFolder"
    
    Write-Host 'Looking for secrets...'
    $secrets = Get-ChildItem -Path $SourceFolder -Filter config*.json -Recurse
    if ($secrets.Count -eq 0)
    {
        Write-Host 'No secrets found.'
        return $false
    }
    else
    {
        Write-Host "Found $($secrets.Count) secret files."
        Write-Host 'Please choose the secret you would like to copy to the release folder:'
        for ($i = 1; $i -lt $secrets.Count; $i++)
        {
            $domain = (Get-Content -Path $secrets[$i - 1].FullName | ConvertFrom-Json).domain
            if (-not $domain)
            {
                $domain = 'Unknown'
            }
            Write-Host "$i. $domain"
        }
        $index = Read-Host 'Enter the number of the secret you would like to copy.'
        $secret = $secrets[$index - 1]
        #make sure only a valid number in the correct range is chosen.
        while ($index -lt 1 -or $index -ge $secrets.Count)
        {
            Write-Host 'Invalid choice.'
            #beep
            [console]::beep(500, 300)
            Write-Host "Please choose a number between 1 and $($secrets.Count)"
            $index = Read-Host 'Enter the number of the secret you would like to copy.'
        }
        if (-not $secret)
        {
            Write-Host 'No secrets selected.'
            return $false
        }
    }
    Write-Verbose "Copying $($secret.FullName) to $DestinationFolder"
    if (-not (Test-Path -Path "$DestinationFolder\.secrets"))
    {
        Write-Host 'Creating .secrets folder...'
        New-Item -ItemType Directory -Path "$DestinationFolder\.secrets" -Force | Out-Null
    }
    try 
    {
        Copy-Item -Path $secret.FullName -Destination "$DestinationFolder\.secrets\config.json" -Force
        Write-Verbose 'Secrets copied successfully.'
    }
    catch
    {
        Write-Error "Failed to copy $($secret.FullName) to $DestinationFolder\.secrets"
        Write-Error $_.Exception.Message
        return $false
    }
    return $true
}

function GetExclusions()
{
    [CmdletBinding()]
    param(
        [string]$ExclusionsFile = "$PSScriptRoot\exclusions.json"
    )
    Write-Verbose "ExclusionsFile: $ExclusionsFile"
    if (Test-Path -Path $ExclusionsFile)
    {
        $filesToExclude = (Get-Content -Path $ExclusionsFile | ConvertFrom-Json).exclusions
        Write-Host "Reading $($filesToExclude.Count) exclusions from $($ExclusionsFile)..."
        if ($filesToExclude.Count -gt 0)
        {
            Write-Verbose 'Files to exclude:'
            $filesToExclude | ForEach-Object { Write-Verbose $_ }
        }
        else 
        {
            Write-Host "No exclusions found in $($ExclusionsFile)"
        }
    }
    else
    {
        Write-Host "Cannot find the exclusion file $($ExclusionsFile)."
        $filesToExclude = ''
    }
    return $filesToExclude
}

function SignScripts()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    Write-Verbose "Signing files in $Path"
    $success = $false
    $files = Get-ChildItem -Path $path -Filter *.ps1
    if ($files.Count -eq 0)
    {
        Write-Host "No files found in $Path"
        return $false
    }
    else 
    {
        Write-Host "Found $($files.Count) PowerShell scripts in $Path"
    }
    $filesToSign = @()
    $filesToExclude = GetExclusions
    foreach ($file in $files)
    {
        Write-Verbose "Processing file: $file"
        if ($file.BaseName -in $filesToExclude)
        {
            Write-Verbose "Skipping $($file.BaseName) because it is in the exclusions list"
            continue
        }
        #Check if the file is already signed
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue
        if ($signature.Status -ne 'Valid')
        {
            Write-Verbose "$($file.FullName) is not signed."
            #Add it to the list of files to sign.
            $filesToSign += $file.FullName
        }
    }
    if ($filesToSign.Count -gt 0)
    {
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
        Write-Verbose 'Signing the following files:'
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
    }
    else
    {
        Write-Host 'No files to sign.'
        $success = $true
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
        [Parameter(Mandatory = $false)]
        [string]$PowerShellFolder = "$sourceFolder\pwsh",
        [Parameter(Mandatory = $true)]
        [string]$manifestFile = "$SourceFolder\manifest.json"
    )
    Write-Verbose 'Received the following parameters:'
    Write-Verbose "SourceFolder: $SourceFolder"
    Write-Verbose "DestinationFolder: $DestinationFolder"
    Write-Verbose "FunctionsFolder: $FunctionsFolder"
    Write-Verbose "PowerShellFolder: $PowerShellFolder"
    Write-Verbose "Manifest: $manifestFile"
    $success = $false
    $destinationFunctionsFolder = "$DestinationFolder\functions"
    # Check if any of the required paths do not exist, set $success to false and return $success.
    if (-not (Test-Path -Path $DestinationFolder) -or -not (Test-Path -Path $manifestFile) -or -not (Test-Path -Path $FunctionsFolder) -or -not (Test-Path -Path $PowerShellFolder))
    {
        Write-Host "Cannot find one or more required paths: DestinationFolder ($DestinationFolder), ManifestFile ($manifest), or FunctionsFolder ($FunctionsFolder)."
        return $success
    }
    # Get the manifest file and convert it to a hashtable.
    $manifest = Get-Content -Path $manifestFile | ConvertFrom-Json
    Write-Host "Read $($manifest.functions.Count) functions, $($manifest.scripts.Count) scripts and $($manifest.cmds.Count) command files from $($manifestFile)."
    foreach ($category in $manifest.PSObject.Properties)
    {
        Write-Host "Processing $($category.Value.Count) $($category.Name)s"
        switch ($category.Name) 
        {
            functions
            {
                foreach ($function in $category.Value)
                {
                    Write-Verbose "Copying $($function.name) to $destinationFunctionsFolder"
                    try
                    {
                        Copy-Item -Path "$FunctionsFolder\$($function.name).ps1" -Destination $destinationFunctionsFolder -Force    
                    }
                    catch
                    {
                        Write-Error "Failed to copy $($function.name) to $destinationFunctionsFolder"
                        Write-Error $_.Exception.Message
                        $success = $false
                        return $success
                    }
                }
                Write-Host "Copied $($category.Value.Count) functions."
            }
            scripts
            {
                foreach ($script in $category.Value)
                {
                    Write-Verbose "Copying $($script.name) to $DestinationFolder"
                    try
                    {
                        Copy-Item -Path "$SourceFolder\$($script.name).ps1" -Destination $DestinationFolder -Force    
                    }
                    catch
                    {
                        Write-Error "Failed to copy $($script.name) to $DestinationFolder"
                        Write-Error $_.Exception.Message
                        $success = $false
                        return $success
                    }
                }
                Write-Host "Copied $($category.Value.Count) scripts."
            }
            cmds
            {
                foreach ($cmd in $category.Value)
                {
                    Write-Verbose "Copying $($cmd.name) to $DestinationFolder"
                    try
                    {
                        Copy-Item -Path "$SourceFolder\$($cmd.name).cmd" -Destination $DestinationFolder -Force    
                    }
                    catch
                    {
                        Write-Error "Failed to copy $($cmd.name) to $DestinationFolder"
                        Write-Error $_.Exception.Message
                        $success = $false
                        return $success
                    }
                }
                Write-Host "Copied $($category.Value.Count) command files."
            }
            Default
            {
                Write-Host 'Unknown category'
            }
        }
    }
    # Copy the PowerShell folder to the destination folder.
    Write-Host "Copying $PowerShellFolder to $DestinationFolder"
    Copy-Item -Path $PowerShellFolder -Destination $DestinationFolder -Recurse -Force
    #check to make sure it copied.
    if (-not (Test-Path -Path "$DestinationFolder\pwsh"))
    {
        Write-Error "Failed to copy $PowerShellFolder to $DestinationFolder"
        $success = $false
        return $success
    }
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
        [string]$ManifestFile
    )
    Write-Verbose 'Received the following parameters:'
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
    $version = @{'Functions' = @(); 'Scripts' = @(); 'Cmds' = @() }
    $version | ConvertTo-Json | Set-Content -Path $ManifestFile -Force
    $functionFiles = Get-ChildItem -File -Path $functionsFolder -Recurse -Include *.ps1 -Force
    $scriptFiles = Get-ChildItem -Path "$pwd" *.ps1 -Force
    $cmdFiles = Get-ChildItem -File -Path "$pwd" *.cmd -Force
    $fileTypes = @('functions', 'scripts', 'cmds')
    $functions = @()
    $scripts = @()
    $cmds = @()
    $filesToExclude = GetExclusions
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
                        $versionString = Select-String -Path $function.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)' -Raw
                        if ($versionString)
                        {
                            $versionNumber = [regex]::Match($versionString, '\d+\.\d+\.\d').Value
                            $versionNumber = [System.Version]$versionNumber
                        }
                        else
                        {
                            $versionNumber = $versionNumber = [System.Version]'0.0.0'
                        }
                        Write-Verbose "The version of $($function.BaseName) is $versionNumber"
                        Write-Verbose "Computing hash for $($function.BaseName)"
                        $hash = Get-FileHash -Path $function.FullName -Algorithm SHA256
                        Write-Verbose "The hash of $($function.BaseName) is $($hash.Hash)"
                        Write-Verbose "Adding $($function.BaseName) to $manifestFile"
                        $functions += [ordered]@{'name' = $function.BaseName; 'version' = $versionNumber; 'hash' = $hash.Hash }
                    }
                    else 
                    {
                        Write-Verbose "Skipping $($function.BaseName)"
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
                        $versionString = Select-String -Path $script.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)' -Raw
                        if ($versionString)
                        {
                            $versionNumber = [regex]::Match($versionString, '\d+\.\d+\.\d').Value
                            $versionNumber = [System.Version]$versionNumber
                        }
                        else
                        {
                            $versionNumber = [System.Version]'0.0.0'
                        }
                        Write-Verbose "The version of $($script.BaseName) is $versionNumber"
                        Write-Verbose "Computing hash for $($script.BaseName)"                        
                        $hash = Get-FileHash -Path $script.FullName -Algorithm SHA256
                        Write-Verbose "The hash of $($script.BaseName) is $($hash.Hash)"
                        Write-Verbose "Adding $($script.BaseName) to $manifestFile"
                        $scripts += [ordered]@{'name' = $script.BaseName; 'version' = $versionNumber; 'hash' = $hash.Hash }
                    }
                    else
                    {
                        Write-Verbose "Skipping $($script.BaseName)"
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
                        $versionString = Select-String -Path $cmd.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)' -Raw
                        if ($versionString)
                        {
                            $versionNumber = [regex]::Match($versionString, '\d+\.\d+\.\d').Value
                            $versionNumber = [System.Version]$versionNumber
                        }
                        else
                        {
                            $versionNumber = [System.Version]'0.0.0'
                        }
                        Write-Verbose "The version of $($cmd.BaseName) is $versionNumber"
                        Write-Verbose "Computing hash for $($cmd.BaseName)"                        
                        $hash = Get-FileHash -Path $cmd.FullName -Algorithm SHA256
                        Write-Verbose "The hash of $($cmd.BaseName) is $($hash.Hash)"
                        Write-Verbose "Adding $($cmd.BaseName) to $manifestFile"
                        $cmds += [ordered]@{'name' = $cmd.BaseName; 'version' = $versionNumber; 'hash' = $hash.Hash }
                    }
                    else
                    {
                        Write-Verbose "Skipping $($cmd.BaseName)"
                    }
                }
                Write-Host "Processed $($cmds.Count) Cmds."
            }
            Default
            {
                Write-Host 'Unknown filetype'
            }
        }        
    }
    $combined = @{'Functions' = $functions; 'Scripts' = $scripts; 'Cmds' = $cmds }    
    $combined | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestFile -Force    
    Write-Host "Successfully updated $($ManifestFile)"
    $success = $true
    return $success
}

### Main script ###
if (-not $Overwrite) 
{
    if (Test-Path -Path $ReleaseFolder)
    {
        Write-Host "Destination folder $releaseFolder already exists."
        Write-Host 'What would you like to do?'
        do
        {
            $response = Read-Host 'Choose O to overwrite, C to continue or E to exit (O/C/E)'
        } 
        until ($response -in 'O', 'C', 'E')
        switch ($response)
        {
            O
            {
                Write-Host "Removing $ReleaseFolder"
                Remove-Item -Path $ReleaseFolder -Recurse -Force | Out-Null
                Write-Host "Creating folder $ReleaseFolder"
                New-Item -Path $ReleaseFolder -ItemType Directory -Force | Out-Null
                Write-Verbose 'Creating functions folder'
                New-Item -Path "$ReleaseFolder\functions" -ItemType Directory -Force | Out-Null
                Write-Host 'Creating secrets folder.'
                New-Item -Path "$ReleaseFolder\.secrets" -ItemType Directory -Force | Out-Null
            }
            C
            {
                Write-Host 'Continuing with the existing folder.'
                #Check to make sure all subfolders exist.
                if (-not (Test-Path -Path "$ReleaseFolder\functions"))
                {
                    Write-Host 'Creating functions folder'
                    New-Item -Path "$ReleaseFolder\functions" -ItemType Directory -Force | Out-Null
                }
                if (-not (Test-Path -Path "$ReleaseFolder\.secrets"))
                {
                    Write-Host 'Creating secrets folder'
                    New-Item -Path "$ReleaseFolder\.secrets" -ItemType Directory -Force | Out-Null
                }
            }
            E
            {
                Write-Host 'Exiting...'
                exit 0
            }
        }
    }
    else
    {
        Write-Host "Creating folder $ReleaseFolder"
        New-Item -Path $ReleaseFolder -ItemType Directory -Force | Out-Null
        Write-Verbose 'Creating functions folder'
        New-Item -Path "$ReleaseFolder\functions" -ItemType Directory -Force | Out-Null
        Write-Verbose 'Creating secrets folder'
        New-Item -Path "$ReleaseFolder\.secrets" -ItemType Directory -Force | Out-Null
    }
}
else
{
    Write-Host "Overwriting $ReleaseFolder"
    Remove-Item -Path $ReleaseFolder -Recurse -Force | Out-Null
    New-Item -Path $ReleaseFolder -ItemType Directory -Force | Out-Null
    Write-Verbose 'Creating functions folder'
    New-Item -Path "$ReleaseFolder\functions" -ItemType Directory -Force | Out-Null
}

if (($sign) -or ($FullRelease))
{
    foreach ($folder in $foldersToSign)
    {
        $folder | ForEach-Object { Write-Verbose $_ }
        if (SignScripts -Path $folder)
        {
            Write-Host "File signature for folder $folder is complete."
        }
        else
        {
            Write-Host "Failed to sign files in $folder"
            Write-Host 'Run the script with the -verbose switch for more information.'
        }
    }
}
else
{
    Write-Host 'Skipping signing process.'
}

if (($Manifest) -or ($FullRelease))
{
    Write-Host "Creating manifest in $ReleaseFolder"
    if (CreateManifest -rootFolder $pwd -ManifestFile $ManifestFile)
    {
        Write-Host 'Manifest created successfully.'
        $manifestFile = (Split-Path -Path $manifestFile -Leaf).json
        Write-Host "Copying manifest $manifestFile.json from $releaseFolder to $PSScriptRoot"
        try
        {
            Copy-Item -Path "$ReleaseFolder\$manifestFile" -Destination $PSScriptRoot -Force 
            Write-Host 'Manifest copied successfully.'
        }
        catch
        {
            Write-Error "Failed to copy manifest to $PSScriptRoot"
            Write-Error $_.Exception.Message
            exit 1
        }
    }
    else
    {
        Write-Host 'Failed to create manifest.'
        Write-Host 'Run the script with the -verbose switch for more information.'
    }
}
else 
{
    Write-Host 'Skipping manifest creation.'
}

if (($Copy) -or ($FullRelease))
{
    Write-Host "Copying files from $SourceFolder to $ReleaseFolder"
    if (CopyFiles -SourceFolder $PSScriptRoot -DestinationFolder $ReleaseFolder -Manifest $ManifestFile)
    {
        Write-Host 'Files copied successfully.'
    }
    else
    {
        Write-Host 'Failed to copy files.'
        Write-Host 'Run the script with the -verbose switch for more information.'
    }
}
else
{
    Write-Host 'Skipping copy process.'
}

if (($Secrets) -or ($FullRelease))
{
    Write-Host "Copying secrets from $PSScriptRoot to $ReleaseFolder"
    if (CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $ReleaseFolder)
    {
        Write-Host 'Secrets copied successfully.'
    }
    else
    {
        Write-Host 'Failed to copy secrets.'
        Write-Host 'Run the script with the -verbose switch for more information.'
    }
}
else
{
    Write-Host 'Skipping secrets copy process.'
}
