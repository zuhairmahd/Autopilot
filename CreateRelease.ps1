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
        Write-Verbose "Signing the following $($filesToSign.count) files."
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
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCRDU5jBhfvKf1A
# y8Za/dFNVozisBwRjGcukApUf+qU1qCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAOBkSbr
# 6+lwVlNvAAAAA4GRMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDIwHhcNMjUwNDI4MDQxOTQxWhcNMjUwNTAx
# MDQxOTQxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# mf7+tbRuD3PX1o3SA5VcMyu24VWwwXFUAKuJ2oHdop3XXh7bGz5l0hJFpYa4AV53
# drxAPr+yqkrMkM7TGBUpHoh5GR72SDwxqL8vct8vk/RvPzGh00mADuoe6nZEmlhM
# b3hd1jSBshAAOp6YriYs5Ya4vczHUzGC2J0/v3grIM1Szrb1W192P9H/wrnvonL1
# 8RpqWqMBSTkmm+poFuQg8L4IOGFjNIwZbFtCoohbaAb8Le87voODb3PTZhSr6pY9
# PHE2z78757rwj9dBuCPDlJJ4p9IF8GcH9x+vtmESbzPr/oi38GOKlYH3d/oL86oJ
# 8otscnjWUswDBjFa3gzS3TsEDZZTVk3X065Nd4Z8ztaN1c21L1D1pgSH7DZpjK37
# WohRZ3EqLj7tdqBDXIBfXft3hKP9hqdTpQJscHlY3nroJO972+76ZUmx6gdFHPG9
# 8d6FXU0iP+VddIxaS80/lJLPp8/N07dvTXUD8CnJGkx7VpDDN0j5KH94qGcfWqxT
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFH/Gq1LSAubj5J7trvB4xaAA4rAxMB8GA1UdIwQY
# MBaAFCRFmaF3kCp8w8qDsG5kFoQq+CxnMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDIuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAyLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAGpzME+ppSK7DG6k
# npXQw635cDKMdzVSx3mUysY/F872vnb5WTj+DoM/hUdH1oKsH6j6Vor3dshcU6IR
# GPGL0Mp8HPoqHbDoq1LR75T1IJA5SYB+yZH6TYkcjxDT4yhJ01rf74/x6JWtUi4Q
# Jjg22WFWxcD/UT5NmivRgQSMhQsLUKI9XaGBgYJuNSIJWkwYWaPBwoKpQz75IZDI
# sdl6311rU5IwkbUeXLvu7oInIBhv3hthwAzqho3u90KewmUZyP9Tma3pS8bXJXXg
# zeBLTk7vRYJzeDa+Wy0YD3gsAJqwnrTZ0VArs7eyFcK7G1go01B7ACd+YYi/FBt3
# EN59yRmn3vvJLLeFnfH8+7KOKr2JDiCnKnc4TdmiZOaZq1HV8s6ILDgfaWhrH7ve
# nKieancFYDNXomvmT7J1sOvZjMG/nBuhBfGTV8CoNXVOpNuW5et8biQuDu7ypPT8
# NDgcKpaz2Oj0AtOGgZYxY7jZF5diDx6vwF/aBwOKWTOunRnWo78z0vSsmUKPPkwm
# 1EhbhvpVWY7aSLqtQBAN8W5mle3fcw9mZt8Jk2BLlVIRJuDM2cUEuAUYXDr2Gl1Z
# lexNQUhLHDjcWCV8QidoXa6iq3pNnuphkbzUj2/t3i0vmKMnbMUniqjO0Gwl/rIf
# NJ7T5tGwLTVNY4jq1uPPD+ZqAhLYMIIG5zCCBM+gAwIBAgITMwADgZEm6+vpcFZT
# bwAAAAOBkTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAyMB4XDTI1MDQyODA0MTk0MVoXDTI1MDUwMTA0MTk0
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJn+/rW0
# bg9z19aN0gOVXDMrtuFVsMFxVACridqB3aKd114e2xs+ZdISRaWGuAFed3a8QD6/
# sqpKzJDO0xgVKR6IeRke9kg8Mai/L3LfL5P0bz8xodNJgA7qHup2RJpYTG94XdY0
# gbIQADqemK4mLOWGuL3Mx1MxgtidP794KyDNUs629Vtfdj/R/8K576Jy9fEaalqj
# AUk5JpvqaBbkIPC+CDhhYzSMGWxbQqKIW2gG/C3vO76Dg29z02YUq+qWPTxxNs+/
# O+e68I/XQbgjw5SSeKfSBfBnB/cfr7ZhEm8z6/6It/BjipWB93f6C/OqCfKLbHJ4
# 1lLMAwYxWt4M0t07BA2WU1ZN19OuTXeGfM7WjdXNtS9Q9aYEh+w2aYyt+1qIUWdx
# Ki4+7XagQ1yAX137d4Sj/YanU6UCbHB5WN566CTve9vu+mVJseoHRRzxvfHehV1N
# Ij/lXXSMWkvNP5SSz6fPzdO3b011A/ApyRpMe1aQwzdI+Sh/eKhnH1qsUwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBR/xqtS0gLm4+Se7a7weMWgAOKwMTAfBgNVHSMEGDAWgBQk
# RZmhd5AqfMPKg7BuZBaEKvgsZzBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAyLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# Mi5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQBqczBPqaUiuwxupJ6V0MOt
# +XAyjHc1Usd5lMrGPxfO9r52+Vk4/g6DP4VHR9aCrB+o+laK93bIXFOiERjxi9DK
# fBz6Kh2w6KtS0e+U9SCQOUmAfsmR+k2JHI8Q0+MoSdNa3++P8eiVrVIuECY4Ntlh
# VsXA/1E+TZor0YEEjIULC1CiPV2hgYGCbjUiCVpMGFmjwcKCqUM++SGQyLHZet9d
# a1OSMJG1Hly77u6CJyAYb94bYcAM6oaN7vdCnsJlGcj/U5mt6UvG1yV14M3gS05O
# 70WCc3g2vlstGA94LACasJ602dFQK7O3shXCuxtYKNNQewAnfmGIvxQbdxDefckZ
# p977ySy3hZ3x/Puyjiq9iQ4gpyp3OE3ZomTmmatR1fLOiCw4H2loax+73pyonmp3
# BWAzV6Jr5k+ydbDr2YzBv5wboQXxk1fAqDV1TqTbluXrfG4kLg7u8qT0/DQ4HCqW
# s9jo9ALThoGWMWO42ReXYg8er8Bf2gcDilkzrp0Z1qO/M9L0rJlCjz5MJtRIW4b6
# VVmO2ki6rUAQDfFuZpXt33MPZmbfCZNgS5VSESbgzNnFBLgFGFw69hpdWZXsTUFI
# Sxw43FglfEInaF2uoqt6TZ7qYZG81I9v7d4tL5ijJ2zFJ4qoztBsJf6yHzSe0+bR
# sC01TWOI6tbjzw/magIS2DCCB1owggVCoAMCAQICEzMAAAAEllBL0tvuy4gAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMgITMwADgZEm6+vpcFZTbwAAAAOBkTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCC7VOFiRliTbRlVc5FNgodqnnYv
# PG+2QDTfuq5Q0B0ZnTANBgkqhkiG9w0BAQEFAASCAYA/zkoqblfqZQpolwl5xgR2
# OjNkgRnoTyqwYC+fqkx8WzEoJ0nvYDR5o+O1G2dIOQbCA62MMQN4YNE7bFzZMp9L
# wqIkjCx/FvqYshc+znwzTGbfqdV+X+nAW7Gn7U1vsQ5M2gMg+8GR8GOwGub4K2+f
# YRvMBqw4axiefEQJgrhsiE8LU289S8udjxUEwosgRWGM9WBrpVmtE9GNZm2T6chh
# iaOcwFcZ4FKRHkpU4khPvvL1NDUqczcoDRDcxDApmTI+9Mi3ou30SsbcbAY5fcSU
# /MTVvujsjiXe/EoUjb0THYipYVrb0ELAyNPGq+7Q3/bk5gZT5HLRJO/my1+uTCQU
# ln1HIjzX4YqEy93AxhOlbSvqGalBMHNxqSz264yOhHv8KMMQLAcz2OzOrjJV9fQg
# Vuxmo2/ZDHz1H8gARaKTdgSgbP196jESqu+AFwcIQy+eY4DUvzVXOYOFOocpmNED
# A3Aup34fSvpgWcnlLO33Li7aXMfG+JDk4GGP8gOMUe6hghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQg8BLnDYmluS0Os8X0m4oJuz1wK/T7zpKchpuaTRP8
# ODMCBmgHpB0Y6RgTMjAyNTA0MjkwMzQ1NTcuMjA2WjAEgAIB9KCB4KSB3TCB2jEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046RTQ2Mi05NkYwLTQ0MkUxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNB
# IFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPIDCCB4IwggVqoAMCAQICEzMAAAAF
# 5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/TWljcm9zb2Z0
# IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVowYTELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1BiKjHB7X55cz
# 0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJAeNcLAyT+XdM5
# i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCnTYocDOcRr9Kx
# qHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1nRliVDwunuLk
# X1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wok6IEaAJanHr2
# 4qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSxnfVYXdTGncaB
# nB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVuLr0g0FXkqfYd
# Umj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBILfHNj8RfOxPg
# juwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3bQAqZt65Kcae
# wEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnhTFtyQX3XgCoc
# 6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXUIQAWMs0d3cRD
# v09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGGMBAGCSsGAQQB
# gjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3bITBUBgNVHSAE
# TTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUF
# BwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1UdHwR9MHsweaB3
# oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRpZmljYXRl
# JTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGHMIGEMIGBBggr
# BgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0
# aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3DQEBDAUAA4IC
# AQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs174bNGO/ilWMm
# +Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezzsoOiBhv14YSd
# 1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD563I1nUJ6y59T
# bXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR83RbfMvmzdp3
# he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AWpsod4OJyT4/y
# 0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOLi2hBwL+KsCh0
# Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGyae6Ki8JYg5v4
# fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URrYiarjmBprwP6
# ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kwo3QLJ6No803j
# UsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlRwD9faBIySAcA
# 9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB5YwggV+oAMCAQIC
# EzMAAABK/bhVx2KqyYkAAAAAAEowDQYJKoZIhvcNAQEMBQAwYTELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAwHhcNMjQxMTI2
# MTg0ODU1WhcNMjUxMTE5MTg0ODU1WjCB2jELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0
# aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046RTQ2Mi05NkYwLTQ0MkUxNTAz
# BgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9y
# aXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA6DkQYZ6zYlw1AbxF
# kFNwc0V0BaXCCo1/+d01YKizalK9bX8fGrIUSVf75pYJOrhYmofIMh7wBv8j+kIp
# lOKYixrtVq+aQwAezI0wBFdFFeOyNCIynTQwz343z5IWVZ0/7cOXT1IDk9fIsI51
# kZKHa4SPf9rFmH9XtH1/P1ExueAGskBF/AvI1Ol2Vv2W9EDke8csxcPgXTkDNG9I
# 5ljEjM9pZUzf9kgw8Po8CVpD1/OFb468jcaWpsi/ydqboa3KJnPoyUlnq+cmgp6f
# kpqYmPM3EhAr1aAqbMnkiUrD4Q15DTv0XoZOi1zjXRhF5xxXKLr1m5k5xZlHp7mn
# PimiG67T7/e5DuFFt7XbAsOCW8N1Zq5jdNeLrMLtBvkRyKlkTSsp6nJQXR4Rf2e8
# 7TrveQiJjLsW+ZQ46KXdcDI1WoaxI0JzypicOQBbcU98823p/TArYdVpIYuYlXq0
# 923cf9+im62BVFG9eXhm+601RsXdWlH7QUMZzbD233aAP8LiB0pDrkK/ybUpYs6D
# okAJ9r0am4NFXu7LC+DfIFveRIZOCBaHGt4SJ3G2VgkFIoALFcThj+ro7oX+BT3s
# r0L57Lzi/QmU2UkTCwV1qKM6+aqbzhV4BxsxRjfQdetqzFvxI4IHf0IBuPoYYMiJ
# 4AXTa2moymfuejK2NZgL75mWwisCAwEAAaOCAcswggHHMB0GA1UdDgQWBBQXdNaJ
# ti4We46ErU/TNnIOeWGVejAfBgNVHSMEGDAWgBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmcl
# MjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0wazBpBggrBgEFBQcwAoZdaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBQ
# dWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAI
# BgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBADApzTDXWbyj/r85v6Az19sJPtwK
# dE5ukA0FrPxJffIDQ0WJLW1G7zXIXIJY3S5dCHbvXr5bDrmL67MlnU0M0RIapm5x
# pS8ejuWdRplHqkRiwhB5hm+7nEdxm+YdKCcoIPxbGqI1t8E0S0Zt7uw1/9LzRUar
# duTHQ0PKyZQnuYkHLGx83/+RR40w1gemiIFtC/UfvNY9URHCfB6bWp90qi3TjWLM
# O03FwcpuvZ15RubMVH/eH3WavJjLB4rDWd7NzeSAkiTqCEUAFNqrGFbnjOviBMUb
# KkAa/mFj9m1Dk6Zx4SbXtT5wCodX3k30m0cSB2nClULbR4YyWO5/MoSlTwnMPvFX
# MOWUkzd/SARbw7XVF6WLtgZHVBKAyZ4MFKwrKCP8hXdozdkeOX3Ru12+wewRk8An
# o/f9zrm4G/B/wO6u7smB3eR8OerqioPt73ufFMWsSCwXhSGz8xpjq6DKiG39sDRP
# F2CHnsBIJmv7dPMgYCKxskb7GiIkHbqa79vIAqQs9nY4s7XhR8NKRAKVIYj9/8Xk
# eY5S1G0YQhCwQlRUtvHZMY0pYmOXBfWpjQG+ZaIwfd07tB0hprJBh5zJLIussfsI
# P3tGr4o64tqRa8+OItP3mLWCdslKcBY5HIzHC2b0NnasAY1bqzfTfotsflhrV+pX
# SyN3As36dKMTqpGGMYID1DCCA9ACAQEweDBhMQswCQYDVQQGEwJVUzEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUHVi
# bGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAITMwAAAEr9uFXHYqrJiQAAAAAA
# SjANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCCszEelCOoNhJf0NZKiKOxYXyG/I+JL5Cak+RloHfCJ
# YTCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEIGZ7KbWlzY0AQkdLdW/gAxiy
# l7PEf9Wpsv+xde8uw+EKMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASv24VcdiqsmJAAAAAABKMCIE
# IELKoZBUQ0mkL8KUWBG4QKZsOjP4S3IrS5XqjDgxeizBMA0GCSqGSIb3DQEBCwUA
# BIICAKFJBrDabKKmNtR+AeFAd+Q7hgD//6DnrAWCef+T6hJUJCFr1qW5PHY/HE3R
# nd4YB+0lJYnKmCT8RZ5mYrHTV8oB5nUjPmsd/JBqej2z3sX6M/eXES6SYQlSovHE
# 8QxQORGtaJfzQYvTYo7+OL0HLpUai6f0kDf31VTrQO96lDjFNvhs9hdzBNciX10r
# 17KZS5rMPoFrzu4D41mMLEXqgdjOAD4d3c1uQlIDDtZHjrvhEeVQ5x4E0JXJOMcQ
# 11FYvbOFi+yylkdQCl1M75YMnLQ8gSV0ZbZHEbcSdEyoV2H24bhp4SP5D0Lc6cWt
# 6vTML0Yc6NaH1KQr1F2Lx9vor1NA/fY8JGN7K6yMB3gF+8L+D7UYhmUYXz8+Ib3V
# yp4igOSxM0II3mnbftKfXX1pbJn5CJDHNEpk4lq7dKjwhr7zAcmXff62isMXD9eM
# LurvSvMvwIPyxbo3bpwocEng+3Ge0IYZh3xdwnXCnhiAZtncviAaYRRvMa4G8Eze
# rLnCuSBRUsA79GdDJd9nrwbTC3VRDIqLnWZaFN942jSTGKd7C32qaMMRvBE4XC5B
# O8d1TrWVTa7EAhPuE7w5cOaXKL3IT3nvtIFxs81DnswOPIUa8Jz86oufVQ1GvC2P
# Gb7pq7Wz2dDWMkhpFseuRPXiOkYJIJf5U8Tu1Q4bLjfz7xZa
# SIG # End signature block
