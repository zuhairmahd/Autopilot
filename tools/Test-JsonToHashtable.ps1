# Test ConvertFrom-JsonToHashtable in PS 5.1

Write-Host "=== Testing ConvertFrom-JsonToHashtable ===" -ForegroundColor Green
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"

# Load the function
. "c:\Users\zuhai\code\Autopilot\functions\setupFunctions\FirstRunWizardFunctions\ConvertFrom-JsonToHashtable.ps1"

# Mock Write-Log to avoid dependency
function Write-Log { param($logFile, $Module, $Message, $LogLevel) }

Write-Host "`n--- Test 1: Create deep nested PSCustomObject ---"
$json = '{"level1":{"level2":{"level3":{"value":"test"}}}}'
$jsonObj = ConvertFrom-Json $json
Write-Host "[OK] Created nested PSCustomObject"

Write-Host "`n--- Test 2: Convert to hashtable ---"
try {
    $result = ConvertFrom-JsonToHashtable -JsonObject $jsonObj
    Write-Host "[OK] Conversion succeeded"
    Write-Host "Result type: $($result.GetType().Name)"
    Write-Host "Keys: $($result.Keys -join ', ')"
} catch {
    Write-Host "[FAIL] Conversion failed: $_" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.GetType().FullName)"
    Write-Host "Message: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)"
}

Write-Host "`n--- Test 3: Deep nesting (100 levels) ---"
$deepObj = @{level0 = "start"}
$current = $deepObj
for ($i = 1; $i -lt 100; $i++) {
    $current["level$i"] = @{}
    $current = $current["level$i"]
}
$current["value"] = "deep"

# Convert to PSCustomObject-like structure
$jsonString = $deepObj | ConvertTo-Json -Depth 100 -Compress
$deepPSObj = ConvertFrom-Json $jsonString

Write-Host "Created 100-level PSCustomObject"

try {
    $deepResult = ConvertFrom-JsonToHashtable -JsonObject $deepPSObj
    Write-Host "[OK] Deep conversion succeeded"
    Write-Host "Result type: $($deepResult.GetType().Name)"
} catch {
    Write-Host "[FAIL] Deep conversion failed: $_" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.GetType().FullName)"
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
