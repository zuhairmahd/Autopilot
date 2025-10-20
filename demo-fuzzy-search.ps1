# Demo: Fuzzy Test File Search
# This script demonstrates the new fuzzy search functionality in Invoke-PesterTests.ps1

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Fuzzy Test File Search Demo" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Test with just a filename
Write-Host "Test 1: Using just a filename" -ForegroundColor Yellow
Write-Host "Command: .\Invoke-PesterTests.ps1 -TestFile 'SettingsFunctions.Tests.ps1'" -ForegroundColor Gray
Write-Host "Expected: Should find the file in tests\Integration folder" -ForegroundColor Gray
Write-Host ""

# Test 2: Test with partial name
Write-Host "Test 2: Using partial name for fuzzy search" -ForegroundColor Yellow
Write-Host "Command: .\Invoke-PesterTests.ps1 -TestFile 'Settings'" -ForegroundColor Gray
Write-Host "Expected: Should show menu with Settings-related test files" -ForegroundColor Gray
Write-Host ""

# Test 3: Test with typo
Write-Host "Test 3: Using filename with typo" -ForegroundColor Yellow
Write-Host "Command: .\Invoke-PesterTests.ps1 -TestFile 'Sttings'" -ForegroundColor Gray
Write-Host "Expected: Should still find SettingsFunctions.Tests.ps1 via fuzzy match" -ForegroundColor Gray
Write-Host ""

# Test 4: Test with keyword
Write-Host "Test 4: Using keyword search" -ForegroundColor Yellow
Write-Host "Command: .\Invoke-PesterTests.ps1 -TestFile 'Menu'" -ForegroundColor Gray
Write-Host "Expected: Should show all menu-related test files" -ForegroundColor Gray
Write-Host ""

# Test 5: Test with non-existent file
Write-Host "Test 5: Using non-existent filename" -ForegroundColor Yellow
Write-Host "Command: .\Invoke-PesterTests.ps1 -TestFile 'NonExistentTest'" -ForegroundColor Gray
Write-Host "Expected: Should show 'No similar test files found' error" -ForegroundColor Gray
Write-Host ""

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "To run these tests manually, use the commands above." -ForegroundColor White
Write-Host "The fuzzy search will activate automatically when" -ForegroundColor White
Write-Host "the specified file cannot be found." -ForegroundColor White
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Show available test files for reference
Write-Host "Available test files in the tests folder:" -ForegroundColor Cyan
Write-Host ""
Get-ChildItem -Path "$PSScriptRoot\tests" -Filter "*.Tests.ps1" -Recurse | 
    ForEach-Object { $_.FullName.Replace("$PSScriptRoot\", "") } |
    Sort-Object |
    Select-Object -First 15 |
    ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
Write-Host "  ... (and more)" -ForegroundColor Gray
Write-Host ""
