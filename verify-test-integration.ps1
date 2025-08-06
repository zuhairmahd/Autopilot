#!/usr/bin/env pwsh
# Verification script to test the new menu tests integration

Write-Host "Testing Menu Test Integration with Unified Framework" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Test 1: Verify new test files exist in TestScripts
Write-Host "`nTest 1: Verifying new test files exist" -ForegroundColor Yellow

$newTestFiles = @(
    "TestScripts\test-menu-logic-validation.ps1",
    "TestScripts\test-menu-search-logic.ps1"
)

foreach ($testFile in $newTestFiles) {
    if (Test-Path $testFile) {
        Write-Host "  ✓ $testFile exists" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $testFile missing" -ForegroundColor Red
    }
}

# Test 2: Verify test files have correct shebang and framework usage
Write-Host "`nTest 2: Verifying test files use unified framework" -ForegroundColor Yellow

foreach ($testFile in $newTestFiles) {
    if (Test-Path $testFile) {
        $content = Get-Content $testFile -Raw
        if ($content -match "#!/usr/bin/env pwsh") {
            Write-Host "  ✓ $testFile has correct shebang" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $testFile missing shebang" -ForegroundColor Red
        }
        
        if ($content -match "Start-UnifiedTest") {
            Write-Host "  ✓ $testFile uses unified framework" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $testFile not using unified framework" -ForegroundColor Red
        }
        
        if ($content -match "Write-TestResult") {
            Write-Host "  ✓ $testFile uses Write-TestResult" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $testFile not using Write-TestResult" -ForegroundColor Red
        }
    }
}

# Test 3: Verify existing tests are updated 
Write-Host "`nTest 3: Verifying existing test consolidation" -ForegroundColor Yellow

$existingTestFile = "TestScripts\test-menu-inclusions.ps1"
if (Test-Path $existingTestFile) {
    $content = Get-Content $existingTestFile -Raw
    if ($content -match "Start-UnifiedTest") {
        Write-Host "  ✓ $existingTestFile updated to use unified framework" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $existingTestFile not updated" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ $existingTestFile missing" -ForegroundColor Red
}

# Test 4: Verify test discovery pattern
Write-Host "`nTest 4: Verifying test discovery by run-all-tests.ps1" -ForegroundColor Yellow

$runAllTests = "TestScripts\run-all-tests.ps1"
if (Test-Path $runAllTests) {
    Write-Host "  ✓ run-all-tests.ps1 exists" -ForegroundColor Green
    
    # Check that it will discover our new tests
    $testFiles = Get-ChildItem -Path "TestScripts" -Filter "test-menu*.ps1" | Where-Object { $_.Name -ne "test-helper.ps1" }
    Write-Host "  ✓ Found $($testFiles.Count) menu-related test files:" -ForegroundColor Green
    foreach ($file in $testFiles) {
        Write-Host "    - $($file.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host "  ✗ run-all-tests.ps1 missing" -ForegroundColor Red
}

Write-Host "`nIntegration verification completed!" -ForegroundColor Cyan
Write-Host "`nTo run the new tests:" -ForegroundColor Yellow
Write-Host "  Individual: .\TestScripts\test-menu-logic-validation.ps1" -ForegroundColor White
Write-Host "  Individual: .\TestScripts\test-menu-search-logic.ps1" -ForegroundColor White
Write-Host "  All menu tests: .\TestScripts\run-all-tests.ps1 -TestPattern 'test-menu*.ps1'" -ForegroundColor White
Write-Host "  All tests: .\TestScripts\run-all-tests.ps1" -ForegroundColor White
