function Get-AppModeConfigurationFromUser()
{
    <#
    .SYNOPSIS
        Collects app mode configuration parameter from the user.
    
    .DESCRIPTION
        Prompts the user to select from available app modes that control which features
        and menu items are displayed in the Autopilot application. This setting determines
        the user interface complexity and available functionality.
    
    .PARAMETER Silent
        If specified, uses default value ('full' mode).
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable containing the appMode configuration.
    
    .EXAMPLE
        $appModeConfig = Get-AppModeConfigurationFromUser
        
    .EXAMPLE
        $appModeConfig = Get-AppModeConfigurationFromUser -Silent
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Provides user-friendly descriptions for each app mode
        - Validates user input and provides feedback
        - Available modes: full, helpDesk, advanced, advancedRegistration, registration, admin, custom
    #>
    [CmdletBinding()]
    param(
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Use Write-SafeLog if available, otherwise fall back to Write-Verbose
    if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
        Write-SafeLog "Collecting app mode configuration" "Information"
    } else {
        Write-Verbose "[$functionName] Collecting app mode configuration"
    }
    Write-Verbose "[$functionName] Starting app mode configuration collection"
    
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
    
    $appModeConfig = @{
        appMode = 'full'
    }
    
    try
    {
        if (-not $Silent)
        {
            Write-Host "`n── App Mode Configuration ──" -ForegroundColor Cyan
            Write-Host "The app mode determines which features and menu items are available." -ForegroundColor White
            Write-Host "Choose the mode that best fits your role and requirements:" -ForegroundColor White
            Write-Host ""
            
            # Display all available app modes
            foreach ($key in $appModes.Keys | Sort-Object)
            {
                $mode = $appModes[$key]
                Write-Host "$key. $($mode.Name)" -ForegroundColor White
                Write-Host "   $($mode.Description)" -ForegroundColor Gray
                Write-Host ""
            }
        }
        
        # Get app mode selection
        $appModeChoice = ""
        if ($Silent)
        {
            $appModeChoice = "1"
            if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
                Write-SafeLog "Using default app mode (full) in silent mode" "Information"
            }
            Write-Verbose "[$functionName] Using default app mode in silent mode"
        }
        else
        {
            do
            {
                $appModeChoice = Read-Host "Enter your choice (1-7)"
                if ($appModeChoice -in @("1", "2", "3", "4", "5", "6", "7"))
                {
                    break
                }
                Write-Host "Invalid choice. Please enter a number between 1 and 7." -ForegroundColor Red
            } while ($true)
        }
        
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
            Write-SafeLog "App mode choice selected: $appModeChoice" "Debug"
        }
        Write-Verbose "[$functionName] User selected app mode choice: $appModeChoice"
        
        # Set app mode value based on choice
        $selectedMode = $appModes[$appModeChoice]
        $appModeConfig.appMode = $selectedMode.Mode
        
        if (-not $Silent)
        {
            Write-Host "`nApp Mode Selected: $($selectedMode.Name)" -ForegroundColor Green
            Write-Host "$($selectedMode.Description)" -ForegroundColor Yellow
            Write-Host "`nThis setting controls which menu items and features will be available." -ForegroundColor White
        }
        
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
            Write-SafeLog "App mode configuration set to: $($appModeConfig.appMode)" "Information"
        }
        Write-Verbose "[$functionName] App mode configuration collected successfully: $($appModeConfig.appMode)"
        return $appModeConfig
        
    }
    catch
    {
        if (Get-Command Write-SafeLog -ErrorAction SilentlyContinue) {
            Write-SafeLog "Error collecting app mode configuration: $($_.Exception.Message)" "Error"
        }
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $null
    }
}