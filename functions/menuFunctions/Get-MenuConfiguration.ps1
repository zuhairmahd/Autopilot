function Get-MenuConfiguration()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$MenuName,
        [Parameter(Mandatory = $false)]
        [string]$MenuConfigFile = "$pwd\menu.json"
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Loading menu configuration from: $MenuConfigFile"
    
    # Check if menu configuration file exists
    if (-not (Test-Path $MenuConfigFile))
    {
        Write-Verbose "[$functionName] Menu configuration file not found: $MenuConfigFile"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration file not found: $MenuConfigFile" -LogLevel "Warning"
        return $null
    }
    
    try
    {
        # Load menu configuration from file
        $menuConfig = Get-Content -Path $MenuConfigFile -Raw | ConvertFrom-Json
        Write-Verbose "[$functionName] Successfully loaded menu configuration"
        
        # If no specific menu name requested, return all configurations
        if (-not $MenuName)
        {
            Write-Verbose "[$functionName] Returning all menu configurations"
            return $menuConfig
        }
        
        # Return specific menu configuration
        if ($menuConfig.PSObject.Properties.Name -contains $MenuName)
        {
            Write-Verbose "[$functionName] Found configuration for menu: $MenuName"
            return $menuConfig.$MenuName
        }
        else
        {
            Write-Verbose "[$functionName] Menu configuration not found for: $MenuName"
            Write-Log -LogFile $LogFile -Module $functionName -Message "Menu configuration not found for: $MenuName" -LogLevel "Warning"
            return $null
        }
    }
    catch
    {
        Write-Verbose "[$functionName] Error loading menu configuration: $_"
        Write-Log -LogFile $LogFile -Module $functionName -Message "Error loading menu configuration: $_" -LogLevel "Error"
        return $null
    }
}