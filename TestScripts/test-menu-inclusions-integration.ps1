# Integration test to validate menu inclusions with real settings.json
param()

Write-Host "Testing Menu Inclusions Integration with settings.json..." -ForegroundColor Green

# Mock the Write-Log function for testing BEFORE loading other functions
function Write-Log
{
    param(
        [Parameter(Mandatory = $false)]
        $LogFile,
        [Parameter(Mandatory = $false)]
        $Module,
        [Parameter(Mandatory = $false)]
        $Message,
        [Parameter(Mandatory = $false)]
        $LogLevel
    )
    Write-Verbose "LOG: [$Module] $Message"
}

try
{
    # Load settings.json to get the actual inclusion list
    $settingsPath = Join-Path $PSScriptRoot ".." "settings.json"
    if (Test-Path $settingsPath)
    {
        $settingsContent = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        
        Write-Host "Test 1: Verify settings.json contains menuItemsToInclude" -ForegroundColor Cyan
        
        if ($settingsContent.menuItemsToInclude)
        {
            Write-Host "✓ PASS: menuItemsToInclude found in settings.json" -ForegroundColor Green
            Write-Host "  Found $($settingsContent.menuItemsToInclude.Count) items to include:" -ForegroundColor Yellow
            $settingsContent.menuItemsToInclude | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
        }
        else
        {
            Write-Host "✗ FAIL: menuItemsToInclude not found in settings.json" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "`nTest 2: Test inclusion logic with real inclusion data" -ForegroundColor Cyan
        
        # Load the required functions
        $functionsPath = Join-Path $PSScriptRoot ".." "functions"
        . (Join-Path $functionsPath "MenuFunctions.ps1")
        
        # Set a mock LogFile variable
        $Global:LogFile = "test.log"
        
        # Set global settings with the actual inclusion list
        $Global:settings = @{
            menuItemsToInclude = $settingsContent.menuItemsToInclude
        }
        
        # Test a few specific items from the inclusion list
        $testItems = @(
            @{ Name = $settingsContent.menuItemsToInclude[0]; ShouldBeIncluded = $true },
            @{ Name = "Some Non-Included Item"; ShouldBeIncluded = $false }
        )
        
        foreach ($testItem in $testItems)
        {
            $result = Test-MenuItemIncluded -MenuItemName $testItem.Name
            if ($result -eq $testItem.ShouldBeIncluded)
            {
                Write-Host "✓ PASS: '$($testItem.Name)' correctly handled (included: $result)" -ForegroundColor Green
            }
            else
            {
                Write-Host "✗ FAIL: '$($testItem.Name)' expected included: $($testItem.ShouldBeIncluded), got: $result" -ForegroundColor Red
            }
        }
        
        Write-Host "`nTest 3: Test case insensitivity (PowerShell default behavior)" -ForegroundColor Cyan
        
        # Test case insensitivity - PowerShell -contains is case-insensitive by default
        $testName = $settingsContent.menuItemsToInclude[0]
        $result1 = Test-MenuItemIncluded -MenuItemName $testName.ToLower()  # lowercase
        $result2 = Test-MenuItemIncluded -MenuItemName $testName           # proper case
        $result3 = Test-MenuItemIncluded -MenuItemName $testName.ToUpper() # uppercase
        
        if ($result1 -eq $true -and $result2 -eq $true -and $result3 -eq $true)
        {
            Write-Host "✓ PASS: Case insensitivity works correctly (all variants included)" -ForegroundColor Green
        }
        else
        {
            Write-Host "✗ FAIL: Case insensitivity issue - lowercase: $result1, proper: $result2, upper: $result3" -ForegroundColor Red
        }
        
        Write-Host "`nMenu Inclusions Integration Test Completed Successfully!" -ForegroundColor Green
        
    }
    else
    {
        Write-Host "✗ FAIL: settings.json not found at $settingsPath" -ForegroundColor Red
        exit 1
    }
}
catch
{
    Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}