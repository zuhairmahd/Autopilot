<#
.SYNOPSIS
    Builds and publishes all C# performance DLLs for Autopilot with multi-target support
.DESCRIPTION
    Publishes Autopilot.GraphCore, Autopilot.DeviceCore, Autopilot.CacheCore, and Autopilot.LogCore
    projects into optimized DLLs for PowerShell integration with all dependencies.
    Outputs to bin/Release/netstandard2.0 (PS 5.1) and bin/Release/net9.0 (PS 7+).
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
.NOTES
    Uses 'dotnet publish' to ensure all NuGet dependencies are included.
    Creates multi-target output for PowerShell 5.1 (netstandard2.0) and PowerShell 7+ (net9.0).
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Autopilot C# DLL Build & Publish" -ForegroundColor Cyan
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

$framework = 'netstandard2.0'
Write-Host "  netstandard2.0 -> PowerShell 5.1 (.NET Framework 4.x)" -ForegroundColor Gray
Write-Host ""

# Clean if requested
if ($Clean)
{
    Write-Host "Cleaning build artifacts..." -ForegroundColor Yellow
    Get-ChildItem -Path "src" -Include "bin", "obj" -Recurse -Directory | Remove-Item -Recurse -Force | Out-Null
    if (Test-Path "bin")
    {
        Remove-Item "bin" -Recurse -Force | Out-Null
    }
    Write-Host "  [OK] Cleaned" -ForegroundColor Green
    Write-Host ""
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
    Write-Host "  [OK] Packages restored" -ForegroundColor Green
    Write-Host ""
}
catch
{
    Write-Host "  [ERROR] Failed to restore packages: $_" -ForegroundColor Red
    exit 1
}

$publishRoot = "bin\$Configuration"
$buildSuccess = $true
$builtDlls = @{}  # Dictionary: framework -> array of DLL paths
$totalBuilds = $projects.Count
$successCount = 0

foreach ($project in $projects)
{
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project.Name)
    
    Write-Host "Publishing $projectName ($framework)..." -ForegroundColor Cyan
    #write-vverbose the parameters passed to dotnet publish.
    Write-Host "  dotnet publish $($project.FullName) --configuration $Configuration --framework $framework --output $publishRoot" -ForegroundColor Gray
    $publishArgs = @(
        'publish'
        $project.FullName
        '--configuration', $Configuration
        '--framework', $framework
        '--output', $publishRoot
        '--no-self-contained'
        '/p:DebugType=portable'
        '--nologo'
    )
    if ($VerbosePreference -eq 'Continue')
    {
        $publishArgs += '--verbosity', 'detailed'
    }
    else
    {
        $publishArgs += '--verbosity', 'minimal'
    }
    $publishOutput = & dotnet @publishArgs 2>&1
    if ($LASTEXITCODE -ne 0)
    {
        Write-Host "  [FAILED] Publish failed for $projectName ($framework)" -ForegroundColor Red
        if ($VerbosePreference -eq 'Continue')
        {
            Write-Host $publishOutput -ForegroundColor Red
        }
        $buildSuccess = $false
    }
    else
    {
        $dllPath = Join-Path $publishRoot "$projectName.dll"
        if (Test-Path $dllPath)
        {
            $dllSize = (Get-Item $dllPath).Length / 1KB
            Write-Host "  [OK] $projectName.dll ($($dllSize.ToString('F1')) KB)" -ForegroundColor Green
                
            if (-not $builtDlls.ContainsKey($framework))
            {
                $builtDlls[$framework] = @()
            }
            $builtDlls[$framework] += $dllPath
            $successCount++
        }
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan

if ($buildSuccess -and $successCount -eq $totalBuilds)
{
    Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Host "Build Summary:" -ForegroundColor Yellow
    Write-Host "  Success: $successCount / $totalBuilds builds" -ForegroundColor Green
    Write-Host ""
    
    if ($builtDlls.ContainsKey($framework))
    {
        $allDllCount = (Get-ChildItem "$publishRoot\*.dll" -ErrorAction SilentlyContinue).Count
        Write-Host "$framework ($allDllCount DLL files total):" -ForegroundColor Cyan
        $builtDlls[$framework] | ForEach-Object {
            $fileName = Split-Path $_ -Leaf
            Write-Host "  - $fileName" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "Output Directory:" -ForegroundColor Yellow
    Write-Host "  $publishRoot (PowerShell 5.1 - netstandard2.0)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "To use in PowerShell 5.1:" -ForegroundColor Yellow
    Write-Host "  `$dllStatus = Initialize-AutopilotDlls -DLLPath '$publishRoot'" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Example usage:" -ForegroundColor Yellow
    Write-Host "  `$client = [Autopilot.GraphCore.GraphHttpClient]::new(`$accessToken)" -ForegroundColor Gray
    Write-Host "  `$devices = `$client.GetAsync('devices').GetAwaiter().GetResult()" -ForegroundColor Gray
    Write-Host ""
}
else
{
    Write-Host "  BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "Success: $successCount / $totalBuilds builds" -ForegroundColor Red
    Write-Host ""
    exit 1
}
