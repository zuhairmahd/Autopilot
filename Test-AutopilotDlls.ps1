<#
.SYNOPSIS
Comprehensive test for all Autopilot C# DLLs in both PowerShell 5.1 and PowerShell 7+.

.DESCRIPTION
Tests DLL loading, dependency resolution, and basic functionality for:
- Autopilot.GraphCore
- Autopilot.DeviceCore
- Autopilot.CacheCore
- Autopilot.LogCore

Tests in current PowerShell version and can launch cross-version tests.

.PARAMETER TestBothVersions
If specified, tests in both PowerShell 5.1 and PowerShell 7+ (requires both installed).

.EXAMPLE
.\Test-AutopilotDlls.ps1

.EXAMPLE
.\Test-AutopilotDlls.ps1 -TestBothVersions -Verbose
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$TestBothVersions
)

$ErrorActionPreference = "Stop"
$scriptPath = $PSScriptRoot

# Import the initialization function
. "$scriptPath\functions\utilityFunctions\Initialize-AutopilotDlls.ps1"

function Test-DllLoading
{
    param(
        [string]$PSVersion,
        [string]$DllPath
    )
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Testing DLL Loading in PowerShell $PSVersion" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "CLR Version: $([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)" -ForegroundColor Yellow
    Write-Host ""
    
    # Initialize DLLs
    Write-Host "Initializing Autopilot DLLs..." -ForegroundColor Green
    $result = Initialize-AutopilotDlls -DLLPath $DllPath
    
    # Display results
    Write-Host ""
    Write-Host "Results:" -ForegroundColor Cyan
    Write-Host "  Target Framework: $($result.TargetFramework)" -ForegroundColor Yellow
    Write-Host "  DLL Path: $($result.DllPath)" -ForegroundColor Yellow
    Write-Host "  Loaded Count: $($result.LoadedCount)/4" -ForegroundColor $(if ($result.LoadedCount -eq 4) { "Green" } else { "Red" })
    Write-Host ""
    
    Write-Host "Individual DLL Status:" -ForegroundColor Cyan
    Write-Host "  GraphCore:  $(if ($result.GraphCoreLoaded) { '[LOADED]' } else { '[FAILED]' })" -ForegroundColor $(if ($result.GraphCoreLoaded) { "Green" } else { "Red" })
    Write-Host "  DeviceCore: $(if ($result.DeviceCoreLoaded) { '[LOADED]' } else { '[FAILED]' })" -ForegroundColor $(if ($result.DeviceCoreLoaded) { "Green" } else { "Red" })
    Write-Host "  CacheCore:  $(if ($result.CacheCoreLoaded) { '[LOADED]' } else { '[FAILED]' })" -ForegroundColor $(if ($result.CacheCoreLoaded) { "Green" } else { "Red" })
    Write-Host "  LogCore:    $(if ($result.LogCoreLoaded) { '[LOADED]' } else { '[FAILED]' })" -ForegroundColor $(if ($result.LogCoreLoaded) { "Green" } else { "Red" })
    Write-Host ""
    
    # Display loaded assemblies
    if ($result.LoadedAssemblies.Count -gt 0)
    {
        Write-Host "Loaded Assemblies:" -ForegroundColor Cyan
        foreach ($asm in $result.LoadedAssemblies)
        {
            Write-Host "  - $($asm.Name)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Display errors if any
    if ($result.Errors.Count -gt 0)
    {
        Write-Host "Errors Encountered:" -ForegroundColor Red
        foreach ($err in $result.Errors)
        {
            Write-Host "  DLL: $($err.Dll)" -ForegroundColor Yellow
            Write-Host "  Type: $($err.ErrorType)" -ForegroundColor Yellow
            Write-Host "  Message: $($err.Message)" -ForegroundColor Red
            if ($err.Exception)
            {
                Write-Host "  Exception: $($err.Exception.GetType().Name)" -ForegroundColor Red
            }
            Write-Host ""
        }
    }
    
    # Test basic functionality if all loaded
    if ($result.LoadedCount -eq 4)
    {
        Write-Host "Testing Basic Functionality..." -ForegroundColor Green
        Write-Host ""
        
        # Test GraphCore
        try
        {
            Write-Host "  Testing GraphCore (BatchProcessor)..." -ForegroundColor Cyan
            $batchProcessor = New-Object Autopilot.GraphCore.BatchProcessor
            $types = [Autopilot.GraphCore.BatchProcessor].GetMethods() | Where-Object { $_.IsPublic } | Select-Object -ExpandProperty Name -Unique
            Write-Host "    Found $($types.Count) public methods" -ForegroundColor Green
            Write-Host "    Methods: $($types -join ', ')" -ForegroundColor Gray
        }
        catch
        {
            Write-Host "    FAILED: $_" -ForegroundColor Red
        }
        Write-Host ""
        
        # Test DeviceCore
        try
        {
            Write-Host "  Testing DeviceCore (DeviceFilter)..." -ForegroundColor Cyan
            $deviceFilter = New-Object Autopilot.DeviceCore.DeviceFilter
            $types = [Autopilot.DeviceCore.DeviceFilter].GetMethods() | Where-Object { $_.IsPublic } | Select-Object -ExpandProperty Name -Unique
            Write-Host "    Found $($types.Count) public methods" -ForegroundColor Green
            Write-Host "    Methods: $($types -join ', ')" -ForegroundColor Gray
        }
        catch
        {
            Write-Host "    FAILED: $_" -ForegroundColor Red
        }
        Write-Host ""
        
        # Test CacheCore
        try
        {
            Write-Host "  Testing CacheCore (DirectoryObjectCache)..." -ForegroundColor Cyan
            $cache = New-Object Autopilot.CacheCore.DirectoryObjectCache
            $types = [Autopilot.CacheCore.DirectoryObjectCache].GetMethods() | Where-Object { $_.IsPublic } | Select-Object -ExpandProperty Name -Unique
            Write-Host "    Found $($types.Count) public methods" -ForegroundColor Green
            Write-Host "    Methods: $($types -join ', ')" -ForegroundColor Gray
        }
        catch
        {
            Write-Host "    FAILED: $_" -ForegroundColor Red
        }
        Write-Host ""
        
        # Test LogCore
        try
        {
            Write-Host "  Testing LogCore (Logger)..." -ForegroundColor Cyan
            $tempLog = Join-Path $env:TEMP "autopilot_test.log"
            $logger = New-Object Autopilot.LogCore.Logger($tempLog, $true, 10)
            
            # Test sync logging
            $logger.WriteLog("Test message from PowerShell $($PSVersionTable.PSVersion)", 3, "Test-AutopilotDlls")
            Write-Host "    Sync logging: OK" -ForegroundColor Green
            
            # Test async logging
            $logger.WriteLogAsync("Async test message", 3, "Test-AutopilotDlls")
            Write-Host "    Async logging: OK" -ForegroundColor Green
            
            # Test separator
            $logger.WriteSeparator("Test Separator")
            Write-Host "    Separator: OK" -ForegroundColor Green
            
            # Get statistics
            $stats = $logger.GetStatistics()
            Write-Host "    Statistics: $($stats.TotalEntriesWritten) entries written" -ForegroundColor Green
            
            # Shutdown
            $logger.Shutdown(5)
            Write-Host "    Shutdown: OK" -ForegroundColor Green
            
            # Verify log file created
            if (Test-Path $tempLog)
            {
                $logContent = Get-Content $tempLog -Raw
                Write-Host "    Log file created: $(Split-Path $tempLog -Leaf) ($($logContent.Length) bytes)" -ForegroundColor Green
                Remove-Item $tempLog -Force
            }
        }
        catch
        {
            Write-Host "    FAILED: $_" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Overall result
    Write-Host "========================================" -ForegroundColor Cyan
    if ($result.LoadedCount -eq 4 -and $result.Errors.Count -eq 0)
    {
        Write-Host "OVERALL RESULT: SUCCESS" -ForegroundColor Green
        Write-Host "All 4 DLLs loaded and tested successfully!" -ForegroundColor Green
    }
    elseif ($result.LoadedCount -gt 0)
    {
        Write-Host "OVERALL RESULT: PARTIAL SUCCESS" -ForegroundColor Yellow
        Write-Host "$($result.LoadedCount)/4 DLLs loaded" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "OVERALL RESULT: FAILURE" -ForegroundColor Red
        Write-Host "No DLLs loaded successfully" -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    return $result
}

# Main execution
$dllPath = Join-Path $scriptPath "bin\Release"

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "Autopilot C# DLL Comprehensive Test Suite" -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host ""

# Test current PowerShell version
$currentVersion = $PSVersionTable.PSVersion.Major
$result = Test-DllLoading -PSVersion $currentVersion -DllPath $dllPath

# Test other version if requested
if ($TestBothVersions)
{
    Write-Host ""
    Write-Host "Cross-Version Testing Requested..." -ForegroundColor Magenta
    Write-Host ""
    
    if ($currentVersion -ge 7)
    {
        # Currently in PS 7+, test PS 5.1
        $ps51Path = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        if (Test-Path $ps51Path)
        {
            Write-Host "Launching PowerShell 5.1 test..." -ForegroundColor Yellow
            $testScript = $MyInvocation.MyCommand.Path
            & $ps51Path -ExecutionPolicy Bypass -NoProfile -File $testScript
        }
        else
        {
            Write-Host "PowerShell 5.1 not found at: $ps51Path" -ForegroundColor Red
        }
    }
    else
    {
        # Currently in PS 5.1, test PS 7+
        $ps7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
        if (Test-Path $ps7Path)
        {
            Write-Host "Launching PowerShell 7+ test..." -ForegroundColor Yellow
            $testScript = $MyInvocation.MyCommand.Path
            & $ps7Path -ExecutionPolicy Bypass -NoProfile -File $testScript
        }
        else
        {
            Write-Host "PowerShell 7+ not found at: $ps7Path" -ForegroundColor Red
        }
    }
}

# Exit with appropriate code
exit $(if ($result.LoadedCount -eq 4) { 0 } else { 1 })
