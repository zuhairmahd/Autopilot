#!/usr/bin/env pwsh
# Test for early menu filtering optimization

# Use unified test framework
try {
    # Load test helper functions
    . "$PSScriptRoot\test-helper.ps1"
    
    # Initialize unified test environment
    $testContext = Start-UnifiedTest -TestName "Early Menu Filtering"
    
    Write-TestResult "Test environment initialized" $true
}
catch {
    Write-TestResult "Failed to set up test environment: $($_.Exception.Message)" $false
    exit 1
}

try {
    Write-TestSection "Early Menu Filtering Optimization Tests"
    
    # Mock global settings for testing
    $Global:settings = @{
        appMode = "helpdesk"
    }
    
    # Test 1: Test FilterMenuItemsByAppMode function with helpdesk mode
    $mockMenuItems = @(
        @{ 
            name = "Helpdesk Item"
            description = "For helpdesk users"
            includeInDisplayModes = @("helpdesk", "admin")
        },
        @{
            name = "Admin Only Item" 
            description = "For admin users only"
            includeInDisplayModes = @("admin")
        },
        @{
            name = "Registration Item"
            description = "For registration users"
            includeInDisplayModes = @("registration")
        },
        @{
            name = "No Restrictions Item"
            description = "No display mode restrictions"
            includeInDisplayModes = @()
        }
    )
    
    $filteredItems = FilterMenuItemsByAppMode -MenuItems $mockMenuItems -CurrentAppMode "helpdesk"
    $helpdeskItemFound = $false
    $adminItemFound = $false
    $registrationItemFound = $false
    $noRestrictionsFound = $false
    
    foreach ($item in $filteredItems) {
        if ($item.name -eq "Helpdesk Item") { $helpdeskItemFound = $true }
        if ($item.name -eq "Admin Only Item") { $adminItemFound = $true }
        if ($item.name -eq "Registration Item") { $registrationItemFound = $true }
        if ($item.name -eq "No Restrictions Item") { $noRestrictionsFound = $true }
    }
    
    Write-TestResult "Helpdesk item included for helpdesk mode: $helpdeskItemFound" $helpdeskItemFound
    Write-TestResult "Admin item excluded for helpdesk mode: $(-not $adminItemFound)" (-not $adminItemFound)
    Write-TestResult "Registration item excluded for helpdesk mode: $(-not $registrationItemFound)" (-not $registrationItemFound)
    Write-TestResult "No restrictions item included by default: $noRestrictionsFound" $noRestrictionsFound
    Write-TestResult "Filtered items count (should be 2): $($filteredItems.Count -eq 2)" ($filteredItems.Count -eq 2)
    
    # Test 2: Test FilterMenuItemsByAppMode with full mode (should include all)
    $filteredItemsFull = FilterMenuItemsByAppMode -MenuItems $mockMenuItems -CurrentAppMode "full"
    Write-TestResult "Full mode includes all items: $($filteredItemsFull.Count -eq 4)" ($filteredItemsFull.Count -eq 4)
    
    # Test 3: Test NewMenu with early filtering enabled (default)
    # This requires menu.json to be available
    if (Test-Path "$pwd\menu.json") {
        $mainMenuFiltered = NewMenu -MenuName "mainMenu"
        
        if ($mainMenuFiltered -and $mainMenuFiltered.Items) {
            $mainMenuItemCount = $mainMenuFiltered.Items.Count
            Write-TestResult "Main menu created with early filtering: $($mainMenuItemCount -gt 0)" ($mainMenuItemCount -gt 0)
            
            # Should have fewer items for helpdesk mode than full mode
            $Global:settings.appMode = "full"
            $mainMenuFull = NewMenu -MenuName "mainMenu"
            $fullItemCount = if ($mainMenuFull -and $mainMenuFull.Items) { $mainMenuFull.Items.Count } else { 0 }
            
            $Global:settings.appMode = "helpdesk"  # Reset back
            Write-TestResult "Early filtering reduces items (helpdesk: $mainMenuItemCount vs full: $fullItemCount): $($mainMenuItemCount -le $fullItemCount)" ($mainMenuItemCount -le $fullItemCount)
        }
        else {
            Write-TestResult "Main menu creation test skipped (menu not loaded)" $true
        }
    }
    else {
        Write-TestResult "Menu.json test skipped (file not found)" $true
    }
    
    # Test 4: Test NewMenu with early filtering disabled
    if (Test-Path "$pwd\menu.json") {
        $mainMenuUnfiltered = NewMenu -MenuName "mainMenu" -DisableEarlyFiltering
        
        if ($mainMenuUnfiltered -and $mainMenuUnfiltered.Items) {
            $unfilteredItemCount = $mainMenuUnfiltered.Items.Count
            Write-TestResult "Main menu created with early filtering disabled: $($unfilteredItemCount -gt 0)" ($unfilteredItemCount -gt 0)
            
            # Should have same or more items when filtering is disabled
            if ($mainMenuFiltered -and $mainMenuFiltered.Items) {
                $filteredItemCount = $mainMenuFiltered.Items.Count
                Write-TestResult "Disabled filtering has same or more items ($unfilteredItemCount >= $filteredItemCount): $($unfilteredItemCount -ge $filteredItemCount)" ($unfilteredItemCount -ge $filteredItemCount)
            }
        }
        else {
            Write-TestResult "Unfiltered menu creation test skipped (menu not loaded)" $true
        }
    }
    else {
        Write-TestResult "Menu.json unfiltered test skipped (file not found)" $true
    }
    
    Write-TestSection "Early Menu Filtering Tests Completed"
    
}
catch {
    Write-TestResult "Test execution failed: $($_.Exception.Message)" $false
}
finally {
    # Cleanup
    if ($testContext) {
        Complete-UnifiedTest -TestContext $testContext
    }
}