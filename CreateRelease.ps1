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
    [string]$ManifestFile = "$ReleaseFolder\manifest.json",
    [switch]$Sign,
    [switch]$Copy,
    [switch]$Manifest,
    [switch]$Overwrite,
    [switch]$FullRelease,
    [switch]$Secrets,
    [switch]$Config
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
Write-Verbose "NoConfig: $NoConfig"

if (-not ($Copy -or $Sign -or $Manifest -or $FullRelease -or $Secrets))
{
    throw 'At least one of the following switches must be provided: -Copy, -Sign, -Manifest, -Secrets or -FullRelease.'
}

function CreateConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [string]$ConfigurationFile = "$folder\vars.json"
    )

    #print verbose log of received parameters
    Write-Verbose "Folder: $Folder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    
    $valuesToEdit = @(
        @{name = 'Repo'; value = @('Github', 'Gitlab')}, 
        @{name = 'Release'; value = @('main', 'auto')}
    )
    $success = $false

    # Load parameters from the configuration file if it exists
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Host " Loading configuration values from $ConfigurationFile."
        $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
        Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    }
    else
    {
        Write-Host "No configuration file found at $ConfigurationFile."
    }
    #itterate over the configuration data and prompt the user to choose a value
    foreach ($config in $configData.PSObject.Properties)
    {
        Write-Verbose "Configuration: $($config.Name) = $($config.Value)"
        if ($valuesToEdit.name -contains $config.Name)
        {
            Write-Host "Choose a value for $($config.Name)"
            $configValues = $valuesToEdit | Where-Object { $_.name -eq $config.Name } | Select-Object -ExpandProperty value
            $index = 1
            $configValues | ForEach-Object {
                Write-Host "($index): $_"
                $index++
            }
            $selectedValue = Read-Host "Enter the number of the value you want to select"
            Write-Verbose "Selected value: $selectedValue"
            while ($selectedValue -lt 1 -or $selectedValue -gt $configValues.Count)
            {
                Write-Host "$selectedValue is an invalid selection. Please enter a number between 1 and $($configValues.Count)"
                [console]::beep(500, 300)
                $selectedValue = Read-Host "Enter the number of the value you want to select"
            }
            $config.Value = $configValues[$selectedValue - 1]
            Write-Verbose "$($config.name) =  $($config.Value )"
        }
    }
    #Print all the new configuration data but only in verbose mode.
    Write-Verbose "New configuration data:"
    $configData.PSObject.Properties | ForEach-Object {
        Write-Verbose "$($_.Name) = $($_.Value)"
    }
    #Save the new configuration data to the configuration file
    Write-Verbose "Saving configuration to $ConfigurationFile."
    $configData | ConvertTo-Json | Set-Content -Path $ConfigurationFile
    Write-Verbose "Configuration saved to $ConfigurationFile."
    Write-Verbose "Checking if configuration file exists."
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "Configuration saved to $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Verbose "Failed to save configuration to $ConfigurationFile."
    }
    return $success
}

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
        [bool]$NoPrompt = $false
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
    $version = @{'Functions' = @(); 'Scripts' = @(); 'Cmds' = @(); 'configurations' = @() }
    $version | ConvertTo-Json | Set-Content -Path $ManifestFile -Force
    $functionFiles = Get-ChildItem -File -Path $functionsFolder -Recurse -Include *.ps1 -Force
    $scriptFiles = Get-ChildItem -Path "$pwd" *.ps1 -Force
    $cmdFiles = Get-ChildItem -File -Path "$pwd" *.cmd -Force
    $configurationFiles = Get-ChildItem -File -Path "$pwd" vars.json -Force
    $fileTypes = @('functions', 'scripts', 'cmds', 'configurations' )
    $functions = @()
    $scripts = @()
    $cmds = @()
    $configurations = @()
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
            configurations 
            {
                foreach ($configuration in $configurationFiles)
                {
                    Write-Verbose "Checking if $($configuration.BaseName) is in the exclusion list."
                    if ($configuration.BaseName -notin $filesToExclude)
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
    $combined = @{'Functions' = $functions; 'Scripts' = $scripts; 'Cmds' = $cmds; configurations = $configurations }    
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

if ($Manifest -or $FullRelease)
{
    Write-Host "Creating manifest in $ReleaseFolder"
    if (CreateManifest -rootFolder $pwd -ManifestFile $ManifestFile)
    {
        Write-Host 'Manifest created successfully.'
        if (CopyManifest -SourceFolder $ReleaseFolder -DestinationFolder $PSScriptRoot -ManifestFile $ManifestFile -NoPrompt $Overwrite)
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

if ($Secrets -or $FullRelease)
{
    Write-Host "Copying secrets from $PSScriptRoot to $ReleaseFolder"
    if (CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $ReleaseFolder)
    {
        Write-Host 'Secrets copied successfully.'
    }
    else
    {
        Write-Host 'No secrets files copied.'
        Write-Host 'Run the script with the -verbose switch for more information.'
    }
}
else
{
    Write-Host 'Skipping secrets copy process.'
}

if ($Config -or $FullRelease)
{
    Write-Host "Creating configuration file in $ReleaseFolder"
    if (CreateConfiguration -Folder $ReleaseFolder)
    {
        Write-Host 'Configuration file created successfully.'
    }
    else
    {
        Write-Host 'Failed to create configuration file.'
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBomOR+92M/hzb9
# zYqS35S1buET1zisS9fczp0ElCmaRqCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
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
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAIztf3H
# p+2ytw6TAAAAAjO1MA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBFT0MgQ0EgMDEwHhcNMjUwMzI1MDY1NjExWhcNMjUwMzI4
# MDY1NjExWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# iSM5tT+Jjd+jvxIrUc0mpDf3zr/MwFft3bbflYjOHrAIJxTjcqrTDp2upH+1Ipyu
# 4ejcycNDOp+anmUZjefME5bpNUBx9oRmVq0RcrB65IZeqKmi9GNsPO0e4ohRt5Lp
# 56lRjkFLXRM99oPrg5oZHC1xDRAFfhpkRe+MSCUhlapJbPvp764uNgIckHtnLgVY
# OCJOmeAWt9wpzlzAuQ7Bwb3U472aENOyuKQSl5GNXZ2KkkhhPmVFOUb/usvrObCF
# teCDsQ4lZzXhrTGZjy3PJUVZzUmdKHzAeSz5KMIKE+Q6UC8TRspwEd12thfZFkqK
# Suh38sX0TNZYOyFLIoz/WE7jxiIWrhKSlSzKOcr3vdWtDU1D4PUdE43M+sEl1nuU
# UQeDzFhAKfiurodcj9bqYtbmGUnUdojPPK0opYIOGPvnh7g15YP+838BJL+8HqW1
# dNEkREELeOyOEPeq5Eo8EkJF9Tl5pVa/sCiyDl48s1TK3stv5MZaMqxWF4qKZAkr
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFE3JWjohOo26TUlGpdFZFn4ClUblMB8GA1UdIwQY
# MBaAFHacNnQT0ZB9YV+zAuuA9JlLpT6FMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEVPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBFT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBAINGxW/npLkbDcHm
# sJ+PIc+bl83WKMAURUk/AjHx9VGDIL9VjBtVQdhZtb+N4Qlgq1SXxaX18Pt4/XxQ
# 30NlnBZlL79C6zedA/nihd0rrm4nRVEomdNWufshITLejU3K2i3U/u3Eb4/Ydtbl
# RVU1IMxlbdnHipB4ey1B20gXWri8n+vNbpppcewlX4K4+557t70d68a5wBuaT0/R
# xl1XdNWqwM3Bxfmv5fR2PNrzGNEVvDvmF/ug4cLJRZMe9kZnaMqYTkb5x2S3PDkW
# JcVY7vyrOdSK77hwZlUxhtBMOy43xUwuwm668Ff+idLcCSlx4n6XYklZaJhvqDri
# RGw6ysCcoihT0udQvupcOVz1ezB5fECWuFTH4eHAUrTJZkdyWrXIqmEiqOJpXB3T
# BxXFjQHZZb2C8UUHp4cBeBizvE3kZiBw+MOkvAPXQwHWPeEEvCqp+Tg5m5PWdJWV
# YkNb7Q4SJaJlHZJbXwA47XsHhdKof/E8pL5f07FJUnvkqOp/OP5bl9BzKkARAQUO
# FRADH32Ea2MXwYfPs+kDrFjYlZzPjvyRDERDnbxT/UasJS2HBr2xjgl2FpUtBPYJ
# 6KnJ9hd/iQ+gIWngnK2MUsDh7viQdTFMdbjWp9tmDfwqfG9yerRC/wxngavEI1C1
# NUEWqP4CkdkJR3wWCglQiNRxIUZ8MIIG5zCCBM+gAwIBAgITMwACM7X9x6ftsrcO
# kwAAAAIztTANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgRU9DIENBIDAxMB4XDTI1MDMyNTA2NTYxMVoXDTI1MDMyODA2NTYx
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIkjObU/
# iY3fo78SK1HNJqQ3986/zMBX7d2235WIzh6wCCcU43Kq0w6drqR/tSKcruHo3MnD
# Qzqfmp5lGY3nzBOW6TVAcfaEZlatEXKweuSGXqipovRjbDztHuKIUbeS6eepUY5B
# S10TPfaD64OaGRwtcQ0QBX4aZEXvjEglIZWqSWz76e+uLjYCHJB7Zy4FWDgiTpng
# FrfcKc5cwLkOwcG91OO9mhDTsrikEpeRjV2dipJIYT5lRTlG/7rL6zmwhbXgg7EO
# JWc14a0xmY8tzyVFWc1JnSh8wHks+SjCChPkOlAvE0bKcBHddrYX2RZKikrod/LF
# 9EzWWDshSyKM/1hO48YiFq4SkpUsyjnK973VrQ1NQ+D1HRONzPrBJdZ7lFEHg8xY
# QCn4rq6HXI/W6mLW5hlJ1HaIzzytKKWCDhj754e4NeWD/vN/ASS/vB6ltXTRJERB
# C3jsjhD3quRKPBJCRfU5eaVWv7Aosg5ePLNUyt7Lb+TGWjKsVheKimQJKwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRNyVo6ITqNuk1JRqXRWRZ+ApVG5TAfBgNVHSMEGDAWgBR2
# nDZ0E9GQfWFfswLrgPSZS6U+hTBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBFT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwRU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQCDRsVv56S5Gw3B5rCfjyHP
# m5fN1ijAFEVJPwIx8fVRgyC/VYwbVUHYWbW/jeEJYKtUl8Wl9fD7eP18UN9DZZwW
# ZS+/Qus3nQP54oXdK65uJ0VRKJnTVrn7ISEy3o1Nytot1P7txG+P2HbW5UVVNSDM
# ZW3Zx4qQeHstQdtIF1q4vJ/rzW6aaXHsJV+CuPuee7e9HevGucAbmk9P0cZdV3TV
# qsDNwcX5r+X0djza8xjRFbw75hf7oOHCyUWTHvZGZ2jKmE5G+cdktzw5FiXFWO78
# qznUiu+4cGZVMYbQTDsuN8VMLsJuuvBX/onS3AkpceJ+l2JJWWiYb6g64kRsOsrA
# nKIoU9LnUL7qXDlc9XsweXxAlrhUx+HhwFK0yWZHclq1yKphIqjiaVwd0wcVxY0B
# 2WW9gvFFB6eHAXgYs7xN5GYgcPjDpLwD10MB1j3hBLwqqfk4OZuT1nSVlWJDW+0O
# EiWiZR2SW18AOO17B4XSqH/xPKS+X9OxSVJ75Kjqfzj+W5fQcypAEQEFDhUQAx99
# hGtjF8GHz7PpA6xY2JWcz478kQxEQ528U/1GrCUthwa9sY4JdhaVLQT2CeipyfYX
# f4kPoCFp4JytjFLA4e74kHUxTHW41qfbZg38Knxvcnq0Qv8MZ4GrxCNQtTVBFqj+
# ApHZCUd8FgoJUIjUcSFGfDCCB1owggVCoAMCAQICEzMAAAAGShr6zwVhanQAAAAA
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
# nTiOL60cPqfny+Fq8UiuZzGCFyAwghccAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEVPQyBDQSAwMQITMwACM7X9x6ftsrcOkwAAAAIztTAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCCzlrkjjpABPvWLRWP2EgZ+keAU
# Is6SCQPLQjxKHKlP5DANBgkqhkiG9w0BAQEFAASCAYAKh2xmwPtQqXuMOnpsBA+Y
# K8ZZyggHVGCc1Wy4jRfP2tl7AAw8hkmwx48YMlpTKfo76zHGww0486MccjiT4URs
# eAEek3mrKcy3if1gfr1xDrk7fEvNQaFta1fQDZ+bQKnK9FgaUj9/vO57FXZR5C5I
# /bSbOJnKfQMmNTv/3jJi2X9tyNzeMMesR9B1Y3Wbmdy6ykzhkKPZRBxaBsh7Z6bm
# QqqTjbrm/HB7kfEKvhPjdTeMKrbFyu4ZKGOVSK1dyxylLYQNA000phMs5SClnPdR
# lpBwkI1sgCjS50ojLRc29KKzLdoSRxze1wdhgL1tpr9pPmFe/DOVQGrQjjRp6/FE
# L98bLOAh6u+SkBjevgPH23WVnmXokO6x5gqdiN9f024ebaHr9wh+AzTSK33li16n
# v/3rPyvwY4Kf/RI3uyHuVcdYn7LSeTVtOrT6wmn5+gsxFVeeF4uRlYPSXH1dHvYy
# ba17IyBTT9j2gYS7adEoD97bkoLQv60mzo3f2pbGiG6hghSgMIIUnAYKKwYBBAGC
# NwMDATGCFIwwghSIBgkqhkiG9w0BBwKgghR5MIIUdQIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYQYLKoZIhvcNAQkQAQSgggFQBIIBTDCCAUgCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgtrPr5830qDkK86FDkwIVRjkI8pHRdHYDXiQQPhwy
# 30YCBmfdnyaxXBgTMjAyNTAzMjUyMzU2MDAuNDkyWjAEgAIB9KCB4KSB3TCB2jEL
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
# MC8GCSqGSIb3DQEJBDEiBCCwVZpLMqUpA6qXlwl8VtFQN8gNu2Kz4MwDGy1IKhQc
# qzCB3QYLKoZIhvcNAQkQAi8xgc0wgcowgccwgaAEIGZ7KbWlzY0AQkdLdW/gAxiy
# l7PEf9Wpsv+xde8uw+EKMHwwZaRjMGExCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJsaWMg
# UlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASv24VcdiqsmJAAAAAABKMCIE
# IHXYk57rB7q2Y+7EDRP0629SC2kPOkozPiK7fn9sLMV5MA0GCSqGSIb3DQEBCwUA
# BIICACr+pI05JR9y1ZUCe86r6cZDSeQryuAlKYe2AJA+K9kfc+wEWhq/mk1dcmAP
# k1nxOa1LokVJmnKWK5qe/SUtUWmW04vCFxwPFCKUonASAjwr8pHZrXJSN3zl9QEM
# 1ilr6DGolgFbf9qDUq5RWH6MnxmtaA7XFerFe3+fefjVCUe1RwXvmsvwByCf4kXa
# QYac+dCBBRSzSk1bGr1M/46K5853WAWVdYQPYzXO/6ixvDCGWlVrYJfQ5egfj3l2
# CdsMyyvXtyMABjNB08vF9HF1F1VsIVVqlEoY4NDruqmfqC++g8mKp2A+TpS7HNm7
# wHpGGSo6AaMotdB5loLgcu9OS+rov+X9adEv0wxsHhZr2YXjHAsgL7lG6vFaiERn
# E0iHCQn62hYEi1QVK+gyXq6w3Rqbi3EYJLMakKaMRt+OR5xsrgAJcyDtb8ItPMna
# w8R5Y5ai1UnAXJc3jfdHILouHsWh13hfCSmTSrTbVBxJoVrVmFnGjGC2nTJXddRP
# hI+uFjHm7EeW/Vym4a5P0apB6uaFSKcHwZ6KACc24/s2JIM19NbdMmi028DSV3EN
# ZNxEjiK+qfwCgTAi0wXBL0Z0g/Z4Q7bOBhSjlPz4g7o3LwKok4nSeWjZktZjQ23n
# el9ZJFFG4rpEPstm/5OqvDF/8BRwD0KYMzcxN3aAcXISCm9b
# SIG # End signature block
