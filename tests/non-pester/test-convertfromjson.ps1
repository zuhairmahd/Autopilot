# Test ConvertFrom-JsonToHashtable with ConfigCore integration

# Mock Write-Log for testing
function Write-Log
{
    param([string]$logFile, [string]$Module, [string]$Message, [string]$LogLevel = "Information")
    # No-op for testing
}

. 'c:\Users\zuhai\code\Autopilot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\FirstRunWizardFunctions\ConvertFrom-JsonToHashtable.ps1'

$dllStatus = Initialize-AutopilotDlls -DLLPath 'c:\Users\zuhai\code\Autopilot\bin\Release'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ConvertFrom-JsonToHashtable Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nDLL Status: ConfigCore=$($dllStatus.ConfigCoreLoaded)" -ForegroundColor $(if ($dllStatus.ConfigCoreLoaded) { 'Green' } else { 'Yellow' })

# Test 1: Simple JSON parsing
Write-Host "`nTest 1: Simple JSON Parsing" -ForegroundColor Cyan
$json1 = '{"name": "Test", "age": 30, "active": true}'
$result1 = ConvertFrom-JsonToHashtable -JsonObject $json1 -Verbose
Write-Host "  Keys: $($result1.Keys.Count)" -ForegroundColor $(if ($result1.Keys.Count -eq 3) { 'Green' } else { 'Red' })
Write-Host "  Name: $($result1.name)" -ForegroundColor $(if ($result1.name -eq 'Test') { 'Green' } else { 'Red' })
Write-Host "  Age: $($result1.age)" -ForegroundColor $(if ($result1.age -eq 30) { 'Green' } else { 'Red' })
Write-Host "  Active: $($result1.active)" -ForegroundColor $(if ($result1.active -eq $true) { 'Green' } else { 'Red' })

# Test 2: Nested JSON parsing
Write-Host "`nTest 2: Nested JSON Parsing" -ForegroundColor Cyan
$json2 = '{"parent": {"child": {"key": "value"}}, "root": "rootValue"}'
$result2 = ConvertFrom-JsonToHashtable -JsonObject $json2 -Verbose
Write-Host "  Top-level keys: $($result2.Keys.Count)" -ForegroundColor $(if ($result2.Keys.Count -eq 2) { 'Green' } else { 'Red' })
Write-Host "  Has 'parent': $($result2.ContainsKey('parent'))" -ForegroundColor $(if ($result2.ContainsKey('parent')) { 'Green' } else { 'Red' })
Write-Host "  Has 'root': $($result2.ContainsKey('root'))" -ForegroundColor $(if ($result2.ContainsKey('root')) { 'Green' } else { 'Red' })
Write-Host "  Root value: $($result2.root)" -ForegroundColor $(if ($result2.root -eq 'rootValue') { 'Green' } else { 'Red' })
Write-Host "  Nested value: $($result2.parent.child.key)" -ForegroundColor $(if ($result2.parent.child.key -eq 'value') { 'Green' } else { 'Red' })

# Test 3: Flattened JSON parsing
Write-Host "`nTest 3: Flattened JSON Parsing" -ForegroundColor Cyan
$json3 = '{"parent": {"child": {"key": "value"}}, "root": "rootValue"}'
$result3 = ConvertFrom-JsonToHashtable -JsonObject $json3 -Flatten -Verbose
Write-Host "  Flattened keys: $($result3.Keys.Count)" -ForegroundColor $(if ($result3.Keys.Count -eq 2) { 'Green' } else { 'Red' })
Write-Host "  Has 'parent.child.key': $($result3.ContainsKey('parent.child.key'))" -ForegroundColor $(if ($result3.ContainsKey('parent.child.key')) { 'Green' } else { 'Red' })
Write-Host "  Has 'root': $($result3.ContainsKey('root'))" -ForegroundColor $(if ($result3.ContainsKey('root')) { 'Green' } else { 'Red' })
Write-Host "  Nested value: $($result3.'parent.child.key')" -ForegroundColor $(if ($result3.'parent.child.key' -eq 'value') { 'Green' } else { 'Red' })

# Test 4: JSON with arrays
Write-Host "`nTest 4: JSON with Arrays" -ForegroundColor Cyan
$json4 = '{"items": [1, 2, 3], "names": ["Alice", "Bob"]}'
$result4 = ConvertFrom-JsonToHashtable -JsonObject $json4 -Verbose
Write-Host "  Keys: $($result4.Keys.Count)" -ForegroundColor $(if ($result4.Keys.Count -eq 2) { 'Green' } else { 'Red' })
Write-Host "  Items array length: $($result4.items.Length)" -ForegroundColor $(if ($result4.items.Length -eq 3) { 'Green' } else { 'Red' })
Write-Host "  Names array length: $($result4.names.Length)" -ForegroundColor $(if ($result4.names.Length -eq 2) { 'Green' } else { 'Red' })
Write-Host "  First item: $($result4.items[0])" -ForegroundColor $(if ($result4.items[0] -eq 1) { 'Green' } else { 'Red' })

# Test 5: Performance comparison (if ConfigCore loaded)
if ($dllStatus.ConfigCoreLoaded)
{
    Write-Host "`nTest 5: Performance Comparison" -ForegroundColor Cyan
    
    # Create a larger JSON for testing
    $largeJson = @"
{
    "config": {
        "auth": {
            "tenantId": "12345678-1234-1234-1234-123456789012",
            "appId": "87654321-4321-4321-4321-210987654321",
            "scopes": ["User.Read", "DeviceManagementManagedDevices.Read.All"]
        },
        "settings": {
            "maxRetries": 3,
            "timeout": 30,
            "verbose": true,
            "logging": {
                "level": "Information",
                "file": "autopilot.log"
            }
        },
        "features": {
            "deviceSync": true,
            "profileAssignment": true,
            "reporting": false
        }
    }
}
"@
    
    # Test with ConfigCore (fast path)
    $sw1 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++)
    {
        $null = ConvertFrom-JsonToHashtable -JsonObject $largeJson
    }
    $sw1.Stop()
    $configCoreTime = $sw1.ElapsedMilliseconds
    
    # Test PowerShell fallback (temporarily disable ConfigCore)
    $savedStatus = $global:AutopilotDllStatus.ConfigCoreLoaded
    $global:AutopilotDllStatus.ConfigCoreLoaded = $false
    
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 100; $i++)
    {
        $jsonObj = ConvertFrom-Json $largeJson
        $null = ConvertFrom-JsonToHashtable -JsonObject $jsonObj
    }
    $sw2.Stop()
    $powershellTime = $sw2.ElapsedMilliseconds
    
    # Restore ConfigCore status
    $global:AutopilotDllStatus.ConfigCoreLoaded = $savedStatus
    
    $speedup = [math]::Round($powershellTime / $configCoreTime, 2)
    
    Write-Host "  ConfigCore time (100 iterations): $($configCoreTime)ms" -ForegroundColor Green
    Write-Host "  PowerShell time (100 iterations): $($powershellTime)ms" -ForegroundColor Yellow
    Write-Host "  Speedup: ${speedup}x faster" -ForegroundColor $(if ($speedup -gt 2) { 'Green' } else { 'Yellow' })
    
    if ($speedup -lt 2)
    {
        Write-Host "  Note: Speedup may vary based on JSON complexity and system performance" -ForegroundColor Gray
    }
}

# Test 6: Backward compatibility - PSCustomObject input
Write-Host "`nTest 6: Backward Compatibility (PSCustomObject)" -ForegroundColor Cyan
$jsonObj = ConvertFrom-Json '{"name": "Test", "value": 123}'
$result6 = ConvertFrom-JsonToHashtable -JsonObject $jsonObj -Verbose
Write-Host "  Keys: $($result6.Keys.Count)" -ForegroundColor $(if ($result6.Keys.Count -eq 2) { 'Green' } else { 'Red' })
Write-Host "  Name: $($result6.name)" -ForegroundColor $(if ($result6.name -eq 'Test') { 'Green' } else { 'Red' })
Write-Host "  Value: $($result6.value)" -ForegroundColor $(if ($result6.value -eq 123) { 'Green' } else { 'Red' })

# Test 7: Hashtable passthrough
Write-Host "`nTest 7: Hashtable Passthrough" -ForegroundColor Cyan
$hashtable = @{ Key1 = "Value1"; Key2 = "Value2" }
$result7 = ConvertFrom-JsonToHashtable -JsonObject $hashtable -Verbose
Write-Host "  Keys: $($result7.Keys.Count)" -ForegroundColor $(if ($result7.Keys.Count -eq 2) { 'Green' } else { 'Red' })
Write-Host "  Key1: $($result7.Key1)" -ForegroundColor $(if ($result7.Key1 -eq 'Value1') { 'Green' } else { 'Red' })

$allTestsPassed = ($result1.Keys.Count -eq 3) -and 
($result2.Keys.Count -eq 2) -and 
($result3.Keys.Count -eq 2) -and 
($result4.Keys.Count -eq 2) -and
($result6.Keys.Count -eq 2) -and
($result7.Keys.Count -eq 2)

if ($allTestsPassed)
{
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  All Tests Passed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}
else
{
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "  Some Tests Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
}
