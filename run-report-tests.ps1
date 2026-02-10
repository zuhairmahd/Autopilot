# Quick test runner for all report tests
$tests = @(
    'Get-AutopilotEventAnalysis.Tests.ps1',
    'Show-AutopilotEventAnalysis.Tests.ps1',
    'Export-AutopilotEventAnalysis.Tests.ps1'
)

Write-Host "`n========== REPORT TESTS SUMMARY ==========`n" -ForegroundColor Cyan

foreach ($testFile in $tests) {
    $testPath = "tests\Unit\Reports\$testFile"

    $config = New-PesterConfiguration
    $config.Run.Path = $testPath
    $config.Output.Verbosity = 'Minimal'
    $config.Run.PassThru = $true

    $result = Invoke-Pester -Configuration $config

    $status = if ($result.FailedCount -eq 0) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($result.FailedCount -eq 0) { "Green" } else { "Yellow" }

    Write-Host "$status $testFile" -ForegroundColor $color
    Write-Host "      $($result.PassedCount)/$($result.TotalCount) passing" -ForegroundColor Gray
    if ($result.FailedCount -gt 0) {
        Write-Host "      $($result.FailedCount) failures" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "=========================================`n" -ForegroundColor Cyan
