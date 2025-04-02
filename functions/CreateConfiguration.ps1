function CreateConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\vars.json",
        [ValidateSet('Dev', 'Release')]
        [string]$ConfigurationType = 'release'
    )
    
    #region Variables and logs
    Write-Verbose "Root folder: $Folder"
    Write-Verbose "Init file: $InitFile"
    Write-Verbose "Destination folder: $DestinationFolder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    Write-Verbose "ConfigurationType: $ConfigurationType"
    $success = $false
    if (Test-Path -Path $InitFile)
    {
        Write-Verbose "Found init file at $InitFile."
        $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
    }
    else
    {
        Write-Host "No init file found at $InitFile."
        Write-Host "Creating init file at $InitFile."
        if (InitializeConfiguration -RootFolder $RootFolder)
        {
            Write-Host "Init file created successfully."
            $valuesToEdit = Get-Content -Path $InitFile -Raw -Force | ConvertFrom-Json
        }
        else
        {
            Write-Host "Failed to create init file."
            return $success
        }
    }
    $data = @{}
    #endregion
    
    Write-Verbose "Found $($valuesToEdit.PSCustomObject.Count) properties."
    #Iterate over the ValuesToEdit and create the config data
    foreach ($value in $valuesToEdit)
    {
        Write-Verbose "Processing property name: $($value.Name)"
        if ($property.type -ne 'static')
        {
            switch ($ConfigurationType)
            {
                'release'
                {
                    Write-Verbose "Name: $($value.Name)"
                    Write-Verbose "Release Value: $($value.reldefault)"
                    $Data += @{$value.Name = $value.relDefault}
                }
                'dev'
                {
                    Write-Verbose "Name: $($value.Name)"
                    Write-Verbose "Dev Value: $($value.devdefault)"
                    $Data += @{$value.Name = $value.devdefault}
                }
            }
        }
    }
    Write-Verbose "Config data: $($Data | ConvertTo-Json -Depth 10)"
    #write the config data to the configuration file
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
    #Check to make sure it was written.
    if (Test-Path -Path $ConfigurationFile)
    {
        Write-Host "Configuration file created successfully at $ConfigurationFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create configuration file at $ConfigurationFile."
        $success = $false
    }
    #Return the success status
    return $success
}

