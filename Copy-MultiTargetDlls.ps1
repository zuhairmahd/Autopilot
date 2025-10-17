<#
.SYNOPSIS
    Manually copy multi-targeted DLLs from obj to bin directory
.DESCRIPTION
    This script copies successfully compiled DLLs from the obj/Release directories
    to a properly structured bin/Release directory with netstandard2.0 and net9.0 subdirectories.
    Use this when the build succeeds but file locking prevents automatic copy.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

Write-Host "Copying multi-targeted DLLs from obj to bin directories..." -ForegroundColor Cyan

$projects = @(
    'Autopilot.GraphCore',
    'Autopilot.DeviceCore',
    'Autopilot.CacheCore',
    'Autopilot.LogCore'
)

$frameworks = @('netstandard2.0', 'net9.0')
$copiedCount = 0
$errors = @()

foreach ($project in $projects)
{
    foreach ($framework in $frameworks)
    {
        $srcDir = "src\$project\obj\$Configuration\$framework"
        $destDir = "bin\$Configuration\$framework"
        
        if (-not (Test-Path $srcDir))
        {
            Write-Warning "Source directory not found: $srcDir"
            continue
        }
        
        # Create destination directory
        if (-not (Test-Path $destDir))
        {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            Write-Verbose "Created directory: $destDir"
        }
        
        # Copy DLL and related files
        $dllName = "$project.dll"
        $srcDll = Join-Path $srcDir $dllName
        $destDll = Join-Path $destDir $dllName
        
        if (Test-Path $srcDll)
        {
            try
            {
                Copy-Item -Path $srcDll -Destination $destDll -Force
                Write-Host "  [OK] $project ($framework)" -ForegroundColor Green
                $copiedCount++
                
                # Copy related files (.pdb, .deps.json, .xml, etc.)
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($dllName)
                Get-ChildItem -Path $srcDir -Filter "$baseName.*" | ForEach-Object {
                    if ($_.Extension -ne '.dll')
                    {
                        Copy-Item -Path $_.FullName -Destination $destDir -Force
                        Write-Verbose "  Copied: $($_.Name)"
                    }
                }
                
                # Copy dependency DLLs (for packages like System.Text.Json)
                Get-ChildItem -Path $srcDir -Filter "*.dll" | Where-Object {
                    $_.Name -ne $dllName -and $_.Name -notlike "Autopilot.*"
                } | ForEach-Object {
                    $destDependency = Join-Path $destDir $_.Name
                    if (-not (Test-Path $destDependency))
                    {
                        Copy-Item -Path $_.FullName -Destination $destDir -Force
                        Write-Verbose "  Dependency: $($_.Name)"
                    }
                }
            }
            catch
            {
                $errorMsg = "Failed to copy $project ($framework): $_"
                Write-Warning $errorMsg
                $errors += $errorMsg
            }
        }
        else
        {
            Write-Warning "DLL not found: $srcDll"
        }
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Copied: $copiedCount DLLs" -ForegroundColor $(if ($copiedCount -gt 0) { 'Green' } else { 'Yellow' })
Write-Host "  Errors: $($errors.Count)" -ForegroundColor $(if ($errors.Count -eq 0) { 'Green' } else { 'Red' })

if ($errors.Count -gt 0)
{
    Write-Host "`nErrors encountered:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

Write-Host "`nMulti-targeted DLLs successfully copied!" -ForegroundColor Green
Write-Host "  netstandard2.0 DLLs: bin\$Configuration\netstandard2.0\" -ForegroundColor Gray
Write-Host "  net9.0 DLLs:         bin\$Configuration\net9.0\" -ForegroundColor Gray
