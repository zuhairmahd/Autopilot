# Quick validation script for refactored functions
try
{
    # Try to load the refactored function
    . "$PSScriptRoot\..\functions\autopilotFunctions\Reports\Get-SignInActivity.ps1"

    Write-Host "Successfully loaded Get-SignInActivity.ps1" -ForegroundColor Green

    # Check if functions are defined
    $functions = @('Get-SignInActivity', 'ConvertTo-SignInEnrichmentData', 'Get-UserSignInActivity')
    $allFound = $true

    foreach ($func in $functions)
    {
        $cmd = Get-Command $func -ErrorAction SilentlyContinue
        if ($cmd)
        {
            Write-Host "  [OK] $func found" -ForegroundColor Green
        }
        else
        {
            Write-Host "  [MISSING] $func not found" -ForegroundColor Red
            $allFound = $false
        }
    }

    if ($allFound)
    {
        Write-Host "`nAll refactored functions are available!" -ForegroundColor Green
        exit 0
    }
    else
    {
        Write-Host "`nSome functions are missing!" -ForegroundColor Red
        exit 1
    }
}
catch
{
    Write-Host "Error loading file: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
