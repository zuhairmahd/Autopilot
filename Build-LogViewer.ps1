<#
.SYNOPSIS
    Builds the Autopilot Log Viewer standalone application
.DESCRIPTION
    Builds the AutopilotLogViewer.exe WPF application and its dependencies (LogViewer.Core and LogCore).
    This script is designed for the standalone LogViewer repository and only builds the components
    necessary for the log viewer to function independently.
.PARAMETER Configuration
    Build configuration: Debug or Release (default: Release)
.PARAMETER Framework
    Target framework: net9.0 or net9.0-windows (default: net9.0-windows)
.PARAMETER BinFolder
    Root output directory for compiled binaries (default: bin)
.PARAMETER Clean
    Remove bin/ and obj/ directories before building
.PARAMETER Verbose
    Show detailed build output
.EXAMPLE
    .\Build-LogViewer.ps1 -Configuration Release
    Builds all projects to bin/Release/net9.0-windows
.EXAMPLE
    .\Build-LogViewer.ps1 -Clean -Verbose
    Cleans and builds with verbose logging
.NOTES
    This script is part of the standalone AutopilotLogViewer repository.
    For integration with the main Autopilot repository, see docs/SUBTREE_INTEGRATION.md
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [ValidateSet('net9.0', 'net9.0-windows')]
    [string]$Framework = 'net9.0-windows',
    [string]$BinFolder = 'bin',
    [switch]$Clean,
    [switch]$ShowSummary,
    [switch]$SignOnly
)

function SignScripts()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Path,
        [string[]]$Exclusions = @(),
        [switch]$Recurse
    )
    $functionName = $MyInvocation.MyCommand.Name
    $excludedFiles = 0
    $signedFiles = 0
    Write-Verbose "[$functionName] Got $($Path.Count) folders to sign."
    $success = $false
    $filesToSign = @()
    foreach ($folder in $Path)
    {
        $files = @()
        if (Test-Path $folder -PathType Leaf)
        {
            # A single file was provided
            $ext = [System.IO.Path]::GetExtension($folder)
            if ($ext -ieq '.exe' -or $ext -ieq '.dll') { $files += (Get-Item -Path $folder) }
        }
        elseif (Test-Path $folder -PathType Container)
        {
            # A directory was provided - collect .exe and .dll files (Filter accepts only a single pattern)
            $params = @{
                Path        = $folder
                ErrorAction = 'SilentlyContinue'
            }
            if ($Recurse) { $params['Recurse'] = $true }
            $params['filter'] = '*.exe'
            $exeFiles = Get-ChildItem @params
            Write-Verbose "[$functionName] Found $($exeFiles.Count) EXE files in $folder"
            if ($exeFiles.Count -gt 0) { $files += $exeFiles }
            $params['Filter'] = '*.dll'
            $dllFiles = Get-ChildItem @params
            Write-Verbose "[$functionName] Found $($dllFiles.Count) DLL files in $folder"
            if ($dllFiles.Count -gt 0) { $files += $dllFiles }
        }
        Write-Host "Found a total of $($exeFiles.Count) EXE files and $($dllFiles.Count) DLL files"
        Write-Verbose "[$functionName] Signing $($files.Count) files in $folder and excluding $($Exclusions.Count) files."
        if ($files.Count -gt 0)
        {
            foreach ($file in $files)
            {
                Write-Verbose "[$functionName] Processing file: $file"
                if ($file.BaseName -in $Exclusions)
                {
                    Write-Verbose "[$functionName] Skipping $($file.BaseName) because it is in the exclusions list"
                    $excludedFiles++
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
                    $signedFiles++
                }
            }
        }
        else
        {
            Write-Host "No executable files found in $Path"
        }
    }
    Write-Host "==============================="
    Write-Host "Total binary files found: $($files.count)"
    Write-Host "Total files excluded from signing: $excludedFiles"
    Write-Host "Number of files already signed: $signedFiles"
    if ($filesToSign.Count -gt 0)
    {
        Write-Host "==============================="
        Write-Host "Submitting $($filesToSign.Count) files for signing..."
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

Write-Verbose "Starting Autopilot Log Viewer Build"
Write-Verbose "Configuration: $Configuration"
Write-Verbose "Framework: $Framework"
Write-Verbose "Output Directory: $BinFolder\$Configuration\$Framework"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Autopilot Log Viewer Build" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verify .NET SDK
Write-Host "Checking .NET SDK..." -ForegroundColor Yellow
Write-Verbose "Executing: dotnet --version"
try
{
    $dotnetVersion = dotnet --version
    Write-Host "  [OK] .NET SDK $dotnetVersion" -ForegroundColor Green
}
catch
{
    Write-Host "  [ERROR] .NET SDK not found. Install from: https://dotnet.microsoft.com/download" -ForegroundColor Red
    exit 1
}

# Verify required .NET version (9.0 or higher)
$requiredVersion = [version]"9.0.0"
$currentVersion = [version]$dotnetVersion
if ($currentVersion -lt $requiredVersion)
{
    Write-Host "  [ERROR] .NET 9.0 or higher is required. Current version: $dotnetVersion" -ForegroundColor Red
    Write-Host "  Download from: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor Yellow
    exit 1
}

if ($SignOnly)
{
    Write-Host "`nSigning only mode enabled. Skipping build..." -ForegroundColor Yellow
    if (SignScripts -path @($BinFolder) -Recurse)
    {
        Write-Host "  [OK] Code signing completed" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "  [ERROR] Code signing failed" -ForegroundColor Red
        exit 1
    }
}                                       

# Find solution file
$solutionFile = "AutopilotLogViewer.sln"
if (-not (Test-Path $solutionFile))
{
    Write-Host "  [ERROR] Solution file not found: $solutionFile" -ForegroundColor Red
    Write-Verbose "Expected path: $((Get-Location).Path)\$solutionFile"
    exit 1
}

Write-Host "Solution: $solutionFile" -ForegroundColor Cyan
Write-Host "Target Framework: $Framework" -ForegroundColor Cyan
Write-Host ""

# Clean if requested
if ($Clean)
{
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    Write-Verbose "Removing bin and obj directories from src/"
    $cleanedDirs = 0
    Get-ChildItem -Path "src" -Include "bin", "obj" -Recurse -Directory | ForEach-Object {
        Write-Verbose "  Removing: $($_.FullName)"
        Remove-Item $_.FullName -Recurse -Force
        $cleanedDirs++
    }
    
    if (Test-Path $BinFolder)
    {
        Write-Verbose "Removing output directory: $BinFolder"
        Remove-Item $BinFolder -Recurse -Force
        $cleanedDirs++
    }
    Write-Host "  [OK] Cleaned $cleanedDirs directories" -ForegroundColor Green
    Write-Host ""
}

# Restore NuGet packages
Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
Write-Verbose "Executing: dotnet restore $solutionFile --verbosity minimal"
try
{
    $restoreOutput = dotnet restore $solutionFile --verbosity minimal 2>&1
    if ($LASTEXITCODE -ne 0)
    {
        Write-Host "  [ERROR] NuGet restore failed" -ForegroundColor Red
        Write-Host $restoreOutput -ForegroundColor Red
        Write-Verbose "Restore exit code: $LASTEXITCODE"
        exit 1
    }
    Write-Host "  [OK] Packages restored" -ForegroundColor Green
    Write-Verbose "NuGet restore completed successfully"
    Write-Host ""
}
catch
{
    Write-Host "  [ERROR] Failed to restore packages: $_" -ForegroundColor Red
    Write-Verbose "Exception: $($_.Exception.Message)"
    exit 1
}

# Determine output path
$publishPath = Join-Path (Join-Path $BinFolder $Configuration) $Framework

# Create output directory if it doesn't exist
if (-not (Test-Path $publishPath))
{
    Write-Verbose "Creating output directory: $publishPath"
    New-Item -ItemType Directory -Path $publishPath -Force | Out-Null
}

# Build the solution
Write-Host "Building AutopilotLogViewer ($Framework)..." -ForegroundColor Cyan
Write-Verbose "Solution: $solutionFile"
Write-Verbose "Framework: $Framework"
Write-Verbose "Output: $publishPath"

$publishArgs = @(
    'publish'
    $solutionFile
    '--configuration', $Configuration
    '--framework', $Framework
    '--output', $publishPath
    '--no-self-contained'
    '/p:DebugType=portable'
    '--nologo'
)

if ($VerbosePreference -eq 'Continue')
{
    $publishArgs += '--verbosity', 'detailed'
    Write-Verbose "Executing: dotnet $($publishArgs -join ' ')"
}
else
{
    $publishArgs += '--verbosity', 'minimal'
}

$publishOutput = & dotnet @publishArgs 2>&1

if ($LASTEXITCODE -ne 0)
{
    Write-Host "  [FAILED] Build failed" -ForegroundColor Red
    Write-Verbose "Exit code: $LASTEXITCODE"
    if ($VerbosePreference -eq 'Continue')
    {
        Write-Host $publishOutput -ForegroundColor Red
    }
    exit 1
}

# Verify output files
$exePath = Join-Path $publishPath "AutopilotLogViewer.exe"
$coreDllPath = Join-Path $publishPath "Autopilot.LogViewer.Core.dll"
$logCoreDllPath = Join-Path $publishPath "Autopilot.LogCore.dll"

$buildSuccess = $true
$builtFiles = @()

if (Test-Path $exePath)
{
    $exeSize = (Get-Item $exePath).Length / 1KB
    Write-Host "  [OK] AutopilotLogViewer.exe ($($exeSize.ToString('F1')) KB)" -ForegroundColor Green
    Write-Verbose "Executable created: $exePath"
    $builtFiles += $exePath
}
else
{
    Write-Host "  [ERROR] AutopilotLogViewer.exe not found" -ForegroundColor Red
    $buildSuccess = $false
}

if (Test-Path $coreDllPath)
{
    $coreDllSize = (Get-Item $coreDllPath).Length / 1KB
    Write-Host "  [OK] Autopilot.LogViewer.Core.dll ($($coreDllSize.ToString('F1')) KB)" -ForegroundColor Green
    Write-Verbose "Core library created: $coreDllPath"
    $builtFiles += $coreDllPath
}
else
{
    Write-Host "  [ERROR] Autopilot.LogViewer.Core.dll not found" -ForegroundColor Red
    $buildSuccess = $false
}

if (Test-Path $logCoreDllPath)
{
    $logCoreDllSize = (Get-Item $logCoreDllPath).Length / 1KB
    Write-Host "  [OK] Autopilot.LogCore.dll ($($logCoreDllSize.ToString('F1')) KB)" -ForegroundColor Green
    Write-Verbose "Log core library created: $logCoreDllPath"
    $builtFiles += $logCoreDllPath
}
else
{
    Write-Host "  [ERROR] Autopilot.LogCore.dll not found" -ForegroundColor Red
    $buildSuccess = $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($buildSuccess)
{
    if (SignScripts -path @($BinFolder) -Recurse)
    {
        Write-Host "  [OK] Code signing completed" -ForegroundColor Green
    }
    else
    {
        Write-Host "  [WARNING] Code signing failed or skipped" -ForegroundColor Yellow                                         
    }

    Write-Host "  [OK] BUILD SUCCESSFUL" -ForegroundColor Green
    if ($ShowSummary)
    {
        Write-Host "========================================`n" -ForegroundColor Cyan
        Write-Verbose "Build completed successfully"
        Write-Host "Build Summary:" -ForegroundColor Yellow
        Write-Host "  Configuration: $Configuration" -ForegroundColor Gray
        Write-Host "  Framework: $Framework" -ForegroundColor Gray
        Write-Host "  Output: $publishPath" -ForegroundColor Gray
        Write-Host ""
        # Display output files
        Write-Host "Output Files:" -ForegroundColor Cyan
        $allFiles = Get-ChildItem "$publishPath\*" -File | Sort-Object Name
        $totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum / 1KB
        Write-Host "  Total: $($allFiles.Count) files ($($totalSize.ToString('F1')) KB)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Key Files:" -ForegroundColor Yellow
        Write-Host "  AutopilotLogViewer.exe - Main application" -ForegroundColor Gray
        Write-Host "  Autopilot.LogViewer.Core.dll - Log parsing engine" -ForegroundColor Gray
        Write-Host "  Autopilot.LogCore.dll - Logging infrastructure" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To run:" -ForegroundColor Yellow
        Write-Host "  $publishPath\AutopilotLogViewer.exe" -ForegroundColor Gray
        Write-Host "  # Or with a log file:" -ForegroundColor DarkGray
        Write-Host "  $publishPath\AutopilotLogViewer.exe `"C:\Path\To\Autopilot.log`"" -ForegroundColor Gray
        Write-Host ""
    }
    Write-Verbose "Build script completed successfully"
}
else
{
    Write-Host "  BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Verbose "Build failed: One or more required files missing"
    Write-Host "Some required files were not created. Check build output for errors." -ForegroundColor Red
    Write-Host ""
    exit 1
}
