# Test #8: Validate error categorization implementation
# This test verifies that all 7 remaining errors are properly categorized

Import-Module "$PSScriptRoot/../functions/encryptionFunctions/Get-StoredCredential.ps1" -Force
Import-Module "$PSScriptRoot/../functions/graphFunctions/CallGraphAPI.ps1" -Force
Import-Module "$PSScriptRoot/../functions/graphFunctions/GetGraphObjectMetadata.ps1" -Force
Import-Module "$PSScriptRoot/../functions/autopilotFunctions/Get-ResourceListEndpoints.ps1" -Force
Import-Module "$PSScriptRoot/../functions/UserAndGroupFunctions/Export-ConfigurationAssignments.ps1" -Force

$cred = Get-StoredCredential -Target 'AutopilotGraphAPI'
if (-not $cred) {
    Write-Host 'Failed to retrieve credentials' -ForegroundColor Red
    exit 1
}

Write-Host "`n=== TEST #8: Error Categorization Validation ===" -ForegroundColor Green
Write-Host "Testing enhanced error categorization with remediation guidance`n" -ForegroundColor Cyan

$result = Export-ConfigurationAssignments -AccessToken $cred.GetNetworkCredential().Password `
    -OutputPath "$PSScriptRoot/../logs" -IncludeBeta -CreateErrorExportFile

Write-Host "`n--- TEST #8 RESULTS ---" -ForegroundColor Green
Write-Host "Success: $($result.Success)" -ForegroundColor Cyan
Write-Host "Resources Processed: $($result.ResourceCount)" -ForegroundColor Cyan
Write-Host "Total Errors: $($result.ErrorCount)" -ForegroundColor $(if ($result.ErrorCount -eq 0) { 'Green' } elseif ($result.ErrorCount -le 10) { 'Yellow' } else { 'Red' })
Write-Host "Output File: $($result.OutputFile)" -ForegroundColor Cyan
Write-Host "Error File: $($result.ErrorFile)" -ForegroundColor Cyan

if ($result.ErrorFile -and (Test-Path $result.ErrorFile)) {
    Write-Host "`n--- ERROR CATEGORIZATION ANALYSIS ---" -ForegroundColor Yellow
    $errors = Import-Csv $result.ErrorFile
    
    Write-Host "`nTotal Errors Found: $($errors.Count)" -ForegroundColor Yellow
    
    # Group by error category
    Write-Host "`nError Category Breakdown:" -ForegroundColor Cyan
    $categoryGroups = $errors | Group-Object ErrorCategory | Sort-Object Count -Descending
    foreach ($cat in $categoryGroups) {
        $isKnown = $cat.Name -in @('API_DESIGN_LIMITATION', 'UNSUPPORTED_ENDPOINT')
        $color = if ($isKnown) { 'Cyan' } else { 'Red' }
        $label = if ($isKnown) { '[Known Limitation]' } else { '[Error]' }
        Write-Host "  $label $($cat.Name): $($cat.Count)" -ForegroundColor $color
    }
    
    # Count known limitations vs real errors
    $knownLimitations = $errors | Where-Object { $_.KnownLimitation -eq 'True' }
    $realErrors = $errors | Where-Object { $_.KnownLimitation -ne 'True' }
    
    Write-Host "`nError Type Distribution:" -ForegroundColor Cyan
    Write-Host "  Known API Limitations: $($knownLimitations.Count)" -ForegroundColor Cyan
    Write-Host "  Real Errors: $($realErrors.Count)" -ForegroundColor $(if ($realErrors.Count -eq 0) { 'Green' } else { 'Red' })
    
    # Show resource types affected
    Write-Host "`nAffected Resource Types:" -ForegroundColor Cyan
    $resourceTypes = $errors | Group-Object Parameters | ForEach-Object {
        if ($_.Name -match 'ResourceType:\s*([^,]+)') {
            $matches[1].Trim()
        }
    } | Where-Object { $_ } | Select-Object -Unique | Sort-Object
    foreach ($rt in $resourceTypes) {
        Write-Host "  - $rt" -ForegroundColor Gray
    }
    
    # Show sample remediation guidance
    if ($errors.Count -gt 0) {
        Write-Host "`nSample Remediation Guidance:" -ForegroundColor Cyan
        $sampleError = $errors | Select-Object -First 1
        Write-Host "  Resource: $($sampleError.ResourceName)" -ForegroundColor Gray
        Write-Host "  Category: $($sampleError.ErrorCategory)" -ForegroundColor Gray
        Write-Host "  Guidance: $($sampleError.RemediationGuidance)" -ForegroundColor Gray
    }
    
    # Success criteria check
    Write-Host "`n--- SUCCESS CRITERIA ---" -ForegroundColor Green
    $successRate = (($result.ResourceCount - $errors.Count) / $result.ResourceCount * 100)
    Write-Host "Success Rate: $([math]::Round($successRate, 1))%" -ForegroundColor $(if ($successRate -ge 95) { 'Green' } else { 'Yellow' })
    Write-Host "All Errors Categorized: $($errors | Where-Object { $_.ErrorCategory -ne 'UNKNOWN' -and $_.ErrorCategory -ne '' }).Count / $($errors.Count)" -ForegroundColor $(if (($errors | Where-Object { $_.ErrorCategory -eq 'UNKNOWN' -or $_.ErrorCategory -eq '' }).Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "Remediation Available: $($errors | Where-Object { $_.RemediationGuidance -ne '' }).Count / $($errors.Count)" -ForegroundColor $(if (($errors | Where-Object { $_.RemediationGuidance -eq '' }).Count -eq 0) { 'Green' } else { 'Yellow' })
    
    Write-Host "`nNote: Known limitations are documented API design patterns." -ForegroundColor Gray
    Write-Host "These require alternative implementation approaches, not bug fixes." -ForegroundColor Gray
}

Write-Host "`n=== TEST #8 COMPLETE ===" -ForegroundColor Green
