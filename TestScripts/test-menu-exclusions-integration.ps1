# Integration test to validate menu exclusions with real settings.json
param()

Write-Host "Testing Menu Exclusions Integration with settings.json..." -ForegroundColor Green

try {
    # Load settings.json to get the actual exclusion list
    $settingsPath = Join-Path $PSScriptRoot ".." "settings.json"
    if (Test-Path $settingsPath) {
        $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        
        Write-Host "Test 1: Verify settings.json contains menuItemsToExclude" -ForegroundColor Cyan
        
        if ($settingsContent.menuItemsToExclude) {
            Write-Host "✓ PASS: menuItemsToExclude found in settings.json" -ForegroundColor Green
            Write-Host "  Found $($settingsContent.menuItemsToExclude.Count) items to exclude:" -ForegroundColor Yellow
            $settingsContent.menuItemsToExclude | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
        } else {
            Write-Host "✗ FAIL: menuItemsToExclude not found in settings.json" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "`nTest 2: Test exclusion logic with real exclusion data" -ForegroundColor Cyan
        
        # Load the required functions
        $functionsPath = Join-Path $PSScriptRoot ".." "functions"
        . (Join-Path $functionsPath "MenuFunctions.ps1")
        
        # Mock the Write-Log function for testing
        if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
            function Write-Log {
                param($LogFile, $Module, $Message, $LogLevel)
                Write-Verbose "LOG: [$Module] $Message"
            }
        }
        
        # Set a mock LogFile variable
        $Global:LogFile = "test.log"
        
        # Set global settings with the actual exclusion list
        $Global:settings = @{
            menuItemsToExclude = $settingsContent.menuItemsToExclude
        }
        
        # Test a few specific items from the exclusion list
        $testItems = @(
            @{ Name = "Autopilot menu"; ShouldBeExcluded = $true },
            @{ Name = "Check for script updates"; ShouldBeExcluded = $true },
            @{ Name = "Some Non-Excluded Item"; ShouldBeExcluded = $false }
        )
        
        foreach ($testItem in $testItems) {
            $result = Test-MenuItemExcluded -MenuItemName $testItem.Name
            if ($result -eq $testItem.ShouldBeExcluded) {
                Write-Host "✓ PASS: '$($testItem.Name)' correctly handled (excluded: $result)" -ForegroundColor Green
            } else {
                Write-Host "✗ FAIL: '$($testItem.Name)' expected excluded: $($testItem.ShouldBeExcluded), got: $result" -ForegroundColor Red
            }
        }
        
        Write-Host "`nTest 3: Test case insensitivity (PowerShell default behavior)" -ForegroundColor Cyan
        
        # Test case insensitivity - PowerShell -contains is case-insensitive by default
        $result1 = Test-MenuItemExcluded -MenuItemName "autopilot menu"  # lowercase
        $result2 = Test-MenuItemExcluded -MenuItemName "Autopilot menu"  # proper case
        $result3 = Test-MenuItemExcluded -MenuItemName "AUTOPILOT MENU"  # uppercase
        
        if ($result1 -eq $true -and $result2 -eq $true -and $result3 -eq $true) {
            Write-Host "✓ PASS: Case insensitivity works correctly (all variants excluded)" -ForegroundColor Green
        } else {
            Write-Host "✗ FAIL: Case insensitivity issue - lowercase: $result1, proper: $result2, upper: $result3" -ForegroundColor Red
        }
        
        Write-Host "`nMenu Exclusions Integration Test Completed Successfully!" -ForegroundColor Green
        
    } else {
        Write-Host "✗ FAIL: settings.json not found at $settingsPath" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}