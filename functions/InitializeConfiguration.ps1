function InitializeConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [string]$ConfigurationFile = "$folder\init.json",
        [switch]$overwrite
    )
    #print verbose log of received parameters
    Write-Verbose "Folder: $Folder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    Write-Verbose "Overwrite: $overwrite"
    
    $initVars = @(
        @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; devdefault = ".\\.secrets\\config.json"; reldefault = ".\\.secrets\\config.json"; type = 'string'},
        @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; devdefault = 'vars.json'; reldefault = 'vars.json'; type = 'string'},
        @{name = 'Name'; value = 'localhost'; description = "The name of the device to configure."; devdefault = 'localhost'; reldefault = 'localhost'; type = 'string'},
        @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; devdefault = "MSB01"; reldefault = "MSB01"; type = 'string'},
        @{name = 'AssignedUser'; value = ''; description = "the user to assign the autopilot device to."; devdefault = ''; reldefault = ''; type = 'string'},
        @{name = 'check'; value = @('true', 'false'); description = "Check the status of the device."; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'NoModuleCheck'; value = @('true', 'false'); description = 'skip checking for installed powershell modules.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'NoUpdateCheck'; value = @('true', 'false'); description = 'skip checking for updates.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'UpdateOnly'; value = @('true', 'false'); description = 'Only check for updates and exit.'; type = 'static'},
        @{name = 'NoAdminCheck'; value = ('true', 'false'); description = 'skip checking for admin rights.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'NoSignatureVerify'; value = @('true', 'false'); description = 'skip verifying the signature of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        @{name = 'NoHashVerify'; value = @('true', 'false'); description = 'skip verifying the hash of the script.'; devdefault = 'true'; reldefault = 'false'; type = 'array'},
        @{name = 'GetDeviceHash'; value = @('true', 'false'); description = 'Gets the hash of the device and exit.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'Redeploy'; value = @('true', 'false'); description = 'Check the deployment status of the device.'; devdefault = 'false'; reldefault = 'false'; type = 'array'},
        @{name = 'SerialNumber'; value = ''; description = 'The serial number of the device to check.'; devdefault = ''; reldefault = ''; type = 'string'},
        @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; devdefault = 'Github'; reldefault = 'Gitlab'; type = 'array'}, 
        @{name = 'Release'; value = @('main', 'auto'); description = 'The release branch to use.'; devdefault = 'main'; reldefault = 'main'; type = 'array'}
    )
    $success = $false
    if (-not(Test-Path $ConfigurationFile) -or $overwrite)
    {
        Write-Verbose "Creating configuration file at $ConfigurationFile"
        $initVars | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigurationFile -Encoding utf8 -Force
        if (Test-Path $ConfigurationFile)
        {
            Write-Verbose "Configuration file created successfully."
            $success = $true
        }
        else
        {
            Write-Error "Failed to create configuration file."
        }
    }
    else
    {
        Write-Verbose "Configuration file already exists at $ConfigurationFile. Use -overwrite to overwrite."
    }
    return $success
}
