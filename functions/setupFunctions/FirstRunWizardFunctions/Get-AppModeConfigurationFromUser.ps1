function Get-AppModeConfigurationFromUser()
{
    <#
    .SYNOPSIS
        Collects app mode configuration from the user using the enhanced multiple mode interface.
    
    .DESCRIPTION
        Prompts the user to select from available app modes that control which features
        and menu items are displayed in the Autopilot application. Now supports both
        single and multiple mode configurations with conflict resolution.
    
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
        - Now uses enhanced multiple app mode interface with conflict resolution
        - Supports both single and multiple mode selection
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

    # Initialize return object with default values
    $result = @{
        appMode              = 'full'
        appModes             = @('full')
        selectedChoice       = '1'
        cancelled            = $false
        currentModeUnchanged = $false
        isMultipleMode       = $false
    }

    try
    {
        if (-not $Silent)
        {
            Write-Verbose "[$functionName] Interactive mode configuration collection in context: $Context"
            
            # Display context-specific header
            switch ($Context)
            {
                'settings' 
                { 
                    $currentModeText = if ($CurrentMode) { " (Current: $CurrentMode)" } else { "" }
                    Write-Host "App Mode Selection$currentModeText" -ForegroundColor Cyan
                    Write-Host "Select your preferred app mode. The selection will return you to the previous menu." -ForegroundColor White
                }
                'wizard' 
                { 
                    Write-Host "App Mode Configuration" -ForegroundColor Cyan
                    Write-Host "Choose the app mode that best fits your role and requirements." -ForegroundColor White
                }
                default 
                { 
                    Write-Host "Select App Mode" -ForegroundColor Cyan
                    Write-Host "Select an app mode to configure the application interface." -ForegroundColor White
                }
            }

            # Load the enhanced app mode input function
            if (-not (Get-Command Get-AppModeInput -ErrorAction SilentlyContinue))
            {
                Write-Verbose "[$functionName] Loading Get-AppModeInput function"
                try
                {
                    . "$PWD/functions/setupFunctions/Show-SettingsEditor.ps1"
                }
                catch
                {
                    Write-Verbose "[$functionName] Could not load enhanced app mode input function: $($_.Exception.Message)"
                    # Use fallback to full mode
                    $result.appMode = 'full'
                    $result.appModes = @('full')
                    return $result
                }
            }

            # Use the enhanced app mode input function
            try
            {
                $selectedConfiguration = Get-AppModeInput -CurrentValue $CurrentMode
                
                if ($selectedConfiguration -is [array])
                {
                    # Multiple modes selected
                    $result.appModes = $selectedConfiguration
                    $result.appMode = $selectedConfiguration[0]  # Primary mode for backward compatibility
                    $result.isMultipleMode = $true
                    $result.selectedChoice = "Multiple: [$($selectedConfiguration -join ', ')]"
                    Write-Verbose "[$functionName] Multiple app modes selected: [$($selectedConfiguration -join ', ')]"
                }
                else
                {
                    # Single mode selected
                    $result.appMode = $selectedConfiguration
                    $result.appModes = @($selectedConfiguration)
                    $result.isMultipleMode = $false
                    $result.selectedChoice = $selectedConfiguration
                    Write-Verbose "[$functionName] Single app mode selected: $selectedConfiguration"
                }
            }
            catch
            {
                Write-Verbose "[$functionName] Error during app mode selection: $($_.Exception.Message)"
                $result.cancelled = $true
                return $result
            }
        }
        else
        {
            Write-Verbose "[$functionName] Silent mode - using default 'full' app mode"
            $result.appMode = 'full'
            $result.appModes = @('full')
        }

        Write-Verbose "[$functionName] App mode configuration completed successfully: Primary='$($result.appMode)', All=[$($result.appModes -join ', ')], Multiple=$($result.isMultipleMode)"
        return $result
    }
    catch
    {
        Write-Verbose "[$functionName] Error during app mode configuration: $($_.Exception.Message)"
        $result.cancelled = $true
        return $result
    }
}
