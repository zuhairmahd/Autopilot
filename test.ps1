function CreateConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [string]$ConfigurationFile = "$folder\vars.json"
    )

    #print verbose log of received parameters
    Write-Verbose "Folder: $Folder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    
    $valuesToEdit = @(
        @{name = 'Repo'; value = @('Github', 'Gitlab')}, 
        @{name = 'Release'; value = @('main', 'auto')}
    )
    $success = $false

    # Load parameters from the configuration file if it exists
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Host " Loading configuration values from $ConfigurationFile."
        $configData = Get-Content -Path $ConfigurationFile -Raw | ConvertFrom-Json
        Write-Host "Found $($configData.PSObject.Properties.Name.count) configurations."
    }
    else
    {
        Write-Host "No configuration file found at $ConfigurationFile."
    }
    #itterate over the configuration data and prompt the user to choose a value
    foreach ($config in $configData.PSObject.Properties)
    {
        Write-Verbose "Configuration: $($config.Name) = $($config.Value)"
        if ($valuesToEdit.name -contains $config.Name)
        {
            Write-Host "Choose a value for $($config.Name)"
            $configValues = $valuesToEdit | Where-Object { $_.name -eq $config.Name } | Select-Object -ExpandProperty value
            $index = 1
            $configValues | ForEach-Object {
                Write-Host "($index): $_"
                $index++
            }
            $selectedValue = Read-Host "Enter the number of the value you want to select"
            Write-Verbose "Selected value: $selectedValue"
            while ($selectedValue -lt 1 -or $selectedValue -gt $configValues.Count)
            {
                Write-Host "$selectedValue is an invalid selection. Please enter a number between 1 and $($configValues.Count)"
                [console]::beep(500, 300)
                $selectedValue = Read-Host "Enter the number of the value you want to select"
            }
            $config.Value = $configValues[$selectedValue - 1]
            Write-Verbose "$($config.name) =  $($config.Value )"
        }
    }
    #Print all the new configuration data but only in verbose mode.
    Write-Verbose "New configuration data:"
    $configData.PSObject.Properties | ForEach-Object {
        Write-Verbose "$($_.Name) = $($_.Value)"
    }
    #Save the new configuration data to the configuration file
    Write-Verbose "Saving configuration to $ConfigurationFile."
    $configData | ConvertTo-Json | Set-Content -Path $ConfigurationFile
    Write-Verbose "Configuration saved to $ConfigurationFile."
    Write-Verbose "Checking if configuration file exists."
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Verbose "Configuration saved to $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Verbose "Failed to save configuration to $ConfigurationFile."
    }
    return $success
}
