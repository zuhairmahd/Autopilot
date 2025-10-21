# Test the fix for array unwrapping issue
param(
    [string]$DomainConfigPath = ".\arabictutor.com.psd1"
)
$domainConfig = Import-PowerShellDataFile -Path $DomainConfigPath

Write-Host "`n══ Testing ORIGINAL assignment (buggy) ══" -ForegroundColor Red
$testVariable1 = if ($null -ne $domainConfig.autopilotProfilesToInclude)
{ 
    $domainConfig.autopilotProfilesToInclude 
}
else
{ 
    @() 
}
Write-Host "Type:  $($testVariable1.GetType().FullName)" -ForegroundColor White
Write-Host "Count: $($testVariable1.Count)" -ForegroundColor $(if ($testVariable1.Count -eq 2) { "Red" } else { "Green" })

Write-Host "`n══ Testing FIXED assignment with @() wrapper ══" -ForegroundColor Green
$testVariable2 = @(if ($null -ne $domainConfig.autopilotProfilesToInclude)
    { 
        $domainConfig.autopilotProfilesToInclude 
    }
    else
    { 
        @() 
    })
Write-Host "Type:  $($testVariable2.GetType().FullName)" -ForegroundColor White
Write-Host "Count: $($testVariable2.Count)" -ForegroundColor $(if ($testVariable2.Count -eq 1) { "Green" } else { "Red" })

if ($testVariable2.Count -eq 1)
{
    Write-Host "`n✓ FIX CONFIRMED: Array now correctly reports 1 element!" -ForegroundColor Green
}
else
{
    Write-Host "`n✗ FIX FAILED: Array still shows incorrect count" -ForegroundColor Red
}
