
1. Purpose
This script uses the Microsoft Graph API to import a device hash for a Windows laptop or desktop into Intune so that it is ready for enrollment using Autopilot.  This is a modified version of the Microsoft provided script referenced in the article at https://learn.microsoft.com/en-us/autopilot/add-devices.

2. How To Use
This script is meant to be used during the installation of Windows on a laptop which was previously running the Igel operating system.  Once the Windows installation is completed and you are at the screen wherre you are asked whether you wish to use the device for personal or business use, please do the following:
1. Press Shift+F10 to get to a command line.  Note that on some laptops you may have to press the FN key as well.
2. Type the command:
Register
at the c:\windows\system32 prompt.

3. How It Works
The script uses an Azure App Registration called Intune Enrollment and uses its application credentials to call the Microsoft Graph API.  This means that it is not delegated and hence does not require a user identity.  All you need to do is have the encrypted configuration file config.json in the .secrets subfolder to access the API.  Once the script imports the device hash into Intune, the device can then be enrolled using Autopilot using the Pre-provisioned autopilot enrollment process documented in the Windows 11 project SOP's.
Consistent with security best practices, the app uses a rotating encrypted secret key to guard against any leakage of credentials.  Without the configuration file, you will not be able to access the API.  Also, consistent with the principle of least required privilege, the app has access only to the scopes it needs to accomplish its goal of enrolling devices.  Those scopes are:
"Device.ReadWrite.All"
"DeviceManagementManagedDevices.ReadWrite.All"
"DeviceManagementServiceConfig.ReadWrite.All"
"Group.ReadWrite.All"
"GroupMember.ReadWrite.All"

4. Problems
If you have any problems, please reach out to Zuhair Mahmoud at mahmoudz@gao.gov.
