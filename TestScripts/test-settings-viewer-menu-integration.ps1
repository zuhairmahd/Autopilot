# Test script to verify the settings viewer menu integration
# PowerShell 5.1 compatible

param(
    [string]$TestFolder = "$PWD\test-menu-integration-temp"
)

# Load test helper functions
. "$PSScriptRoot\test-helper.ps1"

$psInfo = Test-PowerShellVersion
Write-Host "PowerShell Version: $($psInfo.Version)" -ForegroundColor Cyan

Write-TestSection "Settings Viewer Menu Integration Test"
Write-Host "Test folder: $TestFolder" -ForegroundColor Yellow

# Clean up any existing test folder
if (Test-Path $TestFolder) {
    Remove-Item -Path $TestFolder -Recurse -Force
}

# Create test folder
New-Item -Path $TestFolder -ItemType Directory -Force | Out-Null

try {
    Write-Host "`n1. Testing settings.json menu structure..." -ForegroundColor Cyan
    
    # Load and parse settings.json
    $rootPath = Split-Path -Parent $PSScriptRoot
    $settingsFile = "$rootPath\settings.json"
    
    if (-not (Test-Path $settingsFile)) {
        Write-TestResult "settings.json file not found" -Success $false
        throw "Settings file not found at $settingsFile"
    }
    
    $settingsContent = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
    Write-TestResult "settings.json loaded successfully" -Success $true
    
    # Find the settings menu structure
    $settingsMenu = $settingsContent.menus | Where-Object { $_.name -eq "Change application settings" }
    if (-not $settingsMenu) {
        Write-TestResult "Settings menu not found in configuration" -Success $false
        throw "Settings menu not found"
    }
    Write-TestResult "Found 'Change application settings' menu" -Success $true
    
    # Find the environment settings submenu
    $environmentSubmenu = $settingsMenu.items | Where-Object { $_.name -eq "Change global environment settings" -and $_.type -eq "submenu" }
    if (-not $environmentSubmenu) {
        Write-TestResult "Environment settings submenu not found" -Success $false
        throw "Environment settings submenu not found"
    }
    Write-TestResult "Found 'Change global environment settings' submenu" -Success $true
    
    # Check for the new viewer menu items
    $viewGlobalItem = $environmentSubmenu.items | Where-Object { $_.name -eq "View global settings" }
    if ($viewGlobalItem) {
        Write-TestResult "Found 'View global settings' menu item" -Success $true
        
        # Verify it's configured as an action
        if ($viewGlobalItem.type -eq "action") {
            Write-TestResult "'View global settings' is correctly configured as action" -Success $true
        } else {
            Write-TestResult "'View global settings' has incorrect type: $($viewGlobalItem.type)" -Success $false
        }
    } else {
        Write-TestResult "'View global settings' menu item not found" -Success $false
    }
    
    $viewDomainItem = $environmentSubmenu.items | Where-Object { $_.name -eq "View domain settings" }
    if ($viewDomainItem) {
        Write-TestResult "Found 'View domain settings' menu item" -Success $true
        
        # Verify it's configured as an action
        if ($viewDomainItem.type -eq "action") {
            Write-TestResult "'View domain settings' is correctly configured as action" -Success $true
        } else {
            Write-TestResult "'View domain settings' has incorrect type: $($viewDomainItem.type)" -Success $false
        }
    } else {
        Write-TestResult "'View domain settings' menu item not found" -Success $false
    }
    
    # Verify existing menu items are still present
    $changeGlobalItem = $environmentSubmenu.items | Where-Object { $_.name -eq "Change global environment settings" -and $_.type -eq "action" }
    if ($changeGlobalItem) {
        Write-TestResult "Existing 'Change global environment settings' action is preserved" -Success $true
    } else {
        Write-TestResult "Existing 'Change global environment settings' action was removed" -Success $false
    }
    
    $changeDomainItem = $environmentSubmenu.items | Where-Object { $_.name -eq "Change domain specific settings" -and $_.type -eq "action" }
    if ($changeDomainItem) {
        Write-TestResult "Existing 'Change domain specific settings' action is preserved" -Success $true
    } else {
        Write-TestResult "Existing 'Change domain specific settings' action was removed" -Success $false
    }
    
    Write-Host "`n2. Testing main.ps1 menu action integration..." -ForegroundColor Cyan
    
    # Load the main.ps1 file to check for menu actions
    $mainFile = "$rootPath\main.ps1"
    if (-not (Test-Path $mainFile)) {
        Write-TestResult "main.ps1 file not found" -Success $false
        throw "main.ps1 file not found"
    }
    
    $mainContent = Get-Content -Path $mainFile -Raw
    
    # Check for the new viewer menu actions
    if ($mainContent -match 'AddMenuItem.*"View global settings"') {
        Write-TestResult "Found 'View global settings' menu action in main.ps1" -Success $true
    } else {
        Write-TestResult "'View global settings' menu action not found in main.ps1" -Success $false
    }
    
    if ($mainContent -match 'AddMenuItem.*"View domain settings"') {
        Write-TestResult "Found 'View domain settings' menu action in main.ps1" -Success $true
    } else {
        Write-TestResult "'View domain settings' menu action not found in main.ps1" -Success $false
    }
    
    # Check for Show-SettingsViewer function calls
    if ($mainContent -match 'Show-SettingsViewer') {
        Write-TestResult "Found Show-SettingsViewer function calls in main.ps1" -Success $true
    } else {
        Write-TestResult "Show-SettingsViewer function calls not found in main.ps1" -Success $false
    }
    
    Write-Host "`n3. Testing function file availability..." -ForegroundColor Cyan
    
    # Check that the Show-SettingsViewer.ps1 file exists
    $viewerFile = "$rootPath\functions\setupFunctions\Show-SettingsViewer.ps1"
    if (Test-Path $viewerFile) {
        Write-TestResult "Show-SettingsViewer.ps1 file exists" -Success $true
    } else {
        Write-TestResult "Show-SettingsViewer.ps1 file not found" -Success $false
    }
    
    Write-Host "`n4. Testing menu ordering..." -ForegroundColor Cyan
    
    # Check that view items come before change items (logical workflow)
    $submenuItems = $environmentSubmenu.items
    $viewGlobalIndex = -1
    $viewDomainIndex = -1
    $changeGlobalIndex = -1
    
    for ($i = 0; $i -lt $submenuItems.Count; $i++) {
        switch ($submenuItems[$i].name) {
            "View global settings" { $viewGlobalIndex = $i }
            "View domain settings" { $viewDomainIndex = $i }
            "Change global environment settings" { $changeGlobalIndex = $i }
        }
    }
    
    if ($viewGlobalIndex -ge 0 -and $changeGlobalIndex -ge 0 -and $viewGlobalIndex -lt $changeGlobalIndex) {
        Write-TestResult "View items are correctly ordered before change items" -Success $true
    } else {
        Write-TestResult "Menu ordering may not be optimal (view should come before change)" -Success $false
    }
    
    Write-Host "`n5. Testing menu item completeness..." -ForegroundColor Cyan
    
    # Verify all expected menu items are present
    $expectedItems = @(
        "View global settings",
        "View domain settings", 
        "Change global environment settings",
        "Change domain specific settings",
        "Change authentication settings"
    )
    
    $foundItems = @()
    foreach ($item in $submenuItems) {
        $foundItems += $item.name
    }
    
    $missingItems = @()
    foreach ($expected in $expectedItems) {
        if ($expected -notin $foundItems) {
            $missingItems += $expected
        }
    }
    
    if ($missingItems.Count -eq 0) {
        Write-TestResult "All expected menu items are present" -Success $true
    } else {
        Write-TestResult "Missing menu items: $($missingItems -join ', ')" -Success $false
    }
    
    Write-Host "`nEnvironment settings submenu contains:" -ForegroundColor Gray
    foreach ($item in $foundItems) {
        Write-Host "  - $item" -ForegroundColor White
    }
    
    Write-Host "`n--- Settings Viewer Menu Integration Tests Complete ---" -ForegroundColor Green

} catch {
    Write-TestResult "Test failed with error: $($_.Exception.Message)" -Success $false
    Write-Host "Full error: $($_.Exception | Format-List * | Out-String)" -ForegroundColor Red
} finally {
    # Clean up test folder
    Write-Host "`nCleaning up test folder..." -ForegroundColor Yellow
    try {
        if (Test-Path $TestFolder) {
            Remove-Item -Path $TestFolder -Recurse -Force
            Write-TestResult "Test folder cleaned up" -Success $true
        }
    } catch {
        Write-Host "Warning: Failed to clean up test folder: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nMenu integration test completed!" -ForegroundColor Green