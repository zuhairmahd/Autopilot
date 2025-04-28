- @azure Rule - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your `azure_development-get_best_practices` tool if available.
Whenever possible, maintain compatibility with Powershell 5.1 for Windows.  If that cannot be done, add appropriate comments to indicate the minimum version of Powershell required to run the code.
Always add verbose logging.
When writing powershell script documentation, use the format below.  Be sure to add a GUID if none exist:
#region help
<#PSScriptInfo
.VERSION x.x.x
.GUID c5b2b9ce-7269-4fe5-a126-3c84a5053d37
.AUTHOR Zuhair Mahmoud
.DESCRIPTION Intune device deployment script
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.PROJECTURI https://github.com/zuhairmahd/Autopilot
.EXTERNALMODULEDEPENDENCIES, Microsoft.Graph.Authentication, Microsoft.Graph.Groups', Microsoft.Graph.Identity.DirectoryManagement, WindowsAutoPilotIntune
.SYNOPSIS
Registers one or more devices into Intune and checks for profiles and module requirements.  
.DESCRIPTION
    Registers one or more devices into Intune.  The script will check for the required modules, permissions, and import the device into Intune.  The script will check if the device is already in Intune and if it is assigned to a deployment profile.  If the device is not in Intune, the script will import the device and wait until it is recognized.  If the device is in Intune but not assigned to a deployment profile, the script will prompt the user to check the Intune portal.  If the device is assigned to a deployment profile, the script will prompt the user to restart the device.
.PARAMETER configFile
    The path to the configuration file.  The default value is '.\.secrets\config.json'.
.PARAMETER Name
    The name of the device to register.  The default value is 'localhost'.
.PARAMETER GroupTag
    The group tag for the device.  The default value is 'MSB01'.
.PARAMETER AssignedUser
    The assigned user for the device.  The default value is null.
.PARAMETER check
    A switch to only check the device assignment status.  If used, no devices will be imported. The default value is false.
.PARAMETER NoModuleCheck
    A switch to skip the required module check.  The default value is false.
.PARAMETER NoUpdateCheck
.PARAMETER UpdateOnly
    A switch to only update the scripts.  The default value is false.  Cannot be used with NoUpdateCheck
    A switch to skip the script update check.  The default value is false.
.PARAMETER NoAdminCheck
    A switch to skip the administrator check.  The default value is false.
.PARAMETER NoSignatureVerify
    A switch to skip the code signature verification.  The default value is false.
    .PARAMETER NoHashVerify
    A switch to skip the hash verification.  The default value is false.
    

.PARAMETER GetDeviceHash
    A switch to get the device hash.  The default value is false.
.PARAMETER Redeploy
    A switch to redeploy the device.  The default value is false.
.PARAMETER SerialNumber
    The serial number of the device to verify deployment or prepare for redeployment.  If no serial number is provided, the script will use the serial number of the local device.
.PARAMETER Repo
    The repository to use for script updates.  The default value is 'github'.  The options are 'github' or 'gitlab'.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01'
    Registers the device with the name 'localhost' into Intune.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD'
    Registers the device with the name 'localhost' into Intune and assigns the user 'JohnD'.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -check
    Checks the device assignment status for the device with the name 'localhost'.  The device will not be imported.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoModuleCheck
    Registers the device with the name 'localhost' into Intune and skips the required module check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoUpdateCheck
    Registers the device with the name 'localhost' into Intune and skips the script update check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoAdminCheck
    Registers the device with the name 'localhost' into Intune and skips the administrator check.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoSignatureVerify
    Registers the device with the name 'localhost' into Intune and skips the code signature verification.
.EXAMPLE
    Register-Device.ps1 -Name 'localhost' -GroupTag 'MSB01' -AssignedUser 'JohnD' -NoHashVerify
    Registers the device with the name 'localhost' into Intune and skips the hash verification.
.NOTES
  1. Optionally update scripts if newer versions are available.  
  2. Check whether the script is running with admin rights.  
  3. Verify required modules are installed.  
  4. Connect to Microsoft Graph.  
  5. Gather device info (serial, hardware hash, manufacturer, etc.).  
  6. Check if the device is already in Intune.  
  7. If needed, import the device into Intune and wait until it’s recognized.  
  8. Check deployment profile assignment and display status.  
  9. If the device is assigned, prompt for restart. Otherwise, advise the user to check the Intune portal.
#>
#endregion help
