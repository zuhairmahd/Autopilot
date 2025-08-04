function CreateConfiguration()
<#
.SYNOPSIS
    Creates a configuration file (settings.json) from initialization settings with environment-specific values.

.DESCRIPTION
    This function reads the init.json file and creates a settings.json configuration file using values
    appropriate for the specified environment (dev, release, or default). It leverages the consolidated
    configuration loading system for improved reliability and consistency.

.PARAMETER RootFolder
    The root folder containing the source init.json file.

.PARAMETER InitFile
    The path to the init.json file. Defaults to "$RootFolder\init.json".

.PARAMETER DestinationFolder
    The folder where the vars.json file should be created. Defaults to $RootFolder.

.PARAMETER ConfigurationFile
    The full path for the output configuration file. Defaults to "$DestinationFolder\vars.json".

.PARAMETER ConfigurationType
    Specifies which values to extract from the init.json structure:
    - 'dev': Uses devdefault values
    - 'release': Uses reldefault values
    - 'default': Uses default values

.OUTPUTS
    System.Boolean
    Returns $true if the configuration file was created successfully, $false otherwise.

.EXAMPLE
    # Create release configuration
    $success = CreateConfiguration -RootFolder "C:\MyProject" -ConfigurationType 'release'

.EXAMPLE
    # Create development configuration with custom paths
    $success = CreateConfiguration -RootFolder "C:\Source" -DestinationFolder "C:\Config" -ConfigurationType 'dev'

.NOTES
    - Uses the consolidated Get-InitConfiguration function for consistency
    - Automatically creates init.json if it doesn't exist
    - Provides comprehensive error handling and logging
    - Validates successful file creation before returning
#>
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json", [string]$DestinationFolder = $RootFolder,
        [string]$ConfigurationFile = "$DestinationFolder\settings.json",
        [ValidateSet('dev', 'release', 'default')]
        [string]$ConfigurationType = 'release'
    )
    $functionName = $MyInvocation.MyCommand.Name    
    #region Variables and logs
    Write-Verbose "[$functionName] Root folder: $RootFolder"
    Write-Verbose "[$functionName] Init file: $InitFile"
    Write-Verbose "[$functionName] Destination folder: $DestinationFolder"
    Write-Verbose "[$functionName] ConfigurationFile: $ConfigurationFile"
    Write-Verbose "[$functionName] ConfigurationType: $ConfigurationType"
    $success = $false
    #endregion
    
    try
    {
        if (Test-Path -Path $InitFile)
        {
            Write-Verbose "[$functionName] Found init file at $InitFile."
            # Use the consolidated configuration loader with specific configuration type
            $configData = Get-InitConfiguration -InitFile $InitFile -ConfigurationType $ConfigurationType
        }
        else
        {
            Write-Host "No init file found at $InitFile."
            Write-Host "Creating init file at $InitFile."
            if (InitializeConfiguration -RootFolder $RootFolder)
            {
                Write-Host "Init file created successfully."
                $configData = Get-InitConfiguration -InitFile $InitFile -ConfigurationType $ConfigurationType
            }
            else
            {
                Write-Host "Failed to create init file."
                return $success
            }
        }
        Write-Verbose "[$functionName] Config data: $($configData | ConvertTo-Json -Depth 10)"
        
        # Create the settings.json structure with globalSettings and domains
        $settingsStructure = @{
            "description"    = "This is the configuration file for the script. It contains the settings for the script to run correctly."
            "version"        = "1.0"
            "globalSettings" = $configData
            "domains"        = @{}
        }
        
        # Write the structured data to the configuration file
        $settingsStructure | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigurationFile -Force
        
        # Check to make sure it was written
        if (Test-Path -Path $ConfigurationFile)
        {
            Write-Verbose "[$functionName] Configuration file created successfully at $ConfigurationFile."
            $success = $true
        }
        else
        {
            Write-Host "Failed to create configuration file at $ConfigurationFile."
            $success = $false
        }
    }
    catch
    {
        Write-Warning "[$functionName] Error creating configuration: $($_.Exception.Message)"
        Write-Verbose "[$functionName] Full error: $($_.Exception | Format-List * | Out-String)"
        $success = $false
    }
    
    # Return the success status
    return $success
}

