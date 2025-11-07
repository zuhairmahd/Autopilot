# Test directory removal approach for undeletable files
param()

Write-Host "Testing directory removal approach for undeletable files..." -ForegroundColor Cyan

# Set up test environment
$testDir = Join-Path $env:TEMP "TestUndeletableFile"
New-Item $testDir -ItemType Directory -Force | Out-Null

try {
    # Create a subdirectory and file
    $subDir = Join-Path $testDir "subdir"
    New-Item $subDir -ItemType Directory -Force | Out-Null
    
    $testFile = Join-Path $subDir "test.txt"
    New-Item $testFile -ItemType File -Force | Out-Null
    "test content" | Out-File $testFile
    Write-Host "✓ Created file: $testFile" -ForegroundColor Green
    
    # Remove the parent directory to make the file path invalid
    Remove-Item $subDir -Recurse -Force
    Write-Host "✓ Removed parent directory: $subDir" -ForegroundColor Green
    
    # Try to delete the file - this should fail because path doesn't exist
    try {
        Remove-Item $testFile -Force -ErrorAction Stop
        Write-Host "✗ UNEXPECTED: File deletion succeeded" -ForegroundColor Red
    }
    catch {
        Write-Host "✓ EXPECTED: Deletion failed with error: $($_.Exception.Message)" -ForegroundColor Green
        
        # Verify file path doesn't exist
        if (-not (Test-Path $testFile)) {
            Write-Host "✓ CONFIRMED: File path doesn't exist" -ForegroundColor Green
        }
    }
}
finally {
    # Clean up test directory
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Cleaned up test directory" -ForegroundColor Green
}

Write-Host "`nDirectory removal approach test complete." -ForegroundColor Cyan
Write-Host "Let's try a different approach using file locking..." -ForegroundColor Yellow

# Test file locking approach
$testDir2 = Join-Path $env:TEMP "TestFileLocking"
New-Item $testDir2 -ItemType Directory -Force | Out-Null

try {
    $testFile2 = Join-Path $testDir2 "locked.txt"
    
    # Create and open file for exclusive access
    $fileStream = [System.IO.File]::Create($testFile2)
    Write-Host "✓ Created and locked file: $testFile2" -ForegroundColor Green
    
    try {
        Remove-Item $testFile2 -Force -ErrorAction Stop
        Write-Host "✗ UNEXPECTED: Locked file was deleted" -ForegroundColor Red
    }
    catch {
        Write-Host "✓ EXPECTED: Deletion of locked file failed: $($_.Exception.Message)" -ForegroundColor Green
    }
    
    # Close the file stream
    $fileStream.Close()
    $fileStream.Dispose()
    Write-Host "✓ Released file lock" -ForegroundColor Green
    
}
finally {
    if ($fileStream) {
        $fileStream.Close()
        $fileStream.Dispose()
    }
    Remove-Item $testDir2 -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Cleaned up test directory" -ForegroundColor Green
}

Write-Host "`nFile locking approach test complete." -ForegroundColor Cyan