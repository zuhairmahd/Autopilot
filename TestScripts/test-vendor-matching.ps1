<#
.SYNOPSIS
    Regression test for vendor matching logic in GetDeviceInfo.
.DESCRIPTION
    Ensures that when 'Microsoft' is in the allowed vendors list, a device reporting
    'Microsoft Corporation' (common on Windows hardware / virtual environments) is accepted.
#>
[CmdletBinding()]
param()

Write-Host 'Starting vendor matching regression test...' -ForegroundColor Cyan

# Simulate settings object
$global:settings = [ordered]@{
    autopilotDeviceAllowedVendors = @('Dell Inc.', 'Microsoft', 'VMWare')
}

# Provide a fake log file path and other globals if required by write-log
if (-not $global:LogFile)
{
    $global:LogFile = "$PWD/Logs/vendor-test.log" 
}
if (-not (Test-Path (Split-Path $global:LogFile -Parent)))
{
    New-Item -ItemType Directory -Path (Split-Path $global:LogFile -Parent) | Out-Null 
}
if (-not (Get-Command GetDeviceInfo -ErrorAction SilentlyContinue))
{
    . "$PSScriptRoot/../functions/autopilotFunctions/GetDeviceInfo.ps1"
}

# Call with override simulating actual manufacturer value
$result = GetDeviceInfo -ManufacturerOverride 'Microsoft Corporation' -NoHash -Verbose:$false

if ($result.deviceAllowed -ne $true)
{
    Write-Host "Test FAILED: Expected deviceAllowed = true when allowed vendors contains 'Microsoft'." -ForegroundColor Red
    Write-Host "Result object:" -ForegroundColor Red
    $result | Format-List | Out-String | Write-Host
    exit 1
}
else
{
    Write-Host 'Test PASSED: Manufacturer override matched allowed vendor entry.' -ForegroundColor Green
}
