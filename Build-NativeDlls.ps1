<#
.SYNOPSIS
    Builds and publishes Autopilot native DLLs from both solutions with multi-target support
.DESCRIPTION
    This script builds two solutions in order:
      1) Autopilot.sln (root) and
      2) autopilotLogViewer/AutopilotLogViewer.sln (subtree module)

    Projects are resolved from the solution files (not by scanning the repo) and published to
    bin/<Configuration>/<Framework> (e.g., bin/Release/netstandard2.0). Shared projects across
    the two solutions are de-duplicated by AssemblyName so they are built only once even if
    present in both solutions. The autopilotLogViewer subtree is optional; if its solution is
    missing, the build continues for the root solution only.

    Provides 5-50x performance improvement for critical operations by shipping optimized C# DLLs.
.PARAMETER Configuration
    Build configuration: Debug or Release (default: Release)
.PARAMETER Framework
    Target framework: netstandard2.0 (PS 5.1), net9.0 (PS 7+), net9.0-windows (WPF), or All (default: All)
.PARAMETER BinFolder
    Root output directory for compiled binaries (default: bin)
.PARAMETER Clean
    Remove bin/ and obj/ directories before building (covers both src/ and autopilotLogViewer/src/)
.PARAMETER Verbose
    Show detailed build output
.EXAMPLE
    .\Build-NativeDlls.ps1 -Configuration Release
    Builds all frameworks to bin/Release
.EXAMPLE
    .\Build-NativeDlls.ps1 -Framework netstandard2.0 -Configuration Debug
    Builds only netstandard2.0 to bin/Debug
.EXAMPLE
    .\Build-NativeDlls.ps1 -Clean -Verbose -BinFolder "output"
    Cleans and builds all frameworks to output/Release with verbose logging
.NOTES
    Uses 'dotnet publish' to ensure all NuGet dependencies are included.
    Supports building for PowerShell 5.1 (netstandard2.0), PowerShell 7+ (net9.0), and WPF (net9.0-windows).
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [ValidateSet('netstandard2.0', 'net9.0', 'net9.0-windows', 'All')]
    [string]$Framework = 'All',
    [string]$BinFolder = 'bin',
    [switch]$Clean,
    [switch]$signOnly
)

$ErrorActionPreference = 'Stop'
$solutionFiles = @("Autopilot.sln", ".\autopilotLogViewer\AutopilotLogViewer.sln")
$requiredSolutions = @("Autopilot.sln")
$restoredSolutions = @()
Write-Verbose "Starting Autopilot C# DLL Build & Publish"
Write-Verbose "Configuration: $Configuration"
Write-Verbose "Framework: $Framework"
Write-Verbose "Output Directory: $BinFolder\$Configuration"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Autopilot C# DLL Build & Publish" -ForegroundColor Cyan
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

#region helper functions
# Helper: parse .sln to get project csproj paths
function Get-SolutionProjects
{
    param(
        [Parameter(Mandatory)] [string] $SolutionPath
    )
    if ([string]::IsNullOrWhiteSpace($SolutionPath))
    {
        Write-Verbose "Get-SolutionProjects called with empty SolutionPath; returning no projects"
        return @()
    }
    if (-not (Test-Path -LiteralPath $SolutionPath))
    {
        Write-Verbose "Solution not found at path '$SolutionPath'"
        return @()
    }
    try
    {
        $resolved = (Resolve-Path -LiteralPath $SolutionPath).Path
    }
    catch
    {
        Write-Verbose "Failed to resolve solution path '$SolutionPath'"
        return @()
    }
    $solutionDir = [System.IO.Path]::GetDirectoryName($resolved)
    if ([string]::IsNullOrWhiteSpace($solutionDir)) { $solutionDir = (Get-Location).Path }
    $content = Get-Content -LiteralPath $resolved -Raw
    $matches = [regex]::Matches($content, 'Project\(".*?"\)\s*=\s*".*?",\s*"(.*?)",\s*"\{.*?\}"', 'IgnoreCase')
    $csprojs = @()
    foreach ($m in $matches)
    {
        $rel = $m.Groups[1].Value
        if ($rel -and $rel.ToLower().EndsWith('.csproj'))
        {
            $full = [System.IO.Path]::GetFullPath((Join-Path $solutionDir $rel))
            if (Test-Path $full)
            {
                $csprojs += $full
            }
            else
            {
                Write-Verbose "Solution '$SolutionPath' references missing project: $rel (resolved: $full)"
            }
        }
    }
    return $csprojs
}

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

# Helper: get AssemblyName from csproj (fallback to filename)
function Get-AssemblyNameFromCsproj
{
    param(
        [Parameter(Mandatory)] [string] $ProjectPath
    )
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
    try
    {
        $xml = Get-Content -Path $ProjectPath -Raw
        $m = [regex]::Match($xml, '<AssemblyName>([^<]+)</AssemblyName>')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    catch {}
    return $projectName
}
#endregion helper functions

if ($signOnly)
{
    Write-Host "SignOnly parameter specified; skipping build and signing existing DLLs in $BinFolder" -ForegroundColor Yellow
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
# Gather projects from solutions in order and de-duplicate by AssemblyName
$solutionProjectMap = @{}
$selectedProjects = New-Object System.Collections.Generic.List[object]
$seenAssemblies = New-Object 'System.Collections.Generic.HashSet[string]'

Write-Verbose "Gathering C# projects from solutions and de-duplicating by AssemblyName"
foreach ($solution in $solutionFiles)
{
    Write-Host "  Inspect: solution item -> '$solution'" -ForegroundColor DarkGray
    if (-not (Test-Path $solution)) { continue }
    $projPaths = Get-SolutionProjects -SolutionPath $solution
    $solutionProjectMap[$solution] = $projPaths
}

if (-not $solutionProjectMap.ContainsKey('Autopilot.sln'))
{
    Write-Host "  [ERROR] Required solution not found: Autopilot.sln" -ForegroundColor Red
    exit 1
}

Write-Host "Projects discovered per solution:" -ForegroundColor Cyan
foreach ($kvp in $solutionProjectMap.GetEnumerator())
{
    $sol = $kvp.Key
    $list = $kvp.Value
    Write-Host "  - $sol ($($list.Count))" -ForegroundColor Gray
}
Write-Host ""

# Respect order: root first, then subtree
foreach ($solution in $solutionFiles)
{
    if (-not $solutionProjectMap.ContainsKey($solution)) { continue }
    foreach ($proj in $solutionProjectMap[$solution])
    {
        $asm = Get-AssemblyNameFromCsproj -ProjectPath $proj
        if ($seenAssemblies.Contains($asm))
        {
            Write-Verbose "Skipping duplicate assembly '$asm' from $solution (already selected)"
            continue
        }
        [void]$seenAssemblies.Add($asm)
        $selectedProjects.Add([pscustomobject]@{
                Path         = $proj
                AssemblyName = $asm
                Solution     = $solution
            })
    }
}

if ($selectedProjects.Count -eq 0)
{
    Write-Host "  [ERROR] No C# projects resolved from solutions" -ForegroundColor Red
    exit 1
}

Write-Host "Selected unique projects to build ($($selectedProjects.Count)):" -ForegroundColor Cyan
foreach ($p in $selectedProjects)
{
    Write-Host "  - $($p.AssemblyName) ($([System.IO.Path]::GetFileName($p.Path))) from $($p.Solution)" -ForegroundColor Gray
    Write-Verbose "    Project path: $($p.Path)"
}
Write-Host ""

# Define target frameworks based on parameter
if ($Framework -eq 'All')
{
    $frameworks = @('netstandard2.0', 'net9.0', 'net9.0-windows')
    Write-Verbose "Building all frameworks: $($frameworks -join ', ')"
}
else
{
    $frameworks = @($Framework)
    Write-Verbose "Building single framework: $Framework"
}

Write-Host "Target Framework(s): $($frameworks -join ', ')" -ForegroundColor Cyan
foreach ($fw in $frameworks)
{
    $psVersion = switch ($fw)
    {
        'netstandard2.0' { "PowerShell 5.1 (.NET Framework 4.x)" }
        'net9.0' { "PowerShell 7+ (.NET 9.0)" }
        'net9.0-windows' { "PowerShell 7+ / WPF Applications (.NET 9.0)" }
        default { "Unknown" }
    }
    Write-Host "  $fw -> $psVersion" -ForegroundColor Gray
}
Write-Host ""

# Clean if requested
if ($Clean)
{
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    Write-Verbose "Removing bin and obj directories from src/ and autopilotLogViewer/src/"
    $cleanedDirs = 0
    foreach ($root in @('src', 'autopilotLogViewer/src'))
    {
        if (Test-Path $root)
        {
            Get-ChildItem -Path $root -Include "bin", "obj" -Recurse -Directory | ForEach-Object {
                Write-Verbose "  Removing: $($_.FullName)"
                Remove-Item $_.FullName -Recurse -Force
                $cleanedDirs++
            }
        }
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

# Restore NuGet packages per selected project (avoids solution-level missing project failures)
Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
Write-Verbose "Executing restore for each selected project"
try
{
    $restored = 0
    foreach ($p in $selectedProjects)
    {
        Write-Verbose "Restoring packages for project: $($p.Path)"
        $restoreOutput = dotnet restore $p.Path --verbosity minimal 2>&1
        if ($LASTEXITCODE -ne 0)
        {
            Write-Host "  [ERROR] NuGet restore failed for $($p.Path)" -ForegroundColor Red
            Write-Verbose "Restore exit code: $LASTEXITCODE"
            Write-Host $restoreOutput -ForegroundColor Red
            exit 1
        }
        $restored++
    }
    Write-Host "  [OK] Packages restored for $restored project(s)" -ForegroundColor Green
    Write-Verbose "NuGet restore completed successfully for selected projects"
    Write-Host ""
}
catch
{
    Write-Host "  [ERROR] Failed to restore packages: $_" -ForegroundColor Red
    Write-Verbose "Exception: $($_.Exception.Message)"
    exit 1
}

# Determine output directory strategy based on Framework parameter
# - If 'All': Use framework-specific subfolders (bin/Release/netstandard2.0, bin/Release/net9.0)
# - If specific framework: Use configuration folder directly (bin/Release)
$useFrameworkSubfolders = ($Framework -eq 'All')
Write-Verbose "Output strategy: $(if ($useFrameworkSubfolders) { 'Framework-specific subfolders' } else { 'Single configuration folder' })"

# Publish each selected project for each target framework
$buildSuccess = $true
$builtDlls = @{}  # Dictionary: framework -> array of DLL paths
$totalBuilds = $selectedProjects.Count * $frameworks.Count
$successCount = 0
$skipCount = 0

Write-Verbose "Starting build process: $($selectedProjects.Count) projects x $($frameworks.Count) frameworks = $totalBuilds total builds"

foreach ($project in $selectedProjects)
{
    # Get the actual assembly name from the .csproj file
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project.Path)
    
    # Read the .csproj file to find the AssemblyName property and target frameworks
    $projectContent = Get-Content $project.Path -Raw
    $assemblyNameMatch = [regex]::Match($projectContent, '<AssemblyName>([^<]+)</AssemblyName>')
    
    if ($assemblyNameMatch.Success)
    {
        $assemblyName = $assemblyNameMatch.Groups[1].Value
        Write-Verbose "Project $projectName uses custom AssemblyName: $assemblyName"
    }
    else
    {
        # If no AssemblyName is specified, use the project file name
        $assemblyName = $project.AssemblyName
        Write-Verbose "Project $projectName uses default AssemblyName: $assemblyName"
    }
    
    # Detect project's target frameworks
    $projectFrameworks = @()
    $targetFrameworksMatch = [regex]::Match($projectContent, '<TargetFrameworks>([^<]+)</TargetFrameworks>')
    $targetFrameworkMatch = [regex]::Match($projectContent, '<TargetFramework>([^<]+)</TargetFramework>')
    
    if ($targetFrameworksMatch.Success)
    {
        # Multiple frameworks (TargetFrameworks with 's')
        $projectFrameworks = $targetFrameworksMatch.Groups[1].Value -split ';' | ForEach-Object { $_.Trim() }
        Write-Verbose "Project $projectName targets multiple frameworks: $($projectFrameworks -join ', ')"
    }
    elseif ($targetFrameworkMatch.Success)
    {
        # Single framework (TargetFramework without 's')
        $projectFrameworks = @($targetFrameworkMatch.Groups[1].Value.Trim())
        Write-Verbose "Project $projectName targets single framework: $($projectFrameworks -join ', ')"
    }
    else
    {
        Write-Warning "Could not detect target frameworks for $projectName, skipping"
        continue
    }
    
    foreach ($framework in $frameworks)
    {
        # Skip if project doesn't support this framework
        if ($projectFrameworks -notcontains $framework)
        {
            Write-Verbose "Skipping $projectName ($framework) - project does not target this framework"
            Write-Host "  [SKIP] $projectName does not target $framework" -ForegroundColor Yellow
            $skipCount++
            continue
        }
        
        # Determine output path based on strategy
        if ($useFrameworkSubfolders)
        {
            $publishPath = Join-Path (Join-Path $BinFolder $Configuration) $framework
        }
        else
        {
            $publishPath = Join-Path $BinFolder $Configuration
        }
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $publishPath))
        {
            Write-Verbose "Creating output directory: $publishPath"
            New-Item -ItemType Directory -Path $publishPath -Force | Out-Null
        }
        
        Write-Host "Publishing $projectName ($framework)..." -ForegroundColor Cyan
        Write-Verbose "Project: $($project.Path)"
        Write-Verbose "Framework: $framework"
        Write-Verbose "Output: $publishPath"
        
        $publishArgs = @(
            'publish'
            $project.Path
            '--configuration', $Configuration
            '--framework', $framework
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
            Write-Host "  [FAILED] Publish failed for $projectName ($framework)" -ForegroundColor Red
            Write-Verbose "Exit code: $LASTEXITCODE"
            if ($VerbosePreference -eq 'Continue')
            {
                Write-Host $publishOutput -ForegroundColor Red
            }
            $buildSuccess = $false
        }
        else
        {
            $dllPath = Join-Path $publishPath "$assemblyName.dll"
            if (Test-Path $dllPath)
            {
                $dllSize = (Get-Item $dllPath).Length / 1KB
                Write-Host "  [OK] $assemblyName.dll ($($dllSize.ToString('F1')) KB)" -ForegroundColor Green
                Write-Verbose "DLL created: $dllPath"
                
                # Track DLLs per framework
                if (-not $builtDlls.ContainsKey($framework))
                {
                    $builtDlls[$framework] = @()
                }
                $builtDlls[$framework] += $dllPath
                $successCount++
            }
            else
            {
                Write-Verbose "Warning: Expected DLL not found at $dllPath"
            }
        }
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan

$attemptedBuilds = $totalBuilds - $skipCount

if ($buildSuccess -and $successCount -eq $attemptedBuilds)
{
    Write-Host "Signing published DLLs..." -ForegroundColor Yellow
    if (SignScripts -path @($BinFolder) -Recurse)
    {
        Write-Host "  [OK] Code signing completed" -ForegroundColor Green
    }
    else
    {
        Write-Host "  [WARNING] Code signing failed or skipped" -ForegroundColor Yellow                                         
    }
    Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Verbose "All builds completed successfully"
    Write-Host "Build Summary:" -ForegroundColor Yellow
    Write-Host "  Success: $successCount / $attemptedBuilds builds" -ForegroundColor Green
    if ($skipCount -gt 0)
    {
        Write-Host "  Skipped: $skipCount builds (incompatible frameworks)" -ForegroundColor Yellow
    }
    Write-Host "  Configuration: $Configuration" -ForegroundColor Gray
    Write-Host "  Framework(s): $($frameworks -join ', ')" -ForegroundColor Gray
    Write-Host ""
    
    # Display output directories and files
    if ($useFrameworkSubfolders)
    {
        # Multiple frameworks - show each framework's output
        Write-Host "Output Directories:" -ForegroundColor Cyan
        foreach ($framework in $frameworks)
        {
            $frameworkPath = Join-Path (Join-Path $BinFolder $Configuration) $framework
            $frameworkDllCount = (Get-ChildItem "$frameworkPath\*.dll" -ErrorAction SilentlyContinue).Count
            $psVersion = if ($framework -eq 'netstandard2.0') { "PowerShell 5.1" } else { "PowerShell 7+" }
            Write-Host "  $frameworkPath ($frameworkDllCount DLLs, $psVersion)" -ForegroundColor Gray
            Write-Verbose "Framework $framework output: $frameworkPath with $frameworkDllCount DLL files"
            
            if ($builtDlls.ContainsKey($framework))
            {
                $builtDlls[$framework] | ForEach-Object {
                    $fileName = Split-Path $_ -Leaf
                    Write-Host "    - $fileName" -ForegroundColor DarkGray
                    Write-Verbose "      Full path: $_"
                }
            }
        }
    }
    else
    {
        # Single framework - show single output directory
        $outputPath = Join-Path $BinFolder $Configuration
        $allDllCount = (Get-ChildItem "$outputPath\*.dll" -ErrorAction SilentlyContinue).Count
        Write-Host "Output Directory: $outputPath ($allDllCount DLL files total)" -ForegroundColor Cyan
        Write-Verbose "Output directory contains $allDllCount DLL files"
        
        foreach ($framework in $builtDlls.Keys)
        {
            $builtDlls[$framework] | ForEach-Object {
                $fileName = Split-Path $_ -Leaf
                Write-Host "  - $fileName" -ForegroundColor Gray
                Write-Verbose "    Full path: $_"
            }
        }
    }
    Write-Host ""
    
    Write-Host "To use in PowerShell:" -ForegroundColor Yellow
    if ($useFrameworkSubfolders)
    {
        Write-Host "  `$dllStatus = Initialize-AutopilotDlls -DLLPath '$BinFolder\$Configuration'" -ForegroundColor Gray
        Write-Host "  # Automatically selects correct framework based on PS version" -ForegroundColor DarkGray
    }
    else
    {
        $outputPath = Join-Path $BinFolder $Configuration
        Write-Host "  Add-Type -Path '$outputPath\<DllName>.dll'" -ForegroundColor Gray
        Write-Host "  # Or use Initialize-AutopilotDlls for automatic loading" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    Write-Host "Example usage:" -ForegroundColor Yellow
    Write-Host "  `$client = [Autopilot.GraphCore.GraphHttpClient]::new(`$accessToken)" -ForegroundColor Gray
    Write-Host "  `$devices = `$client.GetAsync('devices').GetAwaiter().GetResult()" -ForegroundColor Gray
    Write-Host ""
    
    Write-Verbose "Build script completed successfully"
}
else
{
    Write-Host "  BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Verbose "Build failed: $successCount of $attemptedBuilds builds succeeded"
    Write-Host "Success: $successCount / $attemptedBuilds builds" -ForegroundColor Red
    if ($skipCount -gt 0)
    {
        Write-Host "Skipped: $skipCount builds (incompatible frameworks)" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 1
}
