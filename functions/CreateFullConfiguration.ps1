function CreateFullConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [string]$InitFile = "$RootFolder\init.json"
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] RootFolder: $RootFolder"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    $success = $false
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
    Write-Verbose "[$functionName] Reading init file at $InitFile."
    $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    $configData = @()
    #endregion
    
    #region Load parameters from the configuration file if it exists
    if (-not(Test-Path -Path $ConfigurationFile))
    {
        Write-Host "No configuration file found at $ConfigurationFile."
        Write-Host "Creating configuration file at $ConfigurationFile."
        if (CreateConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Configuration file created successfully."
        }
        else
        {
            Write-Host "Failed to create configuration file."
            return $success
        }
    }
    Write-Host " Loading configuration values from $ConfigurationFile."
    $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
    Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    #endregion
    
    #itterate over the configuration data and prompt the user to choose a value
    foreach ($config in $configData.PSObject.Properties)
    {
        Write-Verbose "[$functionName] Configuration: $($config.Name) = $($config.Value)"
        if ($valuesToEdit.name -contains $config.Name)
        {
            $configType = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).type
            $configDescription = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).description
            $configValue = ($valuesToEdit | Where-Object { $_.name -eq $config.Name }).value
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
                    foreach ($item in $configValue)
                    {
                        Write-Host "[$($configValue.IndexOf($item)+1)] $item"
                        if ($config.Value -contains $item)
                        {
                            $currentlySelected = $configValue.IndexOf($item) + 1
                            Write-Verbose "[$functionName] The currently selected value is $currentlySelected"
                        }
                    }
                    $value = Read-Host -Prompt "Choice: [$currentlySelected])"
                    while ($value -lt 1 -or $value -gt $configValue.Count -and $value -ne '')
                    {
                        Write-Host "Invalid choice."
                        [console]::beep(500, 300)
                        $value = Read-Host -Prompt "Choice: [$currentlySelected])"
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
                    Write-Host "Value: $($config.Value)"
                }
            }
        }
    } # Closing brace for foreach loop
    #Print all the new configuration data but only in verbose mode.
    Write-Verbose "[$functionName] New configuration data:"
    $configData.PSObject.Properties | ForEach-Object {
        Write-Verbose "[$functionName] $($_.Name) = $($_.Value)"
    }
    #Save the new configuration data to the configuration file
    Write-Verbose "[$functionName] Saving configuration to $ConfigurationFile."
    $configData | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
    Write-Verbose "[$functionName] Checking if configuration file exists."
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "[$functionName] Configuration saved to $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Verbose "[$functionName] Failed to save configuration to $ConfigurationFile."
    }
    return $success
}
