<#
.SYNOPSIS
    Diagnoses the C# stack overflow issue in PowerShell 5.1.

.DESCRIPTION
    Loads the C# DLLs and tests basic operations to identify where stack overflow occurs.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "`n=== C# Stack Overflow Diagnostic ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "CLR Version: $($PSVersionTable.CLRVersion)" -ForegroundColor White

# Check bin folder
$binPath = "$PSScriptRoot\..\bin\Release"
if (-not (Test-Path $binPath))
{
    Write-Host "ERROR: bin\Release not found" -ForegroundColor Red
    exit 1
}

$dllFiles = Get-ChildItem $binPath -Filter *.dll
Write-Host "`nFound $($dllFiles.Count) DLL files in bin\Release" -ForegroundColor Gray

# Test 1: Load dependencies
Write-Host "`n--- Test 1: Load Dependencies ---" -ForegroundColor Yellow

$dependencies = @(
    "System.Runtime.CompilerServices.Unsafe.dll",
    "System.Buffers.dll",
    "System.Memory.dll",
    "System.Text.Json.dll"
)

foreach ($dll in $dependencies)
{
    $path = Join-Path $binPath $dll
    if (Test-Path $path)
    {
        try
        {
            [System.Reflection.Assembly]::LoadFrom($path) | Out-Null
            Write-Host "  [OK] $dll" -ForegroundColor Green
        }
        catch
        {
            Write-Host "  [WARN] $dll - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else
    {
        Write-Host "  [SKIP] $dll not found" -ForegroundColor Gray
    }
}

# Test 2: Load Autopilot.ConfigCore
Write-Host "`n--- Test 2: Load Autopilot.ConfigCore ---" -ForegroundColor Yellow

try
{
    $configCorePath = Join-Path $binPath "Autopilot.ConfigCore.dll"
    $assembly = [System.Reflection.Assembly]::LoadFrom($configCorePath)
    Write-Host "  [OK] Loaded $($assembly.FullName)" -ForegroundColor Green
    
    $types = $assembly.GetExportedTypes()
    Write-Host "  Found $($types.Count) exported types:" -ForegroundColor Gray
    foreach ($type in $types)
    {
        Write-Host "    - $($type.Name)" -ForegroundColor Gray
    }
}
catch
{
    Write-Host "  [FAIL] $_" -ForegroundColor Red
    Write-Host "  $($_.Exception.ToString())" -ForegroundColor Gray
    exit 1
}

# Test 3: Create simple hashtable
Write-Host "`n--- Test 3: Simple Hashtable (5 levels) ---" -ForegroundColor Yellow

try
{
    $depth = 5
    $hashtable = @{}
    $current = $hashtable
    for ($i = 0; $i -lt $depth; $i++)
    {
        $current["level$i"] = @{}
        $current = $current["level$i"]
    }
    $current["value"] = "test"
    
    Write-Host "  Created hashtable with $depth levels" -ForegroundColor Gray
    
    $cloned = [Autopilot.ConfigCore.HashtableHelper]::DeepClone($hashtable)
    Write-Host "  [OK] DeepClone succeeded" -ForegroundColor Green
    
    $flattened = [Autopilot.ConfigCore.HashtableHelper]::Flatten($hashtable)
    Write-Host "  [OK] Flatten succeeded ($($flattened.Count) keys)" -ForegroundColor Green
}
catch
{
    Write-Host "  [FAIL] $_" -ForegroundColor Red
    Write-Host "  $($_.Exception.ToString())" -ForegroundColor Gray
}

# Test 4: Medium depth hashtable
Write-Host "`n--- Test 4: Medium Hashtable (25 levels) ---" -ForegroundColor Yellow

try
{
    $depth = 25
    $hashtable = @{}
    $current = $hashtable
    for ($i = 0; $i -lt $depth; $i++)
    {
        $current["level$i"] = @{}
        $current = $current["level$i"]
    }
    $current["value"] = "test"
    
    Write-Host "  Created hashtable with $depth levels" -ForegroundColor Gray
    
    $cloned = [Autopilot.ConfigCore.HashtableHelper]::DeepClone($hashtable)
    Write-Host "  [OK] DeepClone succeeded" -ForegroundColor Green
    
    $flattened = [Autopilot.ConfigCore.HashtableHelper]::Flatten($hashtable)
    Write-Host "  [OK] Flatten succeeded ($($flattened.Count) keys)" -ForegroundColor Green
}
catch
{
    Write-Host "  [FAIL] $_" -ForegroundColor Red
    Write-Host "  $($_.Exception.ToString())" -ForegroundColor Gray
}

# Test 5: Deep hashtable (100 levels)
Write-Host "`n--- Test 5: Deep Hashtable (100 levels) ---" -ForegroundColor Yellow

try
{
    $depth = 100
    $hashtable = @{}
    $current = $hashtable
    for ($i = 0; $i -lt $depth; $i++)
    {
        $current["level$i"] = @{}
        $current = $current["level$i"]
    }
    $current["value"] = "test"
    
    Write-Host "  Created hashtable with $depth levels" -ForegroundColor Gray
    
    Write-Host "  Testing DeepClone..." -ForegroundColor Gray
    $cloned = [Autopilot.ConfigCore.HashtableHelper]::DeepClone($hashtable)
    Write-Host "  [OK] DeepClone succeeded" -ForegroundColor Green
    
    Write-Host "  Testing Flatten..." -ForegroundColor Gray
    $flattened = [Autopilot.ConfigCore.HashtableHelper]::Flatten($hashtable)
    Write-Host "  [OK] Flatten succeeded ($($flattened.Count) keys)" -ForegroundColor Green
}
catch
{
    Write-Host "  [FAIL] $_" -ForegroundColor Red
    if ($_.Exception.InnerException)
    {
        Write-Host "  Inner: $($_.Exception.InnerException.Message)" -ForegroundColor Gray
    }
}

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host ""
