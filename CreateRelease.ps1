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
    [switch]$ManifestOnly,
    [switch]$Copy,
    [switch]$CreateManifest,
    [switch]$Overwrite,
    [switch]$FullRelease,
    [switch]$Secrets,
    [switch]$CreateConfig
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

if (-not ($Copy -or $Sign -or $CreateManifest -or $FullRelease -or $Secrets -or $CreateConfig -or $SignOnly -or $ManifestOnly))
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
if ($ManifestOnly)
{
    Write-Host 'Creating manifest only...'
    if (CreateManifest -rootFolder $pwd -ManifestFile "$PSScriptRoot\manifest.json")
    {
        Write-Host 'Manifest created successfully.'
    }
    else
    {
        Write-Host 'Failed to create manifest.'
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

if ($CreateConfig -or $FullRelease)
{
    Write-Host "Choose the type of configuration you want to create:"
    Write-Host "(1) Create Release Configuration"
    Write-Host "(2) Create Dev Configuration"
    Write-Host "(3) Create custom Configuration"
    Write-Host "(0) Skip Configuration"
    $configChoice = Read-Host "Enter your choice (1, 2, or 0 to skip)"
    while ($configChoice -notin ('0', '1', '2', '3'))
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
        3
        { 
            Write-Host 'Creating custom configuration file.' 
            $configSuccess = CreateConfiguration -RootFolder $PSScriptRoot -DestinationFolder $ReleaseFolder -ConfigurationType 'default'
            if ($configSuccess)
            {
                $configSuccess = CreateFullConfiguration -RootFolder $PSScriptRoot -DestinationFolder $ReleaseFolder
            }
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
# MII6ggYJKoZIhvcNAQcCoII6czCCOm8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA7NghxTVsIeep1
# 7PaRpDNzSnunW9zG8DiduqcSl627gqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAK37bDk
# J2rwVReZAAAAArftMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwNTAyMDQwMjMxWhcNMjUwNTA1
# MDQwMjMxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# mLDKvezpp90GlH4y8UxkwiXPyCu9X9/KlwPRDinfMYqoL8bmIRiR/oCNHk4ubE3h
# Y7vrG6+YVaMdLwo5qqpslnkirO96zPrc/7cIuwX3zVO8DcK1lJTCezXuyCqPWprx
# FAXnHmpFcCVd0zcEiRSkQlJmk+MsV4wStBCAoBMCCXdKoy0kIGCW8+e8i6/eNRcV
# /Nua6bYXYdP2DXzpjcz0DhfvKwSUkomjCbFEn/vVD7pZaSfbWO7eT4I4CvdktXbj
# vBBEiliD80LOlhb5ra5q2JIiGx4RSr0j9gmBFhfkKJ0XZgun5iPAXj9JoCPUWgFm
# kVHmEWoL4hIZR75s6fQFwQI7CeO9c8LcEcYfdsXe1p2SnevtKwczKJPA5xFjaCcS
# 5kMYUuKHBjSuAiuHPrWuPHhsLsEicaEQvzWtwWBWbpzcD1Qs9LA8cHFazlGPOnVg
# QoqyOTtH+CKQykSVzxXQsiX+S45eGUSgkLS/75g9L+LMjuwAU/2rxdd95QYx1MCP
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFPK3uRlxSoAeQ8fUo4XOe0OO2t3cMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAIP8BJ2VV+dlL24G
# ROkFMun2kJTkeX/M6kZi12ZxvP1Va3KHP2kqeZ2iva0XylgixGmXOF1hy2/ArrIN
# Fs2TFndLjm32M3QiUgT1UfIna7OfoaTer/Tulc2nUJl1gxpLqc/Cc9L6McV2DgfA
# 2vbbzHVESCQs06Ff/HgSxFCHa/Lnk6PXSZimT/Oi8Zyi2Gk9Skc5Uyu6nnMa/lcR
# sJwMMrIy/9aMLe0EJXwPZ+sBjZ75AzBHzfikcbwx6Fv4kXR14OPhMnKKmGI0CdSH
# DPxhpyARwVNO6Fxx0lCPhP5oZYBkPE+1rd1zWYgcVEUVxmRIUCk/yBCG/vpUxkWD
# 3QDsb1hhhAN8P2yCh8I2NQxSQTXOSSE8277FdVxXGLVF0VxqrsD7TKgPqvuHAOAJ
# 8w7PakXx6Kf4WvA0e1+sQsQKWj/plDAAHkvT9qPgls44Vu73uRSwZ3oxv7FkgxRt
# epPkrV86OZvYn3sC728ECsa/nDhM73fXHBWHMhc1ZI6QrEZMs+LjqHkFVPOR5a+k
# JMz6mhdXPrxfMJS9tsVJIYgFFPZc0ntOdujPak7lzZXkZ9/UWIVV+0pgfehvkcaY
# XO7vD5q37THFOZeBYjEpAG0joiuGKX/FKLb0NfwzZJkt7C5qBeGGkGEHcH/Hqj1H
# 8vk5YupJd0gLsSYP7VfcibfptWILMIIG5zCCBM+gAwIBAgITMwACt+2w5Cdq8FUX
# mQAAAAK37TANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDUwMjA0MDIzMVoXDTI1MDUwNTA0MDIz
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAJiwyr3s
# 6afdBpR+MvFMZMIlz8grvV/fypcD0Q4p3zGKqC/G5iEYkf6AjR5OLmxN4WO76xuv
# mFWjHS8KOaqqbJZ5Iqzvesz63P+3CLsF981TvA3CtZSUwns17sgqj1qa8RQF5x5q
# RXAlXdM3BIkUpEJSZpPjLFeMErQQgKATAgl3SqMtJCBglvPnvIuv3jUXFfzbmum2
# F2HT9g186Y3M9A4X7ysElJKJowmxRJ/71Q+6WWkn21ju3k+COAr3ZLV247wQRIpY
# g/NCzpYW+a2uatiSIhseEUq9I/YJgRYX5CidF2YLp+YjwF4/SaAj1FoBZpFR5hFq
# C+ISGUe+bOn0BcECOwnjvXPC3BHGH3bF3tadkp3r7SsHMyiTwOcRY2gnEuZDGFLi
# hwY0rgIrhz61rjx4bC7BInGhEL81rcFgVm6c3A9ULPSwPHBxWs5Rjzp1YEKKsjk7
# R/gikMpElc8V0LIl/kuOXhlEoJC0v++YPS/izI7sAFP9q8XXfeUGMdTAjwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBTyt7kZcUqAHkPH1KOFzntDjtrd3DAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQCD/ASdlVfnZS9uBkTpBTLp
# 9pCU5Hl/zOpGYtdmcbz9VWtyhz9pKnmdor2tF8pYIsRplzhdYctvwK6yDRbNkxZ3
# S45t9jN0IlIE9VHyJ2uzn6Gk3q/07pXNp1CZdYMaS6nPwnPS+jHFdg4HwNr228x1
# REgkLNOhX/x4EsRQh2vy55Oj10mYpk/zovGcothpPUpHOVMrup5zGv5XEbCcDDKy
# Mv/WjC3tBCV8D2frAY2e+QMwR834pHG8Mehb+JF0deDj4TJyiphiNAnUhwz8Yacg
# EcFTTuhccdJQj4T+aGWAZDxPta3dc1mIHFRFFcZkSFApP8gQhv76VMZFg90A7G9Y
# YYQDfD9sgofCNjUMUkE1zkkhPNu+xXVcVxi1RdFcaq7A+0yoD6r7hwDgCfMOz2pF
# 8ein+FrwNHtfrELEClo/6ZQwAB5L0/aj4JbOOFbu97kUsGd6Mb+xZIMUbXqT5K1f
# Ojmb2J97Au9vBArGv5w4TO931xwVhzIXNWSOkKxGTLPi46h5BVTzkeWvpCTM+poX
# Vz68XzCUvbbFSSGIBRT2XNJ7Tnboz2pO5c2V5Gff1FiFVftKYH3ob5HGmFzu7w+a
# t+0xxTmXgWIxKQBtI6Irhil/xSi29DX8M2SZLewuagXhhpBhB3B/x6o9R/L5OWLq
# SXdIC7EmD+1X3Im36bViCzCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
# AAYwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBFT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDH48g/9CHdxhnAu8XL
# q64nh9OneWfsaqzuzyVNXJ+A4lY/VoAHCTb+jF1WN9IdSrgxM9eKUvnuqL98ftid
# 0Qrgqd3e7lx50XCvZodJOnq+X88vV0Av2x+gO82l0bQ39HzgCFg2kFBOGk7j8GrG
# YKCXeIhF+GHagVU66JOINVa9cGDvptyOcecQS1fO8BbAm7RsFTuhFGpB53hVcm0g
# JW35mgpRKOpjnBSWEB3AeH7fUGekE8LMW0pWIunrMS1HI7FF6BqAVT7IuBe++Z3T
# sgM3RLZMti6JmNPD6Rxg62g2AqvuTQLoT1Z/cfiMdq+TYzGoWm2B8vSAv7NtJv5U
# E0qJVPSarNckgmZaarDQr4Pcwp+YJ6vd7cJus/4XlG0JvRdoTS5Fwk9kmNbByIMH
# EEhuQ0XgYvXaGXm/J2AUybNBw26h0rJf//eUsnWrbaugdVLVyC2wuCmNZhmUGWEJ
# Nxcl5nfG5om9dkH2twsJfXk6BcvbW1RTAkIsTbtXkAZnGQ7eLniaBIKzC06ZZTgA
# p38H97cq1e/pcFREq4C157PUSmCWhpnBB6P2Xl031SHxbX0FmD0iUuX7EdFfi8OI
# xYBR//sA17gyhL3wXjmvvogYnSELTYQy4xnEASvBmPSWfRovncTOUxrkkKJE5tvR
# Sgsd8ZJ00mwyDS6PcMBAN1VZMQIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBR2nDZ0E9GQfWFfswLrgPSZS6U+
# hTBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAGov
# CZ/YsHVCNSBrQbvMWRsZ3w0FAsc/Qo4UFY0kVmJO0p+k7RtnZZ+zq/m+ogqMTfZD
# ozz0bhmRVy9a4QAD52+MtOFLLz1jT/+b9ZNIrBi2JHUTCfvHWTD8WD3fBCmzYLVZ
# SP7TT/q42sX53gxUnFXUegEgP73lkhbQqSpmimc4DjDm8/hPlwGmtlACU/+8wbIH
# Qf36kc2jSNP1DyB8ok3MdL2LUOAGaa58Z1b1MHK6ejwYCLMUyEuUizTxvmWKUiQT
# nPcUwBQCv5eAgjUU1mdvjc4jpB3bM6KNuNh+6uxdQI0cL5FLAkablQvM/KZiCCcn
# 6SEk6ruhKWo8aluvvSEYF4/D8nv+aZKqnuFOC3SY+KRLWLhqnzH4/fJ6ZhKGcWuB
# XXvnZMj4Czr0t+Au2GQhO9/tsUcHy+YiFp1kI5LS9MLHcH785VwQws07ZsnQ72KR
# zUmpHQW+rHucDAxFKHcVWqiyDMFtadWRAmruhYXAxV8Uhifos9Fky3jy7qIxQIUF
# I912w8D/qTzmYS/7TxTlYJDvJ2PUpVXZMet7/yYseJ6b3B/8LOiGpGe3EzYT/H40
# fLpMEydI9BGqGE1+46BQMBYRiaUz9kcZo8hvvE699XItD/uXph+iBPd6m3CngY4Z
# GMfnP6Ab2SkEjHxCtGXo6KWeXFETGiSYx+UvuXXZMIIHnjCCBYagAwIBAgITMwAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFzIwghcuAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACt+2w5Cdq8FUXmQAAAAK37TAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCD7b3l9wtnvX/mzj+052ToOSM3n
# PrPN/dBenW2LcCsNgjANBgkqhkiG9w0BAQEFAASCAYAoJweQiGQVaxm2FyhUFhNp
# a1VG/YhfRw86Ry0Ga52Fy5K7ZzTtFsksMgA/pDPi0d3+osEErvw8ig1G8x/EES85
# 4Sc/Nw4jQNyB0nb+t/L2iqYW5z8IPd3G+Zh3DdJqs7rYBz1xOassMslIJXY+ITwt
# TRnol10S0LRbPRhd/TRqC0BRntr560PR3+h6go4upCP09LFUHCktj5CQlHj7q9qJ
# PMrrqEUav3yNmqk8Dn73N49dmSgnvALgeCHdnhKc89beMfkb5r3gXSYZKLUW1tlQ
# P1TRObtcKz2RG1+uIHBDgS9vR7SnTy/jxLJ4rzpFZmJS4F70a9CrFDrTFJr/Hlg2
# HGFuLCjhh/ubDwrbbj4pd20jbFSfs6yOIk4/+rkEyZE9Mkq6krcVoKe8nRJke4NF
# ZCy3P1+F3FnhdY9Pd1teEWa3N6J5j4TXMUxkZj9ok/nvu57ZQkn3MMfZPe7+9IHP
# ecnCc4Cbd8KYH0Z6vW2hJGlK+giRRft0B5Tb8qlrrdOhghSyMIIUrgYKKwYBBAGC
# NwMDATGCFJ4wghSaBgkqhkiG9w0BBwKgghSLMIIUhwIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBagYLKoZIhvcNAQkQAQSgggFZBIIBVTCCAVECAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgJrIYZ+KBeuIphmFTfVKq8kpRNT1VlCiBsZ0QAMD7
# w30CBmgTeHRruBgTMjAyNTA1MDMwMjAxMTQuMjEzWjAEgAIB9KCB6aSB5jCB4zEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWlj
# cm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046N0ExQS0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQ
# dWJsaWMgUlNBIFRpbWUgU3RhbXBpbmcgQXV0aG9yaXR5oIIPKTCCB4IwggVqoAMC
# AQICEzMAAAAF5c8P/2YuyYcAAAAAAAUwDQYJKoZIhvcNAQEMBQAwdzELMAkGA1UE
# BhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjFIMEYGA1UEAxM/
# TWljcm9zb2Z0IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRl
# IEF1dGhvcml0eSAyMDIwMB4XDTIwMTExOTIwMzIzMVoXDTM1MTExOTIwNDIzMVow
# YTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEy
# MDAGA1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIw
# MjAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCefOdSY/3gxZ8FfWO1
# BiKjHB7X55cz0RMFvWVGR3eRwV1wb3+yq0OXDEqhUhxqoNv6iYWKjkMcLhEFxvJA
# eNcLAyT+XdM5i2CgGPGcb95WJLiw7HzLiBKrxmDj1EQB/mG5eEiRBEp7dDGzxKCn
# TYocDOcRr9KxqHydajmEkzXHOeRGwU+7qt8Md5l4bVZrXAhK+WSk5CihNQsWbzT1
# nRliVDwunuLkX1hyIWXIArCfrKM3+RHh+Sq5RZ8aYyik2r8HxT+l2hmRllBvE2Wo
# k6IEaAJanHr24qoqFM9WLeBUSudz+qL51HwDYyIDPSQ3SeHtKog0ZubDk4hELQSx
# nfVYXdTGncaBnB60QrEuazvcob9n4yR65pUNBCF5qeA4QwYnilBkfnmeAjRN3LVu
# Lr0g0FXkqfYdUmj1fFFhH8k8YBozrEaXnsSL3kdTD01X+4LfIWOuFzTzuoslBrBI
# LfHNj8RfOxPgjuwNvE6YzauXi4orp4Sm6tF245DaFOSYbWFK5ZgG6cUY2/bUq3g3
# bQAqZt65KcaewEJ3ZyNEobv35Nf6xN6FrA6jF9447+NHvCjeWLCQZ3M8lgeCcnnh
# TFtyQX3XgCoc6IRXvFOcPVrr3D9RPHCMS6Ckg8wggTrtIVnY8yjbvGOUsAdZbeXU
# IQAWMs0d3cRDv09SvwVRd61evQIDAQABo4ICGzCCAhcwDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRraSg6NS9IY0DPe9ivSek+2T3b
# ITBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUyH7SaoUqG8oZmAQHJ89QEE9oqKIwgYQGA1Ud
# HwR9MHsweaB3oHWGc2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3Js
# L01pY3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENl
# cnRpZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcmwwgZQGCCsGAQUFBwEBBIGH
# MIGEMIGBBggrBgEFBQcwAoZ1aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZlcmlmaWNhdGlvbiUyMFJv
# b3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIwMjAuY3J0MA0GCSqGSIb3
# DQEBDAUAA4ICAQBfiHbHfm21WhV150x4aPpO4dhEmSUVpbixNDmv6TvuIHv1xIs1
# 74bNGO/ilWMm+Jx5boAXrJxagRhHQtiFprSjMktTliL4sKZyt2i+SXncM23gRezz
# soOiBhv14YSd1Klnlkzvgs29XNjT+c8hIfPRe9rvVCMPiH7zPZcw5nNjthDQ+zD5
# 63I1nUJ6y59TbXWsuyUsqw7wXZoGzZwijWT5oc6GvD3HDokJY401uhnj3ubBhbkR
# 83RbfMvmzdp3he2bvIUztSOuFzRqrLfEvsPkVHYnvH1wtYyrt5vShiKheGpXa2AW
# psod4OJyT4/y0dggWi8g/tgbhmQlZqDUf3UqUQsZaLdIu/XSjgoZqDjamzCPJtOL
# i2hBwL+KsCh0Nbwc21f5xvPSwym0Ukr4o5sCcMUcSy6TEP7uMV8RX0eH/4JLEpGy
# ae6Ki8JYg5v4fsNGif1OXHJ2IWG+7zyjTDfkmQ1snFOTgyEX8qBpefQbF0fx6URr
# YiarjmBprwP6ZObwtZXJ23jK3Fg/9uqM3j0P01nzVygTppBabzxPAh/hHhhls6kw
# o3QLJ6No803jUsZcd4JQxiYHHc+Q/wAMcPUnYKv/q2O444LO1+n6j01z5mggCSlR
# wD9faBIySAcA9S8h22hIAcRQqIGEjolCK9F6nK9ZyX4lhthsGHumaABdWzCCB58w
# ggWHoAMCAQICEzMAAABTUsIDi+Wa+E4AAAAAAFMwDQYJKoZIhvcNAQEMBQAwYTEL
# MAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAG
# A1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZXN0YW1waW5nIENBIDIwMjAw
# HhcNMjUwMjI3MTk0MDI2WhcNMjYwMjI2MTk0MDI2WjCB4zELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxh
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046
# N0ExQS0wNUUwLUQ5NDcxNTAzBgNVBAMTLE1pY3Jvc29mdCBQdWJsaWMgUlNBIFRp
# bWUgU3RhbXBpbmcgQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAlzkp+i/zCu1Q53pMxjbNF6qhwdHM8SCqZ2QCNT/t8WMyh3qRnEXYPTrz
# MC83O9xf6cic/uM3cUrYr1Hp2nbd409hcM79LGJ1+jd0rH1g4m7gGYuYHRxKInF7
# U6GcW4Jh/lzCzBlm0DY2seuvT/FJwVF4P1W7OM1V+18Qa8FvB2lxbh+s5iJHBTRo
# zEY0p9A0RPk27gowiMA1ONeoBHPFedk+H/B1RdvBEIjxEZR0Xt5NQ3Mv/2s+bN89
# Imt7etD5DMH1PbJksfq1/1xI6Qluir4pSBLy1eiOEJOV3Gn3SBiDwU82GCoOQEDa
# Pb2l4ampCFmFsw+ge+NWjYvDIvCPnXmvE79bE9rZsosLGMggdkYSiaQ5RF3HBRT1
# alztZYKEWGLKWdz4tKLZ4vDmTe21dDm1oNdqo5qhENgBn7jGr+byoq/x5ixNEvIo
# yQbBCL5WrDS7oOoP471C5WpAjSqG1wQLIjE/11gxwoV52aLsocYkii7Cbr+5q3Cd
# sTuU3bgRpDOpXU6t4PI/W0QMqEl6uD+xCVEo0NVyZNEhRlVNWiYyVlAD00b4smR7
# iGAWy314d/R7H95aDTwyK1yUy+vgiLZB7Vna6yucTgbuir2tSNkfpLDP1vuoVf3C
# 9UU8QE3xKnBf2wpx/jRsMTOK8A+B7K2pOZIyI2HVA+IylCHezkECAwEAAaOCAcsw
# ggHHMB0GA1UdDgQWBBRuZESrI2MaHwWzQj0h1vRk//aPajAfBgNVHSMEGDAWgBRr
# aSg6NS9IY0DPe9ivSek+2T3bITBsBgNVHR8EZTBjMGGgX6BdhltodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBQdWJsaWMlMjBS
# U0ElMjBUaW1lc3RhbXBpbmclMjBDQSUyMDIwMjAuY3JsMHkGCCsGAQUFBwEBBG0w
# azBpBggrBgEFBQcwAoZdaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# ZXJ0cy9NaWNyb3NvZnQlMjBQdWJsaWMlMjBSU0ElMjBUaW1lc3RhbXBpbmclMjBD
# QSUyMDIwMjAuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEw
# PwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9j
# cy9SZXBvc2l0b3J5Lmh0bTAIBgZngQwBBAIwDQYJKoZIhvcNAQEMBQADggIBAIhz
# /2VPMlLSGnTEmp99qQ3GGUnxhbrAMbPf1Yr2bPoy6x3lxp3i3YSON7XtMAombBDA
# 4SAsxPx8Y2G8Ii95c5uaziwO4bQLAblGJsh1+0lZhzoAQxzOI5MPpsq3F3t+8CHh
# 6JUak8u3MJscVPYNK/kPQAJ0/Hddk+N/AVEoBWIjIy0v/ZttmOte7lYsyFdPmuL7
# 4FuLkQ7bKB6AWQAH4BGgODSsbk924NXp1iZU2gdV0AyZcLYofKsisfDUnZs8bALt
# wUgHPWFuV+li5vnbUUCmZ0ea5Tzn7Qn5XHjKVeDzLT+nBBx6GMPRUaETfIWC88OX
# Ax5jiMV4jns2KHFjMw491Ukcij3vU75M6xtqiNeZ7e8R0nnpql2+LNyrvmYCVjP0
# ym+QlQZsyvLKKOiP39QbKxK7Y8l5lxGJwxF2N2CmEgtYZVapBKj0OKeXGDEv4kA/
# dJGBOlSOKCucIHnXlDBFIOwMVMrRFqhra4JBKw+YJTIsc4FauSgJc4+tckaO64qk
# jHVWK1nLr9xXmVoYay+5jqOu63I64aaF1R4uTClW5uCmgsYQn5z4y2uAgNKmBm4U
# gGKY1D3xsAKrOIsfIRodRNImOMFuoNfRjVpyIzq/T1qwWxarvaBFXIVnDYN7XbAo
# XGLwydf7ik06aCQLBcgtzC/zQ53jjqa+LUE5qOiNMYID1DCCA9ACAQEweDBhMQsw
# CQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYD
# VQQDEylNaWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMAIT
# MwAAAFNSwgOL5Zr4TgAAAAAAUzANBglghkgBZQMEAgEFAKCCAS0wGgYJKoZIhvcN
# AQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCAIue0Chmhu1JljK+6m
# Fb+npvAvKgH1rfON1A0/OjHxsjCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAE
# IEB/HwRijKuU/vjAU7BdHBp/tHRfrRMPkNejldGf2h0jMHwwZaRjMGExCzAJBgNV
# BAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMT
# KU1pY3Jvc29mdCBQdWJsaWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAA
# U1LCA4vlmvhOAAAAAABTMCIEIC2N9H6xQJ5w5/Dn/XWBMg9G0TisGGJJ6LiCkuI3
# aXRWMA0GCSqGSIb3DQEBCwUABIICAHOoTTCWJXK5aP8qOccZ3pU4+9aGvzKy7CZl
# YQF1ENxfKjd/wMbTFHF+KkkRuOxazwAxod+BcIrSMc1ynxiJqjVzla07HiZhcuj0
# wGLyuWBP3G0KsuBwCK0ttgi8JqSZ4cKEMYgzyKCE83jmG2YP/eu/CVtetEIvSOAE
# onGlcQIym9e03DQM7pQo2bcgETg58Kt9r7WWMwDijSoqEC3WS7VZCwYetHcNU9Du
# mt7et1cuiqZDG6wAO3/P17T0/lQekOW2HvKp2kwJjcEJDqG2o0JlQFX98UWAig38
# cn6olyJJNp577kjsAr4NG3Oolla/IAl0VLmwr5JUFeB87dGudxXCrvLG0tUQbTB7
# Fif1xI+im7+lT66dIH7kov2ejDOgbHmtDc57lwkLvEipf4DNBXty/mE+r/VcQbLR
# mLWJfW4z/ZVlq6Y6z3cdERS/Hl1i8VWmqI0dLUTe9FrWuRa3xAOhAz5+4H1w7iuM
# pyWJFPqSrCs37zev8o5UYIZHTCT0EOyXvtFeqW/Ip24EMeWorO+iZORpWmSdxEVY
# GUqktcg3nsxIQB2JkBrePgOPysAtFqY8cpe1CjhGsnxDRvQnk9gjhK6VFZMsjbon
# SJ/rDnBZTIPyMWq3bFQdS16uyd0Endh0DwQgLHc2oBOQPNX/8SLZlqsBWkQf/ncp
# Bcled3Lq
# SIG # End signature block
