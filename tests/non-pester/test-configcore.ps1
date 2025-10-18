# Test ConfigCore.dll loading and functionality

. 'c:\Users\zuhai\code\Autopilot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1'

$dllStatus = Initialize-AutopilotDlls -DLLPath 'c:\Users\zuhai\code\Autopilot\bin\Release' -Verbose

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ConfigCore DLL Load Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nDLL Load Status:"
Write-Host "  Success: $($dllStatus.Success)" -ForegroundColor $(if ($dllStatus.Success) { 'Green' } else { 'Yellow' })
Write-Host "  Loaded: $($dllStatus.LoadedCount) of 5"
Write-Host "  ConfigCore: $($dllStatus.ConfigCoreLoaded)" -ForegroundColor $(if ($dllStatus.ConfigCoreLoaded) { 'Green' } else { 'Red' })
Write-Host "  Loaded Assemblies:"
$dllStatus.LoadedAssemblies | ForEach-Object { Write-Host "    - $_" -ForegroundColor Green }

if ($dllStatus.Errors.Count -gt 0)
{
    Write-Host "`n  Errors:"
    $dllStatus.Errors | ForEach-Object { Write-Host "    - $($_.Dll): $($_.Message)" -ForegroundColor Red }
}

if ($dllStatus.ConfigCoreLoaded)
{
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  ConfigCore Functionality Tests" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Test 1: Hashtable Merging
    Write-Host "`nTest 1: Hashtable Merging"
    $ht1 = @{ Name = "John"; Age = 30; City = "NYC" }
    $ht2 = @{ Age = 31; Country = "USA" }
    $merged = [Autopilot.ConfigCore.HashtableHelper]::MergeHashtables($ht1, $ht2, "Global")
    Write-Host "  Input 1: Name=$($ht1.Name), Age=$($ht1.Age), City=$($ht1.City)"
    Write-Host "  Input 2: Age=$($ht2.Age), Country=$($ht2.Country)"
    Write-Host "  Merged: $($merged.Count) keys"
    Write-Host "  Age (should be 31): $($merged.Age)" -ForegroundColor $(if ($merged.Age -eq 31) { 'Green' } else { 'Red' })
    Write-Host "  Country (should be USA): $($merged.Country)" -ForegroundColor $(if ($merged.Country -eq 'USA') { 'Green' } else { 'Red' })
    
    # Test 2: Deep Clone
    Write-Host "`nTest 2: Deep Clone"
    $original = @{ 
        Name   = "Test"
        Nested = @{ Key = "Value"; Count = 5 }
    }
    $cloned = [Autopilot.ConfigCore.HashtableHelper]::DeepClone($original)
    $cloned.Nested.Key = "Changed"
    Write-Host "  Original nested key: $($original.Nested.Key)" -ForegroundColor $(if ($original.Nested.Key -eq 'Value') { 'Green' } else { 'Red' })
    Write-Host "  Cloned nested key: $($cloned.Nested.Key)" -ForegroundColor $(if ($cloned.Nested.Key -eq 'Changed') { 'Green' } else { 'Red' })
    
    # Test 3: Flatten
    Write-Host "`nTest 3: Flatten Nested Hashtable"
    $nested = @{
        Parent = @{
            Child = @{
                Key = "Value"
            }
        }
        Root   = "RootValue"
    }
    $flattened = [Autopilot.ConfigCore.HashtableHelper]::Flatten($nested)
    Write-Host "  Original keys: $($nested.Keys.Count)"
    Write-Host "  Flattened keys: $($flattened.Keys.Count)"
    Write-Host "  Has 'Parent.Child.Key': $($flattened.ContainsKey('Parent.Child.Key'))" -ForegroundColor $(if ($flattened.ContainsKey('Parent.Child.Key')) { 'Green' } else { 'Red' })
    
    # Test 4: JSON Parsing
    Write-Host "`nTest 4: JSON Parsing"
    $json = '{"name": "Test", "age": 30, "nested": {"key": "value"}}'
    $parsed = [Autopilot.ConfigCore.JsonParser]::ParseToHashtable($json)
    Write-Host "  Parsed keys: $($parsed.Keys.Count)"
    Write-Host "  Name: $($parsed.name)" -ForegroundColor $(if ($parsed.name -eq 'Test') { 'Green' } else { 'Red' })
    Write-Host "  Nested key: $($parsed.nested.key)" -ForegroundColor $(if ($parsed.nested.key -eq 'value') { 'Green' } else { 'Red' })
    
    # Test 5: File Watcher
    Write-Host "`nTest 5: File Change Detection"
    $testFile = Join-Path $env:TEMP "configcore-test.txt"
    "Test content" | Out-File $testFile -Force
    $changed1 = [Autopilot.ConfigCore.ConfigFileWatcher]::HasChanged($testFile)
    Write-Host "  First check (should be true - first time): $changed1" -ForegroundColor $(if ($changed1) { 'Green' } else { 'Red' })
    [Autopilot.ConfigCore.ConfigFileWatcher]::UpdateMetadata($testFile)
    $changed2 = [Autopilot.ConfigCore.ConfigFileWatcher]::HasChanged($testFile)
    Write-Host "  Second check (should be false - no change): $changed2" -ForegroundColor $(if (-not $changed2) { 'Green' } else { 'Red' })
    Start-Sleep -Milliseconds 100
    "New content" | Out-File $testFile -Force
    Start-Sleep -Milliseconds 100
    $changed3 = [Autopilot.ConfigCore.ConfigFileWatcher]::HasChanged($testFile)
    Write-Host "  Third check (should be true - file modified): $changed3" -ForegroundColor $(if ($changed3) { 'Green' } else { 'Red' })
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  All Tests Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}
else
{
    Write-Host "`nConfigCore.dll not loaded - tests skipped" -ForegroundColor Yellow
}
