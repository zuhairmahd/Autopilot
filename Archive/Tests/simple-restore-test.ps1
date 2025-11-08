# Simple verification test for Restore-ApplicationDefaults
$script:RepoRoot = (Get-Item $PSScriptRoot).Parent.FullName
. "$script:RepoRoot/functions/setupFunctions/Restore-ApplicationDefaults.ps1"
. "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"

# Set up global log file variable
$global:logFile = Join-Path $env:TEMP "test-restore.log"

# Create test environment
$testPath = Join-Path $env:TEMP "RestoreTest_$(Get-Date -Format 'HHmmss')"
New-Item -Path $testPath -ItemType Directory -Force | Out-Null

$testFiles = @(
    (Join-Path $testPath "settings.psd1"),
    (Join-Path $testPath "strings.psd1"),
    (Join-Path $testPath "menu.psd1")
)

# Create test files
foreach ($file in $testFiles) {
    "Test content" | Out-File $file
}

Write-Host "Test files created in: $testPath"
Write-Host "Files:"
$testFiles | ForEach-Object { Write-Host "  - $(Split-Path -Leaf $_)" }

Write-Host "`nTesting parameter validation..."

# Test 1: Parameter validation - should throw
try {
    Restore-ApplicationDefaults -FilesToDelete @() -Domain "test.local" -ScriptPath $testPath
    Write-Host "❌ Test 1 Failed: Should have thrown for empty FilesToDelete"
}
catch {
    Write-Host "✅ Test 1 Passed: Correctly threw for empty FilesToDelete"
}

# Test 2: User cancellation mock
Write-Host "`nTesting with mock cancellation..."
# Mock Read-Host for cancellation
function Read-Host {
    param($Prompt)
    if ($Prompt -like "*continue*") {
        return "N"
    }
    return "Y"
}

$result = Restore-ApplicationDefaults -FilesToDelete $testFiles -Domain "test.local" -ScriptPath $testPath

if ($result.UserCancelled -eq $true) {
    Write-Host "✅ Test 2 Passed: User cancellation works"
}
else {
    Write-Host "❌ Test 2 Failed: User cancellation not detected"
}

# Test 3: Successful deletion mock  
Write-Host "`nTesting with mock acceptance..."
function Read-Host {
    param($Prompt)
    if ($Prompt -like "*continue*") {
        return "Y"
    }
    return "Y"
}

# Recreate files
foreach ($file in $testFiles) {
    "Test content" | Out-File $file
}

$result = Restore-ApplicationDefaults -FilesToDelete $testFiles -Domain "test.local" -ScriptPath $testPath

if ($result.Success -eq $true -and $result.RemovedFileCount -gt 0) {
    Write-Host "✅ Test 3 Passed: File deletion works"
    Write-Host "   Deleted: $($result.RemovedFileCount) files"
    Write-Host "   Message: $($result.Message)"
}
else {
    Write-Host "❌ Test 3 Failed: File deletion didn't work as expected"
    Write-Host "   Success: $($result.Success)"
    Write-Host "   Removed: $($result.RemovedFileCount)"
    Write-Host "   Message: $($result.Message)"
}

# Cleanup
Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nSimple verification test completed!"