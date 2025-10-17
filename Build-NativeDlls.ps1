<#
.SYNOPSIS
    Compiles all C# performance DLLs for Autopilot
.DESCRIPTION
    Builds Autopilot.GraphCore, Autopilot.DeviceCore, and Autopilot.CacheCore
    projects into optimized DLLs for PowerShell integration.
    Provides 5-50x performance improvement for critical operations.
.PARAMETER Configuration
    Build configuration: Debug or Release
.PARAMETER Clean
    Remove bin/ and obj/ directories before building
.PARAMETER Verbose
    Show detailed build output
.EXAMPLE
    .\Build-NativeDlls.ps1 -Configuration Release
.EXAMPLE
    .\Build-NativeDlls.ps1 -Clean -Verbose
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Autopilot C# DLL Build Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verify .NET SDK
Write-Host "Checking .NET SDK..." -ForegroundColor Yellow
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
$projects = Get-ChildItem -Path "src" -Filter "*.csproj" -Recurse

if ($projects.Count -eq 0)
{
    Write-Host "  [ERROR] No C# projects found in src/ directory" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($projects.Count) projects:" -ForegroundColor Cyan
$projects | ForEach-Object {
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    Write-Host "  - $projectName" -ForegroundColor Gray
}
Write-Host ""

# Clean if requested
if ($Clean)
{
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    Get-ChildItem -Path "src" -Include "bin", "obj" -Recurse -Directory | Remove-Item -Recurse -Force
    if (Test-Path "bin")
    {
        Remove-Item "bin" -Recurse -Force
    }
    Write-Host "  [OK] Cleaned`n" -ForegroundColor Green
}

# Restore NuGet packages
Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
try
{
    $restoreOutput = dotnet restore "Autopilot.sln" --verbosity minimal 2>&1
    if ($LASTEXITCODE -ne 0)
    {
        Write-Host "  [ERROR] NuGet restore failed" -ForegroundColor Red
        Write-Host $restoreOutput -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] Packages restored`n" -ForegroundColor Green
}
catch
{
    Write-Host "  [ERROR] Failed to restore packages: $_" -ForegroundColor Red
    exit 1
}

# Create output directory
$outputDir = "bin/$Configuration"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# Build each project
$buildSuccess = $true
$builtDlls = @()

foreach ($project in $projects)
{
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project.Name)
    Write-Host "Building $projectName..." -ForegroundColor Cyan
    
    $buildArgs = @(
        'build'
        $project.FullName
        '--configuration', $Configuration
        '--output', $outputDir
        '--nologo'
    )
    
    if ($VerbosePreference -eq 'Continue')
    {
        $buildArgs += '--verbosity', 'detailed'
    }
    else
    {
        $buildArgs += '--verbosity', 'minimal'
    }
    
    $buildOutput = & dotnet @buildArgs 2>&1
    
    if ($LASTEXITCODE -ne 0)
    {
        Write-Host "  [FAILED] Build failed for $projectName" -ForegroundColor Red
        Write-Host $buildOutput -ForegroundColor Red
        $buildSuccess = $false
    }
    else
    {
        $dllPath = Join-Path $outputDir "$projectName.dll"
        if (Test-Path $dllPath)
        {
            $dllSize = (Get-Item $dllPath).Length / 1KB
            Write-Host "  [OK] $projectName.dll ($($dllSize.ToString('F1')) KB)" -ForegroundColor Green
            $builtDlls += $dllPath
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan

if ($buildSuccess)
{
    Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Host "Compiled DLLs:" -ForegroundColor Yellow
    $builtDlls | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
    
    Write-Host "`nTo use in PowerShell:" -ForegroundColor Yellow
    Write-Host "  Add-Type -Path '$outputDir\Autopilot.GraphCore.dll'" -ForegroundColor Gray
    Write-Host "  Add-Type -Path '$outputDir\Autopilot.DeviceCore.dll'" -ForegroundColor Gray
    Write-Host "  Add-Type -Path '$outputDir\Autopilot.CacheCore.dll'" -ForegroundColor Gray
    
    Write-Host "`nExample usage:" -ForegroundColor Yellow
    Write-Host "  `$client = [Autopilot.GraphCore.GraphHttpClient]::new(`$accessToken)" -ForegroundColor Gray
    Write-Host "  `$devices = `$client.GetAsync('devices').GetAwaiter().GetResult()" -ForegroundColor Gray
    Write-Host ""
}
else
{
    Write-Host "  BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Cyan
    exit 1
}
