<#
.SYNOPSIS
    Build and release automation script for the Windows Autopilot device enrollment tool.

.DESCRIPTION
    This script automates the process of creating a signed executable release from the main PowerShell entry point.
    It merges all function modules, handles configuration and secrets, updates versioning, and signs the output using Azure Trusted Signing.
    Supports module creation, secrets-only mode, and settings update for password change enforcement.
    Compatible with PowerShell 5.1 and leverages project-standard logging and error handling.

.PARAMETER InputFile
    The main PowerShell script to build into an executable.

.PARAMETER Version
    Optional. The version string to use for the build (major.minor.build.revision).

.PARAMETER OutputPath
    Optional. The output path or directory for the generated executable. If a directory is provided (no file extension), the output filename will be derived from the InputFile with an .exe extension inside that directory.

.PARAMETER SettingsFile
    Optional. Path to the settings.psd1 file.

.PARAMETER CompanyName
    Optional. Company name for the executable metadata.

.PARAMETER Author
    Optional. Author name for the executable metadata.

.PARAMETER CreateModule
    Switch. If set, merges all functions into a PowerShell module instead of building an executable.

.PARAMETER noCleanup
    Switch. If set, skips cleanup of temporary build files.

.PARAMETER Overwrite
    Switch. If set, overwrites existing output files and folders without prompting.

.PARAMETER NoVersionUpdate
    Switch. If set, disables automatic version incrementing.

.PARAMETER SecretsOnly
    Switch. If set, only copies secrets to the output folder.

.PARAMETER UpdateSettings
    Switch. If set (with SecretsOnly), updates settings to force password change on next start.

.EXAMPLE
    ./CreateRelease.ps1 -InputFile "main.ps1" -Version "1.2.3.4"

.NOTES
    - Requires modules: Invoke-TrustedSigning, ps2exe
    - All function modules are loaded from the /functions directory.
    - Logging is written to logs/createRelease.log.
    - Running the script requires an active Azure Trusted Signing account.  For testing, this functionality should be mocked.
    - See project documentation for full release workflow.
#>

[CmdletBinding()]
param(
    [string]$InputFile = 'main.ps1',
    [string]$Version,
    [ValidateSet('Major', 'Minor', 'Build', 'Revision')]
    [string]$versionPartToIncrement = 'Revision',
    [Alias('outputFile')]
    [string]$OutputPath = 'build',
    [string]$SettingsFile = (Join-Path -Path $PWD -ChildPath "settings.psd1"),
    [string]$Log = (Join-Path -Path $PWD -ChildPath "logs" | Join-Path -ChildPath "createRelease.log"),
    [string]$CompanyName = 'Zuhair Mahmoud',
    [string]$Author = 'Zuhair Mahmoud',
    [switch]$CreateModule,
    [switch]$noCleanup,
    [switch]$SkipSigning,
    [switch]$skipModuleCheck,
    [switch]$SkipZipArchive,
    [switch]$updateHash,
    [switch]$CreateZipFileOnly,
    [switch]$Overwrite,
    [switch]$NoVersionUpdate,
    [switch]$AddDebug,
    [Parameter(ParameterSetName = 'TargetBuild')]
    [string]$TargetsFile = (Join-Path -Path $PWD -ChildPath "targets.psd1"),
    [Parameter(ParameterSetName = 'TargetBuild')]
    [string]$TargetName = 'development'
)

$scriptName = $MyInvocation.MyCommand.Name
$logFile = $Log

#region Module Dependencies
# Check for required modules and install if missing
if (-not $skipModuleCheck)
{
    $requiredModules = @(
        @{ Name = 'ps2exe'; MinimumVersion = '1.0.0' },
        @{ Name = 'TrustedSigning'; MinimumVersion = '0.0.1' }
    )
    Write-Host "Checking required modules..." -ForegroundColor Cyan
    foreach ($module in $requiredModules)
    {
        $installed = Get-Module -ListAvailable -Name $module.Name | Where-Object {
            $_.Version -ge [Version]$module.MinimumVersion
        }
    
        if (-not $installed)
        {
            Write-Host "Module '$($module.Name)' (version $($module.MinimumVersion) or higher) is not installed." -ForegroundColor Yellow
            Write-Host "Attempting to install $($module.Name)..." -ForegroundColor Cyan
        
            try
            {
                # Try installing from PSGallery first
                Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
                Write-Host "Successfully installed $($module.Name)" -ForegroundColor Green
            }
            catch
            {
                Write-Host "Failed to install $($module.Name): $($_.Exception.Message)" -ForegroundColor Red
            
                # Special handling for modules that might not be in PSGallery
                if ($module.Name -eq 'TrustedSigning')
                {
                    Write-Host "Note: TrustedSigning may require Azure Trusted Signing setup." -ForegroundColor Yellow
                    Write-Host "For testing/development, you can use -SkipSigning parameter to bypass code signing." -ForegroundColor Yellow
                }
            
                Write-Host "Please install manually: Install-Module -Name $($module.Name) -MinimumVersion $($module.MinimumVersion) -Scope CurrentUser" -ForegroundColor Yellow
                Write-Host "Or use -SkipSigning if you don't need code signing functionality." -ForegroundColor Yellow
                exit 1
            }
        }
        else
        {
            Write-Verbose "[$scriptName] Module '$($module.Name)' is already installed (version $($installed[0].Version))"
        }
    }
    Write-Host "All required modules are available." -ForegroundColor Green
    Write-Host ""
}
else
{
    Write-Verbose "[$scriptName] Module check is skipped as per user request."
}       
#endregion Module Dependencies

$targetConfig = $null
if ($PSCmdlet.ParameterSetName -eq 'TargetBuild')
{
    Write-Host "Loading target configuration: $TargetName from $TargetsFile" -ForegroundColor Cyan
    
    # Simple target loading before function imports
    try
    {
        if (-not (Test-Path $TargetsFile))
        {
            Write-Host "Targets file not found: $TargetsFile" -ForegroundColor Red
            exit 1
        }
        
        $targetsData = Import-PowerShellDataFile -Path $TargetsFile
        if (-not $targetsData.targets -or -not $targetsData.targets.ContainsKey($TargetName))
        {
            Write-Host "Target '$TargetName' not found in targets file" -ForegroundColor Red
            $availableTargets = $targetsData.targets.Keys -join ', '
            Write-Host "Available targets: $availableTargets" -ForegroundColor Yellow
            exit 1
        }
        
        $targetConfig = $targetsData.targets[$TargetName]
    }
    catch
    {
        Write-Host "Error loading target configuration: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

#region import functions.
function Find-FolderPath()
{
    <#
    .SYNOPSIS
        Searches upward from the given path for a folder with the specified name.
    .PARAMETER Path
        The starting path to begin searching from.
    .PARAMETER FolderName
        The name of the folder to search for.
    .OUTPUTS
        Returns the full path to the folder if found, otherwise $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write verbose log of received parameters
    Write-Verbose "[$functionName] Find-FolderPath called with Path: $Path, FolderName: $FolderName"
    try
    {
        $currentPath = (Resolve-Path -Path $Path).Path
        Write-Verbose "[$functionName] Current path resolved to: $currentPath"

        # 1. Search children (recursively) of the starting path
        Write-Verbose "[$functionName] Searching children of $currentPath for folder named $FolderName"
        $childMatch = Get-ChildItem -Path $currentPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
        Write-Verbose "[$functionName] Checking child match: $($childMatch.FullName)"
        if ($childMatch)
        {
            Write-Verbose "[$functionName] Found folder in children: $($childMatch.FullName)"
            return $childMatch.FullName
        }
        # Also check if the starting path itself matches
        if ((Split-Path -Path $currentPath -Leaf) -ieq $FolderName)
        {
            Write-Verbose "[$functionName] Starting path itself matches: $currentPath"
            return $currentPath
        }

        # 2. Search up the parent chain, at each level search its children for the folder
        while ($currentPath)
        {
            $parent = Split-Path -Path $currentPath -Parent
            if ($parent -eq $currentPath -or [string]::IsNullOrEmpty($parent))
            {
                break 
            } # Reached root
            Write-Verbose "[$functionName] Searching children of parent: $parent for folder named $FolderName"
            $siblingMatch = Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
            if ($siblingMatch)
            {
                Write-Verbose "[$functionName] Found folder in parent: $($siblingMatch.FullName)"
                return $siblingMatch.FullName
            }
            # Also check if the parent itself matches
            if ((Split-Path -Path $parent -Leaf) -ieq $FolderName)
            {
                Write-Verbose "[$functionName] Parent itself matches: $parent"
                return $parent
            }
            $currentPath = $parent
        }
        Write-Verbose "[$functionName] No folder found with name $FolderName in children or parent hierarchy."
        return $null
    }
    catch
    {
        Write-Error "[$functionName] Error occurred while searching for folder: $_"
        return $null
    }
}
$functionsFolder = Find-FolderPath -Path $PSScriptRoot -FolderName 'functions'
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

#region helper functions
function New-ZipArchive()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$inputPath,
        [Parameter(Mandatory = $true)]
        [string]$outputPath
    )
    
    Write-Verbose "Creating zip archive from $inputPath to $outputPath"
    $tempZipFilePath = Join-Path -Path $env:TEMP -ChildPath "script_$(New-Guid).zip"
    try
    {
        Write-Host "Creating temporary zip archive at: $tempZipFilePath"
        if (Test-Path -Path $inputPath -PathType Container  )
        {
            Compress-Archive -Path "$inputPath\*" -DestinationPath $tempZipFilePath -Force
            Write-Verbose "[$functionName] Compressed folder $inputPath into $tempZipFilePath"  
        }
        elseif (Test-Path -Path $inputPath -PathType Leaf)      
        {
            Compress-Archive -Path $inputPath -DestinationPath $tempZipFilePath -Force
            Write-Verbose "[$functionName] Compressed file $inputPath into $tempZipFilePath"                
        }                   
        else
        {
            throw "Input path '$inputPath' does not exist."
        }       
        Write-Host "Zip archive created successfully: $tempZipFilePath"
        Move-Item -Path $tempZipFilePath -Destination $outputPath -Force       
        Write-Host "Moved zip archive to final destination: $outputPath"    
        return $true        
    }
    catch
    {   
        Write-Host "Failed to create zip archive: $tempZipFilePath"
        Write-Error $_
        return $false
    }
}

function Get-LastRunObject()
{
    [CmdletBinding()]
    param (
        [string]$LastRunFile
    )

    $functionName = $MyInvocation.MyCommand.Name
    $lastRun = [ordered]@{}
    if (Test-Path -Path $LastRunFile)
    {
        Write-Verbose "[$functionName] Last run file found: $lastRunFile"
        $lastRun = Get-Content -Path $lastRunFile -Raw | ConvertFrom-Json
    }
    else
    {
        Write-Verbose "[$functionName] Last run file not found: $lastRunFile"
        $lastRun = [ordered]@{
            date            = ''
            version         = ''
            guid            = ''
            hash            = ''
            stringsVersion  = ''
            settingsVersion = ''
        }
    }
    return $lastRun
}

function update-LastRunObject()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $LastRun,
        [Parameter(Mandatory = $true)]
        [string]$LastRunFile
    )

    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating last run file: $LastRunFile with version: $Version"
    #update the date in lastrun.date
    $LastRun.date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    #print verbose each key in $lastrun.
    foreach ($key in $LastRun.Keys)
    {
        Write-Verbose "[$functionName] LastRun.$key = $($LastRun[$key])"
    }
    try
    {
        $lastRun | ConvertTo-Json -Depth 3 | Set-Content -Path $LastRunFile -Force
        Write-Verbose "[$functionName] Last run file updated successfully."
        return $true
    }
    catch
    {
        Write-Error "[$functionName] Failed to update last run file: $_"
        return $false
    }
}

function Update-LastRunVersion()
{
    [CmdletBinding()]
    param (
        [string]$Version = $null,
        [ValidateSet('Major', 'Minor', 'Build', 'Revision')]
        [string]$PartToIncrement = 'Revision',
        [Parameter(Mandatory = $true)]
        $LastRun
    )

    $functionName = $MyInvocation.MyCommand.Name
    $lastRunObject = [ordered]@{}
    # 1. Normalize & validate supplied version (may be empty)
    if (-not [string]::IsNullOrWhiteSpace($Version))
    {
        if ($Version -notmatch '^[\d\.]+$')
        {
            Write-Warning 'Invalid version format (only digits and periods allowed). Using Null as the supplied version.'
            $updatedVersion = $null
        }
        $versionParts = $Version.Split('.')
        while ($versionParts.Count -lt 4)
        {
            $versionParts += '0' 
        }
        $updatedVersion = ($versionParts[0..3]) -join '.'
    }

    # 2. Normalize last run version if present
    $lastRunVersion = $null
    if (-not [string]::IsNullOrWhiteSpace($LastRun.version) -and $LastRun.version -match '^[\d\.]+$')
    {
        $lrParts = $LastRun.version.Split('.')
        while ($lrParts.Count -lt 4)
        {
            $lrParts += '0' 
        }
        $lastRunVersion = ($lrParts[0..3]) -join '.'
    }

    # 3. Determine base version via interactive logic (preserve existing behavior)
    if ([string]::IsNullOrWhiteSpace($updatedVersion) -and [string]::IsNullOrWhiteSpace($lastRunVersion))
    {
        Write-Host 'What version number would you like to use for this build?'
        Write-Host 'Enter version number using the format major.minor.build.revision (e.g., 1.0.0.0)'
        $updatedVersion = Read-Host 'Enter version number'
        while ($updatedVersion -notmatch '^\d+\.\d+\.\d+\.\d+$')
        {
            Write-Host 'Invalid version format. Please use n.n.n.n'
            [console]::Beep(1000, 500)
            $updatedVersion = Read-Host 'Enter a valid version number'
        }
        $maintainCurrentVersion = $true
    }
    elseif (-not [string]::IsNullOrWhiteSpace($updatedVersion) -and -not [string]::IsNullOrWhiteSpace($lastRunVersion))
    {
        # Both supplied & last run available – ask user which to use (keep behavior), show comparison
        $supObj = [Version]$updatedVersion
        $lastObj = [Version]$lastRunVersion
        $cmp = $supObj.CompareTo($lastObj)
        $relation = if ($cmp -gt 0)
        {
            'greater than' 
        }
        elseif ($cmp -lt 0)
        {
            'less than' 
        }
        else
        {
            'equal to' 
        }
        Write-Host "Supplied version: $updatedVersion"
        Write-Host "Last run version: $lastRunVersion"
        Write-Host "Supplied version is $relation last run version."
        Write-Host 'Which version would you like to use? (S for supplied, L for last run)'
        $response = Read-Host 'Enter S for supplied version, L for last run version, or E to exit'
        while ($response -notin 'S', 'L', 'E')
        {
            Write-Host 'Invalid response. Please enter S, L, or E.'
            [console]::Beep(1000, 500)
            $response = Read-Host 'Enter S for supplied version, L for last run version, or E to exit'
        }
        switch ($response)
        {
            'S'
            {
                Write-Host "Using supplied version: $updatedVersion"; $maintainCurrentVersion = $true 
            }
            'L'
            {
                Write-Host "Using last run version: $lastRunVersion"; $updatedVersion = $lastRunVersion 
            }
            'E'
            {
                Write-Host 'Exiting script.'; exit 0 
            }
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($lastRunVersion) -and [string]::IsNullOrWhiteSpace($updatedVersion))
    {
        Write-Host "No version supplied. Using last run version: $lastRunVersion"
        $updatedVersion = $lastRunVersion
    }
    else
    {
        # Only supplied version exists
        Write-Host "Using supplied version: $updatedVersion"
        $maintainCurrentVersion = $true
    }

    # 4. Show context
    Write-Host "Last run date: $($lastRun.date)"
    Write-Host "GUID: $($lastRun.guid)"
    Write-Host "Part to increment: $PartToIncrement"
    Write-Host "Current base version: $updatedVersion"
    Write-Host "Maintain current version: $maintainCurrentVersion"
    Write-Verbose "[$functionName] No version update switch state: $NoVersionUpdate"

    # 5. Increment if allowed
    $finalVersion = $updatedVersion
    if (-not $maintainCurrentVersion -and -not $NoVersionUpdate)
    {
        $parts = $finalVersion.Split('.')
        # Ensure exactly 4 parts (defensive)
        while ($parts.Count -lt 4)
        {
            $parts += '0' 
        }
        switch ($PartToIncrement)
        {
            'Major'
            {
                $parts[0] = ([int]$parts[0] + 1); $parts[1] = 0; $parts[2] = 0; $parts[3] = 0 
            }
            'Minor'
            {
                $parts[1] = ([int]$parts[1] + 1); $parts[2] = 0; $parts[3] = 0 
            }
            'Build'
            {
                $parts[2] = ([int]$parts[2] + 1); $parts[3] = 0 
            }
            'Revision'
            {
                $parts[3] = ([int]$parts[3] + 1) 
            }
        }
        $finalVersion = ($parts[0..3]) -join '.'
        Write-Host "Incremented $($PartToIncrement): $updatedVersion -> $finalVersion"
    }
    elseif ($maintainCurrentVersion -or $NoVersionUpdate)
    {
        Write-Host "Maintaining version without increment: $finalVersion"
    }
    $LastRun.version = $finalVersion
    $lastRunObject = $LastRun
    return $lastRunObject
}

function UpdateHash()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$executableFilePath,
        [Parameter(Mandatory = $true)]
        $lastRunContent
    )

    $functionName = $MyInvocation.MyCommand.Name
    $lastRunContent = [ordered]@{
        date            = $lastRunContent.date
        version         = $lastRunContent.version
        guid            = $lastRunContent.guid
        hash            = $lastRunContent.hash
        stringsVersion  = $lastRunContent.stringsVersion
        settingsVersion = $lastRunContent.settingsVersion
    }
    Write-Verbose "[$functionName] Updating hash in lastrun file: $lastRunPath"
    Write-Log -logFile $logFile -Message "Updating hash in lastrun file: $lastRunPath" -module $functionName
    if (-not (Test-Path $executableFilePath))
    {
        Write-Error "File not found: $executableFilePath"
        Write-Log -logFile $logFile -Message "File not found: $executableFilePath" -module $functionName -logLevel "Error"
        return $false
    }
    
    # Get the hash of the executable file
    $fileHash = Get-FileHash -Path $executableFilePath -Algorithm SHA256
    
    if ($fileHash)
    {
        Write-Host "File hash (SHA256) of $($executableFilePath): $($fileHash.Hash)"
        Write-Log -logFile $logFile -Message "File hash (SHA256) of $($executableFilePath): $($fileHash.Hash)" -module $functionName
        $lastRunContent.hash = $fileHash.Hash
        $lastRunContent.add('hashUpdated', $true)
    }
    else
    {
        Write-Error "Failed to write updated hash to $lastRunPath"
        Write-Log -logFile $logFile -Message "Failed to write updated hash to $lastRunPath" -module $functionName -logLevel "Error"
        $lastRunContent.add('hashUpdated', $false)
    }
    return $lastRunContent
}

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
        Write-Verbose "[$functionName] Destination file does not contain a path, using current directory: $PWD"
        $destinationDir = $PWD
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
                Write-Host 'Secrets will not be copied.'
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

function Update-TargetSettings()
{
    <#
    .SYNOPSIS
        Applies target settings to global and domain configuration files.
    
    .DESCRIPTION
        Merges target settings into the appropriate configuration files using existing
        settings management functions. Creates default configurations if files don't exist.
    
    .PARAMETER TargetConfig
        Target configuration hashtable containing settings to apply.
    
    .PARAMETER SettingsFilePath
        Path to the main settings.psd1 file.
    
    .PARAMETER ConfigurationPath
        Directory path where configuration files are located.
    
    .OUTPUTS
        System.Boolean
        Returns $true if settings were applied successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$TargetConfig,
        [Parameter(Mandatory = $true)]
        [string]$SettingsFilePath,
        [Parameter(Mandatory = $false)]
        [string]$ConfigurationPath = $PWD
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Applying target settings to configuration files"
    Write-Log -LogFile $logFile -Message "Applying target settings to configuration files" -Module $functionName -LogLevel "Information"
    
    try
    {
        # Load or create main settings file
        if (Test-Path $SettingsFilePath)
        {
            Write-Verbose "[$functionName] Loading existing settings file: $SettingsFilePath"
            $currentSettings = Import-PowerShellDataFile -Path $SettingsFilePath
        }
        else
        {
            Write-Verbose "[$functionName] Creating new settings file from defaults"
            $currentSettings = Get-ApplicationDefaults -DefaultType "Settings"
        }
        
        # Apply global settings if specified
        if ($TargetConfig.globalSettings -and $TargetConfig.globalSettings.Count -gt 0)
        {
            Write-Verbose "[$functionName] Applying $($TargetConfig.globalSettings.Count) global settings"
            Write-Log -LogFile $logFile -Message "Applying $($TargetConfig.globalSettings.Count) global settings" -Module $functionName -LogLevel "Verbose"
            
            foreach ($key in $TargetConfig.globalSettings.Keys)
            {
                $currentSettings.globalSettings[$key] = $TargetConfig.globalSettings[$key]
                Write-Verbose "[$functionName] Applied global setting: $key = $($TargetConfig.globalSettings[$key])"
            }
        }
        
        # Apply auth settings if specified
        if ($TargetConfig.authSettings -and $TargetConfig.authSettings.Count -gt 0)
        {
            Write-Verbose "[$functionName] Applying $($TargetConfig.authSettings.Count) auth settings"
            Write-Log -LogFile $logFile -Message "Applying $($TargetConfig.authSettings.Count) auth settings" -Module $functionName -LogLevel "Verbose"
            
            foreach ($key in $TargetConfig.authSettings.Keys)
            {
                $currentSettings.auth[$key] = $TargetConfig.authSettings[$key]
                Write-Verbose "[$functionName] Applied auth setting: $key = $($TargetConfig.authSettings[$key])"
            }
        }
        
        # Save updated main settings file
        Write-Verbose "[$functionName] Saving updated settings file"
        $currentSettings | Export-PowerShellDataFile -Path $SettingsFilePath -Validate -Force
        Write-Log -LogFile $logFile -Message "Updated settings file saved: $SettingsFilePath" -Module $functionName -LogLevel "Information"
        
        # Handle domain-specific settings if specified
        if ($TargetConfig.domain -and $TargetConfig.domainSettings -and $TargetConfig.domainSettings.Count -gt 0)
        {
            Write-Verbose "[$functionName] Processing domain settings for: $($TargetConfig.domain)"
            Write-Log -LogFile $logFile -Message "Processing domain settings for: $($TargetConfig.domain)" -Module $functionName -LogLevel "Information"
            
            # Load or create domain configuration
            $domainConfig = Get-DomainConfigurationFromFiles -DomainName $TargetConfig.domain -ConfigurationPath $ConfigurationPath
            
            # Ensure we have a proper hashtable or ordered dictionary
            if ($null -eq $domainConfig)
            {
                Write-Verbose "[$functionName] No existing domain config found, creating new ordered dictionary"
                $domainConfig = [ordered]@{}
            }
            elseif ($domainConfig -is [array] -and $domainConfig.Count -gt 0)
            {
                # If array returned, find the first hashtable/ordered dictionary element
                Write-Verbose "[$functionName] Domain config is an array, extracting dictionary"
                $foundDict = $null
                foreach ($item in $domainConfig)
                {
                    if ($item -is [hashtable] -or $item -is [System.Collections.Specialized.OrderedDictionary])
                    {
                        $foundDict = $item
                        break
                    }
                }
                $domainConfig = if ($foundDict) { $foundDict } else { [ordered]@{} }
            }
            elseif ($domainConfig -isnot [hashtable] -and $domainConfig -isnot [System.Collections.Specialized.OrderedDictionary])
            {
                Write-Warning "[$functionName] Domain config is not a hashtable or ordered dictionary (type: $($domainConfig.GetType().Name)), creating new ordered dictionary"
                $domainConfig = [ordered]@{}
            }
            
            Write-Verbose "[$functionName] Domain config type after validation: $($domainConfig.GetType().Name)"
            
            # Apply domain settings
            foreach ($key in $TargetConfig.domainSettings.Keys)
            {
                Write-Verbose "[$functionName] Applying domain setting: $key = $($TargetConfig.domainSettings[$key]) with value type $($TargetConfig.domainSettings[$key].GetType().Name)"
                if ($domainConfig.Keys -contains $key)
                {
                    $domainConfig[$key] = $TargetConfig.domainSettings[$key]
                    Write-Verbose "[$functionName] Updated existing domain setting: $key = $($TargetConfig.domainSettings[$key])"
                }
                else
                {
                    $domainConfig.Add($key, $TargetConfig.domainSettings[$key])
                    Write-Verbose "[$functionName] Added new domain setting: $key = $($TargetConfig.domainSettings[$key])"
                }
                Write-Verbose "[$functionName] Applied domain setting: $key = $($TargetConfig.domainSettings[$key])"
            }
            
            # Save domain configuration
            $saveResult = Save-DomainConfiguration -DomainName $TargetConfig.domain -DomainConfiguration $domainConfig -ConfigurationPath $ConfigurationPath
            if ($saveResult)
            {
                Write-Log -LogFile $logFile -Message "Domain configuration saved for: $($TargetConfig.domain)" -Module $functionName -LogLevel "Information"
            }
            else
            {
                Write-Warning "[$functionName] Failed to save domain configuration for: $($TargetConfig.domain)"
                Write-Log -LogFile $logFile -Message "Failed to save domain configuration for: $($TargetConfig.domain)" -Module $functionName -LogLevel "Warning"
            }
        }
        
        Write-Verbose "[$functionName] Target settings applied successfully"
        Write-Log -LogFile $logFile -Message "Target settings applied successfully" -Module $functionName -LogLevel "Information"
        return $true
    }
    catch
    {
        Write-Error "[$functionName] Error applying target settings: $($_.Exception.Message)"
        Write-Log -LogFile $logFile -Message "Error applying target settings: $($_.Exception.Message)" -Module $functionName -LogLevel "Error"
        return $false
    }
}

function Set-ParametersFromTarget()
{
    <#
    .SYNOPSIS
        Sets script parameters based on target configuration.
    
    .DESCRIPTION
        Extracts build parameters from target configuration and applies them to
        script variables, ensuring target parameters override command-line parameters.
    
    .PARAMETER TargetConfig
        Target configuration hashtable containing build parameters.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns hashtable of parameters to use for the build.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$TargetConfig
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Setting parameters from target configuration"
    Write-Log -LogFile $logFile -Message "Setting parameters from target configuration" -Module $functionName -LogLevel "Information"
    
    $params = @{}
    
    # Copy build parameters from target if they exist
    if ($TargetConfig.buildParameters)
    {
        foreach ($key in $TargetConfig.buildParameters.Keys)
        {
            $params[$key] = $TargetConfig.buildParameters[$key]
            Write-Verbose "[$functionName] Set parameter from target: $key = $($TargetConfig.buildParameters[$key])"
        }
        Write-Log -LogFile $logFile -Message "Applied $($TargetConfig.buildParameters.Count) build parameters from target" -Module $functionName -LogLevel "Verbose"
    }
    
    return $params
}
#endregion helper functions

Write-Log -logFile $logFile -startLogging

#region Apply script parameters and target settings
Write-Host "Applying script parameters..."
Write-Log -logFile $logFile -Message "Applying script parameters..." -module $scriptName
# Apply target build scrit configuration
if ($targetConfig)
{
    # Override script parameters with target build parameters
    $targetParams = Set-ParametersFromTarget -TargetConfig $targetConfig
    Write-Log -logFile $logFile -Message "Build parameters to apply: $($targetParams | Out-String)" -module $scriptName
    foreach ($key in $targetParams.Keys)
    {
        $value = $targetParams[$key]
        Write-Verbose "[$scriptName] Applying target parameter: $key = $value"
        Write-Log -logFile $logFile -Message "Applying target parameter: $key = $value" -module $scriptName
        # Map target parameters to script variables
        switch ($key)
        {
            'Version'
            {
                $Version = $value 
            }
            'OutputPath'
            {
                $OutputPath = $value 
            }
            'SkipSigning'
            {
                $SkipSigning = $value 
            }
            'NoVersionUpdate'
            {
                $NoVersionUpdate = $value 
            }
            'Overwrite'
            {
                $Overwrite = $value 
            }
            'noCleanup'
            {
                $noCleanup = $value 
            }
            'AddDebug'
            {
                $AddDebug = $value 
            }
            'CompanyName'
            {
                $CompanyName = $value 
            }
            'Author'
            {
                $Author = $value 
            }
            default
            {
                Write-Verbose "[$scriptName] Unknown target parameter: $key" 
            }
        }
        Write-Verbose "[$scriptName] Set $key to $value of type $($value.GetType().Name)"
        Write-Log -logFile $logFile -Message "Set $key to $value of type $($value.GetType().Name)" -module $scriptName
    }
    Write-Host "Build configuration applied successfully" -ForegroundColor Green
    Write-Log -logFile $logFile -Message "Build configuration applied successfully" -module $scriptName
}
#endregion

#region Define variables
$lastRunFile = Join-Path -Path $PWD -ChildPath "lastrun.json"
$lastRun = Get-LastRunObject -LastRunFile $lastRunFile
$maintainCurrentVersion = $false
$functionsToMerge = @(Get-ChildItem -Path $functionsFolder -Recurse -Filter "*.ps1" | ForEach-Object { $_.FullName })
$todaysDate = Get-Date -Format "yyyy-MM-dd"
Write-Host "Starting build script on $todaysDate"
# Resolve output file path from -OutputPath (directory or filename)
$leafName = Split-Path -Leaf $InputFile
Write-Verbose "[$scriptName] Leaf name is: $leafName"
$exeName = $leafName.Replace('.ps1', '.exe')
Write-Verbose "[$scriptName] Executable name is: $exeName"
if ([string]::IsNullOrWhiteSpace($OutputPath))
{
    # No output path provided; use default build folder
    Write-Verbose "[$scriptName] No OutputPath specified. Using default build directory."
    $OutputFile = Join-Path -Path $PWD -ChildPath "build" | Join-Path -ChildPath $exeName
}
else
{
    # Detect if OutputPath represents a directory (no extension) or a full file path (has extension)
    $ext = [System.IO.Path]::GetExtension($OutputPath)
    if ([string]::IsNullOrWhiteSpace($ext))
    {
        Write-Verbose "[$scriptName] OutputPath has no extension; treating as directory."
        $OutputFile = Join-Path -Path $OutputPath -ChildPath $exeName
    }
    else
    {
        Write-Verbose "[$scriptName] OutputPath includes an extension; treating as full output filename."
        $OutputFile = $OutputPath
    }
}
Write-Host "Output file resolved to: $OutputFile"
# Initialize success message after resolving OutputFile
$successMessage = "$OutputFile written"
$parentFolder = Split-Path -Parent $OutputFile
$SettingsFile = "$parentFolder\settings.psd1"
$zipFilePath = Join-Path $parentFolder "script.zip"
#endregion

#region initial checks
if ($updateHash)
{
    Write-Host "Updating hash in lastrun file: $lastRunFile"
    Write-Host "Updating hash for executable: $OutputFile"
    $updatedHash = UpdateHash -executableFilePath $OutputFile -lastRunContent $lastRun
    if ($updatedHash.hashUpdated)
    {
        Write-Host "Hash updated successfully in $lastRunFile"
        Write-Log -logFile $logFile -Message "Hash updated successfully in $lastRunFile" -module $scriptName
        Write-Host "Saving lastrun file: $lastRunFile"
        if (Update-LastRunObject -LastRunFile $lastRunFile -LastRun $updatedHash)
        {
            Write-Host "lastrun file saved successfully."
            Write-Log -logFile $logFile -Message "lastrun file saved successfully." -module $scriptName
        }
        else
        {
            Write-Host "Failed to save lastrun file: $lastRunFile"
            Write-Log -logFile $logFile -Message "Failed to save lastrun file: $lastRunFile" -module $scriptName -LogLevel 'Error'
            Write-Log -logFile $logFile -finishLogging
            exit 1
        }
        Write-Log -logFile $logFile -finishLogging
        exit 0
    }
    else
    {
        Write-Host "Failed to update hash in $lastRunFile"
        Write-Log -logFile $logFile -Message "Failed to update hash in $lastRunFile" -module $scriptName -LogLevel 'Error'
        Write-Log -logFile $logFile -finishLogging
        exit 1
    }
}

if ($CreateZipFileOnly)
{
    Write-Host "Creating zip file only: $zipFilePath"
    {
        Write-Host "Zip file created successfully at $zipFilePath"
        Write-Log -logFile $logFile -Message "Zip file created successfully at $zipFilePath" -module $scriptName
        Write-Log -logFile $logFile -finishLogging
        exit 0
    }
    else
    {
        Write-Host "Failed to create zip file at $zipFilePath"
        Write-Log -logFile $logFile -Message "Failed to create zip file at $zipFilePath" -module $scriptName -LogLevel 'Error'
        Write-Log -logFile $logFile -finishLogging
        exit 1
    }
}

Write-Verbose "[$scriptName] Updating last run version..."
$updatedVersion = Update-LastRunVersion -version $version -PartToIncrement 'Revision' -LastRun $LastRun
Write-Verbose "[$scriptName] Last run version after update: $($updatedVersion.version)"
if ($updatedVersion.version -ne $version)
{
    Write-Host "Incremented last run version..."
    Write-Log -logFile $logFile -Message "Incremented last run version to $version" -module $scriptName
}
else
{
    Write-Host "No last run version incremented."
    Write-Log -logFile $logFile -Message "No last run version incremented." -module $scriptName
}
$version = $updatedVersion.version

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

Write-Host "Applying target configuration settings..." -ForegroundColor Cyan
Write-Log -logFile $logFile -Message "Applying target configuration settings..." -module $scriptName
# Apply target settings to configuration files (only if target config is provided)
if ($targetConfig)
{
    $settingsApplied = Update-TargetSettings -TargetConfig $targetConfig -SettingsFilePath $SettingsFile -ConfigurationPath $parentFolder
    Write-Log -logFile $logFile -Message "Target settings application result: $settingsApplied" -module $scriptName
    if (-not $settingsApplied)
    {
        Write-Host "Failed to apply target settings. Exiting." -ForegroundColor Red
        Write-Log -logFile $logFile -finishLogging
        exit 1
    }
    Write-Host "Target settings applied successfully." -ForegroundColor Green
    Write-Log -logFile $logFile -Message "Target settings applied successfully." -module $scriptName
}
else
{
    Write-Host "No target configuration provided - skipping target settings application." -ForegroundColor Yellow
    Write-Log -logFile $logFile -Message "No target configuration provided - skipping target settings application." -module $scriptName
}
#endregion

#region Merge functions
if (-not $CreateModule)
{
    $mergeOutputFile = Join-Path -Path $PWD -ChildPath $OutputPath | Join-Path -ChildPath 'merged.ps1'
    $mergeParentFolder = Split-Path -Parent $mergeOutputFile
    # Ensure destination directory exists
    if (-not (Test-Path -Path $mergeParentFolder))
    {
        Write-Verbose "[$scriptName] Creating parent folder: $mergeParentFolder"
        New-Item -ItemType Directory -Path $mergeParentFolder -Force | Out-Null
    }
    if ($InputFile -ne $OutputFile)
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
if (Test-Path $OutputFile)
{
    Write-Host "The output file $OutputFile already exists. Removing..."
    Remove-Item -Path $OutputFile -Force
}

$params = @{
    inputFile   = $newscriptFile
    outputFile  = $OutputFile
    x64         = $true
    version     = $Version
    title       = "Intune Registration"
    description = "Register devices in Intune and perform other Autopilot device functions"
    STA         = $true
    company     = $CompanyName
    product     = "Intune Autopilot Registration"
    copyright   = '2025'
}
if ($AddDebug)
{
    Write-Host "Adding debug information to parameters"
    $params.Debug = $true
}

Write-Host "Building executable from $newscriptFile to $OutputFile"
Write-Host "parameters used:"
$params | Format-List | Out-Host
$result = Invoke-ps2exe @params -ErrorAction Stop
Write-Host "ps2exe result: $result"
# Use a regex-escaped pattern to avoid invalid escape sequences (e.g., \\m) in Windows paths
if ($result -match [regex]::Escape($successMessage))
{
    Write-Host "Executable created successfully: $OutputFile"
}
else
{
    Write-Host "Failed to create executable: $OutputFile"
    exit 1
}

if (-not $SkipSigning)
{
    Write-Host "Signing executable at $OutputFile"
    if (SignScripts -path $outputFile)
    {
        Write-Host "Executable signed successfully: $OutputFile"
    }
    else
    {
        Write-Host "Failed to sign executable: $OutputFile"
        exit 1
    }
}
else 
{
    Write-Host "Skipping signing of executable as per -SkipSigning flag."
}

#get the hash for the executable
$Hash = UpdateHash -executableFilePath $OutputFile -lastRunContent $lastRun
if ($Hash.hashUpdated)
{
    Write-Host "Got the hash for $($OutputFile): $($Hash.hash)"
    Write-Log -logFile $logFile -Message "Got the hash for $($OutputFile): $($Hash.hash)" -module $scriptName
    $lastrun = $Hash
}
else
{
    Write-Host "Failed to update hash in $lastRunFile"
    exit 1
}

#save the lastrun file
if (Update-LastRunObject -LastRunFile $lastRunFile -LastRun $lastRun)
{
    Write-Host "lastrun file saved successfully."
    Write-Log -logFile $logFile -Message "lastrun file saved successfully." -module $scriptName
}
else
{
    Write-Host "Failed to save lastrun file: $lastRunFile"
    Write-Log -logFile $logFile -Message "Failed to save lastrun file: $lastRunFile" -module $scriptName -LogLevel 'Error'
    Write-Log -logFile $logFile -finishLogging
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

if (-not $SkipZipArchive)
{
    # Ensure any existing zip file is deleted before creating a new one
    if (Test-Path $zipFilePath) {
        Remove-Item $zipFilePath -Force
    }
    Write-Verbose "[$scriptName] Creating zip archive of output folder: $parentFolder"
    $zipCreated = New-ZipArchive -inputPath $parentFolder -outputPath $zipFilePath
    if ($zipCreated)
    {
        Write-Host "Zip archive created successfully at $zipFilePath"
        Write-Log -logFile $logFile -Message "Zip archive created successfully at $zipFilePath" -module $scriptName
    }
    else
    {
        Write-Host "Failed to create zip archive at $zipFilePath"
        Write-Log -logFile $logFile -Message "Failed to create zip archive at $zipFilePath" -module $scriptName -LogLevel 'Error'
    }
}

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
    #look for backup files with a .backup.* extension.
    $backupFiles = Get-ChildItem -Path $parentFolder -Recurse -Filter "*.backup.*"
    if ($backupFiles.Count -gt 0)
    {
        Write-Host "Found $($backupFiles.Count) backup files to remove."
        foreach ($file in $backupFiles)
        {
            Write-Host "Removing backup file: $($file.FullName)"
            Remove-Item -Path $file.FullName -Force | Out-Null
        }
    }
    else
    {
        Write-Host "No backup files found to remove."
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

if ((($response -eq 'Y' -or $response -eq 'y') -or $Overwrite) -and -not $SkipSigning)
{
    Write-Verbose "[$scriptName] User chose to copy the executable to the current directory."
    try
    {
        Copy-Item -Path $OutputFile -Destination $PWD -Force
        Write-Host "Executable copied to current directory at $PWD."
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
    $message = if ($SkipSigning)
    {
        "Skipping copy as signing was skipped." 
    }
    else
    {
        "User chose not to copy the executable." 
    }
    Write-Verbose "[$scriptName] $message"
}
Write-Host "Script completed successfully."
Write-Log -logFile $logFile -finishLogging
exit 0
#endregion Main code