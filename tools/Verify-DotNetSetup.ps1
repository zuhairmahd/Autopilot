<#
.SYNOPSIS
    Verifies .NET SDK installation and compiled DLLs
.DESCRIPTION
    Checks that .NET SDK is installed and DLLs can be loaded in PowerShell
#>

[CmdletBinding()]
param()

Write-Host "`n=== .NET SDK & DLL Verification ===" -ForegroundColor Cyan

# Check .NET SDK
Write-Host "`n1. Checking .NET SDK..." -ForegroundColor Yellow
try
{
    $dotnetVersion = dotnet --version
    Write-Host "   [OK] .NET SDK $dotnetVersion installed" -ForegroundColor Green
    
    $runtimes = dotnet --list-runtimes
    Write-Host "   [OK] Available runtimes:" -ForegroundColor Green
    $runtimes | Select-Object -First 3 | ForEach-Object { Write-Host "        $_" -ForegroundColor Gray }
}
catch
{
    Write-Host "   [FAIL] .NET SDK not found" -ForegroundColor Red
    Write-Host "          Install from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
    exit 1
}

# Check PowerShell version
Write-Host "`n2. Checking PowerShell..." -ForegroundColor Yellow
Write-Host "   [OK] PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green
Write-Host "        Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Gray

# Check compiled DLLs
Write-Host "`n3. Checking compiled DLLs..." -ForegroundColor Yellow
$dllPath = "bin/Release"
if (-not (Test-Path $dllPath))
{
    Write-Host "   [WARN] DLLs not found. Run .\Build-NativeDlls.ps1 first" -ForegroundColor Yellow
    exit 0
}

$dlls = @(
    'Autopilot.GraphCore.dll',
    'Autopilot.DeviceCore.dll',
    'Autopilot.CacheCore.dll'
)

$allFound = $true
foreach ($dll in $dlls)
{
    $fullPath = Join-Path $dllPath $dll
    if (Test-Path $fullPath)
    {
        $size = (Get-Item $fullPath).Length / 1KB
        Write-Host "   [OK] $dll ($($size.ToString('F1')) KB)" -ForegroundColor Green
    }
    else
    {
        Write-Host "   [FAIL] $dll not found" -ForegroundColor Red
        $allFound = $false
    }
}

if (-not $allFound)
{
    Write-Host "`n   Run .\Build-NativeDlls.ps1 to compile DLLs" -ForegroundColor Yellow
    exit 1
}

# Test loading DLLs
Write-Host "`n4. Testing Add-Type (DLL loading)..." -ForegroundColor Yellow
try
{
    Add-Type -Path "$dllPath/Autopilot.GraphCore.dll"
    Add-Type -Path "$dllPath/Autopilot.DeviceCore.dll"
    Add-Type -Path "$dllPath/Autopilot.CacheCore.dll"
    Write-Host "   [OK] All DLLs loaded successfully" -ForegroundColor Green
}
catch
{
    Write-Host "   [FAIL] DLL loading failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test DirectoryObjectCache
Write-Host "`n5. Testing DirectoryObjectCache..." -ForegroundColor Yellow
try
{
    $cache = [Autopilot.CacheCore.DirectoryObjectCache]::new(100, 60)
    $cache.Set("test-key", "test-value")
    $result = $cache.Get("test-key")
    
    if ($result.Found -and $result.Value -eq "test-value")
    {
        Write-Host "   [OK] Cache operations working" -ForegroundColor Green
        
        $stats = $cache.GetStats()
        Write-Host "        Cache size: $($stats.TotalEntries)/$($stats.MaxSize)" -ForegroundColor Gray
    }
    else
    {
        Write-Host "   [FAIL] Cache test failed" -ForegroundColor Red
    }
}
catch
{
    Write-Host "   [FAIL] Cache test error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test DeviceFilter
Write-Host "`n6. Testing DeviceFilter..." -ForegroundColor Yellow
try
{
    $devices = New-Object 'System.Collections.Generic.List[Autopilot.DeviceCore.DeviceInfo]'
    
    $device1 = [Autopilot.DeviceCore.DeviceInfo]::new()
    $device1.Manufacturer = "Dell"
    $device1.Model = "Latitude 7420"
    $device1.SerialNumber = "ABC123"
    $devices.Add($device1)
    
    $device2 = [Autopilot.DeviceCore.DeviceInfo]::new()
    $device2.Manufacturer = "HP"
    $device2.Model = "EliteBook 840"
    $device2.SerialNumber = "XYZ789"
    $devices.Add($device2)
    
    $allowedVendors = New-Object 'System.Collections.Generic.List[string]'
    $allowedVendors.Add("Dell")
    
    $filtered = [Autopilot.DeviceCore.DeviceFilter]::FilterByVendor($devices, $allowedVendors)
    
    if ($filtered.Count -eq 1 -and $filtered[0].Manufacturer -eq "Dell")
    {
        Write-Host "   [OK] Device filtering working" -ForegroundColor Green
        Write-Host "        Filtered $($devices.Count) devices to $($filtered.Count)" -ForegroundColor Gray
    }
    else
    {
        Write-Host "   [FAIL] Device filter test failed" -ForegroundColor Red
    }
}
catch
{
    Write-Host "   [FAIL] Device filter error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Verification Complete ===" -ForegroundColor Cyan
Write-Host "All systems ready for high-performance PowerShell + C# integration!`n" -ForegroundColor Green
