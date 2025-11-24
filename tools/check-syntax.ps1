param([string]$FilePath)

if (-not (Test-Path $FilePath)) {
    Write-Host "File not found: $FilePath" -ForegroundColor Red
    exit 1
}

try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$null)
    Write-Host "Syntax validation PASSED: $FilePath" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "Syntax validation FAILED: $FilePath" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
