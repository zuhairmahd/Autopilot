function CreateFullConfiguration()
<#
.SYNOPSIS
    Creates a comprehensive configuration file through interactive user prompts.

.DESCRIPTION
    This function provides an interactive configuration experience where users can customize
    configuration values based on initialization templates. It uses the consolidated JSON
    configuration system for robust file handling and validation.

.PARAMETER RootFolder
    The root folder containing the source init.json file.

.PARAMETER DestinationFolder
    The folder where the vars.json file should be created. Defaults to $RootFolder.

.PARAMETER ConfigurationFile
    The full path for the output configuration file. Defaults to "$DestinationFolder\vars.json".

.PARAMETER InitFile
    The path to the init.json file. Defaults to "$RootFolder\init.json".

.OUTPUTS
    System.Boolean
    Returns $true if the configuration file was created successfully, $false otherwise.

.EXAMPLE
    # Create interactive configuration in current project
    $success = CreateFullConfiguration -RootFolder "C:\MyProject"

.EXAMPLE
    # Create configuration with custom paths
    $success = CreateFullConfiguration -RootFolder "C:\Source" -DestinationFolder "C:\Config"

.NOTES
    - Uses consolidated JSON configuration system for consistency and reliability
    - Automatically creates missing init.json and vars.json files
    - Provides interactive prompts for each configurable value
    - Supports different input types (string, array, static)
    - Includes comprehensive error handling and validation
    - Improved array handling with better user experience
    - Enhanced error reporting and user feedback
#>
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder, 
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\settings.json",
        [string]$InitFile = "$RootFolder\init.json"
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] RootFolder: $RootFolder"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    $success = $false
    #endregion

    try
    {
        # Ensure init file exists using consolidated system
        Write-Verbose "[$functionName] Checking for init file at $InitFile."
        if (-not(Test-Path -Path $InitFile))
        {
            Write-Host "No init file found at $InitFile."
            Write-Host "Creating init file at $InitFile."
            if (InitializeConfiguration -RootFolder $RootFolder -InitFile $InitFile)
            {
                Write-Host "Init file created successfully."
            }
            else
            {
                Write-Host "Failed to create init file."
                return $success
            }
        }
        # Load raw init configuration directly to get full objects with type, description, value properties
        Write-Verbose "[$functionName] Loading raw init configuration from $InitFile."
        Write-Host "Loading initialization values from init file $InitFile."
        $initContent = Get-Content -Path $InitFile -Raw -Force
        $valuesToEdit = $initContent | ConvertFrom-Json
        Write-Verbose "[$functionName] Loaded raw init configuration values: $($valuesToEdit.count) items"
        Write-Host "Loaded $($valuesToEdit.count) initialization items from init file $InitFile."
        # Ensure configuration file exists using consolidated system
        if (-not(Test-Path -Path $ConfigurationFile))
        {
            Write-Host "No configuration file found at $ConfigurationFile."
            Write-Host "Creating configuration file at $ConfigurationFile."
            if (CreateConfiguration -RootFolder $RootFolder -ConfigurationFile $ConfigurationFile)
            {
                Write-Host "Configuration file created successfully."
            }
            else
            {
                Write-Host "Failed to create configuration file."
                return $success
            }
        }        
        # Load current configuration using consolidated system
        Write-Host "Loading settings from $ConfigurationFile."
        # Load the entire settings.json structure
        $settingsContent = Get-Content -Path $ConfigurationFile -Raw -Force
        $settingsObj = $settingsContent | ConvertFrom-Json
        # Extract globalSettings for editing
        Write-Verbose "[$functionName] Extracting globalSettings from configuration."
        if ($settingsObj.PSObject.Properties.Name -contains 'globalSettings')
        {
            Write-Verbose "[$functionName] Found globalSettings section in configuration."
            $configData = @{}
            foreach ($property in $settingsObj.globalSettings.PSObject.Properties)
            {
                $configData[$property.Name] = $property.Value
                Write-Verbose "[$functionName] Loaded global setting: $($property.Name) = $($property.Value)"
            }
            Write-Host "Found $($configData.Keys.Count) global settings."
        }
        else
        {
            Write-Warning "[$functionName] Configuration file does not contain globalSettings section"
            $configData = @{}
        }
        # Convert the loaded configuration to a PSCustomObject for compatibility with existing logic
        Write-Verbose "[$functionName] Converting configuration data to PSCustomObject."
        $configObject = [PSCustomObject]@{}
        # Add each key-value pair from the configuration data to the configObject
        Write-Verbose "[$functionName] Adding configuration data to configObject."
        foreach ($key in $configData.Keys)
        {
            $configObject | Add-Member -MemberType NoteProperty -Name $key -Value $configData[$key]
            Write-Verbose "[$functionName] Added $key = $($configData[$key]) to configObject."
        }

        # Iterate over the configuration data and prompt the user to choose a value
        Write-Host "Configuring settings interactively. Please follow the prompts."
        foreach ($config in $configObject.PSObject.Properties)
        {
            Write-Verbose "[$functionName] Configuration: $($config.Name) = $($config.Value)"
            Write-Verbose "[$functionName] Current value: $($config.Value)"
            # Find matching init configuration
            Write-Verbose "[$functionName] Searching for init configuration for $($config.Name)."
            $initConfig = $valuesToEdit | Where-Object { $_.name -eq $config.Name }
            Write-Verbose "[$functionName] Value in init configuration: $($initConfig | ConvertTo-Json -Depth 10)"
            if ($initConfig)
            {
                $configType = $initConfig.type
                $configDescription = $initConfig.description
                $configValue = $initConfig.value
                Write-Verbose "[$functionName] Found init configuration for $($config.Name)."
                if ($configValue -eq '')
                {
                    Write-Verbose "[$functionName] Config value is empty."
                    Write-Verbose "[$functionName] Setting config value to 'none'."
                    $configValue = 'none'
                }
                Write-Verbose "[$functionName] Stored Key name: $($config.Name)"
                Write-Verbose "[$functionName] Stored Key value: $($config.Value)"
                Write-Verbose "[$functionName] Possible Key values: $configValue"
                Write-Verbose "[$functionName] Key description: $configDescription"
                Write-Verbose "[$functionName] Key type: $configType"
                Write-Host "Name: $($config.Name)."
                switch ($configType)
                {
                    'string'
                    {
                        Write-Host "Please enter a new value for $($config.Name)."
                        Write-Host "Description: $($configDescription)"
                        $value = Read-Host -Prompt "Press enter to keep the current value: ($($config.Value))"
                        if ($value -eq '' -or $null -eq $value)
                        {
                            $value = $config.Value
                        }
                        Write-Host "New value: $value"
                        Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                        $config.Value = $value
                    }
                    'array'
                    {
                        Write-Host "Please enter a new value for $($config.Name)."
                        Write-Host "Press enter to keep the current value: $($config.Value)."
                        Write-Host "Description: $($configDescription)"
                        
                        $currentlySelected = 1  # Default selection
                        for ($i = 0; $i -lt $configValue.Count; $i++)
                        {
                            Write-Host "[$($i+1)] $($configValue[$i])"
                            if ($config.Value -eq $configValue[$i])
                            {
                                $currentlySelected = $i + 1
                                Write-Verbose "[$functionName] The currently selected value is $currentlySelected"
                            }
                        }
                        
                        $value = Read-Host -Prompt "Choice: [$currentlySelected]"
                        while ($value -ne '' -and ($value -lt 1 -or $value -gt $configValue.Count))
                        {
                            Write-Host "Invalid choice." -ForegroundColor Red
                            [console]::beep(500, 300)
                            $value = Read-Host -Prompt "Choice: [$currentlySelected]"
                        }
                        
                        if ($value -eq '')
                        {
                            $value = $config.Value
                        }
                        else
                        {
                            $value = $configValue[$value - 1]
                        }
                        
                        Write-Host "Value: $value"
                        Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                        $config.Value = $value
                    }
                    'static'
                    {
                        Write-Verbose "[$functionName] This is a static value and cannot be changed."
                        Write-Host "Value: $($config.Value)" -ForegroundColor Yellow
                    }
                }
            }
            else
            {
                Write-Verbose "[$functionName] No matching init configuration found for $($config.Name). Using default string input."
                # If no init configuration is found, treat it as a simple string input
                Write-Host "Please enter a new value for $($config.Name)."
                Write-Host "Description: Advanced setting - no specific description available"
                $value = Read-Host -Prompt "Press enter to keep the current value: ($($config.Value))"
                if ($value -eq '' -or $null -eq $value)
                {
                    $value = $config.Value
                }
                Write-Host "New value: $value"
                Write-Verbose "[$functionName] Changing the value of $($config.Name) from $($config.Value) to $value"
                $config.Value = $value
            }
        }

        # Print all the new configuration data but only in verbose mode
        Write-Verbose "[$functionName] New configuration data:"
        $configObject.PSObject.Properties | ForEach-Object {
            Write-Verbose "[$functionName] $($_.Name) = $($_.Value)"
        }        
        # Convert back to hashtable for saving
        Write-Verbose "[$functionName] Converting configObject back to hashtable for saving."
        $finalConfig = @{}
        foreach ($prop in $configObject.PSObject.Properties)
        {
            $finalConfig[$prop.Name] = $prop.Value
            Write-Verbose "[$functionName] Final config: $($prop.Name) = $($prop.Value)"
        }

        # Preserve the settings.json structure with updated globalSettings
        $settingsObj.globalSettings = [PSCustomObject]$finalConfig
        Write-Verbose "[$functionName] Updated globalSettings in settingsObj."

        # Save the complete settings.json structure to the configuration file
        Write-Verbose "[$functionName] Saving configuration to $ConfigurationFile."
        $settingsObj | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
        Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
        
        # Verify the file was saved successfully
        Write-Verbose "[$functionName] Verifying configuration file at $ConfigurationFile."
        if (Test-Path -Path $ConfigurationFile)
        {
            Write-Verbose "[$functionName] Configuration saved successfully to $ConfigurationFile."
            Write-Host "Configuration saved successfully." -ForegroundColor Green
            $success = $true
        }
        else
        {
            Write-Verbose "[$functionName] Failed to save configuration to $ConfigurationFile."
            Write-Host "Failed to save configuration." -ForegroundColor Red
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error during configuration creation: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        Write-Host "An error occurred during configuration creation. Check verbose logs for details." -ForegroundColor Red
        $success = $false
    }
    return $success
}

