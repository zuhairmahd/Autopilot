# Test read-only file deletion failure
param()

Write-Host "Testing read-only file deletion failure approach..." -ForegroundColor Cyan

# Set up test environment
$testDir = Join-Path $env:TEMP "TestReadOnlyDeletion"
New-Item $testDir -ItemType Directory -Force | Out-Null

try {
    # Create a test file
    $testFile = Join-Path $testDir "test.txt"
    New-Item $testFile -ItemType File -Force | Out-Null
    "test content" | Out-File $testFile
    
    # Make it read-only
    Set-ItemProperty -Path $testFile -Name IsReadOnly -Value $true
    Write-Host "✓ Created read-only file: $testFile" -ForegroundColor Green
    
    # Try to delete it - this should fail
    try {
        Remove-Item $testFile -Force -ErrorAction Stop
        Write-Host "✗ UNEXPECTED: File was deleted despite being read-only" -ForegroundColor Red
    }
    catch {
        Write-Host "✓ EXPECTED: Deletion failed with error: $($_.Exception.Message)" -ForegroundColor Green
        
        # Verify file still exists
        if (Test-Path $testFile) {
            Write-Host "✓ CONFIRMED: File still exists after failed deletion" -ForegroundColor Green
        }
        else {
            Write-Host "✗ UNEXPECTED: File doesn't exist after 'failed' deletion" -ForegroundColor Red
        }
    }
    
    # Clean up
    Set-ItemProperty -Path $testFile -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Cleaned up test file" -ForegroundColor Green
}
finally {
    # Clean up test directory
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Cleaned up test directory" -ForegroundColor Green
}

Write-Host "`nRead-only file approach test complete." -ForegroundColor Cyan