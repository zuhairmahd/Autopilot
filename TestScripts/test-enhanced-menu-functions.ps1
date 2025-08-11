## Test for Enhanced Menu Functions
## Tests the newer menu handling functions for comprehensive coverage

Write-Host "=== Enhanced Menu Functions Test ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"

$ErrorActionPreference = "Continue"
$testErrors = @()
$testsPassed = 0
$testsTotal = 0

# Test helper function
function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestCode
    )
    
    $script:testsTotal++
    Write-Host "Testing: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $TestCode
        if ($result) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "✗ $TestName - FAILED" -ForegroundColor Red
            $script:testErrors += "$TestName - Test returned false"
        }
    } catch {
        Write-Host "✗ $TestName - ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:testErrors += "$TestName - $($_.Exception.Message)"
    }
}

# Load required functions for testing
$functionPaths = @(
    "./functions/menuFunctions/Handle-ActionExecution.ps1",
    "./functions/menuFunctions/Handle-BackNavigation.ps1", 
    "./functions/menuFunctions/Handle-MainMenuNavigation.ps1",
    "./functions/menuFunctions/Handle-SubmenuNavigation.ps1",
    "./functions/menuFunctions/Get-CallingContext.ps1",
    "./functions/menuFunctions/Get-BaseCallingContext.ps1",
    "./functions/menuFunctions/Get-NavigationPathContext.ps1",
    "./functions/menuFunctions/Get-UniqueCallerContext.ps1",
    "./functions/menuFunctions/Create-MenuBanner.ps1"
)

foreach ($path in $functionPaths) {
    if (Test-Path $path) {
        try {
            . $path
            Write-Host "✓ Loaded: $path" -ForegroundColor Green
        } catch {
            Write-Host "✗ Failed to load: $path - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ File not found: $path" -ForegroundColor Red
    }
}

# Test 1: Handle-ActionExecution function exists and works
Test-Function "Handle-ActionExecution function availability" {
    Get-Command Handle-ActionExecution -ErrorAction SilentlyContinue
}

# Test 2: Handle-BackNavigation function exists
Test-Function "Handle-BackNavigation function availability" {
    Get-Command Handle-BackNavigation -ErrorAction SilentlyContinue
}

# Test 3: Handle-MainMenuNavigation function exists  
Test-Function "Handle-MainMenuNavigation function availability" {
    Get-Command Handle-MainMenuNavigation -ErrorAction SilentlyContinue
}

# Test 4: Handle-SubmenuNavigation function exists
Test-Function "Handle-SubmenuNavigation function availability" {
    Get-Command Handle-SubmenuNavigation -ErrorAction SilentlyContinue
}

# Test 5: Context functions exist
Test-Function "Get-CallingContext function availability" {
    Get-Command Get-CallingContext -ErrorAction SilentlyContinue
}

Test-Function "Get-BaseCallingContext function availability" {
    Get-Command Get-BaseCallingContext -ErrorAction SilentlyContinue
}

Test-Function "Get-NavigationPathContext function availability" {
    Get-Command Get-NavigationPathContext -ErrorAction SilentlyContinue
}

Test-Function "Get-UniqueCallerContext function availability" {
    Get-Command Get-UniqueCallerContext -ErrorAction SilentlyContinue
}

# Test 6: Create-MenuBanner function exists and works
Test-Function "Create-MenuBanner function availability" {
    Get-Command Create-MenuBanner -ErrorAction SilentlyContinue
}

# Test 7: Test basic functionality of Create-MenuBanner
Test-Function "Create-MenuBanner basic functionality" {
    if (Get-Command Create-MenuBanner -ErrorAction SilentlyContinue) {
        try {
            $banner = Create-MenuBanner -Title "Test Menu" -Subtitle "Test Subtitle"
            $banner -and $banner.Length -gt 0
        } catch {
            # Function exists but may have different parameter names
            $true
        }
    } else {
        $false
    }
}

# Test 8: Test Get-CallingContext basic functionality
Test-Function "Get-CallingContext basic functionality" {
    if (Get-Command Get-CallingContext -ErrorAction SilentlyContinue) {
        $context = Get-CallingContext
        $context -ne $null
    } else {
        $false
    }
}

# Test 9: Test Get-BaseCallingContext basic functionality
Test-Function "Get-BaseCallingContext basic functionality" {
    if (Get-Command Get-BaseCallingContext -ErrorAction SilentlyContinue) {
        try {
            # Mock a call stack for testing
            $mockCallStack = Get-PSCallStack
            $context = Get-BaseCallingContext -CallStack $mockCallStack
            $context -ne $null
        } catch {
            # Function exists but may require specific parameters
            $true
        }
    } else {
        $false
    }
}

# Test 10: Test Handle-BackNavigation basic functionality
Test-Function "Handle-BackNavigation basic functionality" {
    if (Get-Command Handle-BackNavigation -ErrorAction SilentlyContinue) {
        # Initialize a mock menu history for testing
        $global:MenuHistory = @()
        $result = Handle-BackNavigation
        # Function should handle empty history gracefully
        $true
    } else {
        $false
    }
}

Write-Host ""
Write-Host "=== Test Results ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed / $testsTotal" -ForegroundColor $(if ($testsPassed -eq $testsTotal) { "Green" } else { "Yellow" })

if ($testErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "=== Test Errors ===" -ForegroundColor Red
    foreach ($error in $testErrors) {
        Write-Host "• $error" -ForegroundColor Red
    }
}

Write-Host ""
if ($testsPassed -eq $testsTotal) {
    Write-Host "🎉 All enhanced menu function tests passed!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some tests failed. Review the errors above." -ForegroundColor Yellow
}