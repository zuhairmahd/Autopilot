<#
.SYNOPSIS
    Tests the C# stack overflow fix for deeply nested structures.

.DESCRIPTION
    Verifies that the iterative implementations in JsonParser and HashtableHelper
    can handle deeply nested structures (100+ levels) without stack overflow.
#>

[CmdletBinding()]
param()

Write-Host "`n=== Testing C# Deep Nesting Fix ===" -ForegroundColor Cyan

# Load the DLLs (dependencies first for PS 5.1 compatibility)
try
{
    $binPath = "$PSScriptRoot\..\bin\Release"
    if (-not (Test-Path $binPath))
    {
        Write-Host "ERROR: bin\Release folder not found at $binPath" -ForegroundColor Red
        exit 1
    }
    
    # Load dependencies in correct order for PS 5.1
    $dependencies = @(
        "System.Runtime.CompilerServices.Unsafe.dll"
        "System.Buffers.dll"
        "System.Memory.dll"
        "System.Numerics.Vectors.dll"
        "System.Text.Encodings.Web.dll"
        "System.Text.Json.dll"
        "System.Collections.Immutable.dll"
    )
    
    foreach ($dll in $dependencies)
    {
        $dllPath = Join-Path $binPath $dll
        if (Test-Path $dllPath)
        {
            try
            {
                Add-Type -Path $dllPath -ErrorAction SilentlyContinue
            }
            catch
            {
                # Ignore if already loaded
            }
        }
    }
    
    # Load main DLL
    $mainDll = Join-Path $binPath "Autopilot.ConfigCore.dll"
    if (-not (Test-Path $mainDll))
    {
        Write-Host "ERROR: Autopilot.ConfigCore.dll not found at $mainDll" -ForegroundColor Red
        exit 1
    }
    
    Add-Type -Path $mainDll
    Write-Host "[OK] Loaded Autopilot.ConfigCore.dll with dependencies" -ForegroundColor Green
}
catch
{
    Write-Host "ERROR loading DLL: $_" -ForegroundColor Red
    Write-Host "  Details: $($_.Exception.Message)" -ForegroundColor Gray
    exit 1
}

#region Test 1: Deep JSON Parsing
Write-Host "`n--- Test 1: Deep JSON Parsing (100 levels) ---" -ForegroundColor Yellow

$depth = 100
$json = ""
for ($i = 0; $i -lt $depth; $i++)
{
    $json += "{`"level$i`":"
}
$json += "`"deepValue`""
for ($i = 0; $i -lt $depth; $i++)
{
    $json += "}"
}

Write-Host "Created JSON with $depth levels of nesting"

try
{
    $result = [Autopilot.ConfigCore.JsonParser]::ParseToHashtable($json)
    Write-Host "[OK] Successfully parsed deeply nested JSON" -ForegroundColor Green
    Write-Host "  Result type: $($result.GetType().Name)" -ForegroundColor Gray
}
catch
{
    Write-Host "[FAIL] $_" -ForegroundColor Red
    Write-Host "  Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Gray
}
#endregion

#region Test 2: Deep Hashtable Cloning
Write-Host "`n--- Test 2: Deep Hashtable Cloning (100 levels) ---" -ForegroundColor Yellow

$depth = 100
$hashtable = @{}
$current = $hashtable
for ($i = 0; $i -lt $depth; $i++)
{
    $current["level$i"] = @{}
    $current = $current["level$i"]
}
$current["deepValue"] = "test"

Write-Host "Created hashtable with $depth levels of nesting"

try
{
    $cloned = [Autopilot.ConfigCore.HashtableHelper]::DeepClone($hashtable)
    Write-Host "[OK] Successfully cloned deeply nested hashtable" -ForegroundColor Green
    Write-Host "  Result type: $($cloned.GetType().Name)" -ForegroundColor Gray
}
catch
{
    Write-Host "[FAIL] $_" -ForegroundColor Red
    Write-Host "  Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Gray
}
#endregion

#region Test 3: Deep Hashtable Flattening
Write-Host "`n--- Test 3: Deep Hashtable Flattening (100 levels) ---" -ForegroundColor Yellow

try
{
    $flattened = [Autopilot.ConfigCore.HashtableHelper]::Flatten($hashtable)
    Write-Host "[OK] Successfully flattened deeply nested hashtable" -ForegroundColor Green
    Write-Host "  Result type: $($flattened.GetType().Name)" -ForegroundColor Gray
    Write-Host "  Keys count: $($flattened.Count)" -ForegroundColor Gray
    
    # Show sample key to verify depth
    $keys = @($flattened.Keys)
    if ($keys.Count -gt 0)
    {
        $sampleKey = $keys[0]
        $dotCount = ($sampleKey.ToCharArray() | Where-Object { $_ -eq '.' }).Count
        Write-Host "  Sample key: $sampleKey (depth: $($dotCount + 1))" -ForegroundColor Gray
    }
}
catch
{
    Write-Host "[FAIL] $_" -ForegroundColor Red
    Write-Host "  Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Gray
}
#endregion

#region Test 4: Extreme Depth (500 levels)
Write-Host "`n--- Test 4: Extreme Depth Test (500 levels) ---" -ForegroundColor Yellow

$depth = 500
$hashtable = @{}
$current = $hashtable
for ($i = 0; $i -lt $depth; $i++)
{
    $current["level$i"] = @{}
    $current = $current["level$i"]
}
$current["deepValue"] = "extreme"

Write-Host "Created hashtable with $depth levels of nesting"

try
{
    $cloned = [Autopilot.ConfigCore.HashtableHelper]::DeepClone($hashtable)
    Write-Host "[OK] Successfully handled $depth levels (clone)" -ForegroundColor Green
    
    $flattened = [Autopilot.ConfigCore.HashtableHelper]::Flatten($hashtable)
    Write-Host "[OK] Successfully handled $depth levels (flatten)" -ForegroundColor Green
    Write-Host "  Flattened keys: $($flattened.Count)" -ForegroundColor Gray
}
catch
{
    Write-Host "[FAIL] at extreme depth: $_" -ForegroundColor Red
}
#endregion

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "If all tests passed, the C# stack overflow issue is fixed!" -ForegroundColor Green
Write-Host ""
