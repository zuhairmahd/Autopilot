<#
.SYNOPSIS
    Diagnostic script to investigate autopilotProfilesToInclude array count discrepancy.

.DESCRIPTION
    This script traces the data flow from the PSD1 file through Import-PowerShellDataFile
    to understand why $global:currentAutopilotProfiles shows count of 2 when the 
    configuration file contains only 1 element.
#>

param(
    [string]$DomainConfigFile = ".\arabictutor.com.psd1"
)

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Autopilot Profile Count Diagnostic Tool" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if file exists
Write-Host "[Step 1] Checking configuration file..." -ForegroundColor Yellow
if (-not (Test-Path $DomainConfigFile))
{
    Write-Host "  ERROR: File not found: $DomainConfigFile" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ File exists: $DomainConfigFile" -ForegroundColor Green
Write-Host ""

# Step 2: Import the PSD1 file
Write-Host "[Step 2] Importing PSD1 file with Import-PowerShellDataFile..." -ForegroundColor Yellow
try
{
    $domainConfig = Import-PowerShellDataFile -Path $DomainConfigFile
    Write-Host "  ✓ Successfully imported configuration" -ForegroundColor Green
}
catch
{
    Write-Host "  ERROR: Failed to import: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 3: Check the autopilotProfilesToInclude property
Write-Host "[Step 3] Analyzing autopilotProfilesToInclude property..." -ForegroundColor Yellow
$profiles = $domainConfig.autopilotProfilesToInclude

if ($null -eq $profiles)
{
    Write-Host "  WARNING: autopilotProfilesToInclude is NULL" -ForegroundColor Red
    exit 0
}

Write-Host "  ✓ Property exists and is not null" -ForegroundColor Green
Write-Host ""

# Step 4: Detailed type and count analysis
Write-Host "[Step 4] Type and Count Analysis..." -ForegroundColor Yellow
Write-Host "  Type:                    $($profiles.GetType().FullName)" -ForegroundColor White
Write-Host "  IsArray:                 $($profiles -is [Array])" -ForegroundColor White
Write-Host "  Count Property:          $($profiles.Count)" -ForegroundColor Cyan
Write-Host "  Length Property:         $($profiles.Length)" -ForegroundColor Cyan
Write-Host "  Measure-Object Count:    $(($profiles | Measure-Object).Count)" -ForegroundColor Cyan
Write-Host ""

# Step 5: Examine each element
Write-Host "[Step 5] Examining Array Elements..." -ForegroundColor Yellow
for ($i = 0; $i -lt $profiles.Count; $i++)
{
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  Element [$i]:" -ForegroundColor White
    $element = $profiles[$i]
    Write-Host "    Type:       $($element.GetType().FullName)" -ForegroundColor White
    
    if ($element -is [hashtable])
    {
        Write-Host "    Keys:       $($element.Keys.Count)" -ForegroundColor White
        Write-Host "    Properties:" -ForegroundColor White
        foreach ($key in $element.Keys)
        {
            Write-Host "      - $key : $($element[$key])" -ForegroundColor Gray
        }
    }
    elseif ($element -is [PSCustomObject])
    {
        $props = $element.PSObject.Properties
        Write-Host "    Properties: $($props.Count)" -ForegroundColor White
        foreach ($prop in $props)
        {
            Write-Host "      - $($prop.Name) : $($prop.Value)" -ForegroundColor Gray
        }
    }
    else
    {
        Write-Host "    Value:      $element" -ForegroundColor White
    }
}
Write-Host "  ─────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

# Step 6: Test assignment to variable
Write-Host "[Step 6] Testing Assignment (simulating Show-AutopilotProfilesEditor)..." -ForegroundColor Yellow
$testVariable = if ($null -ne $domainConfig.autopilotProfilesToInclude)
{
    $domainConfig.autopilotProfilesToInclude
}
else
{
    @()
}

Write-Host "  Test Variable Type:  $($testVariable.GetType().FullName)" -ForegroundColor White
Write-Host "  Test Variable Count: $($testVariable.Count)" -ForegroundColor Cyan
Write-Host ""

# Step 7: Check for hidden properties or array wrapping
Write-Host "[Step 7] Advanced Diagnostics..." -ForegroundColor Yellow
Write-Host "  Raw PSD1 autopilotProfilesToInclude:" -ForegroundColor White
$profiles | Format-List | Out-String | Write-Host -ForegroundColor Gray

Write-Host "  Array iteration test:" -ForegroundColor White
$iterationCount = 0
foreach ($profile in $profiles)
{
    $iterationCount++
    Write-Host "    Iteration $iterationCount : Type=$($profile.GetType().FullName)" -ForegroundColor Gray
}
Write-Host "  Total iterations: $iterationCount" -ForegroundColor Cyan
Write-Host ""

# Step 8: Summary
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Configuration File:      $DomainConfigFile" -ForegroundColor White
Write-Host "  Reported Count:          $($profiles.Count)" -ForegroundColor $(if ($profiles.Count -eq 1) { "Green" } else { "Yellow" })
Write-Host "  Actual Iterations:       $iterationCount" -ForegroundColor $(if ($iterationCount -eq 1) { "Green" } else { "Yellow" })
Write-Host "  Expected Count:          1" -ForegroundColor White
Write-Host ""

if ($profiles.Count -ne 1)
{
    Write-Host "  ⚠ ISSUE DETECTED: Count mismatch!" -ForegroundColor Red
    Write-Host "  The array reports $($profiles.Count) elements but should have 1." -ForegroundColor Red
}
elseif ($iterationCount -ne 1)
{
    Write-Host "  ⚠ ISSUE DETECTED: Iteration mismatch!" -ForegroundColor Red
    Write-Host "  The array iterated $iterationCount times but should iterate 1 time." -ForegroundColor Red
}
else
{
    Write-Host "  ✓ No issues detected - array contains exactly 1 element" -ForegroundColor Green
}
Write-Host ""
