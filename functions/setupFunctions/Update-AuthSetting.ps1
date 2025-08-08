function Update-AuthSetting()
<#
.SYNOPSIS
    Updates a setting in the auth section of the settings.json file.

.DESCRIPTION
    This function loads the existing settings.json file, updates a specific setting in the auth
    section, and saves the file back. This allows for granular updates to authentication
    configuration without affecting other sections.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER SettingName
    The name of the auth setting to update (e.g., "Delegated", "authType", "ForceNewToken").

.PARAMETER SettingValue
    The value to set for the auth setting.

.OUTPUTS
    System.Boolean
    Returns $true if the auth setting was updated successfully, $false otherwise.

.EXAMPLE
    # Update Delegated property in auth section
    $success = Update-AuthSetting -SettingName "Delegated" -SettingValue $true

.EXAMPLE
    # Update authType property in auth section
    $success = Update-AuthSetting -SettingsFile "C:\Config\settings.json" -SettingName "authType" -SettingValue "PublicAuthFlow"

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Preserves all other settings sections
    - Creates backup before modification for safety
    - Validates settings file structure before updating
#>
{
    [CmdletBinding()]
    param(
        [string]$SettingsFile = "settings.json",
        [Parameter(Mandatory = $true)]
        [string]$SettingName,
        [Parameter(Mandatory = $true)]
        $SettingValue
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Updating auth setting '$SettingName' to '$SettingValue' in file: $SettingsFile"
    
    try
    {
        # Check if settings file exists
        if (-not (Test-Path -Path $SettingsFile))
        {
            Write-Warning "[$functionName] Settings file not found: $SettingsFile"
            return $false
        }
        
        # Load existing settings
        $jsonContent = Get-Content -Path $SettingsFile -Raw -Force
        $settings = $jsonContent | ConvertFrom-Json
        
        # Validate structure
        if (-not $settings.PSObject.Properties.Name -contains 'auth')
        {
            Write-Warning "[$functionName] Settings file does not contain auth section"
            return $false
        }
        
        # Convert PSCustomObject to hashtable for easier manipulation (PowerShell 5.1 compatible)
        $authSettingsHash = @{}
        foreach ($property in $settings.auth.PSObject.Properties)
        {
            $authSettingsHash[$property.Name] = $property.Value
        }
        
        # Update the specific setting
        $authSettingsHash[$SettingName] = $SettingValue
        Write-Verbose "[$functionName] Updated auth.$SettingName = $SettingValue"
        
        # Convert back to PSCustomObject structure
        $settings.auth = [PSCustomObject]$authSettingsHash
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Force
        
        # Verify the update
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        if ($verifySettings.auth.PSObject.Properties.Name -contains $SettingName)
        {
            $actualValue = $verifySettings.auth.$SettingName
            
            # Handle array comparison specially
            if ($SettingValue -is [array] -and $actualValue -is [array])
            {
                $comparisonResult = Compare-Object $SettingValue $actualValue
                if ($null -eq $comparisonResult)
                {
                    Write-Verbose "[$functionName] Successfully updated and verified auth setting (array)"
                    return $true
                }
                else
                {
                    Write-Warning "[$functionName] Array values do not match after update"
                    Write-Verbose "[$functionName] Expected: $($SettingValue -join ', ') | Actual: $($actualValue -join ', ')"
                    return $false
                }
            }
            # Handle scalar comparison
            elseif ($actualValue -eq $SettingValue)
            {
                Write-Verbose "[$functionName] Successfully updated and verified auth setting (scalar)"
                return $true
            }
            else
            {
                Write-Warning "[$functionName] Setting value does not match after update"
                Write-Verbose "[$functionName] Expected: '$SettingValue' | Actual: '$actualValue'"
                return $false
            }
        }
        else
        {
            Write-Warning "[$functionName] Failed to verify auth setting update - property not found"
            return $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error updating auth setting: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

