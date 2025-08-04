[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [Parameter(Mandatory = $false)]
    [string]$Version,
    [string]$outputFile = '',
    [string]$SettingsFile = "$pwd\settings.json",
    [string]$CompanyName = 'Zuhair Mahmoud',
    [string]$Author = 'Zuhair Mahmoud',
    [switch]$CreateModule,
    [switch]$noCleanup,
    [switch]$Overwrite,
    [switch]$NoVersionUpdate,
    [Parameter(Mandatory = $false, ParameterSetName = 'SecretsOnly')]
    [switch]$SecretsOnly,
    [Parameter(Mandatory = $false, ParameterSetName = 'SecretsOnly')]
    [switch]$UpdateSettings
)

$scriptName = $MyInvocation.MyCommand.Name
$logFile = "$pwd\logs\createRelease.log"

#region import functions.
$functionsFolder = "$PWD\functions"
if (Test-Path $functionsFolder)
{
    Write-Verbose "[$scriptName] Importing functions from $functionsFolder"
    $functions = Get-ChildItem -Path $functionsFolder -Filter '*.ps1' -Recurse -ErrorAction Stop
    foreach ($function in $functions)
    {
        Write-Verbose " [$scriptName] Importing function $function"
        . $function.FullName
    }
}
else
{
    Write-Host 'Cannot find the functions folder. Exiting script.' -ForegroundColor Red
    exit 1
}
#endregion import functions.

Write-Log -logFile $logFile -startLogging

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
        $files = Get-ChildItem -Path $folder -Filter *.exe
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
            Write-Host "No executable files found in $Path"
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
            $currentDestination = Join-Path -Path $Destination -ChildPath $subfolder
        }
        else
        {
            Write-Host "No subfolder found for file: $file"
            $currentDestination = $Destination
        }
        Write-Verbose "[$functionName] Processing file: $file"
        try
        {
            Copy-Item -Path $file -Destination $currentDestination -Force
            Write-Host "Copied $file to $currentDestination"
        }
        catch
        {
            Write-Host "Failed to copy $file to $currentDestination"
            Write-Error $_
        }
    }
    $success = $true
    return $success
}

function IncrementLastrunVersion()
{
    param (
        [string]$Version,
        [string]$LastRunFile
    )

    function IncrementRevision()
    {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Version,
            [Parameter(Mandatory = $false)]
            [int]$IncrementBy = 1
        )

        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Incrementing revision for version: $Version by $IncrementBy"
    
        try
        {
            $versionObj = [System.Version]::Parse($Version)
            $newRevision = $versionObj.Revision + $IncrementBy
            $newVersion = New-Object System.Version($versionObj.Major, $versionObj.Minor, $versionObj.Build, $newRevision)
            Write-Verbose "[$functionName] New version: $newVersion"
            return $newVersion.ToString()
        }
        catch
        {
            Write-Error "Failed to increment revision: $_"
            return $null
        }
    }
    
    $functionName = $MyInvocation.MyCommand.Name
    $updatedVersion = $Version
    if (Test-Path -Path $LastRunFile)
    {
        Write-Verbose "[$functionName] Last run file found: $lastRunFile"
        $lastRun = Get-Content -Path $lastRunFile -Raw | ConvertFrom-Json
    }
    else
    {
        Write-Verbose "[$functionName] Last run file not found: $lastRunFile"
        $lastRun = @{}
    }
    Write-Host "Last run date: $($lastRun.date)"
    Write-Host "Last run version: $($lastRun.version)"
    Write-Host "GUID: $($lastRun.guid)"
    if ([string]::IsNullOrWhiteSpace($updatedVersion) -and [string]::IsNullOrWhiteSpace($lastRun.Version))
    {
        Write-Host "What version number would you like to use for this build?"
        Write-Host "Enter version number using the format major.minor.build.revision (e.g., 1.0.0.0)"
        $updatedVersion = Read-Host "Enter version number"
        while ($updatedVersion -notmatch '^\d+\.\d+\.\d+\.\d+$')
        {
            Write-Host "Invalid version format. Please use the format xx.yy.zz"
            [console]::beep(1000, 500)
            $updatedVersion = Read-Host "Enter a valid version number"
        }
        $maintainCurrentVersion = $true
    }
    elseif (-not ([string]::IsNullOrWhiteSpace($updatedVersion)) -and -not ([string]::IsNullOrWhiteSpace($lastRun.Version)))
    {
        Write-Host "Supplied version: $updatedVersion"
        Write-Host "Last run version: $($lastRun.version)"
        Write-Host "Which version would you like to use? (S for supplied, L for last run)"
        $response = Read-Host "Enter S for supplied version, L for last run version, or E to exit"
        while ($response -notin 'S', 'L', 'E')
        {
            Write-Host "Invalid response. Please enter S, L, or E."
            [console]::beep(1000, 500)
            $response = Read-Host "Enter S for supplied version, L for last run version, or E to exit"
        }   
        switch ($response)
        {
            S
            {
                Write-Host "Using supplied version: $updatedVersion"
                $maintainCurrentVersion = $true
            }
            L
            {
                Write-Host "Using last run version: $($lastRun.version)"
                $updatedVersion = $lastRun.version
            }
            E
            {
                Write-Host "Exiting script."
                exit 0
            }
        }
    }
    elseif (-not ([string]::IsNullOrWhiteSpace($lastRun.Version)) -and [string]::IsNullOrWhiteSpace($updatedVersion))
    {
        Write-Host "No version supplied. Using last run version: $($lastRun.version)"
        $updatedVersion = $lastRun.version
    }
    else
    {
        Write-Host "Using supplied version: $updatedVersion"
        $maintainCurrentVersion = $true
    } 
    Write-Host "Current version: $updatedVersion"
    Write-Host "Maintain current version: $maintainCurrentVersion"
    Write-Verbose "[$functionName] No version update: $NoVersionUpdate"
    if ($maintainCurrentVersion -or $NoVersionUpdate)
    {
        Write-Host "Maintaining current version: $updatedVersion"
    }
    else
    {
        Write-Host "Incrementing revision number for version: $updatedVersion"
        $updatedVersion = IncrementRevision -Version $updatedVersion
        Write-Host "New version: $updatedVersion"
    }
    return $updatedVersion
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
    $mergedContent = New-Object System.Text.StringBuilder
    Write-Verbose "[$functionName] Starting to merge functions from $(($FilesToMerge | Measure-Object).Count) files."
    # Add header to the merged content
    if ($AddComments )
    {
        Write-Verbose "[$functionName] Comments will be added to the merged content."
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
    }
    else
    {
        Write-Verbose "[$functionName] No comments will be added to the merged content."
    }
    
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
    if ($AddComments )
    {
        Write-Verbose "[$functionName] Adding footer comments to the merged content."
        [void]$mergedContent.AppendLine("")
        [void]$mergedContent.AppendLine("#endregion Inlined Functions")
    }
    else
    {
        Write-Verbose "[$functionName] No footer comments will be added to the merged content."
    }
    
    #Check if we are given a destination file with a path
    if ([System.IO.Path]::IsPathRooted($DestinationFile))
    {
        Write-Verbose "[$functionName] Destination file contains a path: $DestinationFile"
        $destinationDir = Split-Path -Parent $DestinationFile    
    }
    else
    {
        Write-Verbose "[$functionName] Destination file does not contain a path, using current directory: $pwd"
        $destinationDir = $pwd
    }
    
    # Ensure the destination directory exists
    if (-not (Test-Path -Path $destinationDir))
    {
        Write-Verbose "[$functionName] Creating destination directory: $destinationDir"
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    
    try
    {
        # Save the merged content to the destination file
        Write-Verbose "[$functionName] Saving content to: $DestinationFile"
        $mergedContent.ToString() | Set-Content -Path $DestinationFile -Force
        Write-Verbose "Merged functions saved to: $DestinationFile"
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

function EncryptSecretsFile()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string]$EncryptionKey
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Encrypting secrets file: $FilePath"
    #if the encryption key is a null or a whitespace, create a random key using guid
    if ([string]::IsNullOrWhiteSpace($EncryptionKey))
    {
        Write-Verbose "[$functionName] No encryption key provided. Generating a random key."
        Write-Log -logFile $logFile -Message "No encryption key provided. Generating a random key." -module $functionName
        $EncryptionKey = [guid]::NewGuid().ToString()
    }
    if ((Invoke-JsonFileEncryption -FilePath $FilePath -Key $EncryptionKey).success)  
    {
        Write-Host "Secrets file encrypted successfully."
        Write-Log -logFile $logFile -Message "Secrets file encrypted successfully." -module $functionName
        return $true
    }
    else
    {
        Write-Error "Failed to encrypt secrets file."
        Write-Log -logFile $logFile -Message "Failed to encrypt secrets file." -module $functionName -LogLevel 'Error'
        return $false
    }
}

function CopySecrets()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder,
        [switch]$Overwrite
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] [$functionName] Starting to copy secrets from $SourceFolder to $DestinationFolder"
    Write-Log -logFile $logFile -Message "Starting to copy secrets from $SourceFolder to $DestinationFolder" -module $functionName
    #region Print logs
    Write-Verbose "[$functionName] Received the following parameters:"
    Write-Log -logFile $logFile -Message "Received the following parameters:" -module $functionName
    Write-Verbose "[$functionName] SourceFolder: $SourceFolder"
    Write-Log -logFile $logFile -Message "SourceFolder: $SourceFolder" -module $functionName
    Write-Verbose "[$functionName] DestinationFolder: $DestinationFolder"
    Write-Log -logFile $logFile -Message "DestinationFolder: $DestinationFolder" -module $functionName
    Write-Verbose "[$functionName] Overwrite: $Overwrite"
    Write-Log -logFile $logFile -Message "Overwrite: $Overwrite" -module $functionName
    #endregion
    
    if (Test-Path -Path "$DestinationFolder\.secrets")
    {
        Write-Host "the folder $DestinationFolder\.secrets already exists."
        Write-Log -logFile $logFile -Message "The folder $DestinationFolder\.secrets already exists." -module $functionName
        if ($Overwrite)
        {
            Write-Host 'Removing .secrets folder...'
            Write-Log -logFile $logFile -Message "Overwrite is set to true. Removing .secrets folder." -module $functionName
            Remove-Item -Path "$DestinationFolder\.secrets" -Recurse -Force | Out-Null
        }
        else 
        {
            Write-Log -logFile $logFile -Message "The folder $DestinationFolder\.secrets already exists. Getting user input." -module $functionName
            $response = Read-Host 'Overwrite? (Y/N)'
            Write-Verbose "[$functionName] User response: $response"
            Write-Log -logFile $logFile -Message "User response: $response" -module $functionName
            while ($response -notin 'Y', 'N', 'yes', 'no')
            {
                $response = Read-Host 'Invalid input. Please enter Y or N: '
                
                Write-Verbose "[$functionName] User response: $response"
                Write-Log -logFile $logFile -Message "User response: $response" -module $functionName
                [console]::beep(500, 300)
            }
            if ($response -eq 'Y' -or $response -eq 'yes')
            {
                Write-Host 'Removing .secrets folder...'
                Write-Log -logFile $logFile -Message "User chose to overwrite. Removing .secrets folder." -module $functionName
                Remove-Item -Path "$DestinationFolder\.secrets" -Recurse -Force | Out-Null
            }
            else
            {
                Write-Host 'Exiting without copying secrets.'
                Write-Log -logFile $logFile -Message "User chose not to overwrite. Exiting without copying secrets." -module $functionName
                return $false
            }   
        }
    }
    else
    {
        Write-Host "Creating .secrets folder in: $DestinationFolder"
        Write-Log -logFile $logFile -Message "Creating .secrets folder in: $DestinationFolder" -module $functionName
        New-Item -ItemType Directory -Path "$DestinationFolder\.secrets" -Force | Out-Null
    }
    
    Write-Host 'Looking for secrets...'
    Write-Log -logFile $logFile -Message "Looking for secrets in $SourceFolder\.secrets" -module $functionName  
    $secrets = Get-ChildItem -Path "$SourceFolder\.secrets" -Filter config*.json -Recurse
    if ($secrets.Count -eq 0)
    {
        Write-Host 'No secrets found.'
        Write-Log -logFile $logFile -Message "No secrets found in $SourceFolder\.secrets" -module $functionName
        return $false
    }
    
    if (-not $Overwrite)
    {
        Write-Host 'Please choose the secret you would like to copy to the release folder.'
        Write-Log -logFile $logFile -Message "User is prompted to choose a secret to copy." -module $functionName
        for ($i = 0; $i -lt $secrets.Count; $i++)
        {
            $fileName = $secrets[$i].Name
            Write-Log -logFile $logFile -Message "Found secret: $fileName" -module $functionName
            $encrypted = Test-FileEncryptionStatus -filePath $secrets[$i].FullName
            Write-Verbose "[$functionName] $fileName is encrypted: $($encrypted.IsEncrypted)"
            Write-Log -logFile $logFile -Message "Secret $fileName is encrypted: $($encrypted.IsEncrypted)" -module $functionName
            Write-Verbose "[$functionName] $fileName is valid: $($encrypted.IsValid)"
            Write-Log -logFile $logFile -Message "Secret $fileName is valid: $($encrypted.IsValid)" -module $functionName
            Write-Verbose "[$functionName] error message: $($encrypted.ErrorMessage)"
            Write-Log -logFile $logFile -Message "Secret $fileName error message: $($encrypted.ErrorMessage)" -module $functionName
            $index = $i + 1
            if ($encrypted.IsEncrypted)
            {
                Write-Host "$index. Encrypted file: ($fileName)"
                Write-Log -logFile $logFile -Message "Secret $fileName is encrypted." -module $functionName
                Write-Verbose "[$functionName] Secret $fileName is encrypted."
            }
            else 
            {
                $data = Get-Content -Path $secrets[$i].FullName | ConvertFrom-Json
                $name = $data.name
                $domain = $data.domain
                if (-not $domain)
                {
                    $domain = 'Unknown'
                    Write-Log -logFile $logFile -Message "Secret $fileName has unknown domain." -module $functionName
                }
                if (-not $name)
                {
                    $name = 'Unknown'
                    Write-Log -logFile $logFile -Message "Secret $fileName has unknown name." -module $functionName
                }
                Write-Host "$index. $($name): $domain ($fileName)"
            }
        }
        $choice = $null
        while ($true)
        {
            $inputValue = Read-Host 'Enter the number of the secret you would like to copy. (0 to quit)'
            if ([int]::TryParse($inputValue, [ref]$null))
            {
                $choiceInt = 0
                [void][int]::TryParse($inputValue, [ref]$choiceInt)
                if ($choiceInt -ge 0 -and $choiceInt -le $secrets.Count)
                {
                    $choice = $choiceInt
                    break
                }
                else
                {
                    Write-Host "Sorry: $inputValue is an invalid choice."
                    Write-Log -logFile $logFile -Message "User entered an invalid choice: $inputValue" -module $functionName
                    [console]::beep(500, 300)
                    Write-Host "Please choose a number between 1 and $($secrets.Count), or 0 to exit."
                }
            }
            else
            {
                Write-Host "Invalid input. Please enter a number between 1 and $($secrets.Count), or 0 to exit."
                Write-Log -logFile $logFile -Message "User entered a non-integer input: $inputValue" -module $functionName
                [console]::beep(1000, 300)
            }
        }
        Write-Verbose "[$functionName] User selected: $choice"
        Write-Log -logFile $logFile -Message "User selected: $choice" -module $functionName
        if ($choice -eq 0)
        {
            Write-Log -logFile $logFile -Message "User chose to cancel. Exiting without copying secrets." -module $functionName
            return $false
        }
        $secret = $secrets[$choice - 1]
        Write-Log -logFile $logFile -Message "User selected secret: $($secret.Name)" -module $functionName
    }
    else
    {
        Write-Log -logFile $logFile -Message "Copying default secret in $SourceFolder\.secrets" -module $functionName
        $secret = Get-ChildItem -Path "$SourceFolder\.secrets" -Filter config*.json -Recurse | Where-Object { $_.Name -eq 'config.json' }
        Write-Host "Using default secrets file: $($secret.Name)"
        Write-Log -logFile $logFile -Message "Using default secrets file: $($secret.Name)" -module $functionName    
    }
    Write-Verbose "[$functionName] Selected secret: $($secret.Name)"
    Write-Log -logFile $logFile -Message "Selected secret: $($secret.Name)" -module $functionName
    Write-Host "Copying $($secret.FullName) to $DestinationFolder"
    Write-Log -logFile $logFile -Message "Copying $($secret.FullName) to $DestinationFolder\.secrets" -module $functionName 
    try
    {
        Write-Host "Copying $($secret.FullName) to $DestinationFolder\.secrets"
        Write-Log -logFile $logFile -Message "Copying $($secret.FullName) to $DestinationFolder\.secrets" -module $functionName
        if (-not (Test-Path -Path "$DestinationFolder\.secrets"))
        {
            Write-Host "Creating .secrets folder in: $DestinationFolder"
            Write-Log -logFile $logFile -Message "Creating .secrets folder in: $DestinationFolder" -module $functionName
            New-Item -ItemType Directory -Path "$DestinationFolder\.secrets" -Force | Out-Null
        }
        Copy-Item -Path $secret.FullName -Destination "$DestinationFolder\.secrets\config.json" -Force
        Write-Host "Secrets copied successfully to $DestinationFolder\.secrets\config.json"
        Write-Verbose "[$functionName] Secrets copied successfully."
        Write-Log -logFile $logFile -Message "Secrets copied successfully to $DestinationFolder\.secrets\config.json" -module $functionName
        Write-Verbose "[$functionName] Checking file encryption status."
        $destStatus = Test-FileEncryptionStatus -FilePath "$DestinationFolder\.secrets\config.json"
        if ($destStatus.IsEncrypted)
        {
            Write-Host "File is already encrypted"
            Write-Log -logFile $logFile -Message "File is already encrypted: $($secret.Name)" -module $functionName
        }
        else
        {
            $tempEncryptionKey = 'P@ssw0rd'
            if (EncryptSecretsFile -FilePath "$DestinationFolder\.secrets\config.json" -EncryptionKey $tempEncryptionKey)
            {
                Write-Host "File encryption successful"
                Write-Host "File encrypted with temporary key: $tempEncryptionKey"
                Write-Log -logFile $logFile -Message "File encryption successful: $($secret.Name)" -module $functionName
            }
            else
            {
                Write-Host "File encryption failed"
                Write-Log -logFile $logFile -Message "File encryption failed: $($secret.Name)" -module $functionName -LogLevel 'Error'
                return $false
            }
        }
    }
    catch
    {
        Write-Error "Failed to copy $($secret.FullName) to $DestinationFolder\.secrets"
        Write-Error $_.Exception.Message
        Write-Log -logFile $logFile -Message "Failed to copy $($secret.FullName) to $DestinationFolder\.secrets" -module $functionName -LogLevel 'Error'
        return $false
    }
    return $true
}

function UpdateSettingsFile()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsFilePath
    )
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating settings file at: $SettingsFilePath"
    Write-Log -LogFile $LogFile -Module $functionName -Message "Updating settings file at: $SettingsFilePath" -LogLevel "Information"
    if (Test-Path $SettingsFilePath)
    {
        try
        {
            Write-Verbose "[$functionName] Reading settings file content."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Reading settings file content." -LogLevel "Information"
            $settingsContent = Get-Content -Path $SettingsFile -Raw -Encoding UTF8
            $settings = ConvertFrom-Json $settingsContent
            # Update the changePWOnNextStart setting
            Write-Verbose "[$functionName] Checking for changePWOnNextStart setting."
            Write-Log -LogFile $LogFile -Module $functionName -Message "Checking for changePWOnNextStart setting." -LogLevel "Information"
            if ($settings.auth -and $settings.auth.PSObject.Properties.Name -contains 'changePWOnNextStart')
            {
                Write-Verbose "[$functionName] changePWOnNextStart setting found. Setting it to true."
                Write-Log -LogFile $LogFile -Module $functionName -Message "changePWOnNextStart setting found. Setting it to true." -LogLevel "Information"
                if ($settings.auth.changePWOnNextStart -eq $true)
                {
                    Write-Host "changePWOnNextStart is already set to true. No changes made."
                    Write-Log -LogFile $LogFile -Module $functionName -Message "changePWOnNextStart is already set to true. No changes made." -LogLevel "Information"
                    return $true
                }
                $settings.auth.changePWOnNextStart = $true
                # Write updated settings back to file
                Write-Verbose "[$functionName] Writing updated settings back to file."
                Write-Log -LogFile $LogFile -Module $functionName -Message "Writing updated settings back to file." -LogLevel "Information"
                $updatedSettingsJson = ConvertTo-Json $settings -Depth 100
                try
                {
                    Set-Content -Path $SettingsFilePath -Value $updatedSettingsJson -Encoding UTF8    
                    Write-Host "Settings updated successfully" -ForegroundColor Green
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Settings.json updated successfully - changePWOnNextStart set to true" -LogLevel "Information"
                }
                catch
                {
                    Write-Error "Failed to write updated settings to $SettingsFilePath"
                    Write-Error $_.Exception.Message
                    Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to write updated settings to $SettingsFilePath" -LogLevel 'Error'
                    return $false
                }
            }                
            else
            {
                Write-Warning "changePWOnNextStart setting not found in auth section"
                Write-Log -LogFile $LogFile -Module $functionName -Message "changePWOnNextStart setting not found in auth section" -LogLevel "Warning"
            }
        }
        catch
        {
            Write-Host "Failed to update settings file: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -LogFile $LogFile -Module $functionName -Message "Failed to update settings file: $($_.Exception.Message)" -LogLevel "Error"
            return $false
        }
    }
    else
    {
        Write-Warning "Settings file not found: $SettingsFile"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Settings file not found: $SettingsFile" -LogLevel "Warning"
    }
}
#endregion helper functions

#region Define variables
$initFile = "init.json"
$lastRunFile = "$pwd\lastrun.json"
$lastRun = Get-Content -Path $lastRunFile | ConvertFrom-Json
$maintainCurrentVersion = $false
$SettingsFile = "$pwd\settings.json"
$functionsToMerge = @(Get-ChildItem -Path "$pwd\functions" -Recurse -Filter "*.ps1" | ForEach-Object { $_.FullName })
$filesToCopy = @('settings.json', 'strings.json', 'init.json') 
$settingsVersion = (Get-Content -Path "$pwd\settings.json" | ConvertFrom-Json).version
$stringsVersion = (Get-Content -Path "$pwd\strings.json" | ConvertFrom-Json).version
$successMessage = "$OutputFile written"
$todaysDate = Get-Date -Format "yyyy-MM-dd"
$helperModuleName = "HelperModule.psm1"
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
$destSettingsFile = "$parentFolder\settings.json"
#endregion

#region initial checks
if ($CreateModule)
{
    Write-Host "Creating module $helperModuleName."
    $mergeResult = MergeFunctions -FilesToMerge $functionsToMerge -DestinationFile $helperModuleName
    if ($mergeResult -eq $true)
    {
        Write-Host "Module $helperModuleName created successfully."
    }
    else
    {
        Write-Host "Failed to create module: $helperModuleName."
        exit 1
    }
}

if ($SecretsOnly)
{
    Write-Host "Running in SecretsOnly mode. Copying secrets to $parentFolder\.secrets"
    if ($UpdateSettings)
    {
        Write-Verbose "[$scriptName] Updating settings file to force password change."
        Write-Log -logFile $logFile -Message "Updating settings file to force password  change." -module $scriptName
        $settingsUpdate = $true
    }
    else
    {
        Write-Verbose "[$scriptName] Skipping settings file update."
        Write-Log -logFile $logFile -Message "Skipping settings file update." -module $scriptName
        $settingsUpdate = $false
    }
    Write-Log -logFile $logFile -Message "Running in SecretsOnly mode. Copying secrets to $parentFolder\.secrets" -module $scriptName
    if ($Overwrite)
    {
        $secretsCopied = CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $parentFolder -Overwrite
    }
    else
    {
        $secretsCopied = CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $parentFolder
    }
    if ($secretsCopied)
    {
        Write-Host "Secrets copied successfully to $parentFolder\.secrets"
        Write-Log -logFile $logFile -Message "Secrets copied successfully to $parentFolder\.secrets" -module $scriptName
    }
    else
    {
        Write-Host "No secrets were copied."
    }
    Write-Host "Checking whether to update settings file to force password change."
    if ($settingsUpdate -eq $true)
    {
        Write-Log -logFile $logFile -Message "Updating settings file to force password change." -module $scriptName
        Write-Verbose "[$scriptName] Updating settings file to force password change."
        if (-not (Test-Path -Path $destSettingsFile))
        {
            Write-Host "Settings file not found at $destSettingsFile. Copying from $SettingsFile."
            Write-Log -logFile $logFile -Message "Settings file not found at $destSettingsFile. Copying from $SettingsFile." -module $scriptName
            Copy-Item -Path $SettingsFile -Destination $destSettingsFile -Force
        }
        else
        {
            Write-Host "Found settings file at $destSettingsFile."
            Write-Log -logFile $logFile -Message "Found settings file at $destSettingsFile." -module $scriptName
        }
        if (UpdateSettingsFile -SettingsFilePath $destSettingsFile)
        {
            Write-Host "Settings file $destSettingsFile updated successfully."
            Write-Log -logFile $logFile -Message "Settings file $destSettingsFile updated successfully." -module $scriptName
        }
        else
        {
            Write-Host "Failed to update settings file $destSettingsFile."
            Write-Log -logFile $logFile -Message "Failed to update settings file $destSettingsFile." -module $scriptName -LogLevel 'Error'
        }
    }
    else
    {
        Write-Host "Skipping settings file update."
        Write-Log -logFile $logFile -Message "Skipping settings file update." -module $scriptName
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

$version = IncrementLastrunVersion -version $version -LastRunFile $lastRunFile
Write-Host "Incrementing Last run version to: $version"
if ($null -ne $version)
{
    Write-Host "Incremented last run version..."
    Write-Log -logFile $logFile -Message "Incremented last run version to $version" -module $scriptName
}
else
{
    Write-Host "No last run version incremented."
    Write-Log -logFile $logFile -Message "No last run version incremented." -module $scriptName
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
            }
            C
            {
                Write-Host 'Continuing with the existing folder.'
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
    }
}
else
{
    Write-Host "Overwriting $parentFolder"
    if (Test-Path -Path $parentFolder)
    {
        Write-Host "Removing $parentFolder"
        Remove-Item -Path $parentFolder -Recurse -Force -ErrorAction Stop | Out-Null
    }
    else
    {
        Write-Host "Creating folder $parentFolder"
    }
    New-Item -Path $parentFolder -ItemType Directory -Force | Out-Null
}
#endregion

#region Merge functions
if (-not $CreateModule)
{
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
        Write-Host "$($functionsToMerge.count)  Functions merged successfully to $mergeOutputFile"
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
            # Replace the region markers in the output content
            $newscriptContent = $newscriptContent.Replace("#region import functions.", "#region Helper functions.")
            $newscriptContent = $newscriptContent.Replace("#endregion import functions.", "#endregion Helper functions.")
            Write-Verbose "[$scriptName] Updated region markers to 'Helper functions'."
            Write-Log -Message "Updated region markers from 'import functions' to 'Helper functions'" -Module $scriptName -LogLevel "Debug" -LogFile $logFile

            # Create informational header block
            Write-Log -Message "Creating informational header block for output script" -Module $scriptName -LogLevel "Information" -LogFile $logFile
            # If the lastRunFile contains a GUID, use it, otherwise create a new GUID.
            Write-Host "Lastrun GUID: $($lastRun.GUID)"
            if ($lastRun.GUID -and $lastRun.GUID -ne '')
            {
                Write-Verbose "[$scriptName] Using GUID from last run: $($lastRun.GUID)"
                Write-Host "Using GUID from last run: $($lastRun.GUID)"
                Write-Log -Message "Using existing GUID from last run: $($lastRun.GUID)" -Module $scriptName -LogLevel "Information" -LogFile $logFile
                $guid = $lastRun.GUID
            }
            else
            {
                Write-Verbose "[$scriptName] No GUID found in last run, generating a new GUID."
                Write-Host "No GUID found in last run, generating a new GUID."
                $guid = [guid]::NewGuid().ToString()
                Write-Verbose "[$scriptName] Generated new GUID: $guid"
                Write-Host "Generated new GUID: $guid"
                Write-Log -Message "Generated new GUID for script: $guid" -Module $scriptName -LogLevel "Information" -LogFile $logFile
            }
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Log -Message "Header timestamp set to: $timestamp" -Module $scriptName -LogLevel "Debug" -LogFile $logFile
        
            $headerBlock = @"
<#
================================================================================
Script Name:    $outputScriptName.ps1
Version:        $Version
Company:        $Company
Author:         $Author
Generated:      $timestamp
GUID:           $guid
Description:    Auto-generated release build with inlined functions
================================================================================
#>

"@
        
            Write-Log -Message "Created header block for output script" -Module $scriptName -LogLevel "Debug" -LogFile $logFile
        
            #add the header block and version string to the top of the script
            $newscriptContent = $headerBlock + $newscriptContent
            Write-Log -Message "Added header block to script content" -Module $scriptName -LogLevel "Information" -LogFile $logFile
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
}
else
{
    Write-Verbose "[$scriptName] No merge operation was performed."
    $newscriptFile = $InputFile
    Write-Verbose "[$scriptName] Using input file as new script file: $newscriptFile"
}
#endregion

#region Main code
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

#write the new version to the lastrun file.
Write-Host "Writing last run information to $lastRunFile"
$lastRun = @{
    date            = $todaysDate
    version         = $Version
    GUID            = $guid
    settingsVersion = $settingsVersion
    stringsVersion  = $stringsVersion
}
try
{
    $lastRun | ConvertTo-Json | Set-Content -Path $lastRunFile -Force
    Write-Host "Last run information written successfully to $lastRunFile"
}
catch
{
    Write-Host "Failed to write last run information to $lastRunFile"
    Write-Error $_
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

if ($Overwrite)
{
    $secretsCopied = CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $parentFolder -Overwrite
}
else
{
    $secretsCopied = CopySecrets -SourceFolder $PSScriptRoot -DestinationFolder $parentFolder
}

if ($secretsCopied)
{
    Write-Host "Secrets copied successfully to $parentFolder\.secrets"
}
else
{
    Write-Host "No secrets were copied."
}

Write-Host "Updating settings file to force password change."
$null = UpdateSettingsFile -SettingsFilePath $destSettingsFile

if (-not $noCleanup)
{
    Write-Host "Cleaning up..."
    if ($null -ne $mergeOutputFile)
    {
        Write-Verbose "[$scriptName] Cleaning up merge output file: $mergeOutputFile"
        if (Test-Path -Path $mergeOutputFile)
        {
            Write-Host "Removing $mergeOutputFile"
            Remove-Item -Path $mergeOutputFile -Force | Out-Null
        }
        else
        {
            Write-Host "No merge operation was performed so no merge files to clean."
        }
        Write-Verbose "[$scriptName] Cleaning up new script file: $newscriptFile"
        if (Test-Path -Path $newscriptFile)
        {
            Write-Host "Removing $newscriptFile"
            Remove-Item -Path $newscriptFile -Force | Out-Null
        }
        else
        {
            Write-Host "No new script file was created so no new script files to clean."
        }
    }
    else
    {
        Write-Host "No merge output file to clean up."
    }
}
else 
{
    Write-Host "Skipping cleanup as per -noCleanup flag."
}
Write-Host "Build process completed successfully."
Write-Host "Executable and files are located in $parentFolder"

$response = $null
if (-not $Overwrite)
{
    Write-Host "Would you like to copy the executable into the current directory? (Y/N)"
    $response = Read-Host "Enter 'y' to copy, 'n' to skip"
    Write-Verbose "[$scriptName] User response: $response"
    while ($response -ne 'Y' -and $response -ne 'y' -and $response -ne 'N' -and $response -ne 'n')
    {
        Write-Host "Invalid response. Please enter Y or N."
        [console]::beep(1000, 500)
        $response = Read-Host "Enter 'y' to copy, 'n' to skip"
    }   
}

if (($response -eq 'Y' -or $response -eq 'y') -or $Overwrite)
{
    Write-Verbose "[$scriptName] User chose to copy the executable to the current directory."
    try
    {
        Copy-Item -Path $OutputFile -Destination $pwd -Force
        Write-Host "Executable copied to current directory at $pwd."
    }
    catch
    {
        Write-Host "Failed to copy executable to current directory."
        Write-Error $_
        exit 1
    }
}
else
{
    Write-Host "Executable not copied."
}
Write-Host "Script completed successfully."
Write-Log -logFile $logFile -finishLogging
exit 0
#endregion Main code