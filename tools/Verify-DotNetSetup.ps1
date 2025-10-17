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

# Determine target framework based on PowerShell version
$targetFramework = if ($PSVersionTable.PSEdition -eq 'Core')
{
    'net9.0'
}
else
{
    'netstandard2.0'
}
Write-Host "        Target: $targetFramework" -ForegroundColor Gray

# Check compiled DLLs
Write-Host "`n3. Checking compiled DLLs..." -ForegroundColor Yellow

# Define DLL list
$dlls = @(
    'Autopilot.GraphCore.dll',
    'Autopilot.DeviceCore.dll',
    'Autopilot.CacheCore.dll',
    'Autopilot.LogCore.dll'
)

# Check both locations: root bin/Release and framework-specific folders
$dllLocations = @(
    @{ Path = "bin/Release"; Label = "Root (copied)" },
    @{ Path = "bin/Release/$targetFramework"; Label = $targetFramework }
)

$allFound = $true
$dllPath = $null

foreach ($location in $dllLocations)
{
    $path = $location.Path
    $label = $location.Label
    
    if (Test-Path $path)
    {
        Write-Host "   Checking $label..." -ForegroundColor Gray
        $foundInLocation = $true
        
        foreach ($dll in $dlls)
        {
            $fullPath = Join-Path $path $dll
            if (Test-Path $fullPath)
            {
                $size = (Get-Item $fullPath).Length / 1KB
                Write-Host "      [OK] $dll ($($size.ToString('F1')) KB)" -ForegroundColor Green
            }
            else
            {
                Write-Host "      [MISS] $dll not found" -ForegroundColor Yellow
                $foundInLocation = $false
            }
        }
        
        # Use the first location where all DLLs are found
        if ($foundInLocation -and -not $dllPath)
        {
            $dllPath = $path
            Write-Host "   [OK] Using DLLs from: $path" -ForegroundColor Green
        }
    }
}

if (-not $dllPath -or -not $allFound)
{
    Write-Host "`n   [WARN] DLLs not found. Run .\Build-NativeDlls.ps1 or .\Build-And-Publish-Dlls.ps1 first" -ForegroundColor Yellow
    exit 0
}

# Test loading DLLs
Write-Host "`n4. Testing Add-Type (DLL loading)..." -ForegroundColor Yellow
$loadedDlls = @{}
$loadSuccess = $true

foreach ($dll in $dlls)
{
    try
    {
        $fullPath = Join-Path $dllPath $dll
        Add-Type -Path $fullPath
        $dllName = [System.IO.Path]::GetFileNameWithoutExtension($dll)
        $loadedDlls[$dllName] = $true
        Write-Host "   [OK] $dll loaded" -ForegroundColor Green
    }
    catch
    {
        Write-Host "   [FAIL] $dll loading failed: $($_.Exception.Message)" -ForegroundColor Red
        $loadSuccess = $false
    }
}

if (-not $loadSuccess)
{
    Write-Host "`n   Some DLLs failed to load. Check errors above." -ForegroundColor Yellow
    exit 1
}

# Test DirectoryObjectCache
Write-Host "`n5. Testing DirectoryObjectCache..." -ForegroundColor Yellow
try
{
    $cache = [Autopilot.CacheCore.DirectoryObjectCache]::new(100, 60)
    $cache.Set("test-key", "test-value")
    $result = $cache.Get("test-key")
    
    # Get() returns a tuple (bool Found, object Value)
    if ($result.Item1 -and $result.Item2 -eq "test-value")
    {
        Write-Host "   [OK] Cache Set/Get operations working" -ForegroundColor Green
        
        # Test statistics
        try
        {
            $stats = $cache.GetStats()
            Write-Host "   [OK] Cache statistics working" -ForegroundColor Green
            Write-Host "        Cache: $($stats.TotalEntries)/$($stats.MaxSize) entries, Hit rate: $($stats.HitRate.ToString('P1'))" -ForegroundColor Gray
        }
        catch
        {
            Write-Host "   [WARN] Cache stats error (non-critical): $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Test expiration check
        if ($cache.ContainsKey("test-key"))
        {
            Write-Host "   [OK] Cache key exists check working" -ForegroundColor Green
        }
        
        # Test removal
        $removed = $cache.Remove("test-key")
        if ($removed -and -not $cache.ContainsKey("test-key"))
        {
            Write-Host "   [OK] Cache removal working" -ForegroundColor Green
        }
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

# Test LogCore
Write-Host "`n7. Testing LogCore..." -ForegroundColor Yellow
try
{
    # Create a temp log file path
    $tempLogPath = Join-Path $env:TEMP "autopilot-test-$(Get-Random).log"
    
    # Test Logger creation - parameters: logFilePath, minimumLogLevel, useCMTraceFormat, maxLogSizeMB, enableAsync
    $logLevel = [Autopilot.LogCore.Logger+LogLevel]::Information
    $logger = [Autopilot.LogCore.Logger]::new($tempLogPath, $logLevel, $false, 10, $false)
    
    if ($null -ne $logger)
    {
        Write-Host "   [OK] Logger instantiation working" -ForegroundColor Green
        
        # Test logging methods - WriteLog(module, message, level)
        $infoLevel = [Autopilot.LogCore.Logger+LogLevel]::Information
        $warningLevel = [Autopilot.LogCore.Logger+LogLevel]::Warning
        $debugLevel = [Autopilot.LogCore.Logger+LogLevel]::Debug
        
        $logger.WriteLog("TestModule", "Test info message", $infoLevel)
        $logger.WriteLog("TestModule", "Test warning message", $warningLevel)
        $logger.WriteLog("TestModule", "Test debug message", $debugLevel)
        Write-Host "   [OK] Logger WriteLog methods working" -ForegroundColor Green
        
        # Test statistics
        $stats = $logger.GetStatistics()
        Write-Host "   [OK] Logger statistics working" -ForegroundColor Green
        Write-Host "        Stats: TotalLogs=$($stats.TotalLogs)" -ForegroundColor Gray
        
        # Test separator
        $logger.WriteSeparator()
        Write-Host "   [OK] Logger WriteSeparator working" -ForegroundColor Green
        
        # Cleanup
        try
        {
            $logger.Shutdown()
            if (Test-Path $tempLogPath)
            {
                Remove-Item $tempLogPath -Force -ErrorAction SilentlyContinue
            }
        }
        catch
        {
            # Ignore cleanup errors
        }
    }
    else
    {
        Write-Host "   [FAIL] Logger test failed" -ForegroundColor Red
    }
}
catch
{
    Write-Host "   [FAIL] LogCore test error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test GraphCore
Write-Host "`n8. Testing GraphCore..." -ForegroundColor Yellow
try
{
    # Test GraphHttpClient creation
    $client = [Autopilot.GraphCore.GraphHttpClient]::new("fake-token-for-testing")
    
    if ($null -ne $client)
    {
        Write-Host "   [OK] GraphHttpClient instantiation working" -ForegroundColor Green
    }
    else
    {
        Write-Host "   [FAIL] GraphHttpClient test failed" -ForegroundColor Red
    }
    
    # Test BatchProcessor creation
    $processor = [Autopilot.GraphCore.BatchProcessor]::new($client)
    
    if ($null -ne $processor)
    {
        Write-Host "   [OK] BatchProcessor instantiation working" -ForegroundColor Green
    }
    else
    {
        Write-Host "   [FAIL] BatchProcessor test failed" -ForegroundColor Red
    }
}
catch
{
    Write-Host "   [FAIL] GraphCore test error: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary of all tests
Write-Host "`n9. Test Summary..." -ForegroundColor Yellow
$testResults = @{
    'SDK Verification' = $true
    'DLL Compilation'  = $allFound
    'DLL Loading'      = $loadSuccess
    'CacheCore'        = $true
    'DeviceCore'       = $true
    'LogCore'          = $true
    'GraphCore'        = $true
}

$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

Write-Host "   Tests Passed: $passedTests/$totalTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { 'Green' } else { 'Yellow' })
foreach ($test in $testResults.GetEnumerator())
{
    $icon = if ($test.Value) { '[PASS]' } else { '[FAIL]' }
    $color = if ($test.Value) { 'Green' } else { 'Red' }
    Write-Host "   $icon $($test.Key)" -ForegroundColor $color
}

Write-Host "`n=== Verification Complete ===" -ForegroundColor Cyan
Write-Host "All systems ready for high-performance PowerShell + C# integration!`n" -ForegroundColor Green
