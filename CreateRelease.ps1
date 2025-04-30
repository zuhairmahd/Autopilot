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
    [switch]$SignOnly,
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
$signatureBlock = "# SIG # Begin signature block"
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

if (-not ($Copy -or $Sign -or $CreateManifest -or $FullRelease -or $Secrets -or $Config -or $SignOnly))
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

#region Helper functions
function isEncrypted()
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
            $name = $data.name
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
            if (-not $name)
            {
                $name = 'Unknown'
            }
            Write-Host "$i. $($name): $domain ($encryption)"
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
        [string[]]$Path,
        $exclusions = $exclusions
    )
    Write-Verbose "Got $($Path.Count) folders to sign."
    $success = $false
    $filesToSign = @()
    foreach ($folder in $Path)
    {
        $files = Get-ChildItem -Path $path -Filter *.ps1
        Write-Verbose "Signing $($files.count) files in $folder and excluding $($exclusions.Count) files."
        if ($files.Count -gt 0)
        {
            Write-Host "Found $($files.Count) PowerShell scripts in $Path"
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
                Write-Verbose "The signature status is $($signature.Status)"
                if ($signature.Status -ne 'Valid')
                {
                    Write-Verbose "$($file.FullName) is not signed."
                    Write-Verbose "Adding the file to the list of files to sign."
                    $filesToSign += $file.FullName
                    Write-Verbose "Checking for a previous signature block..."
                    if ($signature.Status -ne 'NotSigned')
                    {
                        Write-Verbose "Removing previous signature block..."
                        try
                        {
                            $fileContent = Get-Content -Path $file.FullName -Raw
                            $fileContent = $fileContent -replace [regex]::Escape("$signatureBlock.*"), ''
                            Set-Content -Path $file.FullName -Value $fileContent -Force
                            Write-Verbose "Previous signature block removed."
                        }
                        catch
                        {
                            Write-Error "Failed to remove previous signature block from $($file.FullName)"
                            Write-Error $_.Exception.Message
                            return $false
                        }
                    }
                }
                else
                {
                    Write-Verbose "$($file.FullName) is already signed."
                }
            }
        }
        else
        {
            Write-Host "No PowerShell scripts found in $Path"
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
        Write-Verbose "Signing $($filesToSign.count) files."
        try
        {
            Invoke-TrustedSigning @params
            Write-Verbose 'Signing process complete.'
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
    $version | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestFile -Encoding UTF8 -Force
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
    $combined | ConvertTo-Json -Depth 20 | Set-Content -Path $ManifestFile -Encoding UTF8 -Force
    Write-Host "Successfully updated $($ManifestFile)"
    $success = $true
    return $success
}
#endregion Helper functions

### Main script ###
#Just sign and do nothing else.
if ($SignOnly)
{
    Write-Host 'Signing only...'
    if (SignScripts -Path $foldersToSign)
    {
        Write-Host 'Signing process complete.'
    }
    else
    {
        Write-Host 'Failed to sign files.'
        Write-Host 'Run the script with the -verbose switch for more information.'
        exit 1 
    }
    exit 0
}

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
    if (SignScripts -Path $foldersToSign)
    {
        Write-Host "File signature is complete."
    }
    else
    {
        Write-Host "Failed to sign files."
        Write-Host 'Run the script with the -verbose switch for more information.'
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDwwGZ5yxkMgM5o
# WkEjqiB5LLhWWvX6v+DFgF1nLVNQhKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAOGUbwd
# mZB6vjd7AAAAA4ZRMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwNDMwMDQxMTA3WhcNMjUwNTAz
# MDQxMTA3WjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# oqLQPWOvKsrhbSB6OsrCd685g+O+B+bXMF3JIHd5yq9Dwuq0s6EDFgBKDsvRxVUC
# Vv1Y+aDj/UxPHH5hED2wSO1b5VbypD4lvzjbNaZyia6rhrp9jJDPWEjHfzkjEkKY
# +JDXCxzwrDi3OkmX9CFzv91BY/ibAC8cz+iW8h43d+rD6R+0qaUofXQCME2bPdzP
# /VYZwzJsSvLKRkJkCIfgblxHELz7NevNBDfNp8e8pPl8EkHWZgU5SkiHwlzTlAfa
# oyiy9gPPDzXNkZfxJlfh7mXn0lHeGSnMtRkhYx44GhNpmNY8k7t6z2vIKZQw6PSp
# Sswsq9O6hcZsQhv3xDiIjIsz60ZP8f3MigKMxc1KxMjkTr8oa8WaqUpY5AvqIUb4
# RRLJdM6AtQWJCOoLUKTNxljYPNcfywYVZ0I5tJ5KslffZ55fd2yJo8LqcByZUA0m
# CAbERHw0qMfb/zgeUFtQ/RXFpyX80KO2DAGs7oRzAPAZ8Z/MWY6JKkwO1aZxAajd
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFIEuxGH+aqlCsKkNOe0NM8LUj0oFMB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAGy3Mnp2iO6X2QJc
# 6xbd07O60z9HgTOiJK4znPsMsDp8Ahn/3txtsRx75+feCdOGWdoxbdtr1al4ggZU
# NKIxj9nnrGuWVdofz/PaCCMfN0UZF713CF3j+IptuhMA/PmRsPoEkHhe9grx/6P8
# bN6BK4/0DyouTKoay4YEuaCkoL5MDjuADIHjGQE2MQLifj9SDzTuEgirpGu8Q9Vk
# /af2dPBkajxJq5FB5977OKl6zkoxcsdFCOU3McDEyoLoFENTkMoE/Br6hJ37QEVX
# JGkUxJZ5Cyex7VPGpDdiPIl2iN8d86DZ8U4hVR8YF72B82iDqPk+fq2KyUxMGrDB
# ZbgsPFUlPLru6DhyHk/Ian3/GhnatSco47J9Sq+hv88jYurFukuCpZ8P8K+RG6eq
# 4gGp42T1fj2VLIiaB1obrL9lMDTIsmw9CdyWi+wEpl144vfKMg8H1K6PxJrMmOv6
# 9kU79OAyEHtG4agXptaGGDI4MMC0ivUqlV5e3rwofaQ/9EVrJtyy8mTGtjIsPwP3
# ySfeIL6+ZCFuuzI6KjetsGsZ3NJFzk9H5hGtCg0Q1btaSmyeFyXskJV65YpCDtlw
# BwqXTFsLkAsP9+Wljr8jOfunVZje2BECU88g/x15Pk6JeXfkZUJvmvjgIzQfUX+9
# SAHM0NBbCVAZEwKfHPVg3yfb4mQjMIIG5zCCBM+gAwIBAgITMwADhlG8HZmQer43
# ewAAAAOGUTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDQzMDA0MTEwN1oXDTI1MDUwMzA0MTEw
# N1owZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAKKi0D1j
# ryrK4W0gejrKwnevOYPjvgfm1zBdySB3ecqvQ8LqtLOhAxYASg7L0cVVAlb9WPmg
# 4/1MTxx+YRA9sEjtW+VW8qQ+Jb842zWmcomuq4a6fYyQz1hIx385IxJCmPiQ1wsc
# 8Kw4tzpJl/Qhc7/dQWP4mwAvHM/olvIeN3fqw+kftKmlKH10AjBNmz3cz/1WGcMy
# bEryykZCZAiH4G5cRxC8+zXrzQQ3zafHvKT5fBJB1mYFOUpIh8Jc05QH2qMosvYD
# zw81zZGX8SZX4e5l59JR3hkpzLUZIWMeOBoTaZjWPJO7es9ryCmUMOj0qUrMLKvT
# uoXGbEIb98Q4iIyLM+tGT/H9zIoCjMXNSsTI5E6/KGvFmqlKWOQL6iFG+EUSyXTO
# gLUFiQjqC1CkzcZY2DzXH8sGFWdCObSeSrJX32eeX3dsiaPC6nAcmVANJggGxER8
# NKjH2/84HlBbUP0Vxacl/NCjtgwBrO6EcwDwGfGfzFmOiSpMDtWmcQGo3QIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBSBLsRh/mqpQrCpDTntDTPC1I9KBTAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBstzJ6dojul9kCXOsW3dOz
# utM/R4EzoiSuM5z7DLA6fAIZ/97cbbEce+fn3gnThlnaMW3ba9WpeIIGVDSiMY/Z
# 56xrllXaH8/z2ggjHzdFGRe9dwhd4/iKbboTAPz5kbD6BJB4XvYK8f+j/GzegSuP
# 9A8qLkyqGsuGBLmgpKC+TA47gAyB4xkBNjEC4n4/Ug807hIIq6RrvEPVZP2n9nTw
# ZGo8SauRQefe+zipes5KMXLHRQjlNzHAxMqC6BRDU5DKBPwa+oSd+0BFVyRpFMSW
# eQsnse1TxqQ3YjyJdojfHfOg2fFOIVUfGBe9gfNog6j5Pn6tislMTBqwwWW4LDxV
# JTy67ug4ch5PyGp9/xoZ2rUnKOOyfUqvob/PI2LqxbpLgqWfD/CvkRunquIBqeNk
# 9X49lSyImgdaG6y/ZTA0yLJsPQnclovsBKZdeOL3yjIPB9Suj8SazJjr+vZFO/Tg
# MhB7RuGoF6bWhhgyODDAtIr1KpVeXt68KH2kP/RFaybcsvJkxrYyLD8D98kn3iC+
# vmQhbrsyOio3rbBrGdzSRc5PR+YRrQoNENW7Wkpsnhcl7JCVeuWKQg7ZcAcKl0xb
# C5ALD/flpY6/Izn7p1WY3tgRAlPPIP8deT5OiXl35GVCb5r44CM0H1F/vUgBzNDQ
# WwlQGRMCnxz1YN8n2+JkIzCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
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
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwADhlG8HZmQer43ewAAAAOGUTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBa5+ppX6ZbQXD9sYZJ34xb2eHm
# ymS3ZD0Hpg14SgIQMTANBgkqhkiG9w0BAQEFAASCAYA/m4Ghe1XwAx+Z06nQ4WxU
# wfBGsX+D/xwfDc3G2TgXK3dZSWzXBF/c9otgP7X98Uy6uWqK17tLcCB2kqcDlGAY
# fAugaBqsrn5Y2rM1wDQxPqLaI2lbQGktfOU8Pe1XUcudx5OGS7Xm4QIEW4EvyOH6
# CWP+WvC0y68jVhBs998J7JbE9PO0FHHg641qsiJy2+EbPa5Dpd9GW/XNLaWstO/S
# SDhENhTm6HHMulFs6i139jfzTUtibgGf7fXvfQv7Kl/UwxIDvqquZ9De6tXFyr72
# +z9ghN+2RFWIkqhLmRgn8KlzcwZ01P1VGrRppEv9uznD0wqIGmCwBuUc+elH7wSl
# FUBc50SGMeBOuOg5cTXaMabCgr08K69NhoArhAvx3bk5UgWZv4tFmnDig62T1CGO
# 0P6miQFB2psSt5Zuz6CTPJDKj6IwbdXpcLPj+ZUgtdgW99ZBXe4qeeRayKvBZQug
# cyKrZjVSftC9T6ODCm2jHk3i/19fLVJQomLHNpvkyDChghgUMIIYEAYKKwYBBAGC
# NwMDATGCGAAwghf8BgkqhkiG9w0BBwKgghftMIIX6QIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYgYLKoZIhvcNAQkQAQSgggFRBIIBTTCCAUkCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgQMHuQH8TJEHd7JH6IF5AH0IjuJvUWjGsxKnvuTOe
# j6ECBmgLvwQN0BgTMjAyNTA0MzAwNzE0MTYuMzI2WjAEgAIB9KCB4aSB3jCB2zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1Mg
# RVNOOkE1MDAtMDVFMC1EOTQ3MTUwMwYDVQQDEyxNaWNyb3NvZnQgUHVibGljIFJT
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
# AhMzAAAASFV3ch50krf3AAAAAABIMA0GCSqGSIb3DQEBDAUAMGExCzAJBgNVBAYT
# AlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMB4XDTI0MTEy
# NjE4NDg1MloXDTI1MTExOTE4NDg1MlowgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJh
# dGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjpBNTAwLTA1RTAtRDk0NzE1
# MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRo
# b3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDLfoD3Z++SVTIY
# JFnFnPrVlMvaJYlPTronDHe0VuiHANnCKTIq8qJk4weZ+cf1+vIJ7cdl+/gw3AaR
# gAQT/iDU6vLN6QfFg1YAO6cR7voo2y4QDJPguGjKpGtONxGj9fOavAkDTH4gaTJn
# uK9mhvIzUqI7TEDV7JoK6Sy0kYsVcWbp2mF4RJ4FliqEm70YNSwLjnKn5qYIZJoQ
# YKg9ZWYzYabgr9clHsjlZtFepsTYn2hrim8vaeO9dymfk7pmXrQX2O85UQl8k6AK
# 2B8KKQVuNNnBa37EAWfxxqlO97WOvkzboNZYWHWFOlS3aklvSa+742PSVIyEgraC
# gkqIMZkVuzF+5QnuyVekXaZ/hz+3ujmyrxsnXUXbXYmQi6enT7comWGpTfRo2WZt
# +tEzvhl46YmQ9IGREfn+ZRBWr8CHA+x2q1uqg9GTfNUvkQ4HxLSeu4eqDFKj9ViI
# hQu+Yn/IGitWjufmfBKp2nigC4FFabRe4vShrA7xJtrbOFmJ3jAIRtvu2dufiI7V
# uGQCPN2bXRjiafbBXevEuhA3998ECz4uwnGfSFF1u+LS7yDZLb8NzxXnuiN4bP/X
# w3AjKBCGr/lnmSJiCwoMERhXCyLb8KUhAOzXF06EZN0xnwud2A94OTQ7o66oXbii
# 21Z6KxjnSGV1XizJNCa+P1yFEBqVKQIDAQABo4IByzCCAccwHQYDVR0OBBYEFKa9
# d/S6631KGfe8umYaOzc8HPdHMB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7Z
# PdshMGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGlu
# ZyUyMENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUy
# MFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYD
# VR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRt
# MAgGBmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEATa2L4B40TANMMYgCNXTy+cuK
# TjDzNZ3dAJ+S4PbAKf78FBwQ79hYihqZ/qIg6GWt/jQ5GAsBSpBYKNZOMtUMArNQ
# fIlZ42y2tylAP/xBGQ6wwmu0uBmXzg6W3TomTZ56bh90li7ZO4BbiiCg2CAkpvtT
# vrgYu7FbvvTqTIv/LvXQaCJx+sxvJPsbIAyWUSfIYTdAWlVo63sJ8AkH5pzpifvk
# LyXmLxq2jTywaeD/pKazEJwXAby8+u04oCGVCZDbD+sDOJ753hbl6XyWOXmCpXVv
# j2wPoXJdI+T6DPtc9GWtMxSDUKZtVJV2UVgACazx8gODidj6h3aGwOr8Ut/FsO/X
# 853Q1CYpfHWfW3JEkLc3FslKf2Kl2zH14EBoLeUpTykhn8NZUeXhHsuuKjPx8mUA
# LW/LglUjZXyJ3yBQ1PiOevpxTot8afXc6rlq9FJ2kgtM6ij2uW7f9at5yIcdwFM9
# VUm0aCgiXvjvRkQeSUIIAm40LX2qve2kdPgNe/Zt8yb5zDcsJjHhZPtXiW3TnBUY
# LqCsLnD6fVh6X5QvFbtjLlBIMt3XlvAQnuVEzhoyt3isww9w8t+oGCg4aNh94IdK
# vUNS1ffxC+Q+XrsT3wDlSlqNSLfooxhsCu5gXKtzpfhx8+4l9rVHJxgZE9nwGKiA
# bwNXxKFB3bVgmwodJbUxggdGMIIHQgIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASFV3ch50krf3AAAA
# AABIMA0GCWCGSAFlAwQCAQUAoIIEnzARBgsqhkiG9w0BCRACDzECBQAwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA0MzAwNzE0
# MTZaMC8GCSqGSIb3DQEJBDEiBCDjfG8tqwxIAe91cpYQ6CGVnKU3NyT15C9kPS6D
# NprNCzCBuQYLKoZIhvcNAQkQAi8xgakwgaYwgaMwgaAEIOoqAVebTwjWn0P0gLwZ
# 03YfjX3QvDtHZEl38m8i8x1BMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASFV3ch50krf3AAAAAABI
# MIIDYQYLKoZIhvcNAQkQAhIxggNQMIIDTKGCA0gwggNEMIICLAIBATCCAQmhgeGk
# gd4wgdsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNV
# BAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGll
# bGQgVFNTIEVTTjpBNTAwLTA1RTAtRDk0NzE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1
# YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3JpdHmiIwoBATAHBgUrDgMCGgMV
# AOYSfUGUVzjpxDh59/qJiDRZaMMnoGcwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwMA0GCSqGSIb3DQEBCwUAAgUA
# 67wsOjAiGA8yMDI1MDQzMDA0NTczMFoYDzIwMjUwNTAxMDQ1NzMwWjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDrvCw6AgEAMAoCAQACAhpwAgH/MAcCAQACAhNiMAoC
# BQDrvX26AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAK0W8An9MNhB+W8z
# 5vwVSb6fN2kWd40sQhOIJVPKzycRPeeuIH7/QQ0eLp1v+a+yhTlSFy6Us5eUPVnR
# oE47pG63LvxsZ6mPWZ0OjiNdPM6y0DMjRHQn7kiA0eaOJOvH1B5Oqne0WvcfExwS
# cCzN8Bl7jNkdGhKBiCeHz10r8sF2JPgpP/95eU6NEmnCnu3l23vYG/m70aED0dsm
# X1oFUae4RrLO/jtqiFCpLrqjQNyJv8rldFQR19b9XFtI2k2UGHRA3bxLxRCRKTDe
# NL5lfz0lDpKE47NJVLmBQf+sayf0PEpSyH7X8jnjJNZ6dhI3KKjjT24qJhrMzhog
# WRdzhHMwDQYJKoZIhvcNAQEBBQAEggIARhKV47RCEQJ06Z9FcPd62dyjueJMkf8b
# uWN1fdVoaCApMdxzJWPJAIFOx+LgKPgGpiIeDHyp4ShNI/a82eAuVMpn/3pIzolV
# zgbzY54JxKRQ0Ybri4Oi+nESJp2F7Yovm+FrqY2iXbEnDziDvp6bSDr/WIZZiq0Q
# Zf/lnQ7Vc1PhORRLwEd0d3TnEfpjn/mbfyl8awXhV7r0A3bOksz7fV68Mp8OpmlM
# ITy4lzfhG1wMt3t8/v2OsvOq1sOBM99wjs+4WgL2ey6Mio35jmkSnuhzOPfPbODF
# TjBJ/G21jXtkOy8u4a1QBLXAioMi/UDLTXunf2zC0gMVzohlv/27v+GZGR2YjWZm
# SOEqHevoU+AyZ4LTk5EbOJC+Wn61T9hr6XIU6OFQjt0rm2N56pgAmAiMfnE9SLlp
# oA4ha2g07gh1AFSwwnOmBldEEksZMbQpmGAHaLp+F8PkS+RBxlwFztSQ8GpXqcbq
# cd+n9HFillxaiYB9130vTNv55gPuVcNEHiyhQPyJ2dgdsKd8uS6cmUByPGhqr7Nx
# r7DacF4yTYLEX7n4d5k4fbIWPNoA4qtQ5KL8+OLcRsG7a9m0AZTlOnoX9m7mcp5X
# kZHMw2+9ksp235B+MV6vclTLMjY7AdrkE1MnA2K5v0BGv2UFIpEW/gojrn4U7K98
# +Ssh4Drz5jw=
# SIG # End signature block
