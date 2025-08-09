function InitializeConfiguration()
<#
.SYNOPSIS
    Creates or overwrites the initialization configuration file (init.json).

.DESCRIPTION
    This function generates the init.json file with predefined configuration structure including
    authentication settings, deployment profiles, timing configurations, and repository settings.
    The file supports environment-specific values (dev, release, default) for flexible deployment.

.PARAMETER RootFolder
    The root folder where the init.json file should be created.

.PARAMETER InitFile
    The full path to the init.json file. Defaults to "$RootFolder\init.json".

.PARAMETER overwrite
    When specified, overwrites the existing init.json file without prompting.
    When not specified, prompts the user for confirmation if the file already exists.

.OUTPUTS
    System.Boolean
    Returns $true if the initialization file was created successfully, $false otherwise.

.EXAMPLE
    # Create init.json in the current project root
    $success = InitializeConfiguration -RootFolder "C:\MyProject"

.EXAMPLE
    # Force overwrite existing init.json
    $success = InitializeConfiguration -RootFolder "C:\MyProject" -overwrite

.NOTES
    - Creates a comprehensive configuration structure with environment-specific defaults
    - Fixed issue with ShowAdvancedOptions array definition
    - Includes authentication, timing, repository, and deployment profile settings
    - Prompts for user confirmation before overwriting existing files
    - Provides detailed verbose logging throughout the process
#>
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder,
        [string]$InitFile = "$RootFolder\init.json",
        [switch]$overwrite
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    #region print verbose log of received parameters
    Write-Verbose "[$functionName] Root folder: $RootFolder"
    Write-Verbose "[$functionName] InitFile: $InitFile"
    Write-Verbose "[$functionName] Overwrite: $overwrite"
    #endregion
    # PowerShell 5.1 compatible - using regular hashtables instead of OrderedDictionary
    $initVars = @(
        @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; default = ".\\.secrets\\config.json"; type = 'string'},
        @{name = 'configuration'; value = "settings.json"; description = "The path to the configuration file."; devdefault = 'settings.json'; reldefault = 'settings.json'; default = 'settings.json'; type = 'string'},
        @{name = 'ShowAdvancedOptions'; value = @('True', 'False'); description = "Show advanced options in the GUI."; devdefault = 'True'; reldefault = 'True'; default = 'False'; type = 'array'},
        @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; default = ''; type = 'string'},
        @{name = 'maxWaitTime'; value = '60'; description = 'How long to wait before giving up on importing a device.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        @{name = 'timeInSeconds'; value = '60'; description = 'How long to wait before initiating another check.'; devdefault = '60'; reldefault = '60'; default = '30'; type = 'string'},
        @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Github'; default = 'Github'; type = 'array'}, 
        @{name = 'Release'; value = "2.2"; description = 'The release branch to use.'; devdefault = 'main'; reldefault = '2.2'; default = 'main'; type = 'string'}
    )
    
    $success = $false
    
    if (-not(Test-Path $InitFile))
    {
        Write-Verbose "[$functionName] Creating configuration file at $InitFile."
        $initVars | ConvertTo-Json -Depth $maxJSONDepth | Set-Content -Path $InitFile -Force
    }
    else
    {
        if ($overwrite)
        {
            Write-Verbose "[$functionName] Overwriting configuration file at $InitFile."
            $initVars | ConvertTo-Json -Depth $maxJSONDepth | Set-Content -Path $InitFile -Force
        }
        else
        {
            Write-Host "Initialization file already exists at $InitFile."
            Write-Host "Would you like to overwrite the file?"
            $choice = Read-Host "Overwrite? (y/n)"
            while ($choice -notin ('y', 'n'))
            {
                Write-Host "Invalid input. Please enter 'y' or 'n'."
                [console]::beep(1000, 500)
                $choice = Read-Host "Overwrite? (y/n)"
            }
            if ($choice -eq 'y')
            {
                Write-Verbose "[$functionName] Overwriting initialization file at $InitFile."
                $initVars | ConvertTo-Json -Depth $maxJSONDepth | Set-Content -Path $InitFile -Force
            }
            else
            {
                Write-Host "Initialization file not overwritten."
                return $success
            }
        }
    }
    
    if (Test-Path $InitFile)
    {
        Write-Host "Initialization file created successfully at $InitFile."
        $success = $true
    }
    else
    {
        Write-Host "Failed to create initialization file at $InitFile."
    }
    return $success
}

