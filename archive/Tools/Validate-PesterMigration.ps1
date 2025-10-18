<#
.SYNOPSIS
    Validates Pester migration for a specific test
.DESCRIPTION
    Compares legacy test and Pester test results to ensure equivalence
.PARAMETER LegacyTestPath
    Path to legacy test file
.PARAMETER PesterTestPath
    Path to Pester test file
.EXAMPLE
    .\tools\Validate-PesterMigration.ps1 -LegacyTestPath .\TestScripts\archived\test-syntax.ps1 -PesterTestPath .\tests\Unit\Syntax.Tests.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LegacyTestPath,
    
    [Parameter(Mandatory)]
    [string]$PesterTestPath
)

Write-Host "Validating Migration" -ForegroundColor Cyan
Write-Host "Legacy: $LegacyTestPath" -ForegroundColor Gray
Write-Host "Pester: $PesterTestPath" -ForegroundColor Gray
Write-Host ""

# Run legacy test
Write-Host "Running legacy test..." -ForegroundColor Yellow
$legacyOutput = & $LegacyTestPath 2>&1
$legacyExitCode = $LASTEXITCODE
$legacyPassed = $legacyExitCode -eq 0

# Run Pester test
Write-Host "Running Pester test..." -ForegroundColor Yellow
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $PesterTestPath
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Minimal'
$pesterResult = Invoke-Pester -Configuration $pesterConfig
$pesterPassed = $pesterResult.FailedCount -eq 0

# Compare results
Write-Host ""
Write-Host "Comparison Results:" -ForegroundColor Cyan
Write-Host "  Legacy Status: $(if ($legacyPassed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($legacyPassed) { 'Green' } else { 'Red' })
Write-Host "  Pester Status: $(if ($pesterPassed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($pesterPassed) { 'Green' } else { 'Red' })

$match = ($legacyPassed -eq $pesterPassed)
Write-Host "  Results Match: $match" -ForegroundColor $(if ($match) { 'Green' } else { 'Red' })

if (-not $match) {
    Write-Host ""
    Write-Host "VALIDATION FAILED - Results do not match!" -ForegroundColor Red
    Write-Host "Legacy exit code: $legacyExitCode" -ForegroundColor Yellow
    Write-Host "Pester failed count: $($pesterResult.FailedCount)" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "VALIDATION PASSED - Migration successful!" -ForegroundColor Green
exit 0
