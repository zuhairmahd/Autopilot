function Get-AutoUpdateConfigurationFromUser()
{
    <#
    .SYNOPSIS
        Collects autoUpdate configuration parameter from the user.
    
    .DESCRIPTION
        Prompts the user whether they want automatic updates enabled or disabled.
        This setting controls whether the script will automatically check for and apply updates.
    
    .PARAMETER Silent
        If specified, uses default value (enabled).
    
    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable containing the autoUpdate configuration.
    
    .EXAMPLE
        $autoUpdateConfig = Get-AutoUpdateConfigurationFromUser
        
    .EXAMPLE
        $autoUpdateConfig = Get-AutoUpdateConfigurationFromUser -Silent
    
    .NOTES
        - Maintains PowerShell 5.1 compatibility
        - Provides user-friendly prompts with clear explanations
        - Validates user input and provides feedback
    #>
    [CmdletBinding()]
    param(
        [switch]$Silent
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    Write-SafeLog "Collecting autoUpdate configuration"
    
    $autoUpdateConfig = @{
        autoUpdate = $true
    }
    
    try
    {
        if (-not $Silent)
        {
            Write-Host "`n── Auto Update Configuration ──" -ForegroundColor Cyan
            Write-Host "The script can automatically check for and install updates." -ForegroundColor White
            Write-Host "This helps ensure you have the latest features and security improvements." -ForegroundColor White
            Write-Host "" -ForegroundColor White
            Write-Host "Do you want to enable automatic updates?" -ForegroundColor White
            Write-Host "1. Yes - Enable automatic updates (recommended)" -ForegroundColor White
            Write-Host "2. No - Disable automatic updates" -ForegroundColor White
        }
        
        # Get autoUpdate preference
        $autoUpdateChoice = ""
        if ($Silent)
        {
            $autoUpdateChoice = "1"
            Write-SafeLog "Using default autoUpdate setting (enabled) in silent mode" "Information"
        }
        else
        {
            do
            {
                $autoUpdateChoice = Read-Host "Enter your choice (1 or 2)"
                if ($autoUpdateChoice -in @("1", "2"))
                {
                    break
                }
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
            } while ($true)
        }
        
        Write-SafeLog "Auto update choice selected: $autoUpdateChoice" "Debug"
        
        # Set autoUpdate value based on choice
        if ($autoUpdateChoice -eq "1")
        {
            $autoUpdateConfig.autoUpdate = $true
            if (-not $Silent)
            {
                Write-Host "`nAutomatic updates: Enabled" -ForegroundColor Green
                Write-Host "The script will check for updates automatically." -ForegroundColor Yellow
            }
        }
        else
        {
            $autoUpdateConfig.autoUpdate = $false
            if (-not $Silent)
            {
                Write-Host "`nAutomatic updates: Disabled" -ForegroundColor Yellow
                Write-Host "You can manually check for updates when needed." -ForegroundColor Yellow
            }
        }
        
        Write-SafeLog "Auto update configuration set to: $($autoUpdateConfig.autoUpdate)" "Information"
        Write-Verbose "[$functionName] Auto update configuration collected successfully"
        return $autoUpdateConfig
        
    }
    catch
    {
        Write-SafeLog "Error collecting autoUpdate configuration: $($_.Exception.Message)" "Error"
        Write-Verbose "[$functionName] Error: $($_.Exception.Message)"
        return $null
    }
}

