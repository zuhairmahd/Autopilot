function Start-FirstRunWizard()
{
    <#
    .SYNOPSIS
        Launches the first run wizard to set up initial configuration for the Autopilot application.
    
    .DESCRIPTION
        This function guides users through the initial setup process by prompting for essential configuration
        parameters and creating the necessary configuration files. It handles:
        - App ID, Tenant ID, Domain Name, and Application Name collection
        - Authentication type selection (delegated vs application)
        - App secret or certificate thumbprint for delegated authentication
        - Configuration file creation and encryption
        - Default settings.json and strings.json creation if missing
    
    .PARAMETER ConfigFile
        Path to the config.json file to be created. Defaults to ".secrets\config.json".
    
    .PARAMETER SettingsFile
        Path to the settings.json file. Defaults to "settings.json".
    
    .PARAMETER StringsFile
        Path to the strings.json file. Defaults to "strings.json".
    
    .PARAMETER Silent
        If specified, skips interactive prompts and uses default values where possible.
    
    .OUTPUTS
        System.Boolean
        Returns $true if the wizard completed successfully, $false otherwise.
    
    .EXAMPLE
        Start-FirstRunWizard
        
        Launches the wizard with default file paths.
    
    .EXAMPLE
        Start-FirstRunWizard -ConfigFile "C:\Config\.secrets\config.json" -SettingsFile "C:\Config\settings.json"
        
        Launches the wizard with custom file paths.
    
    .NOTES
        - Requires Write-Log function for logging
        - Uses existing encryption functions for config.json protection
        - Maintains PowerShell 5.1 compatibility
        - Provides comprehensive error handling and validation
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigFile = "$PWD\.secrets\config.json",
        [string]$SettingsFile = "$PWD\settings.json",  
        [string]$StringsFile = "$PWD\strings.json",
        [switch]$Silent,
        [switch]$authOnly
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-SafeLog "Starting First Run Wizard" "Information"
    Write-Verbose "[$functionName] Starting First Run Wizard"
    
    try
    {
        # Display welcome message
        if (-not $Silent)
        {
            Write-Host "`n" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "                    Welcome to the Autopilot First Run Wizard                  " -ForegroundColor Green  
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "`nThis wizard will help you set up your Autopilot application configuration." -ForegroundColor White
            Write-Host "Please have the following information ready:" -ForegroundColor White
            Write-Host "• Application ID (from Azure AD)" -ForegroundColor White
            Write-Host "• Tenant ID (from Azure AD)" -ForegroundColor White
            Write-Host "• Domain Name" -ForegroundColor White
            Write-Host "• Application Name" -ForegroundColor White
            Write-Host "• Authentication details (app secret or certificate)" -ForegroundColor White
            Write-Host "`nPress Enter to continue or Ctrl+C to exit..." -ForegroundColor Yellow
            Read-Host
        }
        
        # Step 1: Collect basic configuration
        Write-SafeLog "Collecting basic configuration parameters" "Information"
        $config = Get-BasicConfigurationFromUser -Silent:$Silent
        
        if (-not $config)
        {
            Write-SafeLog "Failed to collect basic configuration" "Error"
            return $false
        }
        
        # Step 2: Collect authentication configuration
        Write-SafeLog "Collecting authentication configuration" "Information"
        $authConfig = Get-AuthenticationConfigurationFromUser -Silent:$Silent
        
        if (-not $authConfig)
        {
            Write-SafeLog "Failed to collect authentication configuration" "Error"
            return $false
        }
        
        # Step 2.5: Collect autoUpdate configuration
        Write-SafeLog "Collecting autoUpdate configuration" "Information"
        $autoUpdateConfig = Get-AutoUpdateConfigurationFromUser -Silent:$Silent
        
        if ($null -eq $autoUpdateConfig)
        {
            Write-SafeLog "Failed to collect autoUpdate configuration" "Error"
            return $false
        }
        
        # Step 3: Merge configurations
        $finalConfig = @{
            domain   = $config.domain
            TenantId = $config.TenantId
            AppId    = $config.AppId
            Name     = $config.Name
        }
        
        # Add authentication credentials based on type
        if (-not ($authConfig.IsDelegated))
        {
            $finalConfig.appCredentials = @{
                AppSecret  = $authConfig.AppSecret
                Thumbprint = $authConfig.Thumbprint
                Subject    = $authConfig.Subject
            }
        }
        
        # Legacy fields for backward compatibility
        $finalConfig.AppSecret = $authConfig.AppSecret
        $finalConfig.Thumbprint = $authConfig.Thumbprint
        $finalConfig.Subject = $authConfig.Subject
        
        # Step 4: Create and encrypt configuration file
        Write-SafeLog "Creating configuration file at: $ConfigFile" "Information"
        $configCreated = New-ConfigurationFile -ConfigFile $ConfigFile -ConfigData $finalConfig -Silent:$Silent
        if (-not $configCreated)
        {
            Write-SafeLog "Failed to create configuration file" "Error"
            return $false
        }
        
        if ($authOnly)
        {
            Write-SafeLog "Authentication configuration completed successfully" "Information"
            Write-Host "Authentication configuration completed successfully." -ForegroundColor Green
            return $true
        }
        
        # Step 5: Ensure settings.json exists with defaults
        Write-SafeLog "Ensuring settings.json exists with defaults" "Information"
        $settingsCreated = Test-SettingsJsonExists -SettingsFile $SettingsFile -Silent:$Silent -AuthType $authConfig.AuthType -IsDelegated $authConfig.IsDelegated -DomainName $config.domain
        
        if (-not $settingsCreated)
        {
            Write-SafeLog "Failed to ensure settings.json exists" "Warning"
        }
        else
        {
            # Step 5.1: Update authentication setting in settings.json
            Write-SafeLog "Updating authentication setting in settings.json" "Information"
            $authUpdateSuccess = Update-AuthSetting -SettingsFile $SettingsFile -SettingName "Delegated" -SettingValue $authConfig.IsDelegated
            
            if ($authUpdateSuccess)
            {
                Write-SafeLog "Successfully updated Delegated setting to: $($authConfig.IsDelegated)" "Information"
            }
            else
            {
                Write-SafeLog "Failed to update Delegated setting" "Warning"
            }
            
            # Step 5.5: Update autoUpdate setting in settings.json
            Write-SafeLog "Updating autoUpdate setting in settings.json" "Information"
            $autoUpdateSuccess = Update-GlobalSetting -SettingsFile $SettingsFile -SettingName "autoUpdate" -SettingValue $autoUpdateConfig.autoUpdate
            
            if ($autoUpdateSuccess)
            {
                Write-SafeLog "Successfully updated autoUpdate setting to: $($autoUpdateConfig.autoUpdate)" "Information"
            }
            else
            {
                Write-SafeLog "Failed to update autoUpdate setting" "Warning"
            }
        }
        
        # Step 6: Ensure strings.json exists with defaults
        Write-SafeLog "Ensuring strings.json exists with defaults" "Information"
        $stringsCreated = Test-StringsJsonExists -StringsFile $StringsFile -Silent:$Silent
        
        if (-not $stringsCreated)
        {
            Write-SafeLog "Failed to ensure strings.json exists" "Warning"
        }
        
        # Step 7: Display completion message
        if (-not $Silent)
        {
            Write-Host "`n" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "                          Setup Complete!                                       " -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "`nYour Autopilot application has been configured successfully." -ForegroundColor White
            Write-Host "Configuration files created:" -ForegroundColor White
            Write-Host "• $ConfigFile (encrypted)" -ForegroundColor Green
            Write-Host "• $SettingsFile" -ForegroundColor Green
            Write-Host "• $StringsFile" -ForegroundColor Green
            Write-Host "`nConfiguration Summary:" -ForegroundColor White
            Write-Host "• Domain: $($config.domain)" -ForegroundColor Cyan
            Write-Host "• Authentication: $($authConfig.AuthType)" -ForegroundColor Cyan
            Write-Host "• Auto Updates: $(if ($autoUpdateConfig.autoUpdate) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Cyan
            Write-Host "`nYou can now run the application normally." -ForegroundColor White
        }
        
        Write-SafeLog "First Run Wizard completed successfully" "Information"
        return $true
        
    }
    catch
    {
        Write-SafeLog "First Run Wizard failed with error: $($_.Exception.Message)" "Error"
        Write-Host "An error occurred during setup: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose "[$functionName] Error details: $($_.Exception.StackTrace)"
        return $false
    }
}

