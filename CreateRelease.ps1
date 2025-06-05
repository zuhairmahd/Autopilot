[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [string]$outputFile = '',
    [string]$Version = '',
    [string]$CompanyName = 'Zuhair Mahmoud',
    [switch]$MergeOnly,
    [switch]$Overwrite
)

#region import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -ErrorAction Stop
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

#region helper functions
function SignScripts()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Path,
        [string]$exclusions = ''
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Got $($Path.Count) folders to sign."
    $success = $false
    $filesToSign = @()
    foreach ($folder in $Path)
    {
        $files = Get-ChildItem -Path $path -Filter *.exe
        Write-Verbose "[$functionName] Signing $($files.count) files in $folder and excluding $($exclusions.Count) files."
        if ($files.Count -gt 0)
        {
            Write-Host "Found $($files.Count) executable files in $Path"
            foreach ($file in $files)
            {
                Write-Verbose "[$functionName] Processing file: $file"
                if ($file.BaseName -in $exclusions)
                {
                    Write-Verbose "[$functionName] Skipping $($file.BaseName) because it is in the exclusions list"
                    continue
                }
                #Check if the file is already signed
                $signature = Get-AuthenticodeSignature -FilePath $file.FullName -ErrorAction SilentlyContinue
                Write-Verbose "[$functionName] The signature status is $($signature.Status)"
                if ($signature.Status -ne 'Valid')
                {
                    Write-Verbose "[$functionName] $($file.FullName) is not signed."
                    Write-Verbose "[$functionName] Adding the file to the list of files to sign."
                    $filesToSign += $file.FullName
                }
                else
                {
                    Write-Verbose "[$functionName] $($file.FullName) is already signed."
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
        Write-Verbose "[$functionName] Signing $($filesToSign.Count) files..."
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
        Write-Verbose "[$functionName] Signing $($filesToSign.count) files."
        try
        {
            Invoke-TrustedSigning @params
            Write-Verbose "[$functionName] Signing process complete."
            $success = $true
        }
        catch
        {
            $success = $false
            Write-Host "An error occurred during the signing process."
            Write-Error $_
        }
    }
    else
    {
        Write-Host "No files to sign."
        $success = $true
    }
    return $success
}

function CopyFiles()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $functionName = $MyInvocation.MyCommand.Name
    $success = $false
    Write-Host "Copying $($source.count) files to $Destination"
    foreach ($file in $Source)
    {
        #Check if any of the source file is in a subfolder, if so, append the subfolder to the destination and create it if needed.
        $subfolder = Split-Path -Parent $file
        if ($subfolder -ne $file)
        {
            $subfolder = Split-Path -Parent $file
            $destinationFolder = Join-Path -Path $Destination -ChildPath $subfolder
            if (-not (Test-Path -Path $destinationFolder))
            {
                Write-Host "Creating folder: $destinationFolder"
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
            }
            $Destination = Join-Path -Path $Destination -ChildPath $subfolder
        }
        else
        {
            Write-Host "No subfolder found for file: $file"
        }
        Write-Verbose "[$functionName] Processing file: $file"
        try
        {
            Copy-Item -Path $file -Destination $Destination -Force
            Write-Host "Copied $file to $Destination"
        }
        catch
        {
            Write-Host "Failed to copy $file to $Destination"
            Write-Error $_
        }
    }
    $success = $true
    return $success
}

function MergeFunctions()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$FilesToMerge,
        [string]$DestinationFile = "build\merged.ps1",
        [Parameter(Mandatory = $false)]
        [switch]$AddComments
    )

    $functionName = $MyInvocation.MyCommand.Name
    $success = $false
    $AddComments = $true # Set default to true for backward compatibility with PS 5.1
    Write-Verbose "[$functionName] Starting to merge functions from $(($FilesToMerge | Measure-Object).Count) files."
    $mergedContent = New-Object System.Text.StringBuilder
    # Add header to the merged content
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    [void]$mergedContent.AppendLine("#region Inlined Functions")
    [void]$mergedContent.AppendLine("# This section contains inlined functions from multiple files")
    [void]$mergedContent.AppendLine("# Generated on: $timestamp")
    [void]$mergedContent.AppendLine("# Source files:")
    foreach ($file in $FilesToMerge)
    {
        [void]$mergedContent.AppendLine("#   - $file")
    }
    [void]$mergedContent.AppendLine("")
    # Process each file
    foreach ($filePath in $FilesToMerge)
    {
        try
        {
            if (Test-Path -Path $filePath)
            {
                Write-Verbose "[$functionName] Processing file: $filePath"
                # Add file header comment if requested
                if ($AddComments)
                {
                    $fileName = Split-Path -Path $filePath -Leaf
                    [void]$mergedContent.AppendLine("")
                    [void]$mergedContent.AppendLine("#region Functions from $fileName")
                    [void]$mergedContent.AppendLine("# Source: $filePath")
                    [void]$mergedContent.AppendLine("")
                }
                # Read and append file content
                $content = Get-Content -Path $filePath -Raw
                [void]$mergedContent.AppendLine($content)
                # Add file footer comment if requested
                if ($AddComments)
                {
                    [void]$mergedContent.AppendLine("")
                    [void]$mergedContent.AppendLine("#endregion Functions from $fileName")
                }
            }
            else
            {
                $errorMsg = "File not found: $filePath"
                Write-Warning "[$functionName] $errorMsg"
                Write-Error $errorMsg
                return $false # Return false immediately if a file is missing
            }
        }
        catch
        {
            $errorMsg = "Error processing file $filePath`: $_"
            Write-Error "[$functionName] $errorMsg"
            return $false # Return false immediately if there's an error
        }
    }
    # Add footer to the merged content
    [void]$mergedContent.AppendLine("")
    [void]$mergedContent.AppendLine("#endregion Inlined Functions")
    
    try
    {
        # Ensure the destination directory exists
        $destinationDir = Split-Path -Parent $DestinationFile
        if (-not (Test-Path -Path $destinationDir))
        {
            Write-Verbose "[$functionName] Creating destination directory: $destinationDir"
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }
        
        # Save the merged content to the destination file
        Write-Verbose "[$functionName] Saving content to: $DestinationFile"
        $mergedContent.ToString() | Set-Content -Path $DestinationFile -Force
        Write-Host "Merged functions saved to: $DestinationFile"
        $success = $true
    }
    catch
    {
        $errorMsg = "Error saving to destination file $DestinationFile`: $_"
        Write-Error "[$functionName] $errorMsg"
        $success = $false
    }
    Write-Verbose "[$functionName] Returning success: $success"
    return $success
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
#endregion

#region Define variables
$initFile = "init.json"
$versionFile = 'version.txt'
$functionsToMerge = @(Get-ChildItem -Path "$pwd\functions" -Filter "*.ps1" | ForEach-Object { $_.FullName })
$filesToCopy = @('settings.json', 'version.txt', 'init.json') 
$successMessage = "$OutputFile written"
$scriptName = $MyInvocation.MyCommand.Name
$todaysDate = Get-Date -Format "yyyy-MM-dd"
Write-Host "Starting build script on $todaysDate"
if ($outputFile -eq '')
{
    Write-Verbose "[$scriptName] No output file specified. Using default output file name."
    $leafName = Split-Path -Leaf $InputFile
    Write-Verbose "[$scriptName] Leaf name is: $leafName"
    $exeName = $leafName.Replace('.ps1', '.exe')
    Write-Verbose "[$scriptName] Executable name is: $exeName"
    $outputFile = Join-Path -Path "$pwd\build" -ChildPath $exeName
    Write-Verbose "[$scriptName] Output file set to: $outputFile"
    Write-Host "No output file specified. Output file set to: $outputFile"
}
$parentFolder = Split-Path -Parent $outputFile
#endregion

#region initial checks
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

#Define the version variable.
if ($Version -eq '')
{
    Write-Host 'No version specified. Attempting to read version from input file.'
    $versionString = Select-String -Path $InputFile -Pattern '.VERSION\s*(\d+\.\d+\.\d)'
    if ($versionString -match '(\d+\.\d+\.\d+)')
    {
        $Version = $matches[1]
        Write-Host "Found version $($Version) in input file."
    }
    else
    {
        Write-Host "No version found in input file. Checking for version file $versionFile."
        if (Test-Path -Path $versionFile)
        {
            $Version = Get-Content -Path $versionFile -ErrorAction SilentlyContinue
            Write-Host "Found version $($Version) in version file."
            $versionFileFound = $true
            Write-Host "Using version $($Version) from version file."
        }
        else
        {
            Write-Host "No version specified and no version file found. Using default version 1.0.0."
            $Version = '1.0.0'
            $versionFileFound = $false
        }
    }
}
else
{
    Write-Host "Using version $($Version)"
}

#Check if the version file exists.  If not, create it.
if (-not $versionFileFound)
{
    if (-not (Test-Path -Path $versionFile))
    {
        Write-Verbose "[$scriptName] Cannot find the version file $($versionFile). Creating..."
        Set-Content -Path $versionFile -Value $Version -Force -ErrorAction SilentlyContinue
        Write-Host 'Version file created successfully.'
    }
    else
    {
        Write-Host "Found version file $($versionFile)..."
        $VersionFileContent = Get-Content -Path $versionFile -ErrorAction SilentlyContinue
        $VersionFileContentObject = [System.Version]::Parse($VersionFileContent)
        Write-Verbose "[$scriptName] Local version object: $VersionFileContentObject"
        $versionObject = [System.Version]::Parse($Version)
        Write-Verbose "[$scriptName] Version object: $versionObject"
        if ($VersionFileContentObject -lt $versionObject)
        {
            Write-Host "Version file content is less than the specified version. Updating file..."
            Set-Content -Path $versionFile -Value $Version -Force -ErrorAction SilentlyContinue
            Write-Host 'Version file updated successfully.'
        }
        elseif ($VersionFileContentObject -gt $versionObject)
        {
            Write-Host "Version file content is greater than the specified version. Updating the local variable."
            $Version = $VersionFileContentObject.ToString()
            Write-Verbose "[$scriptName] Version updated to: $Version"
        }
        else
        {
            Write-Host "Version file content matches the specified version."
        }
    }
}

if (-not $Overwrite)
{
    if (Test-Path -Path $parentFolder)
    {
        Write-Host "Destination folder $parentFolder already exists."
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
                Write-Host "Removing $parentFolder"
                Remove-Item -Path $parentFolder -Recurse -Force | Out-Null
                Write-Host "Creating folder $parentFolder"
                New-Item -Path $parentFolder -ItemType Directory -Force | Out-Null
                Write-Verbose 'Creating functions folder'
                New-Item -Path "$parentFolder\functions" -ItemType Directory -Force | Out-Null
                Write-Host 'Creating secrets folder.'
                New-Item -Path "$parentFolder\.secrets" -ItemType Directory -Force | Out-Null
            }
            C
            {
                Write-Host 'Continuing with the existing folder.'
                #Check to make sure all subfolders exist.
                if (-not (Test-Path -Path "$parentFolder\functions"))
                {
                    Write-Host 'Creating functions folder'
                    New-Item -Path "$parentFolder\functions" -ItemType Directory -Force | Out-Null
                }
                if (-not (Test-Path -Path "$parentFolder\.secrets"))
                {
                    Write-Host 'Creating secrets folder'
                    New-Item -Path "$parentFolder\.secrets" -ItemType Directory -Force | Out-Null
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
        Write-Host "Creating folder $parentFolder"
        New-Item -Path $parentFolder -ItemType Directory -Force | Out-Null
        Write-Verbose 'Creating functions folder'
        New-Item -Path "$parentFolder\functions" -ItemType Directory -Force | Out-Null
        Write-Verbose 'Creating secrets folder'
        New-Item -Path "$parentFolder\.secrets" -ItemType Directory -Force | Out-Null
    }
}
else
{
    Write-Host "Overwriting $parentFolder"
    if (Test-Path -Path $parentFolder)
    {
        Write-Host "Removing $parentFolder"
        Remove-Item -Path $parentFolder -Recurse -Force | Out-Null
    }
    else
    {
        Write-Host "Creating folder $parentFolder"
    }
    New-Item -Path $parentFolder -ItemType Directory -Force | Out-Null
}
#endregion

#region Merge functions
$mergeOutputFile = Join-Path -Path "$pwd\build" -ChildPath 'merged.ps1'
$mergeParentFolder = Split-Path -Parent $mergeOutputFile
# Ensure destination directory exists
if (-not (Test-Path -Path $mergeParentFolder))
{
    Write-Verbose "[$scriptName] Creating parent folder: $mergeParentFolder"
    New-Item -ItemType Directory -Path $mergeParentFolder -Force | Out-Null
}
if ($InputFile -ne $outputFile)
{
    Write-Verbose "[$scriptName] Copying input file to parent folder: $mergeParentFolder"
    $newscriptFile = "$mergeParentFolder\$($InputFile.Split('\')[-1])"
    Write-Verbose "[$scriptName] New script file path: $newscriptFile"
    Copy-Item -Path $InputFile -Destination $mergeParentFolder -Force
}
Write-Verbose "[$scriptName] Calling MergeFunctions with destination: $mergeOutputFile"
Write-Host "Merging sourced functions in $inputFile to $mergeOutputFile"
$mergeResult = MergeFunctions -FilesToMerge $functionsToMerge -DestinationFile $mergeOutputFile
Write-Verbose "[$scriptName] MergeFunctions returned: $mergeResult"
if ($mergeResult -eq $true)
{
    Write-Host "Functions merged successfully to $mergeOutputFile"
    Write-Host "Creating master script at $newscriptFile"
    #read the newscript into a variable.
    Write-Verbose "[$scriptName] Reading new script content into variable."
    $newscriptContent = Get-Content -Path $newscriptFile -Raw
    Write-Verbose "[$scriptName] New script content read successfully."        #read the merged script into a variable.
    Write-Verbose "[$scriptName] Reading merged script content into variable."
    $mergedContent = Get-Content -Path $mergeOutputFile -Raw
    Write-Verbose "[$scriptName] Merged script content read from: $mergeOutputFile"
    # Find the positions of the region markers
    Write-Verbose "[$scriptName] Finding region markers in the script."
    $startMarker = "#region import functions."
    $endMarker = "#endregion import functions."
    $startPosition = $newscriptContent.IndexOf($startMarker)
    $endPosition = $newscriptContent.IndexOf($endMarker, $startPosition)
    if ($startPosition -ge 0 -and $endPosition -gt $startPosition)
    {
        Write-Verbose "[$scriptName] Found start marker at position $startPosition and end marker at position $endPosition."
        # Extract portions before, between, and after markers
        $beforeRegion = $newscriptContent.Substring(0, $startPosition + $startMarker.Length)
        $afterRegion = $newscriptContent.Substring($endPosition)
        # Construct the new content by concatenating the parts with the merged content
        $newscriptContent = $beforeRegion + "`r`n" + $mergedContent + "`r`n" + $afterRegion
        Write-Verbose "[$scriptName] Replaced content between import functions markers."
    }
    else
    {
        Write-Warning "[$scriptName] Could not find region markers in the script. Script will not be modified."
    }
    #write the newscriptContent to the newscriptFile
    Write-Verbose "[$scriptName] Writing new script content to: $newscriptFile"
    try
    {
        $newscriptContent | Set-Content -Path $newscriptFile -Force
        Write-Verbose "[$scriptName] New script content written successfully."
        Write-Host "New script content written to $newscriptFile"
    }
    catch
    {
        Write-Host "Failed to write new script content to $newscriptFile"
        Write-Error $_
        exit 1
    }
}
else
{
    Write-Host "Failed to merge functions to $OutputFile"
    exit 1
}
#endregion

if (Test-Path $outputFile)
{
    Write-Host "The output file $outputFile already exists. Do you want to replace it? (Y/N)"
    $response = Read-Host
    while ($response -ne 'Y' -and $response -ne 'N')
    {
        Write-Host "Invalid response. Please enter Y or N."
        [console]::beep(1000, 500)
        $response = Read-Host
    }
    if ($response -ne 'Y')
    {
        Write-Host "Exiting script."
        exit 0
    }
    else
    {
        Write-Host "Replacing $outputFile"
    }
}

Write-Host "Building executable from $newscriptFile to $OutputFile"
$result = Invoke-ps2exe -inputFile $newscriptFile -outputFile $OutputFile -x64 -version $Version -title "Intune Registration" -description "Register devices in Intune and perform other Autopilot device functions" -company $CompanyName -product "Intune Autopilot Registration" -copyright '2025'
if ($result -match $successMessage)
{
    Write-Host "Executable created successfully: $OutputFile"
}
else
{
    Write-Host "Failed to create executable: $OutputFile"
    exit 1
}

Write-Host "Signing executable at $OutputFile"
if (SignScripts -path "$pwd\build")
{
    Write-Host "Executable signed successfully: $OutputFile"
}
else
{
    Write-Host "Failed to sign executable: $OutputFile"
    exit 1
}

if (CopyFiles -Source $filesToCopy -Destination $parentFolder)
{
    Write-Host "Files copied successfully to $parentFolder"
}
else
{
    Write-Host "Failed to copy files to $parentFolder"
    exit 1
}

Write-Verbose 'Checking if the secrets folder exists.'
if (Test-Path -Path "parentFolder\.secrets\config.json")
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
            if (CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $parentFolder)
            {
                Write-Host 'Secrets copied successfully.'
            }
            else
            {
                Write-Host 'Failed to copy secrets.'
                Write-Host 'Run the script with the -Verbose switch for more information.'
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
    if (CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $parentFolder)
    {
        Write-Host 'Secrets copied successfully.'
    }
    else
    {
        Write-Host 'Failed to copy secrets.'
        Write-Host 'Run the script with the -Verbose switch for more information.'
    }
}

Write-Host "Cleaning up..."
if (Test-Path -Path $mergeOutputFile)
{
    Write-Host "Removing $mergeOutputFile"
    Remove-Item -Path $mergeOutputFile -Force | Out-Null
}
if (Test-Path -Path $newscriptFile)
{
    Write-Host "Removing $newscriptFile"
    Remove-Item -Path $newscriptFile -Force | Out-Null
}

Write-Host "Build process completed successfully."
Write-Host "Executable and files are located in $parentFolder"