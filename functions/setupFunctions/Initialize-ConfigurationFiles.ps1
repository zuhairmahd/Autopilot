function Initialize-ConfigurationFiles()
{
    <#
    .SYNOPSIS
        Ensures configuration files exist with proper defaults.
    #>
    [CmdletBinding()]
    param(
        [string]$InitFile = "$pwd\settings.psd1",
        [string]$StringsFile = "$pwd\strings.psd1",
        [string]$MenuFile = "$pwd\menu.psd1",
        [string]$Domain,
        [switch]$domainOnly,
        [string]$ConfigurationPath
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    
    # Calculate configuration path from InitFile if not provided
    if (-not $ConfigurationPath)
    {
        if (Test-Path $InitFile)
        {
            $ConfigurationPath = Split-Path -Parent $InitFile
        }
        elseif ([System.IO.Path]::IsPathRooted($InitFile))
        {
            $ConfigurationPath = Split-Path -Parent $InitFile
        }
        else
        {
            $ConfigurationPath = Split-Path -Parent (Join-Path $pwd $InitFile)
        }
    }
    
    $domainFileName = Join-Path $ConfigurationPath "$Domain.psd1"
    $result = @{ Success = $false; ErrorMessage = "" }
    
    try
    {
        if (-not $domainOnly)   
        {
            # Ensure settings.psd1 exists with defaults
            Write-Verbose "[$functionName] Ensuring settings.psd1 exists with defaults"
            $settingsCreated = $true 
            if (-not (Test-Path $InitFile))
            {
                try
                {
                    # Get default settings and save as PSD1
                    $defaultSettings = Get-ApplicationDefaults -DefaultType "Settings"
                    Write-Verbose "[$functionName] Saving to path $InitFile"
                    $defaultSettings | Export-PowerShellDataFile -Path $InitFile -validate -Force
                    Write-Verbose "[$functionName] Created settings.psd1 with defaults"
                }
                catch
                {
                    Write-Warning "[$functionName] Failed to create settings.psd1: $($_.Exception.Message)"
                    $settingsCreated = $false
                }
            }
            else
            {
                Write-Verbose "[$functionName] settings.psd1 already exists, skipping creation"
            }
            if (-not $settingsCreated)
            {
                $result.ErrorMessage = "Failed to create or validate settings.psd1 file"
                Write-Verbose "[$functionName] $($result.ErrorMessage)"
                return $result
            }
        
            # Ensure strings.psd1 exists with defaults
            Write-Verbose "[$functionName] Ensuring strings.psd1 exists with defaults"
            $stringsCreated = $true 
            if (-not (Test-Path $StringsFile))
            {
                try
                {
                    # Get default strings and save as PSD1
                    $defaultStrings = Get-ApplicationDefaults -DefaultType "Strings"
                    $defaultStrings | Export-PowerShellDataFile -Path $StringsFile -validate -Force
                    Write-Verbose "[$functionName] Created strings.psd1 with defaults"
                }
                catch
                {
                    Write-Warning "[$functionName] Failed to create strings.psd1: $($_.Exception.Message)"
                    $stringsCreated = $false
                }
            }
            else
            {
                Write-Verbose "[$functionName] strings.psd1 already exists, skipping creation"
            }
            if (-not $stringsCreated)
            {
                $result.ErrorMessage = "Failed to create or validate strings.psd1 file"
                Write-Verbose "[$functionName] $($result.ErrorMessage)"
                return $result
            }

            #ensure menu.psd1 exists
            Write-Verbose "[$functionName] Ensuring menu.psd1 exists with defaults"
            $menuCreated = $true
            if (-not (Test-Path $MenuFile))
            {
                try
                {
                    # Get default menu and save as PSD1
                    $defaultMenu = Get-ApplicationDefaults -DefaultType "Menus"
                    $defaultMenu | Export-PowerShellDataFile -Path $MenuFile -validate -Force
                    Write-Verbose "[$functionName] Created menu.psd1 with defaults"
                }
                catch
                {
                    Write-Warning "[$functionName] Failed to create menu.psd1: $($_.Exception.Message)"
                    $menuCreated = $false
                }
            }
            else
            {
                Write-Verbose "[$functionName] menu.psd1 already exists, skipping creation"
            }
            if (-not $menuCreated)
            {
                $result.ErrorMessage = "Failed to create or validate menu.psd1 file"
                Write-Verbose "[$functionName] $($result.ErrorMessage)"
                return $result
            }   
        }

        # Ensure domain.psd1 exists with defaults
        Write-Verbose "[$functionName] Ensuring initialization file for $domain at $domainFile exists with defaults"
        $domainCreated = $true
        if (-not (Test-Path $domainFileName))
        {
            try
            {
                # Get default domain and save as PSD1
                $defaultDomain = Get-ApplicationDefaults -DefaultType "Domain" -DomainName $Domain
                $defaultDomain | Export-PowerShellDataFile -Path $domainFileName -validate -Force
                Write-Verbose "[$functionName] Created $domainFileName with defaults"
            }
            catch
            {
                Write-Warning "[$functionName] Failed to create $($domainFileName): $($_.Exception.Message)"
                $domainCreated = $false
            }
        }
        else
        {
            Write-Verbose "[$functionName] $domainFileName already exists, skipping creation"
        }
        if (-not $domainCreated)
        {
            $result.ErrorMessage = "Failed to create or validate $domainFileName file"
            Write-Verbose "[$functionName] $($result.ErrorMessage)"
            return $result
        }

        $result.Success = $true
        return $result
    }
    catch
    {
        $result.ErrorMessage = "Error ensuring configuration files exist: $($_.Exception.Message)"
        Write-Verbose "[$functionName] $($result.ErrorMessage)"
        return $result
    }
}
