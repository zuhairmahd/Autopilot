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
    [switch]$FullRelease
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

if (-not ($Copy -or $Sign -or $Manifest -or $FullRelease))
{
    throw 'At least one of the following switches must be provided: -Copy, -Sign, -Manifest, or -FullRelease.'
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
        Write-Host "Files in the folder will be overwritten."
        do
        {
            $response = Read-Host "Proceed? (Y/N)"
        } 
        until ($response -eq 'Y' -or $response -eq 'N')
        if ($response -eq 'Y')
        {
            Write-Host "Cleaning folder $releaseFolder..."
            Remove-Item -Path $releaseFolder\*.ps1 -Force | Out-Null
            Write-Verbose "Removing scripts in  $releaseFolder"
            Remove-Item -Path $releaseFolder\*.cmd -Force | Out-Null
            Write-Verbose "Removing commands in  $releaseFolder"
            Remove-Item -Path $releaseFolder\functions\*.ps1 -Force | Out-Null
            Write-Verbose "Removing functions in  $releaseFolder\functions"
            Remove-Item -Path $releaseFolder\Pwsh -Recurse  -Force | Out-Null
            Write-Verbose "Removing PowerShell folder in  $releaseFolder\Pwsh"
        }    
        else 
        {
            Write-Host 'Exiting...'
            exit 0  
        }
    }
}
else 
{
    if (Test-Path -Path $ReleaseFolder)
    {
        Write-Host "Destination folder $releaseFolder already exists."
        Write-Host "Removing $ReleaseFolder..."
        Remove-Item -Path $ReleaseFolder -Recurse -Force
    }
    Write-Host "Creating $ReleaseFolder"
    New-Item -Path $ReleaseFolder -ItemType Directory -Force | Out-Null
    Write-Host "Creating $releaseFolder\functions"
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

#remove the path from the manifest file
$manifestFile = (Split-Path -Path $manifestFile -Leaf).json
#Copy the generated manifest to the root folder.
Write-Host "Copying manifest $manifestFile.json from $releaseFolder to $PSScriptRoot"
try
{
    Copy-Item -Path "$ReleaseFolder\$manifestFile" -Destination $PSScriptRoot -Force 
    Write-Host "Manifest copied successfully."
}
catch
{
    Write-Error "Failed to copy manifest to $PSScriptRoot"
    Write-Error $_.Exception.Message
    exit 1
}

# SIG # Begin signature block
# MII95AYJKoZIhvcNAQcCoII91TCCPdECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC+go8GXQHZ3rh9
# qazS1j11AfeQoKRkzeDLp9ulpIGP36CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAMMtJvn
# rrWgNRokAAAAAwy0MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwMzIxMDcxNDE1WhcNMjUwMzI0
# MDcxNDE1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# tBsEz+zbg92T+0waG5eMjJkVWC9CW3VdTvZl7bFz8UrQV4ym1lWDXIuixT/obXOR
# 10SMyZ8nfRztD3Nxzyx6WF7crrKI6exQTRFkXclbyxiIpYYggA0h2HcVjGn0woEY
# JLQMGplBHinAUvJnVX5L2QHhw2Z3LEAbmjIcI5cfE96UdOMV2hj6e/Rn15I4qvgi
# o7viABNWhxNOPDu0tXi7HmoDxJR5Y859WQ+PEs+i1k7GuIdp9Um4l2StLa5zGzfJ
# rEWvMbVSWN7qFifgxyIYJKPnMlMDJVJWGDgNqclCjypW9UtKcu3YdeXBwmNBkQqQ
# 9DocbACp2xmmS/2a5++lv4gL8tQpHEVdkqoW7CiY5dsOXAZa1WSOZMaV49Lle+hv
# jEAcZzjucWB1vOAjJUz9y39wuyzNZMgUpV9N+VrzsNIQMTMOTDEQAuKRPy01Ycig
# nBSHjqZPYxuyjIqF7i1GzJ6jEDcpvS42e1IrqwfoKX1VRbyn5NxZwmQ0UstvWo0N
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFDW4qjO4Q+HRGucAaV+VaeqapYe6MB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBACEZW/cvYGkaW6NA
# ypVO36NtlcPr4ZdnY8lOgk6mhdBz1xjIO7R1xRPmtLhIApomav0Q8CqKZYRrNywX
# g1la6IG8wfNRbhswGtxSXztJA5fB9NlOyEAEa+73cX4HRc9ilCN/Fd16naercH0k
# tjkVsHjhouuvCOPgR78EwpXC/KHEEzh8vMsrcuwfBT7URUYRG24qnz11VXyAix2W
# 90fm8DK4Ob6KefSd46Fii/aLLzabm3LHTOjUR6+bmYWg+8KxA7qfe9zQTa2op6YK
# OMkuBiJzxmcqpni9BkoM1dewbwsjhfXFEiKRIOgbYT2F/oHTRUtAKhvtp0WAvR4Y
# GYlr1L5l0swqGoh7cfvieDYrRR9yYF0eeRxy8yAlqemwjM1hZ5FfKBudFVXQlCuO
# i/I/Nsrx8e7NuDp2xOC9dKnpm02UD3PCcwtY+wmUYGJ7VAQwXPyon7JMZqTVsU54
# KZtHYPsWFEtDmTZ1VFxMCva12TU3e/b+yxdlzS3Cn2Ov0CDDQQtZPSnI44pfBNDL
# v3ZerM45bJFRXPhD1ouzf7FHES0oqBnc5NsmbueFwXMzY/s2CKHhQip2ZAMWpoXe
# ros6Dvn4ABn3Hfe+yzZ3LBCxD/zQ7zdQjEjmQY5AjGuL6UVkHpR4jR6mJ6xTlw8z
# 2+oF0pWpLFCRxiLBiDsjVWIZUcfFMIIG5zCCBM+gAwIBAgITMwADDLSb5661oDUa
# JAAAAAMMtDANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDMyMTA3MTQxNVoXDTI1MDMyNDA3MTQx
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBALQbBM/s
# 24Pdk/tMGhuXjIyZFVgvQlt1XU72Ze2xc/FK0FeMptZVg1yLosU/6G1zkddEjMmf
# J30c7Q9zcc8selhe3K6yiOnsUE0RZF3JW8sYiKWGIIANIdh3FYxp9MKBGCS0DBqZ
# QR4pwFLyZ1V+S9kB4cNmdyxAG5oyHCOXHxPelHTjFdoY+nv0Z9eSOKr4IqO74gAT
# VocTTjw7tLV4ux5qA8SUeWPOfVkPjxLPotZOxriHafVJuJdkrS2ucxs3yaxFrzG1
# Ulje6hYn4MciGCSj5zJTAyVSVhg4DanJQo8qVvVLSnLt2HXlwcJjQZEKkPQ6HGwA
# qdsZpkv9mufvpb+IC/LUKRxFXZKqFuwomOXbDlwGWtVkjmTGlePS5Xvob4xAHGc4
# 7nFgdbzgIyVM/ct/cLsszWTIFKVfTfla87DSEDEzDkwxEALikT8tNWHIoJwUh46m
# T2MbsoyKhe4tRsyeoxA3Kb0uNntSK6sH6Cl9VUW8p+TcWcJkNFLLb1qNDQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQ1uKozuEPh0RrnAGlflWnqmqWHujAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQAhGVv3L2BpGlujQMqVTt+j
# bZXD6+GXZ2PJToJOpoXQc9cYyDu0dcUT5rS4SAKaJmr9EPAqimWEazcsF4NZWuiB
# vMHzUW4bMBrcUl87SQOXwfTZTshABGvu93F+B0XPYpQjfxXdep2nq3B9JLY5FbB4
# 4aLrrwjj4Ee/BMKVwvyhxBM4fLzLK3LsHwU+1EVGERtuKp89dVV8gIsdlvdH5vAy
# uDm+inn0neOhYov2iy82m5tyx0zo1Eevm5mFoPvCsQO6n3vc0E2tqKemCjjJLgYi
# c8ZnKqZ4vQZKDNXXsG8LI4X1xRIikSDoG2E9hf6B00VLQCob7adFgL0eGBmJa9S+
# ZdLMKhqIe3H74ng2K0UfcmBdHnkccvMgJanpsIzNYWeRXygbnRVV0JQrjovyPzbK
# 8fHuzbg6dsTgvXSp6ZtNlA9zwnMLWPsJlGBie1QEMFz8qJ+yTGak1bFOeCmbR2D7
# FhRLQ5k2dVRcTAr2tdk1N3v2/ssXZc0twp9jr9Agw0ELWT0pyOOKXwTQy792XqzO
# OWyRUVz4Q9aLs3+xRxEtKKgZ3OTbJm7nhcFzM2P7Ngih4UIqdmQDFqaF3q6LOg75
# +AAZ9x33vss2dywQsQ/80O83UIxI5kGOQIxri+lFZB6UeI0epiesU5cPM9vqBdKV
# qSxQkcYiwYg7I1ViGVHHxTCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC398ADKAfFuj6PEDTi
# E0jxvP4Spta9K711GABrCMJlq7VjnghBqXkCuklaLxwiPRYD6anCLHyJNGC6r0kQ
# tm9MyjZnVToC0TVOfea+rebLBn1J7FV36s85Ov651roZWDAsDzQuFF/zYC+tLDGZ
# mkIf+VpPTx2fv4a3RxdhU0ok5GbWFKsCOMNCJnUmKr9KqIOgc3o8aZPmFcqzbYTv
# 0x4VZgHjLRSU2pbRnYs825ryTStsRF2I1L6dM//GwRJlSetubJdloe9zIQpgrzlY
# HPdKvoS3xWVt2J3+mMGlwcj4fK2hpQAYTqtJaqaHv9oRl4MNSTP24wo4ZqwiBid6
# dSTkTRvZT/9tCoO/ep2GP1QlhYAM1gL/eLeLFxbVUQtpT7BOpdPEsAV6UKL+VEdK
# NpaKkN4T9NsFvTNMKIudz2eY6Nk8qW60w2Gj3XDGjiK1wmgiTZs+i3234BX5TA1o
# NEhtwRpBoHJyX2lxjBaZ/RsnggWf8KZgxUbV6QIHEHLJE2QWQea4xctfo8xdy94T
# jqMyv2zILczwkdF11HjNWN38XEGdLkc6ujemDpK24Q+yGunsj8qTVxMbzI5aXxqp
# /o4l4BXIbiXIn1X5nEKViZpTnK+0pgqTUUsGcQF8NbD5QDNBXS9wunoBXHYVzyfS
# +mjK52vdLBmZyQm7PtH5Lv0HMwIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTog8Qz19yfDJx2mgqm1N+Hpl5Y
# 7jBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+
# 60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72
# gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE0
# 4dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7oh
# qfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJb
# DDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV
# +4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgN
# ZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJe
# S7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+H
# LeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2Agdd
# ynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8Xngsb
# raLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
# nTiOL60cPqfny+Fq8UiuZzGCGpQwghqQAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwADDLSb5661oDUaJAAAAAMMtDAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCDxHY5zUFlQ5E1NY5Lewu9FZtj7
# rxxV2FVXavx8dvB0uDANBgkqhkiG9w0BAQEFAASCAYCDbCBtzq6Tc2OJj2guztRN
# DwznvrNrT6+ZDygY57x5OgeU8Ofwgri2uwkWR12gBDVYPA0oIqdRaYE9Z46l9tue
# R4XopAUsKtgEaaTqU1OHPY3W3ZK56uEaZfiNXHTSSOPtdctMaGeROr0ksxOmbo/H
# /9rfi0xJfm99Cy0JKh50SzBhDMawytBw1Ldrp2u5GcGE+J7yLQbyHM8IElEWWiNJ
# lW2WWP7MyleqfblG41FFcn3a/JzJRCyvPDOOD+Pt6S37HE5g3i4rx8K41E8U5r1H
# eop+N0TxO/pA9XjEp980iYyFw9m+nkC7utxllY7wpbjj6DMVMK4obFndfK01LO3l
# q8Sx97Jd1Q4KbSBBwu1hGyMNfjWDDP8HEXhEt2MZW7vl/tQbOAJ5beZLp9vpO2+V
# +cD9hsih60hzL3JOaDoH0LZ91sNCibJLyIfXajnK9O3Pt6qhTZKP1n9HC693lYEn
# sskwWKfsMwt0DzwZcH6v6hIvWhNR2ks4m8tyGYc/KXOhghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgKP/1XG/kxJcIC3TGkMmLHrSbIa8r70BnHABr/+XN
# MRgCBmfcmdLFHxgTMjAyNTAzMjEyMzE3MzMuMzQ0WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjdEMDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
# QSBUaW1lIFN0YW1waW5nIEF1dGhvcml0eaCCDyEwggeCMIIFaqADAgECAhMzAAAA
# BeXPD/9mLsmHAAAAAAAFMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29m
# dCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAyMDAeFw0yMDExMTkyMDMyMzFaFw0zNTExMTkyMDQyMzFaMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnnznUmP94MWfBX1jtQYioxwe1+eX
# M9ETBb1lRkd3kcFdcG9/sqtDlwxKoVIcaqDb+omFio5DHC4RBcbyQHjXCwMk/l3T
# OYtgoBjxnG/eViS4sOx8y4gSq8Zg49REAf5huXhIkQRKe3Qxs8Sgp02KHAznEa/S
# sah8nWo5hJM1xznkRsFPu6rfDHeZeG1Wa1wISvlkpOQooTULFm809Z0ZYlQ8Lp7i
# 5F9YciFlyAKwn6yjN/kR4fkquUWfGmMopNq/B8U/pdoZkZZQbxNlqJOiBGgCWpx6
# 9uKqKhTPVi3gVErnc/qi+dR8A2MiAz0kN0nh7SqINGbmw5OIRC0EsZ31WF3Uxp3G
# gZwetEKxLms73KG/Z+MkeuaVDQQheangOEMGJ4pQZH55ngI0Tdy1bi69INBV5Kn2
# HVJo9XxRYR/JPGAaM6xGl57Ei95HUw9NV/uC3yFjrhc087qLJQawSC3xzY/EXzsT
# 4I7sDbxOmM2rl4uKK6eEpurRduOQ2hTkmG1hSuWYBunFGNv21Kt4N20AKmbeuSnG
# nsBCd2cjRKG79+TX+sTehawOoxfeOO/jR7wo3liwkGdzPJYHgnJ54UxbckF914Aq
# HOiEV7xTnD1a69w/UTxwjEugpIPMIIE67SFZ2PMo27xjlLAHWW3l1CEAFjLNHd3E
# Q79PUr8FUXetXr0CAwEAAaOCAhswggIXMA4GA1UdDwEB/wQEAwIBhjAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQUa2koOjUvSGNAz3vYr0npPtk92yEwVAYDVR0g
# BE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFMh+0mqFKhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmg
# d6B1hnNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3Nv
# ZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0
# ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3JsMIGUBggrBgEFBQcBAQSBhzCBhDCBgQYI
# KwYBBQUHMAKGdWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2Vy
# dGlmaWNhdGUlMjBBdXRob3JpdHklMjAyMDIwLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAX4h2x35ttVoVdedMeGj6TuHYRJklFaW4sTQ5r+k77iB79cSLNe+GzRjv4pVj
# JviceW6AF6ycWoEYR0LYhaa0ozJLU5Yi+LCmcrdovkl53DNt4EXs87KDogYb9eGE
# ndSpZ5ZM74LNvVzY0/nPISHz0Xva71QjD4h+8z2XMOZzY7YQ0Psw+etyNZ1Cesuf
# U211rLslLKsO8F2aBs2cIo1k+aHOhrw9xw6JCWONNboZ497mwYW5EfN0W3zL5s3a
# d4Xtm7yFM7Ujrhc0aqy3xL7D5FR2J7x9cLWMq7eb0oYioXhqV2tgFqbKHeDick+P
# 8tHYIFovIP7YG4ZkJWag1H91KlELGWi3SLv10o4KGag42pswjybTi4toQcC/irAo
# dDW8HNtX+cbz0sMptFJK+KObAnDFHEsukxD+7jFfEV9Hh/+CSxKRsmnuiovCWIOb
# +H7DRon9TlxydiFhvu88o0w35JkNbJxTk4MhF/KgaXn0GxdH8elEa2Imq45gaa8D
# +mTm8LWVydt4ytxYP/bqjN49D9NZ81coE6aQWm88TwIf4R4YZbOpMKN0CyejaPNN
# 41LGXHeCUMYmBx3PkP8ADHD1J2Cr/6tjuOOCztfp+o9Nc+ZoIAkpUcA/X2gSMkgH
# APUvIdtoSAHEUKiBhI6JQivRepyvWcl+JYbYbBh7pmgAXVswggeXMIIFf6ADAgEC
# AhMzAAAAS6GxreFZ/Oc0AAAAAABLMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1N1oXDTI1MTExOTE4NDg1N1owgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCdnYqzfzSDLZ8t
# /IcnBhZ/VS77fz7MIUKa1I9mDjnJRNPdVWovmgU5UbARCbLCIIzZj8J0/YDeyJBD
# YFTySXAgaHlDw06rUBcryq2eaxoWfShTHSdlOnyzhDUw8GXGYJT1x/q+nGm6k1or
# uwW2wrYNR86/Q5sr1XYCJlM8yteWaJFvZJGE6vCOPQxni/lEN2qoTrq2ejmpVVMP
# ngkX9IMCyrlxav40gC15WTU7dZ3o19bQs7u+drzbzON0MtKsqa1vDFsHuqvH2q1S
# 21zETmed/llmTK5QaRLLhk5WCd9w1n/Do5gHarg6Jv861uSCqAdMdNnI34fnTsIR
# naEtCGWGu7W1Zd7blHSligBaGALIC61vJzWj1Mb8JxhhmhfPX20d6nB1Jpmm4qIP
# /FW02uCxJSq9Fe8ziedvlg4m1aCqjWX0Q566/i7VieVsOA3rx1xRXeIbADmsxnw3
# 6YlZohsqREsZUMjQZ4e6cCfKAlaO02ca7GizIRn7mNvzHNYc47gQCFEC+YgX2SLv
# w4b6R5Taq43XJ0hfhDwPSPiT60dySjLUIcmDcs2vI878t3WxEl2an9HJCaYPKvV/
# UZ1Ay9HjkSJc3ZqIXvgGlh1VI7kCpPTBayY7RC0IzJl5a7+DM7FcBhei9h1eJ8Ad
# ZszVcUGk+LkF+uqU3GAnjYadJC/x2QIDAQABo4IByzCCAccwHQYDVR0OBBYEFCCZ
# GsUvRVF/zToRWkE3JYWmuHQmMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAMb3YbNgyOUIdvrmh8yK25QWz
# U4kVUvlJmCygDGdnUKokh4ZAMzZu+c7cTlw+hcCH8vbx7zMRbKbLzp1XOXP+/Bvn
# UKynTgEGBkXPEbKwEezCtNwGZm7fAHHh7fAC8GN0R4dEneZBuyvUwjv/RMa3bRCN
# 0IuMTsIpjzwOVivH6lDU8o6dxkE6w+1EhKgImb3iCnGXS1gnotzJ6oa0x3lYMuir
# YOpLFlc54xJR1RncJBKqVqC+2vu31GRaVmBiwVU/bFuYN0o6LVnAPTcu1fMDcn6t
# s5EbW5chgEMFIoUM3tSDMNXoMIQkMQvN3beZpjnLDb4V8OANLd5oXz+bd+p5zW21
# v6odGTBUX/qhjSxBhTbwTPqlV1/Dx95x/6/52PrETq6bQb6t6TAFq4fpXTmRo8uB
# Vj1pkGVljJPDxvi6DyaBZECqlHQws8wM4qDWTk9hTIZrKlK/mvD6J3hR782HLG6W
# JiEuuVSxv+8zsI86ibPK6ywwjlBloH6/+YEtQtS4gIx4D/1xnP7qVfK7FcPtRO4A
# HEw2g+Nm37R+6B+RDime4WvUvxR8FweNjEry0QGtQVvZcEIflDXryIp2UdQIIgW+
# zmUO2b05TulkFPIsiVsgcAYPZjeBuyJkdlhZpYdP0JpYPQiUZTY3hjkum3n/7FnE
# aVhOV+ZdS+0XXVa3A7kxggdGMIIHQgIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAA
# AABLMA0GCWCGSAFlAwQCAQUAoIIEnzARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTAzMjEyMzE3
# MzNaMC8GCSqGSIb3DQEJBDEiBCD/SQaXeKsN7ZWZlBDaz+rk2A9IXhYDUK1tuPDL
# hZk7UzCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEINuJKJ0rsvRcScm4woZm
# CKowMSTh9DWm0OSNAeUABkSnMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAAS6GxreFZ/Oc0AAAAAABL
# MIIDYQYLKoZIhvcNAQkQAhIxggNQMIIDTKGCA0gwggNEMIICLAIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3RDAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# APV6ws6b5FNHUOmEILADVgzql5kzoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 64hp0jAiGA8yMDI1MDMyMTIyNDIyNloYDzIwMjUwMzIyMjI0MjI2WjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDriGnSAgEAMAoCAQACAh6/AgH/MAcCAQACAhNSMAoC
# BQDribtSAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAFwWAg7M9qBlluEz
# mX94nNhqQrdM67vC7TdFgBL/OFsfwa/rB3P3tUj/CbDWxApQs4vKpLcKvUN1Rved
# lUtLwYcYz+PYVGfbMn3RZ0yZmSWtZVUlfF8Y5/lzOIA8pKAWeyJptf7TcjeJO0Bm
# SWGWMpGovbWSwYvpWj28qVuDH6gg7P1udZgP25eGXx+7RRHi94/7891CXzzDKbuG
# MVRg5XopBRO3lXESKAvPeCWQUgijOtZw/dH5GvEWvFDtf17HOehfHdI/6EvGHrGZ
# kAjbzmCk3kmeyih5kbbZadJP1BIP1iUO0tJBDGIsHhAj8qO+bs0MskQUvAM+2Ipz
# e0IFjfowDQYJKoZIhvcNAQEBBQAEggIAeCeqbMlDp48J5PcHd7KWMNfrAfcbHTP5
# GA8MdvKM2XA9wPK0UTLSdZBXjJpEWw6w6JNozo++Q0RsfV2Qsl7HxptUBpFMturJ
# n2EuPb15T0i7VCxafxBkHktx6pTb+VBy1dI8pRR3l7Y+EW7FK58tTePBDR007IQE
# bSiEIJtNbQY2Vj3l0ZfvsMq9gurya1OaQBop1a+MTgbzhvLCfPnXjmqBBjn5bCBO
# qIpfBOcbt7Ab024s9NhMbfFmdUbjg5ALYmsf0FZilOKtt/sDawhrp7UWyuYeSqao
# ke8N9r7MRvu4MyUvb/ptWyoeZ/+trYkmdTariKMXyQ21S12LyZ4X1F1AEOWoAVL1
# jHoF+Oj/weHAn2t42uvQACfBdZT/Yb6j7SjhfMTf/k6F3t/q9m8dAhLJH8k2Jwhk
# C+EaAvQKkY0RCGPOmiwSeAd8nBQpDleLL8jVYf+5qokhQ19OlQ9LhoV8NSRH4yGQ
# jMP3S+wzl21S/GI4h3UBkB+q7Q6FbnpF4PDZFPWPbsQ6DBzOBLYzobp5ygIjVyYn
# 4sLcMBA9VUTGoma0NZf8fqq0uPf5BlR+9CdVG399MAoISmZ5FWRxfU07Byn5UzK4
# kbtrbDRjzJ6Mg+ZmdGYXMcoWRRk3ecHxAJJXMo3xBtfIvH1Tl7KFCFVP/XjVzKLq
# fgpR7/MMNOM=
# SIG # End signature block
