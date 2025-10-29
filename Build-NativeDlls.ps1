<#
.SYNOPSIS
    Builds and publishes all C# performance DLLs for Autopilot with multi-target support
.DESCRIPTION
    Publishes Autopilot.GraphCore, Autopilot.DeviceCore, Autopilot.CacheCore, Autopilot.LogCore,
    Autopilot.ConfigCore, Autopilot.StringCore, Autopilot.CsvCore, and Autopilot.CollectionCore 
    projects into optimized DLLs for PowerShell integration with all dependencies. Outputs to 
    specified BinFolder/Configuration (e.g., bin/Release or bin/Debug). Provides 5-50x performance 
    improvement for critical operations.
.PARAMETER Configuration
    Build configuration: Debug or Release (default: Release)
.PARAMETER Framework
    Target framework: netstandard2.0 (PS 5.1), net9.0 (PS 7+), or All (default: All)
.PARAMETER BinFolder
    Root output directory for compiled binaries (default: bin)
.PARAMETER Clean
    Remove bin/ and obj/ directories before building
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
    Supports building for PowerShell 5.1 (netstandard2.0) and PowerShell 7+ (net9.0).
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [ValidateSet('netstandard2.0', 'net9.0', 'All')]
    [string]$Framework = 'All',
    [string]$BinFolder = 'bin',
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

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

# Find all C# projects
Write-Verbose "Searching for C# projects in src/ directory"
$projects = Get-ChildItem -Path "src" -Filter "*.csproj" -Recurse

if ($projects.Count -eq 0)
{
    Write-Host "  [ERROR] No C# projects found in src/ directory" -ForegroundColor Red
    Write-Verbose "Project search path: $((Get-Location).Path)\src"
    exit 1
}

Write-Host "Found $($projects.Count) projects:" -ForegroundColor Cyan
$projects | ForEach-Object {
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    Write-Host "  - $projectName" -ForegroundColor Gray
    Write-Verbose "  Project path: $($_.FullName)"
}
Write-Host ""

# Define target frameworks based on parameter
if ($Framework -eq 'All')
{
    $frameworks = @('netstandard2.0', 'net9.0')
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
    $psVersion = if ($fw -eq 'netstandard2.0') { "PowerShell 5.1 (.NET Framework 4.x)" } else { "PowerShell 7+ (.NET 9.0)" }
    Write-Host "  $fw -> $psVersion" -ForegroundColor Gray
}
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
Write-Verbose "Executing: dotnet restore Autopilot.sln --verbosity minimal"
try
{
    $restoreOutput = dotnet restore "Autopilot.sln" --verbosity minimal 2>&1
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

# Determine output directory strategy based on Framework parameter
# - If 'All': Use framework-specific subfolders (bin/Release/netstandard2.0, bin/Release/net9.0)
# - If specific framework: Use configuration folder directly (bin/Release)
$useFrameworkSubfolders = ($Framework -eq 'All')
Write-Verbose "Output strategy: $(if ($useFrameworkSubfolders) { 'Framework-specific subfolders' } else { 'Single configuration folder' })"

# Publish each project for each target framework
$buildSuccess = $true
$builtDlls = @{}  # Dictionary: framework -> array of DLL paths
$totalBuilds = $projects.Count * $frameworks.Count
$successCount = 0

Write-Verbose "Starting build process: $($projects.Count) projects x $($frameworks.Count) frameworks = $totalBuilds total builds"

foreach ($project in $projects)
{
    # Get the actual assembly name from the .csproj file
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project.Name)
    
    # Read the .csproj file to find the AssemblyName property
    $projectContent = Get-Content $project.FullName -Raw
    $assemblyNameMatch = [regex]::Match($projectContent, '<AssemblyName>([^<]+)</AssemblyName>')
    
    if ($assemblyNameMatch.Success)
    {
        $assemblyName = $assemblyNameMatch.Groups[1].Value
        Write-Verbose "Project $projectName uses custom AssemblyName: $assemblyName"
    }
    else
    {
        # If no AssemblyName is specified, use the project file name
        $assemblyName = $projectName
        Write-Verbose "Project $projectName uses default AssemblyName: $assemblyName"
    }
    
    foreach ($framework in $frameworks)
    {
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
        Write-Verbose "Project: $($project.FullName)"
        Write-Verbose "Framework: $framework"
        Write-Verbose "Output: $publishPath"
        
        $publishArgs = @(
            'publish'
            $project.FullName
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

if ($buildSuccess -and $successCount -eq $totalBuilds)
{
    Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Verbose "All builds completed successfully"
    Write-Host "Build Summary:" -ForegroundColor Yellow
    Write-Host "  Success: $successCount / $totalBuilds builds" -ForegroundColor Green
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
    Write-Host "Success: $successCount / $totalBuilds builds" -ForegroundColor Red
    Write-Verbose "Build failed: $successCount of $totalBuilds builds succeeded"
    Write-Host ""
    exit 1
}
