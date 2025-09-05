function Get-MenuConfiguration()
{
    <#
.SYNOPSIS
    Loads menu configuration with support for both JSON and PSD1 formats.

.DESCRIPTION
    This function loads menu configuration data from menu.psd1 files. 
    It uses the unified Get-ConfigurationData function to provide intelligent format detection, 
    automatic fallback, and performance optimization.

.PARAMETER MenuName
    Optional. Specific menu name to retrieve from the configuration.

.PARAMETER MenuConfigFile
    The path to the menu configuration file (without extension). Defaults to "$pwd\menu".
    The function will automatically detect the .psd1 format for optimal performance.

.OUTPUTS
    System.Collections.Hashtable
    Returns menu configuration hashtable or specific menu section if MenuName is specified.

.EXAMPLE
    # Load complete menu configuration (uses menu.psd1)
    $menuConfig = Get-MenuConfiguration

.EXAMPLE  
    # Load specific menu section
    $mainMenu = Get-MenuConfiguration -MenuName "mainMenu"

.NOTES
    - Uses the unified Get-ConfigurationData function for optimal performance
    - Uses .psd1 format for optimal performance
    - Provides comprehensive default menu configuration
    - Handles missing files and invalid configuration gracefully
    - Maintains full backward compatibility with existing code
    - Native PowerShell Data File processing
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$MenuName,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Loading menu configuration from: $MenuConfigFile"
    
    # Default menu configuration fallback values
    $defaultMenuValues = @{
        name             = 'menu.psd1'
        description      = 'This file contains the definitions for the menus used in the application.'
        version          = '1.3.0.0'
        appModeHierarchy = @{
            full                 = @('*')
            advanced             = @('advanced', 'helpdesk', 'registration')
            helpdesk             = @('helpdesk')
            registration         = @('registration')
            advancedRegistration = @('advancedRegistration', 'registration')
            admin                = @('admin', 'advanced', 'helpdesk', 'registration')
            custom               = @()
        }
        appModeDefaults  = @{
            full         = @{
                description  = 'Full administrative access with all features enabled'
                capabilities = @('all_menus', 'all_actions', 'settings_management', 'advanced_diagnostics', 'export_all', 'device_management')
            }
            advanced     = @{
                description  = 'Advanced user with helpdesk and configuration capabilities'
                capabilities = @('advanced_features', 'helpdesk_operations', 'device_registration', 'settings_view')
            }
            helpdesk     = @{
                description  = 'Helpdesk operator with device support capabilities'
                capabilities = @('device_lookup', 'basic_troubleshooting', 'user_assistance')
            }
            registration = @{
                description  = 'Device registration specialist'
                capabilities = @('device_registration', 'autopilot_enrollment')
            }
        }
        menus            = @()
    }
    
    try
    {
        # Use the unified configuration loader (uses .psd1 for performance)
        $menuConfig = Get-ConfigurationData -ConfigurationPath $MenuConfigFile -DefaultValues $defaultMenuValues -EnableCaching
        
        Write-Verbose "[$functionName] Successfully loaded menu configuration"
        
        # Return specific menu or all configurations based on request
        if (-not $MenuName)
        {
            return $menuConfig
        }
        elseif ($menuConfig -and $menuConfig.ContainsKey($MenuName))
        {
            return $menuConfig[$MenuName]
        }
        else
        {
            Write-Warning "[$functionName] Menu '$MenuName' not found in configuration"
            return $null
        }
    }
    catch
    {
        Write-Warning "[$functionName] Failed to load menu configuration: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Returning default menu values"
        
        if (-not $MenuName)
        {
            return $defaultMenuValues
        }
        elseif ($defaultMenuValues.ContainsKey($MenuName))
        {
            return $defaultMenuValues[$MenuName]
        }
        else
        {
            return $null
        }
    }
}