# Test if C# methods work immediately after DLL load in PS 5.1

Write-Host "=== Testing Direct C# Method Calls ===" -ForegroundColor Green
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"

# Load DLLs same way as main.ps1
$dllPath = "c:\Users\zuhai\code\Autopilot\bin\Release"

Write-Host "`n--- Loading DLLs ---"
try {
    Add-Type -Path "$dllPath\Autopilot.ConfigCore.dll"
    Write-Host "[OK] Loaded Autopilot.ConfigCore.dll"
} catch {
    Write-Host "[FAIL] Failed to load: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n--- Test 1: Create simple hashtable ---"
$testHash = @{
    level1 = @{
        level2 = @{
            value = "test"
        }
    }
}
Write-Host "[OK] Created test hashtable"

Write-Host "`n--- Test 2: Call DeepClone ---"
try {
    $cloned = [Autopilot.ConfigCore.HashtableHelper]::DeepClone($testHash)
    Write-Host "[OK] DeepClone succeeded"
    Write-Host "Cloned type: $($cloned.GetType().Name)"
} catch {
    Write-Host "[FAIL] DeepClone failed: $_" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.GetType().FullName)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
}

Write-Host "`n--- Test 3: Call Flatten ---"
try {
    $flattened = [Autopilot.ConfigCore.HashtableHelper]::FlattenRecursive($testHash)
    Write-Host "[OK] Flatten succeeded"
    Write-Host "Flattened keys: $($flattened.Keys.Count)"
} catch {
    Write-Host "[FAIL] Flatten failed: $_" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
