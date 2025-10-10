<#
.SYNOPSIS
    Runs all tests - both Pester and legacy
.DESCRIPTION
    Executes full test suite including Pester tests and remaining legacy tests
    Generates combined report
.PARAMETER Quick
    Run only fast tests (Unit tests only)
.PARAMETER CI
    Run in CI/CD mode with XML output
.EXAMPLE
    .\Invoke-AllTests.ps1 -Quick
.EXAMPLE
    .\Invoke-AllTests.ps1 -CI
#>
[CmdletBinding()]
param(
    [switch]$Quick,  # Run only fast tests
    [switch]$CI      # CI/CD mode
)

Write-Host "=" * 63 -ForegroundColor Cyan
Write-Host "  Autopilot Complete Test Suite" -ForegroundColor Cyan
Write-Host "=" * 63 -ForegroundColor Cyan

$startTime = Get-Date
$allPassed = $true

# Run Pester tests
Write-Host "`n=== Running Pester Tests ===" -ForegroundColor Yellow
try {
    if ($Quick) {
        & "$PSScriptRoot\Invoke-PesterTests.ps1" -TestType Unit -CI:$CI
    } else {
        & "$PSScriptRoot\Invoke-PesterTests.ps1" -TestType All -EnableCodeCoverage -CI:$CI
    }
    $pesterExitCode = $LASTEXITCODE
    if ($pesterExitCode -ne 0) { $allPassed = $false }
}
catch {
    Write-Host "Error running Pester tests: $($_.Exception.Message)" -ForegroundColor Red
    $pesterExitCode = 1
    $allPassed = $false
}

# Run remaining legacy tests (categories not yet migrated)
Write-Host "`n=== Running Legacy Tests ===" -ForegroundColor Yellow
$legacyCategories = @('performance')  # Only categories not migrated

$legacyExitCode = 0
foreach ($category in $legacyCategories) {
    Write-Host "Running $category tests..." -ForegroundColor Cyan
    try {
        & "$PSScriptRoot\TestScripts\Test-Runner.ps1" -TestCategory $category
        $categoryExitCode = $LASTEXITCODE
        if ($categoryExitCode -ne 0) { 
            $legacyExitCode = $categoryExitCode
            $allPassed = $false 
        }
    }
    catch {
        Write-Host "Error running $category tests: $($_.Exception.Message)" -ForegroundColor Red
        $legacyExitCode = 1
        $allPassed = $false
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

# Combined report
Write-Host "`n" -NoNewline
Write-Host "=" * 63 -ForegroundColor Cyan
Write-Host "  Complete Suite Results" -ForegroundColor Cyan
Write-Host "=" * 63 -ForegroundColor Cyan
Write-Host "  Pester Tests: $(if ($pesterExitCode -eq 0) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($pesterExitCode -eq 0) { 'Green' } else { 'Red' })
Write-Host "  Legacy Tests: $(if ($legacyExitCode -eq 0) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($legacyExitCode -eq 0) { 'Green' } else { 'Red' })
Write-Host "  Total Duration: $($duration.TotalMinutes.ToString('F1')) minutes" -ForegroundColor White
Write-Host "  Overall Status: $(if ($allPassed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($allPassed) { 'Green' } else { 'Red' })
Write-Host "=" * 63 -ForegroundColor Cyan
Write-Host ""

exit $(if ($allPassed) { 0 } else { 1 })
