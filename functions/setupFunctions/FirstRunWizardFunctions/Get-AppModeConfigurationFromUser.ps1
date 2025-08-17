function Get-AppModeConfigurationFromUser()
{
    <#
    .SYNOPSIS
        Collects app mode configuration parameter from the user using the menu system.
    
    .DESCRIPTION
        Prompts the user to select from available app modes that control which features
        and menu items are displayed in the Autopilot application. Uses the existing
        menu system for consistent user experience across the application.
    
    .PARAMETER Silent
        If specified, uses default value ('full' mode).
        
    .PARAMETER CurrentMode
        The current app mode to highlight in the selection. Used in settings menu context.
        
    .PARAMETER Context
        Specifies the context for display customization ('wizard' or 'settings').
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable containing the appMode configuration and selection metadata.
    
    .EXAMPLE
        $appModeConfig = Get-AppModeConfigurationFromUser
        
    .EXAMPLE
        $appModeConfig = Get-AppModeConfigurationFromUser -Silent
        
    .EXAMPLE
        $result = Get-AppModeConfigurationFromUser -CurrentMode "helpDesk" -Context "settings"
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Uses existing menu system for consistent UI navigation
        - Available modes: full, helpDesk, advanced, advancedRegistration, registration, admin, custom
    #>
    [CmdletBinding()]
    param(
        [switch]$Silent,
        [string]$CurrentMode,
        [string]$Context = 'wizard'
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting app mode configuration collection"    
    # Validate context parameter
    if ($Context -notin @('wizard', 'settings'))
    {
        Write-Verbose "[$functionName] Invalid context '$Context', defaulting to 'wizard'"
        $Context = 'wizard'
    }
    
    # Use Write-SafeLog if available, otherwise fall back to Write-Verbose
    if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue)
    {
        Write-SafeLog "Collecting app mode configuration (Context: $Context)" "Information"
    }
    else
    {
        Write-Verbose "[$functionName] Collecting app mode configuration (Context: $Context)"
    }
    Write-Verbose "[$functionName] Starting app mode configuration collection"
    Write-Verbose "[$functionName] Parameters - Silent: $Silent, CurrentMode: $CurrentMode, Context: $Context"
    
    # Define available app modes with descriptions
    $appModes = @(
        @{ Mode = 'full'; Name = 'Full Mode'; Description = 'Complete feature set with all available functionality (recommended for administrators)' }
        @{ Mode = 'helpDesk'; Name = 'Help Desk Mode'; Description = 'Streamlined interface for help desk operations and device troubleshooting' }
        @{ Mode = 'advanced'; Name = 'Advanced Mode'; Description = 'Advanced features for experienced users and technical staff' }
        @{ Mode = 'advancedRegistration'; Name = 'Advanced Registration Mode'; Description = 'Advanced device registration capabilities with extended options' }
        @{ Mode = 'registration'; Name = 'Registration Mode'; Description = 'Device registration and enrollment focused interface' }
        @{ Mode = 'admin'; Name = 'Administrator Mode'; Description = 'Administrative functions and system configuration options' }
        @{ Mode = 'custom'; Name = 'Custom Mode'; Description = 'Custom configuration for specialized deployments' }
    )
    
    # Initialize result object with default values and metadata
    $result = @{
        appMode              = 'full'
        selectedChoice       = '1'
        cancelled            = $false
        currentModeUnchanged = $false
    }
    
    try
    {
        if (-not $Silent)
        {
            # Create menu title and description based on context
            $menuTitle = switch ($Context)
            {
                'settings'
                { 
                    $currentModeText = if ($CurrentMode) { " (Current: $CurrentMode)" } else { "" }
                    "App Mode Selection$currentModeText"
                }
                'wizard' { "App Mode Configuration" }
                default { "Select App Mode" }
            }
            
            $menuDescription = switch ($Context)
            {
                'settings' { "Select your preferred app mode. Back and Main options will return you to the previous menu." }
                'wizard' { "Choose the app mode that best fits your role and requirements." }
                default { "Select an app mode to configure the application interface." }
            }
            
            # Create the app mode selection menu from configuration
            $appModeMenu = NewMenu -MenuName "appModeMenu"
            if (-not $appModeMenu) {
                # Fallback to manual creation if config not found
                $appModeMenu = NewMenu -Title $menuTitle -Description $menuDescription
            } else {
                # Update title and description with actual values
                $appModeMenu.Title = $appModeMenu.Title -replace '\$menuTitle', $menuTitle
                $appModeMenu.Description = $appModeMenu.Description -replace '\$menuDescription', $menuDescription
            }
            
            # Add menu items for each app mode
            foreach ($appMode in $appModes)
            {
                $itemName = "$($appMode.Name)"
                if ($CurrentMode -and $appMode.Mode -eq $CurrentMode)
                {
                    $itemName += " (Current)"
                }
                $itemName += " - $($appMode.Description)"
                
                # Create action that returns the selected mode
                $selectedMode = $appMode.Mode
                $appModeMenu = AddMenuItem -Menu $appModeMenu -Name $itemName -Action {
                    return $selectedMode
                }.GetNewClosure() -ReturnsValue
            }
            
            # Show the menu and get user selection
            $menuResult = ShowMenu -Menu $appModeMenu -CalledBy 'Action'
            
            # Handle menu navigation results
            if ($menuResult -eq "Back" -or $menuResult -eq "Main Menu" -or $menuResult -eq "EXIT_APPLICATION")
            {
                $result.cancelled = $true
                return $result
            }
            
            # Check if we got a valid app mode
            $selectedAppMode = $null
            foreach ($mode in $appModes)
            {
                if ($mode.Mode -eq $menuResult)
                {
                    $selectedAppMode = $mode
                    break
                }
            }
            
            if ($selectedAppMode)
            {
                $result.appMode = $selectedAppMode.Mode
                $result.selectedChoice = ($appModes.IndexOf($selectedAppMode) + 1).ToString()
                
                # Check if same as current mode
                if ($CurrentMode -and $selectedAppMode.Mode -eq $CurrentMode)
                {
                    $result.currentModeUnchanged = $true
                }
                
                # Display selection confirmation for wizard context
                if ($Context -eq 'wizard')
                {
                    Write-Host "`nApp Mode Selected: $($selectedAppMode.Name)" -ForegroundColor Green
                    Write-Host "$($selectedAppMode.Description)" -ForegroundColor Yellow
                    Write-Host "`nThis setting controls which menu items and features will be available." -ForegroundColor White
                }
            }
            else
            {
                # No valid selection, mark as cancelled
                $result.cancelled = $true
            }
        }
        else
        {
            # Silent mode - use defaults
            $result.selectedChoice = "1"
            $result.appMode = "full"
            if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue)
            {
                Write-SafeLog "Using default app mode (full) in silent mode" "Information"
            }
            Write-Verbose "[$functionName] Using default app mode in silent mode"
        }
        
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue)
        {
            Write-SafeLog "App mode choice selected: $($result.selectedChoice), Mode: $($result.appMode)" "Debug"
        }
        Write-Verbose "[$functionName] User selected app mode choice: $($result.selectedChoice), Mode: $($result.appMode)"
        
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue)
        {
            Write-SafeLog "App mode configuration completed successfully: $($result.appMode)" "Information"
        }
        Write-Verbose "[$functionName] App mode configuration collected successfully: $($result.appMode)"
        
        # Ensure we return a proper hashtable
        return @{
            appMode              = $result.appMode
            selectedChoice       = $result.selectedChoice
            cancelled            = $result.cancelled
            currentModeUnchanged = $result.currentModeUnchanged
        }
        
    }
    catch
    {
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue)
        {
            Write-SafeLog "Error collecting app mode configuration: $($_.Exception.Message)" "Error"
        }
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        
        # Return cancelled result on error
        return @{
            appMode              = 'full'
            selectedChoice       = '1'  
            cancelled            = $true
            currentModeUnchanged = $false
        }
    }
}