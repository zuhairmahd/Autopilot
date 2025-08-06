function Get-AppModeConfigurationFromUser()
{
    <#
    .SYNOPSIS
        Collects app mode configuration parameter from the user.
    
    .DESCRIPTION
        Prompts the user to select from available app modes that control which features
        and menu items are displayed in the Autopilot application. This setting determines
        the user interface complexity and available functionality. Supports both first-run
        wizard context and settings menu context with different display options.
    
    .PARAMETER Silent
        If specified, uses default value ('full' mode).
        
    .PARAMETER CurrentMode
        The current app mode to highlight in the selection. Used in settings menu context.
        
    .PARAMETER ShowCancel
        If specified, includes a cancel option in the menu.
        
    .PARAMETER Context
        Specifies the context for display customization ('wizard' or 'settings').
        
    .PARAMETER UseMenuSystem
        If specified, uses the existing DisplayNumericMenu system for consistent UI.
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable containing the appMode configuration and selection metadata.
    
    .EXAMPLE
        $appModeConfig = Get-AppModeConfigurationFromUser
        
    .EXAMPLE
        $appModeConfig = Get-AppModeConfigurationFromUser -Silent
        
    .EXAMPLE
        $result = Get-AppModeConfigurationFromUser -CurrentMode "helpDesk" -ShowCancel -Context "settings" -UseMenuSystem
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Provides user-friendly descriptions for each app mode
        - Validates user input and provides feedback
        - Integrates with existing menu system for consistent UI
        - Available modes: full, helpDesk, advanced, advancedRegistration, registration, admin, custom
    #>
    [CmdletBinding()]
    param(
        [switch]$Silent,
        [string]$CurrentMode,
        [switch]$ShowCancel,
        [string]$Context = 'wizard',
        [switch]$UseMenuSystem
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Validate context parameter
    if ($Context -notin @('wizard', 'settings')) {
        Write-Verbose "[$functionName] Invalid context '$Context', defaulting to 'wizard'"
        $Context = 'wizard'
    }
    
    # Use Write-SafeLog if available, otherwise fall back to Write-Verbose
    if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
        Write-SafeLog "Collecting app mode configuration (Context: $Context)" "Information"
    } else {
        Write-Verbose "[$functionName] Collecting app mode configuration (Context: $Context)"
    }
    Write-Verbose "[$functionName] Starting app mode configuration collection"
    Write-Verbose "[$functionName] Parameters - Silent: $Silent, CurrentMode: $CurrentMode, ShowCancel: $ShowCancel, Context: $Context, UseMenuSystem: $UseMenuSystem"
    
    # Define available app modes with descriptions
    $appModes = @{
        '1' = @{
            Mode = 'full'
            Name = 'Full Mode'
            Description = 'Complete feature set with all available functionality (recommended for administrators)'
        }
        '2' = @{
            Mode = 'helpDesk'
            Name = 'Help Desk Mode'
            Description = 'Streamlined interface for help desk operations and device troubleshooting'
        }
        '3' = @{
            Mode = 'advanced'
            Name = 'Advanced Mode'
            Description = 'Advanced features for experienced users and technical staff'
        }
        '4' = @{
            Mode = 'advancedRegistration'
            Name = 'Advanced Registration Mode'
            Description = 'Advanced device registration capabilities with extended options'
        }
        '5' = @{
            Mode = 'registration'
            Name = 'Registration Mode'
            Description = 'Device registration and enrollment focused interface'
        }
        '6' = @{
            Mode = 'admin'
            Name = 'Administrator Mode'
            Description = 'Administrative functions and system configuration options'
        }
        '7' = @{
            Mode = 'custom'
            Name = 'Custom Mode'
            Description = 'Custom configuration for specialized deployments'
        }
    }
    
    # Initialize result object with default values and metadata
    $result = @{
        appMode = 'full'
        selectedChoice = '1'
        cancelled = $false
        currentModeUnchanged = $false
    }
    
    try
    {
        if (-not $Silent)
        {
            if ($UseMenuSystem -and (Get-Command DisplayNumericMenu -ErrorAction SilentlyContinue))
            {
                # Use existing menu system for consistent UI
                Write-Verbose "[$functionName] Using DisplayNumericMenu for app mode selection"
                
                # Prepare menu choices with descriptions
                $menuChoices = @()
                foreach ($key in $appModes.Keys | Sort-Object)
                {
                    $mode = $appModes[$key]
                    $marker = ""
                    if ($CurrentMode -and $mode.Mode -eq $CurrentMode) 
                    {
                        $marker = " (Current)"
                    }
                    $menuChoices += "$($mode.Name)$marker - $($mode.Description)"
                }
                
                # Add cancel option if requested
                if ($ShowCancel)
                {
                    $menuChoices += "Cancel (keep current setting)"
                }
                
                # Display banner based on context
                $banner = switch ($Context) {
                    'settings' { 
                        $currentModeText = if ($CurrentMode) { " (Current: $CurrentMode)" } else { "" }
                        "══════════════════════════════════════════════════════════════════`n                          App Mode Selection$currentModeText                          `n══════════════════════════════════════════════════════════════════`n`nSelect your preferred app mode:"
                    }
                    'wizard' { 
                        "── App Mode Configuration ──`nThe app mode determines which features and menu items are available.`nChoose the mode that best fits your role and requirements:"
                    }
                    default { "Select an app mode:" }
                }
                
                # Use DisplayNumericMenu for selection
                $menuResult = DisplayNumericMenu -choices $menuChoices -banner $banner -Prompt "Enter your choice"
                
                # Process menu result
                if ($menuResult -eq 0) # Exit selected
                {
                    $result.cancelled = $true
                    return $result
                }
                
                # Calculate choice index (menuResult is 1-based for menu items)
                $choiceIndex = $menuResult
                
                # Handle cancel option
                if ($ShowCancel -and $choiceIndex -eq ($menuChoices.Count))
                {
                    $result.cancelled = $true
                    return $result
                }
                
                # Get selected mode
                $selectedModeKey = $choiceIndex.ToString()
                $selectedMode = $appModes[$selectedModeKey]
                $result.selectedChoice = $selectedModeKey
                $result.appMode = $selectedMode.Mode
                
                # Check if same as current mode
                if ($CurrentMode -and $selectedMode.Mode -eq $CurrentMode)
                {
                    $result.currentModeUnchanged = $true
                }
            }
            else
            {
                # Fallback to original display method
                Write-Verbose "[$functionName] Using original display method for app mode selection"
                
                # Display header based on context
                switch ($Context) {
                    'settings' {
                        Write-Host "`n══════════════════════════════════════════════════════════════════" -ForegroundColor Green
                        Write-Host "                          App Mode Selection                          " -ForegroundColor Green
                        Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Green
                        if ($CurrentMode) {
                            Write-Host "`nCurrent App Mode: $CurrentMode" -ForegroundColor Yellow
                        }
                        Write-Host "`nAvailable App Modes:" -ForegroundColor White
                    }
                    'wizard' {
                        Write-Host "`n── App Mode Configuration ──" -ForegroundColor Cyan
                        Write-Host "The app mode determines which features and menu items are available." -ForegroundColor White
                        Write-Host "Choose the mode that best fits your role and requirements:" -ForegroundColor White
                    }
                }
                Write-Host ""
                
                # Display all available app modes
                foreach ($key in $appModes.Keys | Sort-Object)
                {
                    $mode = $appModes[$key]
                    $marker = ""
                    $color = "White"
                    if ($CurrentMode -and $mode.Mode -eq $CurrentMode) 
                    {
                        $marker = " (Current)"
                        $color = "Green"
                    }
                    Write-Host "$key. $($mode.Name)$marker" -ForegroundColor $color
                    Write-Host "   $($mode.Description)" -ForegroundColor Gray
                    Write-Host ""
                }
                
                # Add cancel option if requested
                if ($ShowCancel)
                {
                    $cancelOption = ($appModes.Keys.Count + 1).ToString()
                    Write-Host "$cancelOption. Cancel (keep current setting)" -ForegroundColor Yellow
                    Write-Host ""
                }
                
                # Get app mode selection
                $maxChoice = if ($ShowCancel) { [int]($appModes.Keys.Count) + 1 } else { [int]($appModes.Keys.Count) }
                $validChoices = 1..$maxChoice | ForEach-Object { $_.ToString() }
                
                do
                {
                    $appModeChoice = Read-Host "Enter your choice (1-$maxChoice)"
                    if ($appModeChoice -in $validChoices)
                    {
                        break
                    }
                    Write-Host "Invalid choice. Please enter a number between 1 and $maxChoice." -ForegroundColor Red
                } while ($true)
                
                # Handle cancel choice
                if ($ShowCancel -and $appModeChoice -eq $cancelOption)
                {
                    $result.cancelled = $true
                    return $result
                }
                
                # Set selected mode
                $selectedMode = $appModes[$appModeChoice]
                $result.selectedChoice = $appModeChoice
                $result.appMode = $selectedMode.Mode
                
                # Check if same as current mode
                if ($CurrentMode -and $selectedMode.Mode -eq $CurrentMode)
                {
                    $result.currentModeUnchanged = $true
                }
                
                # Display selection confirmation
                Write-Host "`nApp Mode Selected: $($selectedMode.Name)" -ForegroundColor Green
                Write-Host "$($selectedMode.Description)" -ForegroundColor Yellow
                if ($Context -eq 'wizard') {
                    Write-Host "`nThis setting controls which menu items and features will be available." -ForegroundColor White
                }
            }
        }
        else
        {
            # Silent mode - use defaults
            $result.selectedChoice = "1"
            $result.appMode = "full"
            if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
                Write-SafeLog "Using default app mode (full) in silent mode" "Information"
            }
            Write-Verbose "[$functionName] Using default app mode in silent mode"
        }
        
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
            Write-SafeLog "App mode choice selected: $($result.selectedChoice), Mode: $($result.appMode)" "Debug"
        }
        Write-Verbose "[$functionName] User selected app mode choice: $($result.selectedChoice), Mode: $($result.appMode)"
        
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
            Write-SafeLog "App mode configuration completed successfully: $($result.appMode)" "Information"
        }
        Write-Verbose "[$functionName] App mode configuration collected successfully: $($result.appMode)"
        
        # Ensure we return a proper hashtable
        return @{
            appMode = $result.appMode
            selectedChoice = $result.selectedChoice
            cancelled = $result.cancelled
            currentModeUnchanged = $result.currentModeUnchanged
        }
        
    }
    catch
    {
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
            Write-SafeLog "Error collecting app mode configuration: $($_.Exception.Message)" "Error"
        }
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        
        # Return cancelled result on error
        return @{
            appMode = 'full'
            selectedChoice = '1'  
            cancelled = $true
            currentModeUnchanged = $false
        }
    }
}