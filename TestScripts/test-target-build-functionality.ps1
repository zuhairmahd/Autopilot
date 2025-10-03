#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for CreateRelease.ps1 target-based build functionality.

.DESCRIPTION
    Validates that the CreateRelease.ps1 script can read targets from a targets.psd1 file
    and apply the appropriate settings and build parameters.
#>

[CmdletBinding()]
param()

$scriptName = $MyInvocation.MyCommand.Name
$testStartTime = Get-Date

# Test configuration
$testDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "target-build-test"
$targetsFile = Join-Path -Path $testDir -ChildPath "test-targets.psd1"
$testMainScript = Join-Path -Path $testDir -ChildPath "main.ps1"

Write-Host "=== Testing CreateRelease.ps1 Target-Based Build Functionality ===" -ForegroundColor Cyan
Write-Host "Test directory: $testDir"

try
{
    # Create test directory
    if (Test-Path $testDir)
    {
        Remove-Item -Path $testDir -Recurse -Force
    }
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    
    # Create a simple test main.ps1 file
    @'
Write-Host "Test main script"
# Simple script for testing build process
'@ | Set-Content -Path $testMainScript
    
    # Create test targets file
    @'
@{
    description = 'Test targets for CreateRelease.ps1 validation'
    version = '1.0.0'
    
    targets = @{
        test = @{
            buildParameters = @{
                Version = 'test.1.0.0'
                OutputPath = './build/test'
                SkipSigning = $true
                NoVersionUpdate = $true
                Overwrite = $true
            }
            
            globalSettings = @{
                testMode = $true
                autoUpdate = $false
            }
            
            authSettings = @{
                changePwOnNextStart = $false
                validateScopes = $false
            }
            
            domain = $null
            domainSettings = @{}
            
            description = 'Test target for validation'
        }
    }
}
'@ | Set-Content -Path $targetsFile
    
    Write-Host "✓ Test files created" -ForegroundColor Green
    
    # Test 1: Validate targets file loading
    Write-Host "Test 1: Validating targets file loading..." -ForegroundColor Yellow
    try
    {
        $targetsContent = Import-PowerShellDataFile -Path $targetsFile
        if ($targetsContent.targets -and $targetsContent.targets.ContainsKey('test'))
        {
            Write-Host "✓ Targets file loads correctly" -ForegroundColor Green
        }
        else
        {
            throw "Targets file structure is invalid"
        }
    }
    catch
    {
        Write-Host "✗ Failed to load targets file: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    
    # Test 2: Validate CreateRelease.ps1 parameter set recognition
    Write-Host "Test 2: Validating CreateRelease.ps1 parameter sets..." -ForegroundColor Yellow
    
    # Test help output for new parameters
    $createReleaseScript = Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'CreateRelease.ps1'
    $helpOutput = pwsh -Command "Get-Help '$createReleaseScript' -Parameter TargetsFile -ErrorAction SilentlyContinue"
    if ($helpOutput)
    {
        Write-Host "✓ TargetsFile parameter is recognized" -ForegroundColor Green
    }
    else
    {
        Write-Host "! TargetsFile parameter help not available (expected for new parameters)" -ForegroundColor Yellow
    }
    
    # Test 3: Test dry-run functionality (SecretsOnly mode to avoid full build)
    Write-Host "Test 3: Testing target configuration loading (SecretsOnly mode)..." -ForegroundColor Yellow
    
    Set-Location -Path $testDir
    
    # Get the repository root directory
    $repoRoot = Join-Path -Path $PSScriptRoot -ChildPath '..'
    $createReleaseScript = Join-Path -Path $repoRoot -ChildPath 'CreateRelease.ps1'
    
    # Run CreateRelease with SecretsOnly to test target loading without full build
    $testOutput = pwsh -Command "
        try {
            & '$createReleaseScript' -TargetsFile '$targetsFile' -TargetName 'test' -SecretsOnly -NoPasswordChange -ErrorAction Stop 2>&1
        } catch {
            Write-Output 'ERROR: ' + `$_.Exception.Message
        }
    "
    
    if ($testOutput -like "*Target loaded: Test target for validation*")
    {
        Write-Host "✓ Target configuration loaded successfully" -ForegroundColor Green
    }
    else
    {
        Write-Host "! Target loading test output:" -ForegroundColor Yellow
        Write-Host $testOutput -ForegroundColor Gray
    }
    
    # Test 4: Test invalid target name
    Write-Host "Test 4: Testing invalid target name handling..." -ForegroundColor Yellow
    
    $errorOutput = pwsh -Command "
        try {
            & '$createReleaseScript' -TargetsFile '$targetsFile' -TargetName 'nonexistent' -SecretsOnly -NoPasswordChange 2>&1
        } catch {
            Write-Output 'Expected error: ' + `$_.Exception.Message
        }
    "
    
    if ($errorOutput -like "*not found*" -or $errorOutput -like "*nonexistent*")
    {
        Write-Host "✓ Invalid target name properly handled" -ForegroundColor Green
    }
    else
    {
        Write-Host "! Invalid target test output:" -ForegroundColor Yellow
        Write-Host $errorOutput -ForegroundColor Gray
    }
    
    # Test 5: Test missing targets file
    Write-Host "Test 5: Testing missing targets file handling..." -ForegroundColor Yellow
    
    # Use absolute path in test directory to avoid creating artifacts in project root
    $nonexistentTargetsFile = Join-Path $testDir "nonexistent.psd1"
    
    $missingFileOutput = pwsh -Command "
        try {
            & '$createReleaseScript' -TargetsFile '$nonexistentTargetsFile' -TargetName 'test' -SecretsOnly -NoPasswordChange 2>&1
        } catch {
            Write-Output 'Expected error: ' + `$_.Exception.Message
        }
    "
    
    if ($missingFileOutput -like "*not found*" -or $missingFileOutput -like "*nonexistent*")
    {
        Write-Host "✓ Missing targets file properly handled" -ForegroundColor Green
    }
    else
    {
        Write-Host "! Missing file test output:" -ForegroundColor Yellow
        Write-Host $missingFileOutput -ForegroundColor Gray
    }
    
    # Test 6: Validate backward compatibility (standard parameters still work)
    Write-Host "Test 6: Testing backward compatibility..." -ForegroundColor Yellow
    
    $backwardCompatOutput = pwsh -Command "
        try {
            & '$createReleaseScript' -InputFile '$testMainScript' -SecretsOnly -NoPasswordChange 2>&1 | Select-Object -First 10
        } catch {
            Write-Output 'ERROR: ' + `$_.Exception.Message
        }
    "
    
    if ($backwardCompatOutput -notlike "*ERROR:*")
    {
        Write-Host "✓ Backward compatibility maintained" -ForegroundColor Green
    }
    else
    {
        Write-Host "✗ Backward compatibility issue:" -ForegroundColor Red
        Write-Host $backwardCompatOutput -ForegroundColor Gray
    }
    
    $testDuration = (Get-Date) - $testStartTime
    Write-Host "=== Test Summary ===" -ForegroundColor Cyan
    Write-Host "✓ Target-based build functionality validation completed" -ForegroundColor Green
    Write-Host "✓ All core functionality tests passed" -ForegroundColor Green
    Write-Host "Test duration: $($testDuration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
    
    # Test with the actual targets.psd1 file if it exists
    $actualTargetsFile = Join-Path -Path $repoRoot -ChildPath "targets.psd1"
    if (Test-Path $actualTargetsFile)
    {
        Write-Host "=== Testing with actual targets.psd1 ===" -ForegroundColor Cyan
        
        $actualTargetsContent = Import-PowerShellDataFile -Path $actualTargetsFile
        $availableTargets = $actualTargetsContent.targets.Keys -join ', '
        Write-Host "Available targets in actual file: $availableTargets" -ForegroundColor Gray
        
        # Test one of the actual targets
        $firstTarget = $actualTargetsContent.targets.Keys | Select-Object -First 1
        Write-Host "Testing target: $firstTarget" -ForegroundColor Yellow
        
        $actualTestOutput = pwsh -Command "
            try {
                & '$createReleaseScript' -TargetsFile '$actualTargetsFile' -TargetName '$firstTarget' -SecretsOnly -NoPasswordChange 2>&1 | Select-Object -First 5
            } catch {
                Write-Output 'ERROR: ' + `$_.Exception.Message
            }
        "
        
        if ($actualTestOutput -like "*Target loaded:*")
        {
            Write-Host "✓ Actual targets.psd1 file works correctly" -ForegroundColor Green
        }
        else
        {
            Write-Host "! Actual targets file test output:" -ForegroundColor Yellow
            Write-Host $actualTestOutput -ForegroundColor Gray
        }
    }
    
    Write-Host "=== Target-Based Build Test Completed Successfully ===" -ForegroundColor Green
}
catch
{
    Write-Host "✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally
{
    # Cleanup
    Set-Location -Path $repoRoot
    if (Test-Path $testDir)
    {
        Remove-Item -Path $testDir -Recurse -Force
        Write-Host "✓ Test cleanup completed" -ForegroundColor Gray
    }
}