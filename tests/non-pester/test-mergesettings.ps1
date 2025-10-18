# Test MergeSettings with ConfigCore integration

. 'c:\Users\zuhai\code\Autopilot\functions\utilityFunctions\Initialize-AutopilotDlls.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\FirstRunWizardFunctions\ConvertFrom-JsonToHashtable.ps1'
. 'c:\Users\zuhai\code\Autopilot\functions\setupFunctions\MergeSettings.ps1'

$dllStatus = Initialize-AutopilotDlls -DLLPath 'c:\Users\zuhai\code\Autopilot\bin\Release'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  MergeSettings ConfigCore Integration Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nDLL Status: ConfigCore=$($dllStatus.ConfigCoreLoaded)" -ForegroundColor $(if ($dllStatus.ConfigCoreLoaded) { 'Green' } else { 'Yellow' })

$local = @{ Name = "Local"; Age = 30; City = "NYC" }
$global = @{ Age = 31; Country = "USA"; Region = "NA" }

Write-Host "`nInput:" -ForegroundColor Cyan
Write-Host "  Local: Name=$($local.Name), Age=$($local.Age), City=$($local.City)"
Write-Host "  Global: Age=$($global.Age), Country=$($global.Country), Region=$($global.Region)"

Write-Host "`nExecuting merge..." -ForegroundColor Cyan
$merged = MergeSettings -localSettings $local -globalSettings $global -ConflictResolution 'Global' -Verbose

Write-Host "`nResults:" -ForegroundColor Green
Write-Host "  Total keys: $($merged.Count)"
Write-Host "  Name: $($merged.Name)" -ForegroundColor $(if ($merged.Name -eq 'Local') { 'Green' } else { 'Red' })
Write-Host "  Age (should be 31): $($merged.Age)" -ForegroundColor $(if ($merged.Age -eq 31) { 'Green' } else { 'Red' })
Write-Host "  City: $($merged.City)" -ForegroundColor $(if ($merged.City -eq 'NYC') { 'Green' } else { 'Red' })
Write-Host "  Country: $($merged.Country)" -ForegroundColor $(if ($merged.Country -eq 'USA') { 'Green' } else { 'Red' })
Write-Host "  Region: $($merged.Region)" -ForegroundColor $(if ($merged.Region -eq 'NA') { 'Green' } else { 'Red' })

if ($merged.Count -eq 5 -and $merged.Age -eq 31)
{
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  SUCCESS: MergeSettings working with ConfigCore!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}
else
{
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "  ERROR: Unexpected results" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
}
