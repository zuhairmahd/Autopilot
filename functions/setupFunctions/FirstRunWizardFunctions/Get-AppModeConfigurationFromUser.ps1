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
        appModes             = @('full')
        selectedChoice       = '1'
        cancelled            = $false
        currentModeUnchanged = $false
        useGlobalStorage     = $false
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
                    $currentModeText = if ($CurrentMode)
                    {
                        " (Current: $CurrentMode)" 
                    }
                    else
                    {
                        "" 
                    }
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

            # Use the enhanced app mode input function
            try
            {
                $selectedConfiguration = Get-MultipleAppModeInput -CurrentValue $CurrentMode
                
                if ($selectedConfiguration.modeSelection)
                {
                    # Multiple modes selected
                    $result.appModes = $selectedConfiguration.modeSelection
                    $result.selectedChoice = "Multiple: [$($selectedConfiguration.modeSelection -join ', ')]"
                    $result.useGlobalStorage = $selectedConfiguration.useGlobalStorage
                    Write-Verbose "[$functionName] Multiple app modes selected: [$($selectedConfiguration -join ', ')]"
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
            $result.appModes = @('full')
        }
        Write-Verbose "[$functionName] App mode configuration completed successfully: [$($result.appModes -join ', ')]"
        return $result
    }
    catch
    {
        Write-Verbose "[$functionName] Error during app mode configuration: $($_.Exception.Message)"
        $result.cancelled = $true
        return $result
    }
}
