function InitializeConfiguration()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Folder,
        [string]$ConfigurationFile = "$folder\init.json",
        [ValidateSet('Dev','Rel')]
        [string]$Release = 'Rel'
    )
    #print verbose log of received parameters
    Write-Verbose "Folder: $Folder"
    Write-Verbose "ConfigurationFile: $ConfigurationFile"
    
    $initVars = @(
        @{name = 'configFile'; value = ".\\.secrets\\config.json"; description = "The path to the authentication configuration file."; type = 'string'},
        @{name = 'configuration'; value = "vars.json"; description = "The path to the configuration file."; type = 'string'},
        @{name = 'Name'; value = 'localhost'; description = "The name of the device to configure."; type = 'string'},
        @{name = 'GroupTag'; value = "MSB01"; description = "The Autopilot group tag."; type = 'string'},
        @{name = 'AssignedUser'; value = ''; description = "the user to assign the autopilot device to."; type = 'string'},
        @{name = 'check'; value = @('true','false'); description = "Check the status of the device."; type = 'array'},
        @{name = 'NoModuleCheck'; value = @('true','false'); description = 'skip checking for installed powershell modules.'; type = 'array'},
        @{name = 'NoUpdateCheck'; value = @('true','false'); description = 'skip checking for updates.'; type = 'array'},
        @{name = 'UpdateOnly'; value = @('true','false'); description = 'Only check for updates and exit.'; type = 'static'},
        @{name = @('true','false'); value = 'false'; description = 'skip checking for admin rights.'; type = 'array'},
        @{name = 'NoSignatureVerify'; value = @('true','false'); description = 'skip verifying the signature of the script.'; type = 'array'},
        @{name = 'NoHashVerify'; value = @('true','false'); description = 'skip verifying the hash of the script.'; type = 'array'},
        @{name = 'GetDeviceHash'; value = @('true','false'); description = 'Gets the hash of the device and exit.'; type = 'array'},
        @{name = 'Redeploy'; value = @('true','false'); description = 'Check the deployment status of the device.'; type = 'array'},
        @{name = 'SerialNumber'; value = ''; description = 'The serial number of the device to check.'; type = 'string'},
        @{name = 'Repo'; value = @('Github', 'Gitlab'); description = 'The repository provider to use.'; type = 'array'}, 
        @{name = 'Release'; value = @('main', 'auto'); description = 'The release branch to use.'; type = 'array'}
    )
    $success = $false
    $initVars |ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigurationFile -Encoding utf8 -Force
    if (Test-Path $ConfigurationFile) {
        Write-Verbose "Configuration file created successfully."
        $success = $true
    } else {
        Write-Error "Failed to create configuration file."
    }
    return $success
}
