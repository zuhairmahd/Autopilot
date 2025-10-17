<#
.SYNOPSIS
    Builds and publishes all C# DLLs with dependencies for multi-target support
.DESCRIPTION
    Publishes Autopilot DLLs (GraphCore, DeviceCore, CacheCore, LogCore) with all
    dependencies to bin/Release/netstandard2.0 and bin/Release/net9.0 directories.
    Uses dotnet publish to ensure all NuGet dependencies are included.
.PARAMETER Configuration
    Build configuration: Debug or Release
.EXAMPLE
    .\Build-And-Publish-Dlls.ps1 -Configuration Release
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Autopilot DLL Build & Publish" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verify .NET SDK
Write-Host "Checking .NET SDK..." -ForegroundColor Yellow
try
{
    $dotnetVersion = dotnet --version
    Write-Host "  [OK] .NET SDK $dotnetVersion`n" -ForegroundColor Green
}
catch
{
    Write-Host "  [ERROR] .NET SDK not found`n" -ForegroundColor Red
    exit 1
}

$projects = @(
    'Autopilot.GraphCore',
    'Autopilot.DeviceCore',
    'Autopilot.CacheCore',
    'Autopilot.LogCore'
)

$frameworks = @('netstandard2.0', 'net9.0')
$publishRoot = "bin\$Configuration"

# Clean output directories
Write-Host "Cleaning output directories..." -ForegroundColor Yellow
if (Test-Path $publishRoot)
{
    Remove-Item -Path $publishRoot -Recurse -Force
}

foreach ($framework in $frameworks)
{
    $outputDir = Join-Path $publishRoot $framework
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "  [OK] Output directories ready`n" -ForegroundColor Green

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

# Build and publish each project
$successCount = 0
$totalProjects = $projects.Count * $frameworks.Count

foreach ($project in $projects)
{
    foreach ($framework in $frameworks)
    {
        $projectPath = "src\$project\$project.csproj"
        $outputDir = Join-Path $publishRoot $framework
        
        Write-Host "Publishing $project ($framework)..." -ForegroundColor Yellow
        
        try
        {
            $result = dotnet publish $projectPath `
                -c $Configuration `
                -f $framework `
                -o $outputDir `
                --no-self-contained `
                /p:DebugType=portable `
                2>&1
                
            if ($LASTEXITCODE -eq 0)
            {
                Write-Host "  [OK] $project ($framework)" -ForegroundColor Green
                $successCount++
            }
            else
            {
                Write-Host "  [FAIL] $project ($framework)" -ForegroundColor Red
                Write-Host "  Error: $result" -ForegroundColor DarkRed
            }
        }
        catch
        {
            Write-Host "  [FAIL] $project ($framework): $_" -ForegroundColor Red
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build Summary:" -ForegroundColor Cyan
Write-Host "  Success: $successCount / $totalProjects" -ForegroundColor $(if ($successCount -eq $totalProjects) { 'Green' } else { 'Yellow' })

if ($successCount -eq $totalProjects)
{
    Write-Host "`nAll DLLs published successfully!" -ForegroundColor Green
    Write-Host "  Output: $publishRoot\netstandard2.0\ (for PowerShell 5.1)" -ForegroundColor Gray
    Write-Host "  Output: $publishRoot\net9.0\ (for PowerShell 7+)" -ForegroundColor Gray
    
    # Show file counts
    $ns20Count = (Get-ChildItem "$publishRoot\netstandard2.0\*.dll").Count
    $net9Count = (Get-ChildItem "$publishRoot\net9.0\*.dll").Count
    Write-Host "`n  netstandard2.0: $ns20Count DLLs" -ForegroundColor Gray
    Write-Host "  net9.0: $net9Count DLLs" -ForegroundColor Gray
    
    exit 0
}
else
{
    Write-Host "`nSome builds failed. Check errors above." -ForegroundColor Red
    exit 1
}
