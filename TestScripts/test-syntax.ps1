# Simple syntax check for PowerShell files
param(
    [string[]]$Files = @("./main.ps1", "./functions/FirstRunWizardFunctions.ps1")
)

Write-Host "Checking PowerShell syntax..." -ForegroundColor Green

foreach ($file in $Files) {
    if (Test-Path $file) {
        Write-Host "Checking: $file" -ForegroundColor Cyan
        try {
            $content = Get-Content $file -Raw
            $tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
            Write-Host "✓ Syntax OK - $($tokens.Count) tokens" -ForegroundColor Green
        } catch {
            Write-Host "✗ Syntax Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ File not found: $file" -ForegroundColor Red
    }
}

Write-Host "Syntax check completed!" -ForegroundColor Green