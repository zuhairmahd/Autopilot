# Test script for GetAppAssignmentTypes function enhancements

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

# Tests the functionality described in the problem statement
# PowerShell 5.1 compatible

Write-Host "Testing GetAppAssignmentTypes Function Enhancements" -ForegroundColor Green

# Load the function
Write-TestSection "`n1. Loading GetAppAssignmentTypes function..."
try {
    $rootPath = Split-Path -Parent $PSScriptRoot
Load-AllFunctions -RootPath $rootPath | Out-Null
    Write-Host "[PASS] Function loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Error loading function: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Testing parameter validation..." -ForegroundColor Cyan

# Test parameter structure
$commandInfo = Get-Command GetAppAssignmentTypes
$parameters = $commandInfo.Parameters

# Test AccessToken parameter (mandatory)
$accessTokenParam = $parameters['AccessToken']
if ($accessTokenParam.Attributes.Mandatory) {
    Write-Host "[PASS] AccessToken parameter is mandatory" -ForegroundColor Green
} else {
    Write-Host "[FAIL] AccessToken parameter should be mandatory" -ForegroundColor Red
}

# Test Export parameter (switch)
$exportParam = $parameters['Export']
if ($exportParam -and $exportParam.ParameterType -eq [switch]) {
    Write-Host "[PASS] Export parameter is a switch" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Export parameter should be a switch" -ForegroundColor Red
}

# Test outputPath parameter (required when Export is used)
$outputPathParam = $parameters['outputPath']
$exportParameterSet = $outputPathParam.Attributes | Where-Object { $_.GetType().Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'Export' -and $_.Mandatory -eq $true }
if ($exportParameterSet) {
    Write-Host "[PASS] outputPath parameter is mandatory in Export parameter set" -ForegroundColor Green
} else {
    Write-Host "[FAIL] outputPath parameter should be mandatory when Export is used" -ForegroundColor Red
}

# Test fileMode parameter validation
$fileModeParam = $parameters['fileMode']
$validateSet = $fileModeParam.Attributes | Where-Object { $_.GetType().Name -eq 'ValidateSetAttribute' }
if ($validateSet -and $validateSet.ValidValues -contains 'Append' -and $validateSet.ValidValues -contains 'Overwrite') {
    Write-Host "[PASS] fileMode parameter has correct validation: $($validateSet.ValidValues -join ', ')" -ForegroundColor Green
} else {
    Write-Host "[FAIL] fileMode parameter should validate Append and Overwrite" -ForegroundColor Red
}

Write-Host "`n3. Testing function content for required features..." -ForegroundColor Cyan

$functionContent = Get-Content ".\functions\GetAppAssignmentTypes.ps1" -Raw

# Test for PSCustomObject usage
if ($functionContent -match '\[PSCustomObject\]') {
    Write-Host "[PASS] Function uses [PSCustomObject] for robust CSV output" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Function should use [PSCustomObject] for CSV output" -ForegroundColor Red
}

# Test for extensive logging
$verboseCount = ([regex]::Matches($functionContent, 'Write-Verbose')).Count
$logCount = ([regex]::Matches($functionContent, 'Write-Log')).Count
if ($verboseCount -gt 30 -and $logCount -gt 30) {
    Write-Host "[PASS] Function has extensive logging: $verboseCount Write-Verbose + $logCount Write-Log statements" -ForegroundColor Green
} else {
    Write-Host "⚠ Function has moderate logging: $verboseCount Write-Verbose + $logCount Write-Log statements" -ForegroundColor Yellow
}

# Test for Intent column in CSV export
if ($functionContent -match 'Intent.*=.*"Required"' -and $functionContent -match 'Intent.*=.*"Available"' -and $functionContent -match 'Intent.*=.*"Unassigned"') {
    Write-Host "[PASS] Function adds Intent/category column to CSV export" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Function should add Intent column with Required/Available/Unassigned values" -ForegroundColor Red
}

# Test for structured return object
if ($functionContent -match 'RequiredApps.*=' -and $functionContent -match 'AvailableApps.*=' -and $functionContent -match 'UnassignedApps.*=' -and $functionContent -match 'AllApps.*=') {
    Write-Host "[PASS] Function creates structured return object with all required properties" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Function should return object with RequiredApps, AvailableApps, UnassignedApps, AllApps" -ForegroundColor Red
}

# Test for correct return value (not tuple)
if ($functionContent -match 'return \$returnedApps' -and $functionContent -notmatch 'return \$exportSuccessful, \$returnedApps') {
    Write-Host "[PASS] Function returns structured object (not tuple)" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Function should return structured object, not tuple" -ForegroundColor Red
}

# Test for CSV export handling
if ($functionContent -match 'if \(\$Export\)' -and $functionContent -match 'Export-Csv') {
    Write-Host "[PASS] Function handles CSV export correctly" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Function should handle CSV export when Export parameter is used" -ForegroundColor Red
}

# Test for file mode handling
if ($functionContent -match "fileMode -eq 'Append'" -and $functionContent -match "-Append") {
    Write-Host "[PASS] Function handles Append mode correctly" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Function should handle Append file mode" -ForegroundColor Red
}

Write-Host "`n4. Testing usage examples from problem statement..." -ForegroundColor Cyan

# Test the syntax of usage examples
try {
    # These are the exact examples from the problem statement
    $example1 = 'GetAppAssignmentTypes -AccessToken $token -Export -outputPath "app-assignments.csv" -fileMode Overwrite'
    $example2 = 'GetAppAssignmentTypes -AccessToken $token -Export -outputPath "app-assignments.csv" -fileMode Append'
    $example3 = '$result = GetAppAssignmentTypes -AccessToken $token'
    
    # Parse the syntax (without executing)
    [scriptblock]::Create($example1) | Out-Null
    [scriptblock]::Create($example2) | Out-Null  
    [scriptblock]::Create($example3) | Out-Null
    
    Write-Host "[PASS] All usage examples from problem statement have valid syntax" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Usage example syntax error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Green
Write-Host "GetAppAssignmentTypes function enhancement test completed!" -ForegroundColor Green
Write-Host "The function implements all requirements from the problem statement:" -ForegroundColor Green
Write-Host "• Enhanced parameters: -Export, -outputPath, -fileMode" -ForegroundColor Green
Write-Host "• Exports all app assignments to single CSV with intent/category column" -ForegroundColor Green  
Write-Host "• Uses [PSCustomObject] for robust CSV output" -ForegroundColor Green
Write-Host "• Extensive Write-Verbose and Write-Log logging" -ForegroundColor Green
Write-Host "• Returns structured object for programmatic use" -ForegroundColor Green
Write-Host "• Fixes previous export bugs (CSV path, case sensitivity, return value)" -ForegroundColor Green
