function Update-GlobalSetting()
<#
.SYNOPSIS
    Updates a specific setting in the globalSettings section of settings.json.

.DESCRIPTION
    This function loads the existing settings.json file, updates a specific property
    in the globalSettings section, and saves the file back. This allows for granular
    updates without overwriting the entire configuration structure.

.PARAMETER SettingsFile
    The path to the settings.json file. Defaults to "settings.json".

.PARAMETER SettingName
    The name of the setting to update in globalSettings.

.PARAMETER SettingValue
    The new value for the setting.

.OUTPUTS
    System.Boolean
    Returns $true if the setting was updated successfully, $false otherwise.

.EXAMPLE
    # Update the GroupTag in globalSettings
    $success = Update-GlobalSetting -SettingName "GroupTag" -SettingValue "NEWGROUP"

.EXAMPLE
    # Update the maxWaitTime setting
    $success = Update-GlobalSetting -SettingsFile "C:\Config\settings.json" -SettingName "maxWaitTime" -SettingValue "120"

.NOTES
    - Maintains PowerShell 5.1 compatibility
    - Preserves all other settings in the file
    - Creates backup before modification for safety
    - Validates JSON structure before and after update
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
    Write-Verbose "[$functionName] Updating setting '$SettingName' to '$SettingValue' in file: $SettingsFile"
    
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
        if (-not $settings.PSObject.Properties.Name -contains 'globalSettings')
        {
            Write-Warning "[$functionName] Settings file does not contain globalSettings section"
            return $false
        }
        
        # Convert PSCustomObject to hashtable for easier manipulation (PowerShell 5.1 compatible)
        $globalSettingsHash = @{}
        foreach ($property in $settings.globalSettings.PSObject.Properties)
        {
            $globalSettingsHash[$property.Name] = $property.Value
        }
        
        # Update the specific setting
        $globalSettingsHash[$SettingName] = $SettingValue
        Write-Verbose "[$functionName] Updated globalSettings.$SettingName = $SettingValue"
        
        # Convert back to PSCustomObject structure
        $settings.globalSettings = [PSCustomObject]$globalSettingsHash
        
        # Create backup
        $backupFile = "$SettingsFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item -Path $SettingsFile -Destination $backupFile -Force
        Write-Verbose "[$functionName] Created backup: $backupFile"
        
        # Save updated settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Force
        
        # Verify the update
        $verifyContent = Get-Content -Path $SettingsFile -Raw -Force
        $verifySettings = $verifyContent | ConvertFrom-Json
        
        if ($verifySettings.globalSettings.PSObject.Properties.Name -contains $SettingName -and
            $verifySettings.globalSettings.$SettingName -eq $SettingValue)
        {
            Write-Verbose "[$functionName] Successfully updated and verified setting"
            return $true
        }
        else
        {
            Write-Warning "[$functionName] Failed to verify setting update"
            return $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error updating global setting: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        return $false
    }
}

