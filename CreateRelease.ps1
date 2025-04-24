<#region PSScriptInfo
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
#endregion PSScriptInfo

[CmdletBinding()]
param(
    [ValidateSet('register-device', 'helpdesk')]
    [string]$Application = 'register-device',
    [string]$SourceFolder = $PSScriptRoot,
    [string]$ReleaseFolder = "$($pwd)\Release",
    [string]$ManifestFile = "$ReleaseFolder\manifest.json",
    [string]$ExclusionsFile = "$pwd\exclusions.json",
    [switch]$Sign,
    [switch]$Copy,
    [switch]$CreateManifest,
    [switch]$Overwrite,
    [switch]$FullRelease,
    [switch]$Secrets,
    [switch]$Config
)


#region Variables and logs
$exclusions = (Get-Content -Path $ExclusionsFile | ConvertFrom-Json).$Application.exclusions
$initFile = "$PSScriptRoot\init.json"
$foldersToSign = @(
    $PSScriptRoot,
    "$PSScriptRoot\functions"
)
Write-Verbose 'Received the following parameters:'
Write-Verbose "SourceFolder: $SourceFolder"
Write-Verbose "ReleaseFolder: $ReleaseFolder"
Write-Verbose "ManifestFile: $ManifestFile"
Write-Verbose "ExclusionsFile: $ExclusionsFile"
Write-Verbose "Application: $Application"
Write-Verbose 'The following switches were passed:'
Write-Verbose "Sign: $Sign"
Write-Verbose "Copy: $Copy"
Write-Verbose "Create manifest: $CreateManifest"
Write-Verbose "Overwrite: $Overwrite"
Write-Verbose "FullRelease: $FullRelease"
Write-Verbose "Secrets: $Secrets"
Write-Verbose "Config: $Config"
Write-Verbose "The following variables were initialized:"
Write-Verbose "Exclusions: $($exclusions.Count)"
#endregion Variables

if (-not ($Copy -or $Sign -or $CreateManifest -or $FullRelease -or $Secrets -or $Config))
{
    throw 'At least one of the following switches must be provided: -Copy, -Sign, -Manifest, -Secrets or -FullRelease.'
}

#region import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*Configuration.ps1' -ErrorAction Stop
    Write-Host "Importing $($functions.Count) functions."
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
#endregion import functions.

function isEncrypted
{
    [CmdletBinding()]
    param (
        [psObject]$data
    )
    $isEncrypted = $false
    $encryptedCount = 0
    $unencryptedCount = 0
    Write-Verbose 'Checking if the data is encrypted.'
    foreach ($prop in $data.PSObject.Properties)
    {
        Write-Verbose "Checking if the value of $($prop.Name) $($prop.Value) is encrypted."
        if ($(try
                {
                    $null = [Convert]::FromBase64String($prop.Value); $true 
                }
                catch
                {
                    $false 
                }))
        {
            Write-Verbose "The value $($prop.Value) is encrypted."
            $encryptedCount++
        }
        else
        {
            Write-Verbose "The value $($prop.Value) is not encrypted."
            $unencryptedCount++
        }
    }
    Write-Verbose "The number of encrypted values is $encryptedCount"
    Write-Verbose "The number of unencrypted values is $unencryptedCount"
    #If the number of encrypted values is greater than the number of unencrypted values, the data is encrypted.
    if ($encryptedCount -gt $unencryptedCount)
    {
        $isEncrypted = $true
    }
    Write-Verbose "The data is encrypted: $isEncrypted"
    return $isEncrypted
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
        Write-Host 'Please choose the secret you would like to copy to the release folder.'
        for ($i = 0; $i -lt $secrets.Count; $i++)
        {
            $data = Get-Content -Path $secrets[$i].FullName | ConvertFrom-Json
            $domain = $data.domain
            $encrypted = (isEncrypted -data $data)
            if ($encrypted)
            {
                $encryption = 'Encrypted'
            }
            else
            {
                $encryption = 'Unencrypted'
            }
            if (-not $domain)
            {
                $domain = 'Unknown'
            }
            Write-Host "$i. $domain ($encryption)"
        }
        $index = Read-Host 'Enter the number of the secret you would like to copy. (99 to quit)'
        $secret = $secrets[$index]
        while (($index -lt 0 -or $index -ge $secrets.Count) -and $index -ne 99)
        {
            Write-Host 'Invalid choice.'
            #beep
            [console]::beep(500, 300)
            Write-Host "Please choose a number between 1 and $($secrets.Count)"
            $index = Read-Host 'Enter the number of the secret you would like to copy.'
        }
        if (-not $secret)
        {
            Write-Verbose 'No secrets selected.'
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

function SignScripts()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        $exclusions = $exclusions
    )
    
    Write-Verbose "Signing files in $Path and excluding $($exclusions.Count) files."
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
    foreach ($file in $files)
    {
        Write-Verbose "Processing file: $file"
        if ($file.BaseName -in $exclusions)
        {
            Write-Verbose "Skipping $($file.BaseName) because it is in the exclusions list"
            continue
        }
        #Check if the file is already signed
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue
        if ($signature.Status -ne 'Valid')
        {
            Write-Verbose "$($file.FullName) is not signed."
            Write-Verbose "Adding the file to the list of files to sign."
            #Add it to the list of files to sign.
            $filesToSign += $file.FullName
        }
        else
        {
            Write-Verbose "$($file.FullName) is already signed."
        }
    }
    if ($filesToSign.Count -gt 0)
    {
        Write-Verbose "Signing $($filesToSign.Count) files..."
        $filesToSign = $filesToSign -join ","
        $params = @{
            'Endpoint'               = 'https://eus.codesigning.azure.net/'
            'CodeSigningAccountName' = 'zuhairmahd'
            'CertificateProfileName' = 'Cert1'
            'FileDigest'             = 'SHA256'
            'TimestampRfc3161'       = 'http://timestamp.acs.microsoft.com'
            'TimestampDigest'        = 'SHA256'
            files                    = $filesToSign
        }
        Write-Verbose "Signing the following $($filesToSign.count) files."
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
            Write-Error $_
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
        [Parameter(Mandatory = $true)]
        $manifest = $manifest
    )

    #region Variable logs and definitions
    Write-Verbose 'Received the following parameters:'
    Write-Verbose "SourceFolder: $SourceFolder"
    Write-Verbose "DestinationFolder: $DestinationFolder"
    Write-Verbose "FunctionsFolder: $FunctionsFolder"
    Write-Verbose "Manifest: $manifest"
    $success = $false
    $destinationFunctionsFolder = "$DestinationFolder\functions"
    #endregion Variable logs and definitions

    if (-not (Test-Path -Path $DestinationFolder) -or -not (Test-Path -Path $FunctionsFolder))
    {
        Write-Host "Cannot find one or more required paths: DestinationFolder ($DestinationFolder) or FunctionsFolder ($FunctionsFolder)."
        return $success
    }
    Write-Host "Read $($manifest.functions.Count) functions, $($manifest.scripts.Count) scripts, $($manifest.cmds.Count) command files and $($manifest.configurations.Count) configurations from $($manifestFile)."
    foreach ($category in $manifest.PSObject.Properties)
    {
        Write-Host "Copying $($category.Value.Count) $($category.Name)s"
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
            configurations
            {
                foreach ($configuration in $category.Value)
                {
                    Write-Verbose "Copying $($configuration.name) to $DestinationFolder"
                    try
                    {
                        Copy-Item -Path "$SourceFolder\$($configuration.name).json" -Destination $DestinationFolder -Force    
                    }
                    catch
                    {
                        Write-Error "Failed to copy $($configuration.name) to $DestinationFolder"
                        Write-Error $_.Exception.Message
                        $success = $false
                        return $success
                    }
                }
                Write-Host "Copied $($category.Value.Count) configuration files."
            }
            Default
            {
                Write-Host 'Unknown category'
            }
        }
    }
    $success = $true
    return $success
}

function CopyManifest()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder,
        [Parameter(Mandatory = $false)]
        [string]$manifestFile = "$SourceFolder\manifest.json",
        [switch]$NoPrompt
    )
    
    #write a verbose log of all received parameters
    Write-Verbose "SourceFolder: $SourceFolder"
    Write-Verbose "DestinationFolder: $DestinationFolder"
    Write-Verbose "ManifestFile: $manifestFile"
    Write-Verbose "NoPrompt: $NoPrompt"
    $manifestFileName = Split-Path -Path $manifestFile -Leaf
    Write-Verbose "ManifestFileName: $manifestFileName"
    $success = $false
    
    if (-not $NoPrompt)
    {
        $response = Read-Host "Would you like to copy the manifest from the release folder to the root folder at $($PSScriptRoot)? (Y/N)"
        while ($response -notin 'Y', 'N')
        {
            $response = Read-Host "Invalid input. Please enter Y or N: "
            [console]::beep(500, 300)
        }
    }
    if ($response -eq 'Y' -or $NoPrompt)
    {
        Write-Host "Copying the $manifestFileName from $SourceFolder to $DestinationFolder"
        try
        {
            Copy-Item -Path "$sourceFolder\$manifestFileName" -Destination "$destinationFolder\$manifestFileName" -Force 
            Write-Verbose 'Manifest copied successfully.'
        }
        catch
        {
            Write-Error "Failed to copy manifest to $PSScriptRoot"
            Write-Error $_.Exception.Message
            $success = $false
            return $success
        }
    }
    else
    {
        Write-Verbose 'The manifest will not be copied to the root folder.'
        return $success
    }
    #Check if the file was really copied.
    if (Test-Path -Path "$destinationFolder\$manifestFileName")
    {
        $success = $true
    }
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
        [string]$Application = $application,
        $Exclusions = $exclusions,
        [Parameter(Mandatory = $false)]
        [string]$ManifestFile
    )
    
    #region variables and logs
    Write-Verbose 'Received the following parameters:'
    Write-Verbose "rootFolder: $rootFolder"
    Write-Verbose "functionsFolder: $functionsFolder"
    Write-Verbose "Application: $Application"
    Write-Verbose "$($exclusions.count) exclusions."
    Write-Verbose "ManifestFile: $ManifestFile"
    $success = $false
    #endregion variables and logs
    
    if (Test-Path -Path $ManifestFile)
    {
        Write-Host "Updating $($ManifestFile)..."
    }
    else
    {
        Write-Host "Creating $($ManifestFile)..."
    }
    $version = @{
        $application = 
        @{
            "Functions"      = @()
            "Scripts"        = @()
            "Cmds"           = @()
            "configurations" = @()
        }
    }   
    $version | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestFile -Force
    $functionFiles = Get-ChildItem -File -Path $functionsFolder -Recurse -Include *.ps1 -Force
    $scriptFiles = Get-ChildItem -Path "$pwd" *.ps1 -Force
    $cmdFiles = Get-ChildItem -File -Path "$pwd" *.cmd -Force
    $configurationFiles = Get-ChildItem -File -Path $pwd -Filter '*.json' -Force
    $fileTypes = @('functions', 'scripts', 'cmds', 'configurations' )
    $functions = @()
    $scripts = @()
    $cmds = @()
    $configurations = @()
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
                    if ($function.BaseName -notin $Exclusions)
                    {
                        Write-Verbose "Getting the version number for $($function.BaseName)"
                        $versionString = Select-String -Path $function.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)'
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
                    if ($script.BaseName -notin $Exclusions)
                    {
                        Write-Verbose "Getting the version number for $($script.BaseName)"
                        $versionString = Select-String -Path $script.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)'
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
                    if ($cmd.BaseName -notin $Exclusions)
                    {
                        Write-Verbose "Getting the version number for $($cmd.BaseName)"
                        $versionString = Select-String -Path $cmd.FullName -Pattern '.VERSION\s*(\d+\.\d+\.\d)'
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
            configurations
            {
                foreach ($configuration in $configurationFiles)
                {
                    Write-Verbose "Checking if $($configuration.BaseName) is in the exclusion list."
                    if ($configuration.BaseName -notin $Exclusions)
                    {
                        Write-Verbose "Computing hash for $($cmd.BaseName)"                        
                        $hash = Get-FileHash -Path $configuration.FullName -Algorithm SHA256
                        Write-Verbose "The hash for $($configuration.BaseName) is $($hash.Hash)"
                        Write-Verbose "Adding $($configuration.BaseName) to $manifestFile"
                        $configurations += [ordered]@{'name' = $configuration.BaseName; 'hash' = $hash.Hash }
                    }
                    else
                    {
                        Write-Verbose "Skipping $($configuration.BaseName)"
                    }
                }
                Write-Host "Processed $($configurations.Count) configurations."
            }
            Default
            {
                Write-Host 'Unknown filetype'
            }
        }        
    }
    $combined = @{$application = @{'Functions' = $functions; 'Scripts' = $scripts; 'Cmds' = $cmds; configurations = $configurations }}    
    $combined | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestFile -Encoding UTF8 -Force
    Write-Host "Successfully updated $($ManifestFile)"
    $success = $true
    return $success
}

### Main script ###
#Check if the initialization file exists.  If not, create it.
if (-not (Test-Path -Path $initFile))
{
    Write-Host "Cannot find the initialization file $($initFile). Creating..."
    if (InitializeConfiguration -rootFolder $PSScriptRoot)
    {
        Write-Host 'Initialization file created successfully.'
    }
    else
    {
        Write-Host 'Failed to create initialization file.'
        Write-Host 'Run the script with the -verbose switch for more information.'
        exit 1
    }
}
else
{
    Write-Host "Found initialization file $($initFile)..."
}

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

if ($sign -or $FullRelease)
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

if ($CreateManifest -or $FullRelease)
{
    Write-Host "Creating manifest in $ReleaseFolder"
    if (CreateManifest -rootFolder $pwd -ManifestFile $ManifestFile)
    {
        Write-Host 'Manifest created successfully.'
        $manifest = (Get-Content -Path $ManifestFile | ConvertFrom-Json).$Application
        if (CopyManifest -SourceFolder $ReleaseFolder -DestinationFolder $PSScriptRoot -ManifestFile $ManifestFile -NoPrompt)
        {
            Write-Host 'Manifest copied successfully.'
        }
        else
        {
            Write-Host 'The manifest was not copied.'
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
    Write-Host 'Skipping manifest creation process.'
}

if ($Copy -or $FullRelease)
{
    Write-Host "Copying files from $SourceFolder to $ReleaseFolder using $ManifestFile"
    if (CopyFiles -SourceFolder $PSScriptRoot -DestinationFolder $ReleaseFolder -Manifest $Manifest)
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
    Write-Host 'Skipping file copy process.'
}

if ($Secrets -or $FullRelease)
{
    Write-Verbose 'Checking if the secrets folder exists.'
    #Check if there are any secrets in the destination folder.
    if (Test-Path -Path "$ReleaseFolder\.secrets\config.json")
    {
        Write-Host 'Secrets already exist in the destination folder.'
        $response = Read-Host 'Would you like to overwrite them? (Y/N)'
        while ($response -notin 'Y', 'N')
        {
            $response = Read-Host 'Invalid input. Please enter Y or N: '
            [console]::beep(500, 300)
        }
        switch ($response)
        {
            Y
            { 
                Write-Host 'Overwriting secrets...' 
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
            N
            {
                Write-Host 'No secrets will be copied.'
            }
        }
    }
    else
    {
        Write-Host 'Secrets do not exist in the destination folder.'
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
}
else
{
    Write-Host 'Skipping secrets copy process.'
}

if ($Config -or $FullRelease)
{
    Write-Host "Choose the type of configuration you want to create:"
    Write-Host "(1) Create Release Configuration"
    Write-Host "(2) Create Dev Configuration"
    Write-Host "(0) Skip Configuration"
    $configChoice = Read-Host "Enter your choice (1, 2, or 0 to skip)"
    while ($configChoice -notin ('0', '1', '2'))
    {
        Write-Host "Invalid choice. Please enter 1, 2 or 3, or enter 0 to skip."
        [console]::beep(500, 300)
        $configChoice = Read-Host "Enter your choice (1 or 2)"
    }
    switch ($configChoice)
    {
        1
        { 
            Write-Host 'Creating Release configuration file.' 
            $configSuccess = CreateConfiguration -RootFolder $PSScriptRoot -DestinationFolder $ReleaseFolder -ConfigurationType 'Release'
        }
        2
        { 
            Write-Host 'Creating Development configuration file.' 
            $configSuccess = CreateConfiguration -RootFolder $PSScriptRoot -DestinationFolder $ReleaseFolder -ConfigurationType 'Dev'
        }
        0
        { 
            Write-Host 'Skipping configuration file creation process.' 
            $configSuccess = $true
        }
    }
    if ($configSuccess -and $configChoice -ne 0)
    {
        Write-Host 'Configuration file created successfully.'
    }
    elseif ($configChoice -eq 0)
    {
        Write-Host 'Skipping configuration file creation process.'
    }
    else
    {
        Write-Host 'Configuration file was not created.'
        Write-Host 'Run the script with the -verbose switch for more information.'
    }
}
else
{
    Write-Host 'Skipping configuration file creation process.'
}

# SIG # Begin signature block
# MII95AYJKoZIhvcNAQcCoII91TCCPdECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCznm8TAe5oiWMT
# zJmjSHd7fV4tw5pQwP+wZSIxVlb2+aCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAN0uwl7
# vtDCSQaiAAAAA3S7MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDIzMDQ0NDU1WhcNMjUwNDI2
# MDQ0NDU1WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# h/5tCSWKbPKt8F93wvLZlP5AAfdF3mukm8z0mBQtyMLGXK+NWnLO8fvV0ge5eUjI
# A9wcMLEcX2TvQCW7IyvihQMgHy1L6uzT9xKUmyQI9kJGEXpw64rtKAgDlJqD6GgA
# WnyhOzNcHRfgN0HNTai/MezVyct6AF9SxZn1XinCOhUbBx1wTZTvScxwTEqe43HU
# ZIVJ40G32BYnBeOoSXYAO0ZK4b+mxStrfB9II8lQ3tdTxu524cM+qaIF23QUnhBa
# asuCBhne2rFQuaQnY++/GvWc+ZdkR1d4eoV4zyt9d+mzYHNZ9JNOI4XWn78S2rKd
# gsL9xWj1YKAD1mhVFuuBKMIXktSaSDXiPdhGWSQcaTYbchw2OI0Peb3Xf50WD9qD
# GAPcYdjtB0vugl/dx5YJOLBfqiIxXeVg6TEsgSQTRDQdBaKDjHma/gXRJIsQw5KP
# mJMHaAZ5dEDoVuXbDev27Yvv4VV95giO3wLUx2iOsC1qDenBWiFyWPe4WovyDvxF
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFCmIHt4RADaTywJxAromEjAGzJZjMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAFXeJOg62AhYTxzF
# Yip4wYPtqc/tDdCid07e6FTg2jM84hJXep5mqbcU8VtqDNTqVODwDy1dFGRmHAdu
# 3F4o2Hkb0W4QVFAZsHR9yd+BQTJGDBFv+i23cHJ+qODBTZ6rh1NOMRGSuH6k3lX7
# nsI0/WQXbff/5XsSqpO9/d0+2VwWmeujUSCQf48tY7PsXBH+4rPOe3U9NW0/HXiI
# adefC8/N9UltDmQ4by+CtRmra3nBkIEAPRmFC1ERfq3JMPAJ4yJ3ddzakrjO0w56
# JyW7yeawoSB3iX8due4vRy2rDIfFWsKrcIKEqBZItd3ZTDIuLXbpQD/tZxocQPIx
# Eg6Wy5XRMlKxgQmxVP8IIsmz9InLM1qjhAtGgIv+kx+iisyg1qvojhnGnJohaZbq
# 2XH5Nx84JnfOfTAZ0mfEuSnuZA7IvCtaL66lP6Q1TikBAIGUa5wwk6cL0GGFGcI4
# p/Lr9n34HsCuJp4Qu/d6IaHMwA0s4YJnwH/bJctKJYO5VhV5MEVDU2QgeVkAkQ5G
# EIKOIBA1SR+fC87xg9dmbFjmAHqA3wkNgL1DVijsPpMXByQnkP3IqFFlDrP+rlBz
# WBv7814VxOszcciIgYPGI24asSBGXE6oQyAKkmTfTthhzNdgT5JxpNrgBwFEuUle
# mnqxm4/T9GIubTff34taJzANNNJVMIIG5zCCBM+gAwIBAgITMwADdLsJe77QwkkG
# ogAAAAN0uzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyMzA0NDQ1NVoXDTI1MDQyNjA0NDQ1
# NVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIf+bQkl
# imzyrfBfd8Ly2ZT+QAH3Rd5rpJvM9JgULcjCxlyvjVpyzvH71dIHuXlIyAPcHDCx
# HF9k70AluyMr4oUDIB8tS+rs0/cSlJskCPZCRhF6cOuK7SgIA5Sag+hoAFp8oTsz
# XB0X4DdBzU2ovzHs1cnLegBfUsWZ9V4pwjoVGwcdcE2U70nMcExKnuNx1GSFSeNB
# t9gWJwXjqEl2ADtGSuG/psUra3wfSCPJUN7XU8buduHDPqmiBdt0FJ4QWmrLggYZ
# 3tqxULmkJ2Pvvxr1nPmXZEdXeHqFeM8rfXfps2BzWfSTTiOF1p+/EtqynYLC/cVo
# 9WCgA9ZoVRbrgSjCF5LUmkg14j3YRlkkHGk2G3IcNjiND3m913+dFg/agxgD3GHY
# 7QdL7oJf3ceWCTiwX6oiMV3lYOkxLIEkE0Q0HQWig4x5mv4F0SSLEMOSj5iTB2gG
# eXRA6Fbl2w3r9u2L7+FVfeYIjt8C1MdojrAtag3pwVohclj3uFqL8g78RQIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBQpiB7eEQA2k8sCcQK6JhIwBsyWYzAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBV3iToOtgIWE8cxWIqeMGD
# 7anP7Q3QondO3uhU4NozPOISV3qeZqm3FPFbagzU6lTg8A8tXRRkZhwHbtxeKNh5
# G9FuEFRQGbB0fcnfgUEyRgwRb/ott3ByfqjgwU2eq4dTTjERkrh+pN5V+57CNP1k
# F233/+V7EqqTvf3dPtlcFpnro1EgkH+PLWOz7FwR/uKzznt1PTVtPx14iGnXnwvP
# zfVJbQ5kOG8vgrUZq2t5wZCBAD0ZhQtREX6tyTDwCeMid3Xc2pK4ztMOeiclu8nm
# sKEgd4l/HbnuL0ctqwyHxVrCq3CChKgWSLXd2UwyLi126UA/7WcaHEDyMRIOlsuV
# 0TJSsYEJsVT/CCLJs/SJyzNao4QLRoCL/pMfoorMoNar6I4ZxpyaIWmW6tlx+Tcf
# OCZ3zn0wGdJnxLkp7mQOyLwrWi+upT+kNU4pAQCBlGucMJOnC9BhhRnCOKfy6/Z9
# +B7AriaeELv3eiGhzMANLOGCZ8B/2yXLSiWDuVYVeTBFQ1NkIHlZAJEORhCCjiAQ
# NUkfnwvO8YPXZmxY5gB6gN8JDYC9Q1Yo7D6TFwckJ5D9yKhRZQ6z/q5Qc1gb+/Ne
# FcTrM3HIiIGDxiNuGrEgRlxOqEMgCpJk307YYczXYE+ScaTa4AcBRLlJXpp6sZuP
# 0/RiLm0339+LWicwDTTSVTCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
# AAQwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTJaFw0yNjA0MTMx
# NzMxNTJaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDIwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDhzqDoM6JjpsA7AI9s
# GVAXa2OjdyRRm5pvlmisydGnis6bBkOJNsinMWRn+TyTiK8ElXXDn9v+jKQj55cC
# pprEx3IA7Qyh2cRbsid9D6tOTKQTMfFFsI2DooOxOdhz9h0vsgiImWLyTnW6locs
# vsJib1g1zRIVi+VoWPY7QeM73L81GZxY2NqZk6VGPFbZxaBSxR1rNIeBEJ6TztXZ
# sz/Xtv6jxZdRb3UimCBFqyaJnrlYQUdcpvKGbYtuEErplaZCgV4T4ZaspYIYr+r/
# hGJNow2Edda9a/7/8jnxS07FWLcNorV9DpgvIggYfMPgKa1ysaK/G6mr9yuse6cY
# 0Hv/9Ca6XZk/0dw6Zj9qm2BSfBP7bSD8DfuIN+65XDrJLYujT+Sn+Nv4ny8TgUyo
# iLDEYHIvjzY8xUELep381sVBrwyaPp6exT4cSq/1qv4BtwrC6ZtmokkqZCsZpI11
# Z+TY2h2BxY6aruPKFvHBk6OcuPT9vCexQ1w0B7T2/6qKjPJBB6zwDdRc9xFBvwb5
# zTJo7YgKJ9ZMrvJK7JQnzyTWa03bYI1+1uOK2IB5p+hn1WaGflF9v5L8rlqtW9Nw
# u6S3k91MNDGXnnsQgToD7pcUGl2yM7OQvN0SHsQuTw9U8yNB88KAq0nzhzXt93YL
# 36nEXWURBQVdj9i0Iv42az1xZQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQkRZmhd5AqfMPKg7BuZBaEKvgs
# ZzBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGct
# OF2Vsw0iiR0q3NJryKj6kQ73kJzdU7Jj+FCwghx0zKTaEk7Mu38zVZd9DISUOT9C
# 3IvNfrdN05vkn6c7y3SnPPCLtli8yI2oq8BA7nSww4mfdPeEI+mnE02GgYVXHPZT
# KJDhva86tywsr1M4QVdZtQwk5tH08zTBmwAEiG7iTpVUvEQN7QZJ5Bf9kTs8d9OD
# jgu5+3ggqpiae/UK6iyneCUVixV6AucxZlRnxS070XxAKICi4liEvk6UKSyANv29
# 78dCEsWd6V+Dp1C5sgWyoH0iUKidgoln8doxm9i0DvL0Q5ErhzGW9N60JcAdrKJJ
# cfS54T9P3bBUbRyy/lV1TKPrJWubba+UpgCRcg0q8M4Hz6ziH5OBKGVRrYAK7YVa
# fsnOVNJumTQgTxES5iaS7IT8FOST3dYMzHs/Auefgn7l+S9uONDTw57B+kyGHxK4
# 91AqqZnjQjhbZTIkowxNt63XokWKZKoMKGCcIHqXCWl7SB9uj3tTumult8EqnoHa
# TZ/tj5ONatBg3451w87JAB3EYY8HAlJokbeiF2SULGAAnlqcLF5iXtKNDkS5rpq2
# Mh5WE3Qp88sU+ljPkJBT4kLYfv3Hh387pg4VH1ph7nj8Ia6nt1FQh8tK/X+PQM9z
# oSV/djJbGWhaPzJ5jeQetkVoCVEzCEBfI9DesRf3MIIHnjCCBYagAwIBAgITMwAA
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
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADdLsJe77QwkkGogAAAAN0uzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBtYHPK8kIz7Ibxfc6BXjUSvXt8
# WUTlFtfR94HFBGKaCjANBgkqhkiG9w0BAQEFAASCAYARomTpErzkWyEKPeQxWPkg
# IMX7pTP0BPakWRkc2G70n6BikO46DclwMXLPZkgv9XeF2XZ6Bw2T6ftv3M7B/5S3
# CU9G2Ud1EDD6fyCpcqlGpZ8o9N3O7cfXy8GmzoU/y/EspdS2el5mOkM+pWha8+j3
# Nbl2Bv+iABx2sO61jlqOZiFpbBkUUpQjHXUGP7/7MoTWibSuxX7HqJiXtvYxzY6t
# 55MG74NfKZo9CHSHuACRU5YlGoM2MXdH8H9L+ysWN70nKtN4OgCSdT5SnBl1pq0U
# 65ifUPp6D2tszs7FezpWpvjJGackVUBOVIcSp6OB89Xjvr6VpXZxH+HNHPuvuPGj
# MXsjyc33FPkCirt4ZWK7a9ZwpZlDrTWF3msmREUlVVbECcEdvFQa/LpgcNK2JIRZ
# cxes6y+KkXH16fZfvADb5ezLBLrH3wJRnf6jeHw16LClinqSx9LUqbR45rDcl3MU
# FL2gelQW6MubQLXRR7FYYiRAfSyRazHS5GJzUqMC6mmhghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgDGEhnPuVgbXgogtwPMEOx4N2mWTjIPJxydug4vHC
# 9t8CBmfnuw0k6xgTMjAyNTA0MjQwMDMwMDIuMzcxWjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOjc4MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
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
# AhMzAAAATBtLnGPC5NN6AAAAAABMMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1OVoXDTI1MTExOTE4NDg1OVowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3ODAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDcde8XEX4HjETY
# u6YHtWiP7+6Vf2abeUo/si4NcaeiKrRMTF8F7mpCoPJyo/h5VHbhyKDZazOm1cLu
# zKeVEMzDN4vuf3fZb5hSlpVlCXBSJ3YBLwLnRJtWNk+XkUMcAc96RdalToVYWltO
# IwbCCkjE42fnCafwjZajw1UGaxl4tRQNHwVk5gwC2wlVVSJREJqCSsB9TXXHIKxP
# HnnFJqJ/LI1goJ+Ve0Bar4PiKiMfnvnZ8LR3ktW24X6FDQJRKLjnJQ0JVebQEvI+
# q8Y/frheUldXeLVD4SfQNl1fLKN58o+NJsWI0ET6C8wYZc+eu+EqrzubIPXB7mKI
# 9cbtmGHvztslz1K/NmRvGGQkeKEKdOWfpfRuYxmhmeVmR1QMLe5pBccJiXw7PUIW
# +3MB0pM5SBF5FH6INtT1gf5vHwBA9vbeiiggbijJMuK0qu63sIbbE/YN4iYrCURv
# jZampsTtxmlEtN921N0qXNtNgU0vavdc/vJl/rDef6fMeQuJAinIHxcJzPDTsOXZ
# legwcCr/J52eij6T9szMlPSCQVAt5u/agNcJ212t6qdwZ4hYYF4LkCmXQgDPZpR1
# lGDCaojAB6zy/H7nME+nnTvTgTMtR4d4lHVBQxpJDnvYNvGPurrnP7FZT3ue8Yzf
# FEiE5chmJia8THexs46F8tCr8T5UxQIDAQABo4IByzCCAccwHQYDVR0OBBYEFGrq
# I3Sxu357rKTylpgwcVAF1Nw/MB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAAFYcd7rrNVHRZWofhE4ft9YN
# ZPVEzaQ90iE/5kCDoQlCKTE7jFYnFcfxETrL4ed8JSj0JxCZSJQVUwEp6haUSPki
# Sg4mf7rq+m3qbCjHB8Dj82rsFSxAs8NqI/08Dq1Ci/rxVhryPOSZmtXRgNeJzxwD
# qSch50pNBGQMU8APLSnwpqzhwRN76MK5PXYCVqm/u/v579+fFJh0bIsw49/wTcTC
# Xh3s0C9y0iAmSvsJKnTfEvtfe+eS9qw2wyf2LdJ5n8klFJ6OtDg8YB9n+E+0vX1E
# JIDPxN2yX7+2sJiABcUSc55jIHxPTArDdzR0YUwQIjZO0j9hIjyMbRYjgjJ4UK9Z
# LrvN2nUyc0upLqKKvhAqKP1jX0FL5M0wuneZ9/SGy2ZFn/Bg8ISBOp34ri+412tO
# lzqR9ZU+CU9Xn1MqcWXvvDhTqjexxKZMVRMqGjRECQWSA62WdCGYjEOWnH5lQJqL
# YRhYpeAwvjszdEAjSFtFXFLGTRw4bSKoad5TjUEvsKFO8DVPCjrbMEzGdku4znme
# FddbqXR41HlunpyOLuSoC1II/Bh+aX0nU19JU79T10OFRKZDFKUI3LWB9jTdT+3E
# OJr/pQ5T0fFeei0A7UdmTgXbmP4IaCbTc41NG7KMmsmV6Xyank4qB5aSL30uegrr
# vnHPjQBLLYjerGCNtQMxggdGMIIHQgIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAATBtLnGPC5NN6AAAA
# AABMMA0GCWCGSAFlAwQCAQUAoIIEnzARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MjQwMDMw
# MDJaMC8GCSqGSIb3DQEJBDEiBCDmw8m+iAOKpIkii19DeId7scI8dJKGJPskzhNl
# V4buyDCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIN46bOoVmqp2Rt/G6TI8
# VIZkg7qJ8OddiPDqk6jY+midMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAATBtLnGPC5NN6AAAAAABM
# MIIDYQYLKoZIhvcNAQkQAhIxggNQMIIDTKGCA0gwggNEMIICLAIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjo3ODAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# AJueWs/5vWNYP+JGxmOfpj88ZvzBoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 67PXUzAiGA8yMDI1MDQyMzIxMTcwN1oYDzIwMjUwNDI0MjExNzA3WjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDrs9dTAgEAMAoCAQACAiHUAgH/MAcCAQACAhLiMAoC
# BQDrtSjTAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAHMnzRRqT4SBCgIa
# gIKQH1xDEudHBoaE/I2oD7SxVnAnxZV1xVm5fqriI2juN3sTBjRAWQEgwst7+s44
# 63mwTdry3XtFPsQmoueexJte86JaM/LjKQXk1lCIqno64QnBzs+3zGbuLYKy24of
# 0vCALFIf5kzgLr5tQPBkRi0F2X1DXbssakBgPUcJ18cR9hC68SmqDx/w3Yr6HhOw
# x2At3vfUanASupypyDtycdGyrs9jv11ZW6oKrE0YhIvUK/SpeRI4b2i7nR+Ouf9k
# ME1HzDanPn/jDKLCY89zAdVXyF+L37zD0ODhXtp8zYiavPGuJSDQiof9aM2kySMP
# fO/5lVwwDQYJKoZIhvcNAQEBBQAEggIACxoU7nhUlvEU11wTh8BmXhpOeUitPxT5
# rGsQfYl0GWoanzBczwkI6Ylze4inY2okLzgdcMSoJgZNsP92MS4v5w4UharUpXTa
# kzRYZ4mU6f1XrUAg5017Am7VI3M2SD6FOVqH8GdP8tKOZqSCysj5xW4TGDxgDdhw
# pfeLVkRx73c7NUCybHQD4fiVjCHID3CwhiDvf07Q1wxZ/zp6PjvYYqixOruNHPUV
# QDBqoiNJmKpzHStk/vdicvCgNNNwXVPAX4VIBcGSVOqeRvp7hN+4n5Ves3ZEIWma
# iW7BYMSpUaj+mm7l5q9uZywxkmxBOWAt68UhLnbt+8uzoqQWegKHMfKhW1chjN9Y
# LnatZMqWf5/u111zNeDIjyZ0M2oANX5gIFlrFdZXJfM4tFIPfBi7tYj6mv41Xg6t
# yEwMIO+LtysSaSIkhDJzDBOcx+vUDcRA5KdGx9anJ1LaZYDwjU8hnNmLKPclgCFs
# eoCmuy0FI7J8i+Ef1N/B8GFmKWPhdZfyxFYXJd+6pJ65R+Trxqra3t7eL8vMCoSr
# YsMTajdAa+NbGgbnyL0lquO/tIoctld+LYRDu0amhjvkaYMQKjQT/jJZfjA3utNY
# IeOvwPS96URrul8NAdR9u42nfGbJUaLFy9GwI6ByTUlJ9m2ZEPjbuiyft082KiyZ
# ysioI3DYMsk=
# SIG # End signature block
