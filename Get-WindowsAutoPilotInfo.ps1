<#PSScriptInfo

.VERSION 3.9

.GUID ebf446a3-3362-4774-83c0-b7299410b63f

.AUTHOR Windows Autopilot

.COMPANYNAME Microsoft

.COPYRIGHT 

.TAGS Windows AutoPilot

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 1.0:  Original published version.
Version 1.1:  Added -Append switch.
Version 1.2:  Added -Credential switch.
Version 1.3:  Added -Partner switch.
Version 1.4:  Switched from Get-WMIObject to Get-CimInstance.
Version 1.5:  Added -GroupTag parameter.
Version 1.6:  Bumped version number (no other change).
Version 2.0:  Added -Online parameter.
Version 2.1:  Bug fix.
Version 2.3:  Updated comments.
Version 2.4:  Updated "online" import logic to wait for the device to sync, added new parameter.
Version 2.5:  Added AssignedUser for Intune importing, and AssignedComputerName for online Intune importing.
Version 2.6:  Added support for app-based authentication via Connect-MSGraphApp.
Version 2.7:  Added new Reboot option for use with -Online -Assign.
Version 2.8:  Fixed up parameter sets.
Version 2.9:  Fixed typo installing AzureAD module.
Version 3.0:  Fixed typo for app-based auth, added logic to explicitly install NuGet (silently).
Version 3.2:  Fixed logic to explicitly install NuGet (silently).
Version 3.3:  Added more logging and error handling for group membership.
Version 3.4:  Added logic to verify that devices were added successfully.  Fixed a bug that could cause all Autopilot devices to be added to the specified AAD group.
Version 3.5:  Added logic to display the serial number of the gathered device.
Version 3.6:  Switch from MSGraph to MgGraph.
Version 3.7:  Switching back to using Write-Host.
Version 3.8:  AddToGroup dependencies fixed.
Version 3.9:  Expand MgGraph scopes and enforce minimum version for WindowsAutoPilotIntune module.
#>

<#
.SYNOPSIS
Retrieves the Windows AutoPilot deployment details from one or more computers

MIT LICENSE

Copyright (c) 2023 Microsoft

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.DESCRIPTION
This script uses WMI to retrieve properties needed for a customer to register a device with Windows Autopilot.  Note that it is normal for the resulting CSV file to not collect a Windows Product ID (PKID) value since this is not required to register a device.  Only the serial number and hardware hash will be populated.
.PARAMETER Name
The names of the computers.  These can be provided via the pipeline (property name Name or one of the available aliases, DNSHostName, ComputerName, and Computer).
.PARAMETER OutputFile
The name of the CSV file to be created with the details for the computers.  If not specified, the details will be returned to the PowerShell
pipeline.
.PARAMETER Append
Switch to specify that new computer details should be appended to the specified output file, instead of overwriting the existing file.
.PARAMETER Credential
Credentials that should be used when connecting to a remote computer (not supported when gathering details from the local computer).
.PARAMETER Partner
Switch to specify that the created CSV file should use the schema for Partner Center (using serial number, make, and model).
.PARAMETER GroupTag
An optional tag value that should be included in a CSV file that is intended to be uploaded via Intune (not supported by Partner Center or Microsoft Store for Business).
.PARAMETER AssignedUser
An optional value specifying the UPN of the user to be assigned to the device.  This can only be specified for Intune (not supported by Partner Center or Microsoft Store for Business).
.PARAMETER Online
Add computers to Windows Autopilot via the Intune Graph API
.PARAMETER AssignedComputerName
An optional value specifying the computer name to be assigned to the device.  This can only be specified with the -Online switch and only works with AAD join scenarios.
.PARAMETER AddToGroup
Specifies the name of the Azure AD group that the new device should be added to.
.PARAMETER Assign
Wait for the Autopilot profile assignment.  (This can take a while for dynamic groups.)
.PARAMETER Reboot
Reboot the device after the Autopilot profile has been assigned (necessary to download the profile and apply the computer name, if specified).
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv -GroupTag Kiosk
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv -GroupTag Kiosk -AssignedUser JohnDoe@contoso.com
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER -OutputFile .\MyComputer.csv -Append
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER1,MYCOMPUTER2 -OutputFile .\MyComputers.csv
.EXAMPLE
Get-ADComputer -Filter * | .\GetWindowsAutoPilotInfo.ps1 -OutputFile .\MyComputers.csv
.EXAMPLE
Get-CMCollectionMember -CollectionName "All Systems" | .\GetWindowsAutoPilotInfo.ps1 -OutputFile .\MyComputers.csv
.EXAMPLE
.\Get-WindowsAutoPilotInfo.ps1 -ComputerName MYCOMPUTER1,MYCOMPUTER2 -OutputFile .\MyComputers.csv -Partner
.EXAMPLE
.\GetWindowsAutoPilotInfo.ps1 -Online

#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
	[Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0)][alias("DNSHostName","ComputerName","Computer")] [String[]] $Name = @("localhost"),
	[Parameter(Mandatory=$False)] [String] $OutputFile = "", 
	[Parameter(Mandatory=$False)] [String] $GroupTag = "",
	[Parameter(Mandatory=$False)] [String] $AssignedUser = "",
	[Parameter(Mandatory=$False)] [Switch] $Append = $false,
	[Parameter(Mandatory=$False)] [System.Management.Automation.PSCredential] $Credential = $null,
	[Parameter(Mandatory=$False)] [Switch] $Partner = $false,
	[Parameter(Mandatory=$False)] [Switch] $Force = $false,
	[Parameter(Mandatory=$True,ParameterSetName = 'Online')] [Switch] $Online = $false,
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $TenantId = "",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppId = "",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppSecret = "",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AddToGroup = "",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AssignedComputerName = "",
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Assign = $false, 
	[Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Reboot = $false
)

Begin
{
	# Initialize empty list
	$computers = @()

	# If online, make sure we are able to authenticate
	if ($Online) {

		# Get NuGet
		$provider = Get-PackageProvider NuGet -ErrorAction Ignore
		if (-not $provider) {
			Write-Host "Installing provider NuGet"
			Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
		}
        
		# Get WindowsAutopilotIntune module (and dependencies)
		$module = Import-Module WindowsAutopilotIntune -MinimumVersion 5.4.0 -PassThru -ErrorAction Ignore
		if (-not $module) {
			Write-Host "Installing module WindowsAutopilotIntune"
			Install-Module WindowsAutopilotIntune -Force
		}
		Import-Module WindowsAutopilotIntune -Scope Global
		
        	# Get Graph Authentication module (and dependencies)
        	$module = Import-Module microsoft.graph.authentication -PassThru -ErrorAction Ignore
        	if (-not $module) {
            		Write-Host "Installing module microsoft.graph.authentication"
            		Install-Module microsoft.graph.authentication -Force
        	}
        	Import-Module microsoft.graph.authentication -Scope Global

		# Get required modules for AddToGroup switch
		if ($AddToGroup)
		{
			$module = Import-Module Microsoft.Graph.Groups -PassThru -ErrorAction Ignore
			if (-not $module)
			{
				Write-Host "Installing module Microsoft.Graph.Groups"
				Install-Module Microsoft.Graph.Groups -Force
			}

            		$module = Import-Module Microsoft.Graph.Identity.DirectoryManagement -PassThru -ErrorAction Ignore
			if (-not $module)
			{
				Write-Host "Installing module Microsoft.Graph.Identity.DirectoryManagement"
				Install-Module Microsoft.Graph.Identity.DirectoryManagement -Force
			}
		}

        	# Connect
		if ($AppId -ne "")
		{
			$graph = Connect-MSGraphApp -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret
			Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
		}
		else {
			Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "Device.ReadWrite.All", "Group.ReadWrite.All", "GroupMember.ReadWrite.All"
            		$graph = Get-MgContext
			Write-Host "Connected to Intune tenant" $graph.TenantId
		}

		# Force the output to a file
		if ($OutputFile -eq "")
		{
			$OutputFile = "$($env:TEMP)\autopilot.csv"
		} 
	}
}

Process
{
	foreach ($comp in $Name)
	{
		$bad = $false

		# Get a CIM session
		if ($comp -eq "localhost") {
			$session = New-CimSession
		}
		else
		{
			$session = New-CimSession -ComputerName $comp -Credential $Credential
		}

		# Get the common properties.
		Write-Verbose "Checking $comp"
		$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber

		# Get the hash (if available)
		$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
		if ($devDetail -and (-not $Force))
		{
			$hash = $devDetail.DeviceHardwareData
		}
		else
		{
			$bad = $true
			$hash = ""
		}

		# If the hash isn't available, get the make and model
		if ($bad -or $Force)
		{
			$cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
			$make = $cs.Manufacturer.Trim()
			$model = $cs.Model.Trim()
			if ($Partner)
			{
				$bad = $false
			}
		}
		else
		{
			$make = ""
			$model = ""
		}

		# Getting the PKID is generally problematic for anyone other than OEMs, so let's skip it here
		$product = ""

		# Depending on the format requested, create the necessary object
		if ($Partner)
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
				"Manufacturer name" = $make
				"Device model" = $model
			}
			# From spec:
			#	"Manufacturer Name" = $make
			#	"Device Name" = $model

		}
		else
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
			}
			
			if ($GroupTag -ne "")
			{
				Add-Member -InputObject $c -NotePropertyName "Group Tag" -NotePropertyValue $GroupTag
			}
			if ($AssignedUser -ne "")
			{
				Add-Member -InputObject $c -NotePropertyName "Assigned User" -NotePropertyValue $AssignedUser
			}
		}

		# Write the object to the pipeline or array
		if ($bad)
		{
			# Report an error when the hash isn't available
			Write-Error -Message "Unable to retrieve device hardware data (hash) from computer $comp" -Category DeviceError
		}
		elseif ($OutputFile -eq "")
		{
			$c
		}
		else
		{
			$computers += $c
			Write-Host "Gathered details for device with serial number: $serial"
		}

		Remove-CimSession $session
	}
}

End
{
	if ($OutputFile -ne "")
	{
		if ($Append)
		{
			if (Test-Path $OutputFile)
			{
				$computers += Import-CSV -Path $OutputFile
			}
		}
		if ($Partner)
		{
			$computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash", "Manufacturer name", "Device model" | ConvertTo-CSV -NoTypeInformation | ForEach-Object {$_ -replace '"',''} | Out-File $OutputFile
		}
		elseif ($AssignedUser -ne "")
		{
			$computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag", "Assigned User" | ConvertTo-CSV -NoTypeInformation | ForEach-Object {$_ -replace '"',''} | Out-File $OutputFile
		}
		elseif ($GroupTag -ne "")
		{
			$computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag" | ConvertTo-CSV -NoTypeInformation | ForEach-Object {$_ -replace '"',''} | Out-File $OutputFile
		}
		else
		{
			$computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash" | ConvertTo-CSV -NoTypeInformation | ForEach-Object {$_ -replace '"',''} | Out-File $OutputFile
		}
	}
    if ($Online)
    {
        # Add the devices
		$importStart = Get-Date
		$imported = @()
		$computers | ForEach-Object {
			$imported += Add-AutopilotImportedDevice -serialNumber $_.'Device Serial Number' -hardwareIdentifier $_.'Hardware Hash' -groupTag $_.'Group Tag' -assignedUser $_.'Assigned User'
		}

		# Wait until the devices have been imported
		$processingCount = 1
		while ($processingCount -gt 0)
		{
			$current = @()
			$processingCount = 0
			$imported | ForEach-Object {
				$device = Get-AutopilotImportedDevice -id $_.id
				if ($device.state.deviceImportStatus -eq "unknown") {
					$processingCount = $processingCount + 1
				}
				$current += $device
			}
			$deviceCount = $imported.Length
			Write-Host "Waiting for $processingCount of $deviceCount to be imported"
			if ($processingCount -gt 0){
				Start-Sleep 30
			}
		}
		$importDuration = (Get-Date) - $importStart
		$importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
		$successCount = 0
		$current | ForEach-Object {
			Write-Host "$($device.serialNumber): $($device.state.deviceImportStatus) $($device.state.deviceErrorCode) $($device.state.deviceErrorName)"
			if ($device.state.deviceImportStatus -eq "complete") {
				$successCount = $successCount + 1
			}
		}
		Write-Host "$successCount devices imported successfully.  Elapsed time to complete import: $importSeconds seconds"
		
		# Wait until the devices can be found in Intune (should sync automatically)
		$syncStart = Get-Date
		$processingCount = 1
		while ($processingCount -gt 0)
		{
			$autopilotDevices = @()
			$processingCount = 0
			$current | ForEach-Object {
				if ($device.state.deviceImportStatus -eq "complete") {
					$device = Get-AutopilotDevice -id $_.state.deviceRegistrationId
					if (-not $device) {
						$processingCount = $processingCount + 1
					}
					$autopilotDevices += $device
				}	
			}
			$deviceCount = $autopilotDevices.Length
			Write-Host "Waiting for $processingCount of $deviceCount to be synced"
			if ($processingCount -gt 0){
				Start-Sleep 30
			}
		}
		$syncDuration = (Get-Date) - $syncStart
		$syncSeconds = [Math]::Ceiling($syncDuration.TotalSeconds)
		Write-Host "All devices synced.  Elapsed time to complete sync: $syncSeconds seconds"
        
        # Add the device to the specified AAD group
		if ($AddToGroup)
		{
			$aadGroup = Get-MgGroup -Filter "DisplayName eq '$AddToGroup'"
			if ($aadGroup)
			{
				$autopilotDevices | ForEach-Object {
					$aadDevice = Get-MgDevice -Search "deviceId:$($_.azureActiveDirectoryDeviceId)" -ConsistencyLevel eventual
					if ($aadDevice) {
						Write-Host "Adding device $($_.serialNumber) to group $AddToGroup"
						New-MgGroupMember -GroupId $($aadGroup.Id) -DirectoryObjectId $($aadDevice.Id)
                        			Write-Host "Added devices to group '$AddToGroup' $($aadGroup.Id)"
					}
					else {
						Write-Error "Unable to find Azure AD device with ID $($_.azureActiveDirectoryDeviceId)"
					}
				}				
			}
			else {
				Write-Error "Unable to find group $AddToGroup"
			}
		}

		# Assign the computer name 
		if ($AssignedComputerName -ne "")
		{
			$autopilotDevices | ForEach-Object {
				Set-AutopilotDevice -id $_.id -displayName $AssignedComputerName
			}
		}

		# Wait for assignment (if specified)
		if ($Assign)
		{
			$assignStart = Get-Date
			$processingCount = 1
			while ($processingCount -gt 0)
			{
				$processingCount = 0
				$autopilotDevices | ForEach-Object {
					$device = Get-AutopilotDevice -id $_.id -Expand
					if (-not ($device.deploymentProfileAssignmentStatus.StartsWith("assigned"))) {
						$processingCount = $processingCount + 1
					}
				}
				$deviceCount = $autopilotDevices.Length
				Write-Host "Waiting for $processingCount of $deviceCount to be assigned"
				if ($processingCount -gt 0){
					Start-Sleep 30
				}	
			}
			$assignDuration = (Get-Date) - $assignStart
			$assignSeconds = [Math]::Ceiling($assignDuration.TotalSeconds)
			Write-Host "Profiles assigned to all devices.  Elapsed time to complete assignment: $assignSeconds seconds"	
			if ($Reboot)
			{
				Restart-Computer -Force
			}
		}
	}
}

# SIG # Begin signature block
# MII6bwYJKoZIhvcNAQcCoII6YDCCOlwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD8pVxEgjr499LG
# vQGsPuNLBUnk4vue69JRn1s522/Hc6CCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAy
# MDAeFw0yMDA0MTYxODM2MTZaFw00NTA0MTYxODQ0NDBaMHcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jv
# c29mdCBJZGVudGl0eSBWZXJpZmljYXRpb24gUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAyMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALORKgeD
# Bmf9np3gx8C3pOZCBH8Ppttf+9Va10Wg+3cL8IDzpm1aTXlT2KCGhFdFIMeiVPvH
# or+Kx24186IVxC9O40qFlkkN/76Z2BT2vCcH7kKbK/ULkgbk/WkTZaiRcvKYhOuD
# PQ7k13ESSCHLDe32R0m3m/nJxxe2hE//uKya13NnSYXjhr03QNAlhtTetcJtYmrV
# qXi8LW9J+eVsFBT9FMfTZRY33stuvF4pjf1imxUs1gXmuYkyM6Nix9fWUmcIxC70
# ViueC4fM7Ke0pqrrBc0ZV6U6CwQnHJFnni1iLS8evtrAIMsEGcoz+4m+mOJyoHI1
# vnnhnINv5G0Xb5DzPQCGdTiO0OBJmrvb0/gwytVXiGhNctO/bX9x2P29Da6SZEi3
# W295JrXNm5UhhNHvDzI9e1eM80UHTHzgXhgONXaLbZ7LNnSrBfjgc10yVpRnlyUK
# xjU9lJfnwUSLgP3B+PR0GeUw9gb7IVc+BhyLaxWGJ0l7gpPKWeh1R+g/OPTHU3mg
# trTiXFHvvV84wRPmeAyVWi7FQFkozA8kwOy6CXcjmTimthzax7ogttc32H83rwjj
# O3HbbnMbfZlysOSGM1l0tRYAe1BtxoYT2v3EOYI9JACaYNq6lMAFUSw0rFCZE4e7
# swWAsk0wAly4JoNdtGNz764jlU9gKL431VulAgMBAAGjVDBSMA4GA1UdDwEB/wQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTIftJqhSobyhmYBAcnz1AQ
# T2ioojAQBgkrBgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQwFAAOCAgEAr2rd5hnn
# LZRDGU7L6VCVZKUDkQKL4jaAOxWiUsIWGbZqWl10QzD0m/9gdAmxIR6QFm3FJI9c
# Zohj9E/MffISTEAQiwGf2qnIrvKVG8+dBetJPnSgaFvlVixlHIJ+U9pW2UYXeZJF
# xBA2CFIpF8svpvJ+1Gkkih6PsHMNzBxKq7Kq7aeRYwFkIqgyuH4yKLNncy2RtNwx
# AQv3Rwqm8ddK7VZgxCwIo3tAsLx0J1KH1r6I3TeKiW5niB31yV2g/rarOoDXGpc8
# FzYiQR6sTdWD5jw4vU8w6VSp07YEwzJ2YbuwGMUrGLPAgNW3lbBeUU0i/OxYqujY
# lLSlLu2S3ucYfCFX3VVj979tzR/SpncocMfiWzpbCNJbTsgAlrPhgzavhgplXHT2
# 6ux6anSg8Evu75SjrFDyh+3XOjCDyft9V77l4/hByuVkrrOj7FjshZrM77nq81YY
# uVxzmq/FdxeDWds3GhhyVKVB0rYjdaNDmuV3fJZ5t0GNv+zcgKCf0Xd1WF81E+Al
# GmcLfc4l+gcK5GEh2NQc5QfGNpn0ltDGFf5Ozdeui53bFv0ExpK91IjmqaOqu/dk
# ODtfzAzQNb50GQOmxapMomE2gj4d8yu8l13bS3g7LfU772Aj6PXsCyM2la+YZr9T
# 03u4aUoqlmZpxJTG9F9urJh4iIAGXKKy7aIwggbnMIIEz6ADAgECAhMzAAKbV4w5
# QsRxBYZDAAAAAptXMA0GCSqGSIb3DQEBDAUAMFoxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJ
# RCBWZXJpZmllZCBDUyBBT0MgQ0EgMDEwHhcNMjUwMjAzMTAzNDQxWhcNMjUwMjA2
# MTAzNDQxWjBmMQswCQYDVQQGEwJVUzERMA8GA1UECBMIVmlyZ2luaWExEjAQBgNV
# BAcTCUFybGluZ3RvbjEXMBUGA1UEChMOWnVoYWlyIE1haG1vdWQxFzAVBgNVBAMT
# Dlp1aGFpciBNYWhtb3VkMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA
# iyGzwvcvcHXw7HeB/druZg3eS/1i3USYXzitPOlUSJPBTkXIL+oYR0uIcAKret/v
# VU7yldDf+WFWb6jGgIaM0j6suoOOeYMR2cEDeck2gdYZrp6daIK6uVhiI8ceuuwO
# K5eNNG9Xf1jyhJD+3W+Je7ov3fjooQ9VgQqNC5mkkuUenAmy5qKhzKrDvfmolc/A
# rveWkt4xBv6bVKBJS832e+9NkOrqt5VOaRzfrkvW7/vEfjpoahCDk+G4/sQnHPIC
# lmql6NdJbl4uGXBOA8kL17dtR+IzJ7tDMVfecAsZfNt6ZK05aa8Ruwlkw3icbL0K
# T4JGKBO4px/IWxEqJP0kEJD4LR1E4p7oTyO60R9QyGOkDhKLMiuoyHknCjOqIbbG
# 8RjnN9MWiL+ad22NQhrZ8/W+9+TP2pCX8dlj9+X9Oem/nKEtD6py7+e/pxhgSJsG
# eSly7sDqV6sOvM8b3bERZ8P49hOA0gn08c0rFhMDRx37byVP3TPX9uguLWzAOyZv
# AgMBAAGjggIYMIICFDAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIHgDA7BgNV
# HSUENDAyBgorBgEEAYI3YQEABggrBgEFBQcDAwYaKwYBBAGCN2GBmtGaFtje9WuB
# vfqFXPmA7xswHQYDVR0OBBYEFEKOW7hc8Q95KoYjXucFUqlLDn32MB8GA1UdIwQY
# MBaAFOiDxDPX3J8MnHaaCqbU34emXljuMGcGA1UdHwRgMF4wXKBaoFiGVmh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMElEJTIw
# VmVyaWZpZWQlMjBDUyUyMEFPQyUyMENBJTIwMDEuY3JsMIGlBggrBgEFBQcBAQSB
# mDCBlTBkBggrBgEFBQcwAoZYaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jZXJ0cy9NaWNyb3NvZnQlMjBJRCUyMFZlcmlmaWVkJTIwQ1MlMjBBT0MlMjBD
# QSUyMDAxLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9zb2Z0
# LmNvbS9vY3NwMGYGA1UdIARfMF0wUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUH
# AgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0
# b3J5Lmh0bTAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIBACEIszlLdcL+pXIo
# JUCmArnzUTEsXbC3gFi60PZWu4W2WXROt+Z959JJNDz90ssyoerdfQKPwGGW4Q16
# bBI909HcNd7zQjM6ncA1G14Z31nQEedoXODCthtmtIPoPcVKlQfNJGPj9CMnlin/
# QneC2Rs/EC0c8s9kcqHQH7aXbNPG7rPeHeFCQwgWYzVBTqhpZ9pQJo8f/vVKnGPP
# Cb8a5HGZCh4f6RDwFyltBKMiwuOZlmUY9dZU45Th6xhNaibrXjhtCTXNv4RkBnvk
# ewOkijf8VekktYMMxKzksXpwTvcYUIjUn3N283UThlLqMio9T2jo/YE3XVrCgvnU
# dBG8SxInDxkMFcMceEqJMNXlN/3/i5Ohg2eqE9PKuon4fuFoDX+bFT26satprM3E
# 0FeeKXPU7iUPdUOSNOQ0AppEg2uXalIPsdEfPDGx5C6IzyuMTsuNauKkRWntXmIF
# 7he1sDVuxeyk6dkLqVqJ5xFRhLtQSy/7+qo1vK58Go2/QwdwefS5mQh01xVZV5GV
# mFa8U6Wx88m8utWEBnuOklc1AfQ6uz3oG3zgQBzM+I8KnY55FRHG+ALKn912+HqV
# laHOvIrRVFCXIi34Q26CHPTaa4hD4cLPt44Aw1EYRhi0adeN9ypaXbztLdDuSBqX
# /1fmLOJDGYkaGL+EdzD3KeLBkitUMIIG5zCCBM+gAwIBAgITMwACm1eMOULEcQWG
# QwAAAAKbVzANBgkqhkiG9w0BAQwFADBaMQswCQYDVQQGEwJVUzEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSswKQYDVQQDEyJNaWNyb3NvZnQgSUQgVmVy
# aWZpZWQgQ1MgQU9DIENBIDAxMB4XDTI1MDIwMzEwMzQ0MVoXDTI1MDIwNjEwMzQ0
# MVowZjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRIwEAYDVQQHEwlB
# cmxpbmd0b24xFzAVBgNVBAoTDlp1aGFpciBNYWhtb3VkMRcwFQYDVQQDEw5adWhh
# aXIgTWFobW91ZDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAIshs8L3
# L3B18Ox3gf3a7mYN3kv9Yt1EmF84rTzpVEiTwU5FyC/qGEdLiHACq3rf71VO8pXQ
# 3/lhVm+oxoCGjNI+rLqDjnmDEdnBA3nJNoHWGa6enWiCurlYYiPHHrrsDiuXjTRv
# V39Y8oSQ/t1viXu6L9346KEPVYEKjQuZpJLlHpwJsuaiocyqw735qJXPwK73lpLe
# MQb+m1SgSUvN9nvvTZDq6reVTmkc365L1u/7xH46aGoQg5PhuP7EJxzyApZqpejX
# SW5eLhlwTgPJC9e3bUfiMye7QzFX3nALGXzbemStOWmvEbsJZMN4nGy9Ck+CRigT
# uKcfyFsRKiT9JBCQ+C0dROKe6E8jutEfUMhjpA4SizIrqMh5JwozqiG2xvEY5zfT
# Foi/mndtjUIa2fP1vvfkz9qQl/HZY/fl/Tnpv5yhLQ+qcu/nv6cYYEibBnkpcu7A
# 6lerDrzPG92xEWfD+PYTgNIJ9PHNKxYTA0cd+28lT90z1/boLi1swDsmbwIDAQAB
# o4ICGDCCAhQwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwOwYDVR0lBDQw
# MgYKKwYBBAGCN2EBAAYIKwYBBQUHAwMGGisGAQQBgjdhgZrRmhbY3vVrgb36hVz5
# gO8bMB0GA1UdDgQWBBRCjlu4XPEPeSqGI17nBVKpSw599jAfBgNVHSMEGDAWgBTo
# g8Qz19yfDJx2mgqm1N+Hpl5Y7jBnBgNVHR8EYDBeMFygWqBYhlZodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJRCUyMFZlcmlm
# aWVkJTIwQ1MlMjBBT0MlMjBDQSUyMDAxLmNybDCBpQYIKwYBBQUHAQEEgZgwgZUw
# ZAYIKwYBBQUHMAKGWGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwSUQlMjBWZXJpZmllZCUyMENTJTIwQU9DJTIwQ0ElMjAw
# MS5jcnQwLQYIKwYBBQUHMAGGIWh0dHA6Ly9vbmVvY3NwLm1pY3Jvc29mdC5jb20v
# b2NzcDBmBgNVHSAEXzBdMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDAUAA4ICAQAhCLM5S3XC/qVyKCVApgK5
# 81ExLF2wt4BYutD2VruFtll0TrfmfefSSTQ8/dLLMqHq3X0Cj8BhluENemwSPdPR
# 3DXe80IzOp3ANRteGd9Z0BHnaFzgwrYbZrSD6D3FSpUHzSRj4/QjJ5Yp/0J3gtkb
# PxAtHPLPZHKh0B+2l2zTxu6z3h3hQkMIFmM1QU6oaWfaUCaPH/71Spxjzwm/GuRx
# mQoeH+kQ8BcpbQSjIsLjmZZlGPXWVOOU4esYTWom6144bQk1zb+EZAZ75HsDpIo3
# /FXpJLWDDMSs5LF6cE73GFCI1J9zdvN1E4ZS6jIqPU9o6P2BN11awoL51HQRvEsS
# Jw8ZDBXDHHhKiTDV5Tf9/4uToYNnqhPTyrqJ+H7haA1/mxU9urGraazNxNBXnilz
# 1O4lD3VDkjTkNAKaRINrl2pSD7HRHzwxseQuiM8rjE7LjWripEVp7V5iBe4XtbA1
# bsXspOnZC6laiecRUYS7UEsv+/qqNbyufBqNv0MHcHn0uZkIdNcVWVeRlZhWvFOl
# sfPJvLrVhAZ7jpJXNQH0Ors96Bt84EAczPiPCp2OeRURxvgCyp/ddvh6lZWhzryK
# 0VRQlyIt+ENughz02muIQ+HCz7eOAMNRGEYYtGnXjfcqWl287S3Q7kgal/9X5izi
# QxmJGhi/hHcw9yniwZIrVDCCB1owggVCoAMCAQICEzMAAAAHN4xbodlbjNQAAAAA
# AAcwDQYJKoZIhvcNAQEMBQAwYzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjE0MDIGA1UEAxMrTWljcm9zb2Z0IElEIFZlcmlmaWVk
# IENvZGUgU2lnbmluZyBQQ0EgMjAyMTAeFw0yMTA0MTMxNzMxNTRaFw0yNjA0MTMx
# NzMxNTRaMFoxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xKzApBgNVBAMTIk1pY3Jvc29mdCBJRCBWZXJpZmllZCBDUyBBT0MgQ0Eg
# MDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC398ADKAfFuj6PEDTi
# E0jxvP4Spta9K711GABrCMJlq7VjnghBqXkCuklaLxwiPRYD6anCLHyJNGC6r0kQ
# tm9MyjZnVToC0TVOfea+rebLBn1J7FV36s85Ov651roZWDAsDzQuFF/zYC+tLDGZ
# mkIf+VpPTx2fv4a3RxdhU0ok5GbWFKsCOMNCJnUmKr9KqIOgc3o8aZPmFcqzbYTv
# 0x4VZgHjLRSU2pbRnYs825ryTStsRF2I1L6dM//GwRJlSetubJdloe9zIQpgrzlY
# HPdKvoS3xWVt2J3+mMGlwcj4fK2hpQAYTqtJaqaHv9oRl4MNSTP24wo4ZqwiBid6
# dSTkTRvZT/9tCoO/ep2GP1QlhYAM1gL/eLeLFxbVUQtpT7BOpdPEsAV6UKL+VEdK
# NpaKkN4T9NsFvTNMKIudz2eY6Nk8qW60w2Gj3XDGjiK1wmgiTZs+i3234BX5TA1o
# NEhtwRpBoHJyX2lxjBaZ/RsnggWf8KZgxUbV6QIHEHLJE2QWQea4xctfo8xdy94T
# jqMyv2zILczwkdF11HjNWN38XEGdLkc6ujemDpK24Q+yGunsj8qTVxMbzI5aXxqp
# /o4l4BXIbiXIn1X5nEKViZpTnK+0pgqTUUsGcQF8NbD5QDNBXS9wunoBXHYVzyfS
# +mjK52vdLBmZyQm7PtH5Lv0HMwIDAQABo4ICDjCCAgowDgYDVR0PAQH/BAQDAgGG
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTog8Qz19yfDJx2mgqm1N+Hpl5Y
# 7jBUBgNVHSAETTBLMEkGBFUdIAAwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgw
# FoAU2UEpsA8PY2zvadf1zSmepEhqMOYwcAYDVR0fBGkwZzBloGOgYYZfaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwSUQlMjBW
# ZXJpZmllZCUyMENvZGUlMjBTaWduaW5nJTIwUENBJTIwMjAyMS5jcmwwga4GCCsG
# AQUFBwEBBIGhMIGeMG0GCCsGAQUFBzAChmFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMElEJTIwVmVyaWZpZWQlMjBDb2Rl
# JTIwU2lnbmluZyUyMFBDQSUyMDIwMjEuY3J0MC0GCCsGAQUFBzABhiFodHRwOi8v
# b25lb2NzcC5taWNyb3NvZnQuY29tL29jc3AwDQYJKoZIhvcNAQEMBQADggIBAHf+
# 60si2TAtOng1+H32+tulKwvw3A8iPb5MGdkYvcLx61MZiz4dlTE0b6s15lr5HO72
# gRwBkkOIaMRbK3Mxq8PoGKHecRYWwhbhoaHiAHif+lE955WsriLUsbuMneQ8tGE0
# 4dmItRC2asXhXojG1QWO8GeKNpn2gjGxJJA/yIcyM/3amNCscEVYcYNuSbH7I7oh
# qfdA3diZt197DNK+dCYpuSJOJsmBwnUvRNnsHCawO+b7RdGw858WCfOEtWpl0TJb
# DDXRt+U54EqqRvdJoI1BPPyeyFpRmGvFVTmo2BiNpoNBCb4/ZISkEXtGiUQLeWWV
# +4vgA4YK2g1085avH28FlNcBV1MTavQgOTz7nLWQsZMsrOY0WfqRUJzkF10zvGgN
# ZDhpSgJFdywF5GGxyWTuRVc/7MkY85fCNQlufPYq32IX/wHoUM7huUa4auiAynJe
# S7AILZnhdx/IyM8OGplgA8YZNQg0y0Vtq7lG0YbUM5YT150JqG248wOAHJ8+LG+H
# LeyfvNQeAgL9iw5MzFW4xCL9uBqZ6aj9U0pmuxlpLSfOY7EqmD2oN5+Pl8n2Agdd
# ynYXQ4dxXB7cqcRdrySrMwN+tGX/DAqs1IWfenuDRvjgB3U40OZa3rUwtC8Xngsb
# raLp9+FMJ6gVP1n2ltSjaDGXJMWDsGbR+A6WdF8YMIIHnjCCBYagAwIBAgITMwAA
# AAeHozSje6WOHAAAAAAABzANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3Nv
# ZnQgSWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMjAwHhcNMjEwNDAxMjAwNTIwWhcNMzYwNDAxMjAxNTIwWjBjMQswCQYD
# VQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTQwMgYDVQQD
# EytNaWNyb3NvZnQgSUQgVmVyaWZpZWQgQ29kZSBTaWduaW5nIFBDQSAyMDIxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsvDArxmIKOLdVHpMSWxpCFUJ
# tFL/ekr4weslKPdnF3cpTeuV8veqtmKVgok2rO0D05BpyvUDCg1wdsoEtuxACEGc
# gHfjPF/nZsOkg7c0mV8hpMT/GvB4uhDvWXMIeQPsDgCzUGzTvoi76YDpxDOxhgf8
# JuXWJzBDoLrmtThX01CE1TCCvH2sZD/+Hz3RDwl2MsvDSdX5rJDYVuR3bjaj2Qfz
# ZFmwfccTKqMAHlrz4B7ac8g9zyxlTpkTuJGtFnLBGasoOnn5NyYlf0xF9/bjVRo4
# Gzg2Yc7KR7yhTVNiuTGH5h4eB9ajm1OCShIyhrKqgOkc4smz6obxO+HxKeJ9bYmP
# f6KLXVNLz8UaeARo0BatvJ82sLr2gqlFBdj1sYfqOf00Qm/3B4XGFPDK/H04kteZ
# EZsBRc3VT2d/iVd7OTLpSH9yCORV3oIZQB/Qr4nD4YT/lWkhVtw2v2s0TnRJubL/
# hFMIQa86rcaGMhNsJrhysLNNMeBhiMezU1s5zpusf54qlYu2v5sZ5zL0KvBDLHtL
# 8F9gn6jOy3v7Jm0bbBHjrW5yQW7S36ALAt03QDpwW1JG1Hxu/FUXJbBO2AwwVG4F
# re+ZQ5Od8ouwt59FpBxVOBGfN4vN2m3fZx1gqn52GvaiBz6ozorgIEjn+PhUXILh
# AV5Q/ZgCJ0u2+ldFGjcCAwEAAaOCAjUwggIxMA4GA1UdDwEB/wQEAwIBhjAQBgkr
# BgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU2UEpsA8PY2zvadf1zSmepEhqMOYwVAYD
# VR0gBE0wSzBJBgRVHSAAMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFMh+0mqF
# KhvKGZgEByfPUBBPaKiiMIGEBgNVHR8EfTB7MHmgd6B1hnNodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBJZGVudGl0eSUyMFZl
# cmlmaWNhdGlvbiUyMFJvb3QlMjBDZXJ0aWZpY2F0ZSUyMEF1dGhvcml0eSUyMDIw
# MjAuY3JsMIHDBggrBgEFBQcBAQSBtjCBszCBgQYIKwYBBQUHMAKGdWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwSWRlbnRp
# dHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUlMjBBdXRob3Jp
# dHklMjAyMDIwLmNydDAtBggrBgEFBQcwAYYhaHR0cDovL29uZW9jc3AubWljcm9z
# b2Z0LmNvbS9vY3NwMA0GCSqGSIb3DQEBDAUAA4ICAQB/JSqe/tSr6t1mCttXI0y6
# XmyQ41uGWzl9xw+WYhvOL47BV09Dgfnm/tU4ieeZ7NAR5bguorTCNr58HOcA1tcs
# HQqt0wJsdClsu8bpQD9e/al+lUgTUJEV80Xhco7xdgRrehbyhUf4pkeAhBEjABvI
# UpD2LKPho5Z4DPCT5/0TlK02nlPwUbv9URREhVYCtsDM+31OFU3fDV8BmQXv5hT2
# RurVsJHZgP4y26dJDVF+3pcbtvh7R6NEDuYHYihfmE2HdQRq5jRvLE1Eb59PYwIS
# FCX2DaLZ+zpU4bX0I16ntKq4poGOFaaKtjIA1vRElItaOKcwtc04CBrXSfyL2Op6
# mvNIxTk4OaswIkTXbFL81ZKGD+24uMCwo/pLNhn7VHLfnxlMVzHQVL+bHa9KhTyz
# wdG/L6uderJQn0cGpLQMStUuNDArxW2wF16QGZ1NtBWgKA8Kqv48M8HfFqNifN6+
# zt6J0GwzvU8g0rYGgTZR8zDEIJfeZxwWDHpSxB5FJ1VVU1LIAtB7o9PXbjXzGifa
# IMYTzU4YKt4vMNwwBmetQDHhdAtTPplOXrnI9SI6HeTtjDD3iUN/7ygbahmYOHk7
# VB7fwT4ze+ErCbMh6gHV1UuXPiLciloNxH6K4aMfZN1oLVk6YFeIJEokuPgNPa6E
# nTiOL60cPqfny+Fq8UiuZzGCFx8wghcbAgEBMHEwWjELMAkGA1UEBhMCVVMxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjErMCkGA1UEAxMiTWljcm9zb2Z0
# IElEIFZlcmlmaWVkIENTIEFPQyBDQSAwMQITMwACm1eMOULEcQWGQwAAAAKbVzAN
# BglghkgBZQMEAgEFAKBeMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCASBNU+muJ6vp/h7eQRkdwj+2MQ
# NmzTLV5Jk03Y0kWCQjANBgkqhkiG9w0BAQEFAASCAYA0X2sxvz/BP/voqKmGufGq
# r2qFJdfu9pXDNiqACfY6aREiA3NBzCfA+aLUviODFn7UkQBZTa3l/7aoiQhpl7ij
# GLVEVfobE7Jb9X6dLEL8uDA6VUB4+LTzUDZC8RRk49C+G2Frd6xaMl98ByFLf+J1
# PN25uAyT+fjkicRoMjHsPMu+N/bwZRBcRMZ+0pQ9mRELei0CqysFedPjEvGctAIe
# +G7BHzpqTPW/0xf/PAc2zq+a9f+7zduT7EWr/sb+nLTchfPm63V1jRUeCx5P3RrV
# /dzzxykWjRFbR2gDT5jBxsQHaj9Zh81p+PgwyInWSZZuI7N13dgy/J6s9sLFSTDu
# VegjLfeP8bL5muCZ5lRHmqg0AlK42RH6QPH9yo7fQ+zB7C5ThBMi9qbAnJsQEP0I
# Ipb0QtKFCyebAbjlC97QRpRFpp3n0rkzvdUe8TZy/jInDkKAWha+42XD/VHtNenq
# Qq2Shmtkn8H5X0ZPGh1gM1YPYzF+2qU3lOjFD6SvQ7qhghSfMIIUmwYKKwYBBAGC
# NwMDATGCFIswghSHBgkqhkiG9w0BBwKgghR4MIIUdAIBAzEPMA0GCWCGSAFlAwQC
# AQUAMIIBYAYLKoZIhvcNAQkQAQSgggFPBIIBSzCCAUcCAQEGCisGAQQBhFkKAwEw
# MTANBglghkgBZQMEAgEFAAQgmsYbZISqfyNH+hu7Z9nQpgl+HFhxoPk/Smi/GUvP
# EfQCBmebw25ToBgSMjAyNTAyMDQwMDU5NDcuNzFaMASAAgH0oIHgpIHdMIHaMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNy
# b3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVT
# TjpFNDYyLTk2RjAtNDQyRTE1MDMGA1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0Eg
# VGltZSBTdGFtcGluZyBBdXRob3JpdHmggg8gMIIHgjCCBWqgAwIBAgITMwAAAAXl
# zw//Zi7JhwAAAAAABTANBgkqhkiG9w0BAQwFADB3MQswCQYDVQQGEwJVUzEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMUgwRgYDVQQDEz9NaWNyb3NvZnQg
# SWRlbnRpdHkgVmVyaWZpY2F0aW9uIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMjAwHhcNMjAxMTE5MjAzMjMxWhcNMzUxMTE5MjA0MjMxWjBhMQswCQYDVQQG
# EwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylN
# aWNyb3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ5851Jj/eDFnwV9Y7UGIqMcHtfnlzPR
# EwW9ZUZHd5HBXXBvf7KrQ5cMSqFSHGqg2/qJhYqOQxwuEQXG8kB41wsDJP5d0zmL
# YKAY8Zxv3lYkuLDsfMuIEqvGYOPURAH+Ybl4SJEESnt0MbPEoKdNihwM5xGv0rGo
# fJ1qOYSTNcc55EbBT7uq3wx3mXhtVmtcCEr5ZKTkKKE1CxZvNPWdGWJUPC6e4uRf
# WHIhZcgCsJ+sozf5EeH5KrlFnxpjKKTavwfFP6XaGZGWUG8TZaiTogRoAlqcevbi
# qioUz1Yt4FRK53P6ovnUfANjIgM9JDdJ4e0qiDRm5sOTiEQtBLGd9Vhd1MadxoGc
# HrRCsS5rO9yhv2fjJHrmlQ0EIXmp4DhDBieKUGR+eZ4CNE3ctW4uvSDQVeSp9h1S
# aPV8UWEfyTxgGjOsRpeexIveR1MPTVf7gt8hY64XNPO6iyUGsEgt8c2PxF87E+CO
# 7A28TpjNq5eLiiunhKbq0XbjkNoU5JhtYUrlmAbpxRjb9tSreDdtACpm3rkpxp7A
# QndnI0Shu/fk1/rE3oWsDqMX3jjv40e8KN5YsJBnczyWB4JyeeFMW3JBfdeAKhzo
# hFe8U5w9WuvcP1E8cIxLoKSDzCCBOu0hWdjzKNu8Y5SwB1lt5dQhABYyzR3dxEO/
# T1K/BVF3rV69AgMBAAGjggIbMIICFzAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYBBAGC
# NxUBBAMCAQAwHQYDVR0OBBYEFGtpKDo1L0hjQM972K9J6T7ZPdshMFQGA1UdIARN
# MEswSQYEVR0gADBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwDwYDVR0TAQH/BAUwAwEB/zAf
# BgNVHSMEGDAWgBTIftJqhSobyhmYBAcnz1AQT2ioojCBhAYDVR0fBH0wezB5oHeg
# dYZzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0
# JTIwSWRlbnRpdHklMjBWZXJpZmljYXRpb24lMjBSb290JTIwQ2VydGlmaWNhdGUl
# MjBBdXRob3JpdHklMjAyMDIwLmNybDCBlAYIKwYBBQUHAQEEgYcwgYQwgYEGCCsG
# AQUFBzAChnVodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01p
# Y3Jvc29mdCUyMElkZW50aXR5JTIwVmVyaWZpY2F0aW9uJTIwUm9vdCUyMENlcnRp
# ZmljYXRlJTIwQXV0aG9yaXR5JTIwMjAyMC5jcnQwDQYJKoZIhvcNAQEMBQADggIB
# AF+Idsd+bbVaFXXnTHho+k7h2ESZJRWluLE0Oa/pO+4ge/XEizXvhs0Y7+KVYyb4
# nHlugBesnFqBGEdC2IWmtKMyS1OWIviwpnK3aL5JedwzbeBF7POyg6IGG/XhhJ3U
# qWeWTO+Czb1c2NP5zyEh89F72u9UIw+IfvM9lzDmc2O2END7MPnrcjWdQnrLn1Nt
# day7JSyrDvBdmgbNnCKNZPmhzoa8PccOiQljjTW6GePe5sGFuRHzdFt8y+bN2neF
# 7Zu8hTO1I64XNGqst8S+w+RUdie8fXC1jKu3m9KGIqF4aldrYBamyh3g4nJPj/LR
# 2CBaLyD+2BuGZCVmoNR/dSpRCxlot0i79dKOChmoONqbMI8m04uLaEHAv4qwKHQ1
# vBzbV/nG89LDKbRSSvijmwJwxRxLLpMQ/u4xXxFfR4f/gksSkbJp7oqLwliDm/h+
# w0aJ/U5ccnYhYb7vPKNMN+SZDWycU5ODIRfyoGl59BsXR/HpRGtiJquOYGmvA/pk
# 5vC1lcnbeMrcWD/26ozePQ/TWfNXKBOmkFpvPE8CH+EeGGWzqTCjdAsno2jzTeNS
# xlx3glDGJgcdz5D/AAxw9Sdgq/+rY7jjgs7X6fqPTXPmaCAJKVHAP19oEjJIBwD1
# LyHbaEgBxFCogYSOiUIr0Xqcr1nJfiWG2GwYe6ZoAF1bMIIHljCCBX6gAwIBAgIT
# MwAAAEr9uFXHYqrJiQAAAAAASjANBgkqhkiG9w0BAQwFADBhMQswCQYDVQQGEwJV
# UzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNy
# b3NvZnQgUHVibGljIFJTQSBUaW1lc3RhbXBpbmcgQ0EgMjAyMDAeFw0yNDExMjYx
# ODQ4NTVaFw0yNTExMTkxODQ4NTVaMIHaMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRp
# b25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpFNDYyLTk2RjAtNDQyRTE1MDMG
# A1UEAxMsTWljcm9zb2Z0IFB1YmxpYyBSU0EgVGltZSBTdGFtcGluZyBBdXRob3Jp
# dHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDoORBhnrNiXDUBvEWQ
# U3BzRXQFpcIKjX/53TVgqLNqUr1tfx8ashRJV/vmlgk6uFiah8gyHvAG/yP6QimU
# 4piLGu1Wr5pDAB7MjTAEV0UV47I0IjKdNDDPfjfPkhZVnT/tw5dPUgOT18iwjnWR
# kodrhI9/2sWYf1e0fX8/UTG54AayQEX8C8jU6XZW/Zb0QOR7xyzFw+BdOQM0b0jm
# WMSMz2llTN/2SDDw+jwJWkPX84VvjryNxpamyL/J2puhrcomc+jJSWer5yaCnp+S
# mpiY8zcSECvVoCpsyeSJSsPhDXkNO/Rehk6LXONdGEXnHFcouvWbmTnFmUenuac+
# KaIbrtPv97kO4UW3tdsCw4Jbw3VmrmN014uswu0G+RHIqWRNKynqclBdHhF/Z7zt
# Ou95CImMuxb5lDjopd1wMjVahrEjQnPKmJw5AFtxT3zzben9MCth1Wkhi5iVerT3
# bdx/36KbrYFUUb15eGb7rTVGxd1aUftBQxnNsPbfdoA/wuIHSkOuQr/JtSlizoOi
# QAn2vRqbg0Ve7ssL4N8gW95Ehk4IFoca3hIncbZWCQUigAsVxOGP6ujuhf4FPeyv
# QvnsvOL9CZTZSRMLBXWoozr5qpvOFXgHGzFGN9B162rMW/Ejggd/QgG4+hhgyIng
# BdNraajKZ+56MrY1mAvvmZbCKwIDAQABo4IByzCCAccwHQYDVR0OBBYEFBd01om2
# LhZ7joStT9M2cg55YZV6MB8GA1UdIwQYMBaAFGtpKDo1L0hjQM972K9J6T7ZPdsh
# MGwGA1UdHwRlMGMwYaBfoF2GW2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvY3JsL01pY3Jvc29mdCUyMFB1YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUy
# MENBJTIwMjAyMC5jcmwweQYIKwYBBQUHAQEEbTBrMGkGCCsGAQUFBzAChl1odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFB1
# YmxpYyUyMFJTQSUyMFRpbWVzdGFtcGluZyUyMENBJTIwMjAyMC5jcnQwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4Aw
# ZgYDVR0gBF8wXTBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMAgG
# BmeBDAEEAjANBgkqhkiG9w0BAQwFAAOCAgEAMCnNMNdZvKP+vzm/oDPX2wk+3Ap0
# Tm6QDQWs/El98gNDRYktbUbvNchcgljdLl0Idu9evlsOuYvrsyWdTQzREhqmbnGl
# Lx6O5Z1GmUeqRGLCEHmGb7ucR3Gb5h0oJygg/FsaojW3wTRLRm3u7DX/0vNFRqt2
# 5MdDQ8rJlCe5iQcsbHzf/5FHjTDWB6aIgW0L9R+81j1REcJ8Hptan3SqLdONYsw7
# TcXBym69nXlG5sxUf94fdZq8mMsHisNZ3s3N5ICSJOoIRQAU2qsYVueM6+IExRsq
# QBr+YWP2bUOTpnHhJte1PnAKh1feTfSbRxIHacKVQttHhjJY7n8yhKVPCcw+8Vcw
# 5ZSTN39IBFvDtdUXpYu2BkdUEoDJngwUrCsoI/yFd2jN2R45fdG7Xb7B7BGTwCej
# 9/3Oubgb8H/A7q7uyYHd5Hw56uqKg+3ve58UxaxILBeFIbPzGmOroMqIbf2wNE8X
# YIeewEgma/t08yBgIrGyRvsaIiQduprv28gCpCz2djizteFHw0pEApUhiP3/xeR5
# jlLUbRhCELBCVFS28dkxjSliY5cF9amNAb5lojB93Tu0HSGmskGHnMksi6yx+wg/
# e0avijri2pFrz44i0/eYtYJ2yUpwFjkcjMcLZvQ2dqwBjVurN9N+i2x+WGtX6ldL
# I3cCzfp0oxOqkYYxggPUMIID0AIBATB4MGExCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBQdWJs
# aWMgUlNBIFRpbWVzdGFtcGluZyBDQSAyMDIwAhMzAAAASv24VcdiqsmJAAAAAABK
# MA0GCWCGSAFlAwQCAQUAoIIBLTAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQw
# LwYJKoZIhvcNAQkEMSIEIMDspUjAUtNjO3KoDAEGD6nhCw0PXKXiVb/KS9u4qi+Q
# MIHdBgsqhkiG9w0BCRACLzGBzTCByjCBxzCBoAQgZnsptaXNjQBCR0t1b+ADGLKX
# s8R/1amy/7F17y7D4QowfDBlpGMwYTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFB1YmxpYyBS
# U0EgVGltZXN0YW1waW5nIENBIDIwMjACEzMAAABK/bhVx2KqyYkAAAAAAEowIgQg
# bX2VIGVbvWxZrrZhNd4Jg8BodYBl35zhL2UN/TceWkQwDQYJKoZIhvcNAQELBQAE
# ggIA0dBfP2EsUu3oBojhNFTgk/A9DwoSYWa4vkNSQ4SBH1kN7q/4o7F5ZP8596E3
# o0AoajjNBsGhgh/1N4ggy/d0dtWU6VJwf+jL0gyinfMEGHR2S4xnJmFJzIqQ1j12
# BceHLtzNe6dd7EBv4V0ridJK2jRSzv0IW8yxiZl23wMP0LvmRRM/MRVoEprVToQD
# ldQ9ArW/Q22yRI4ziprzhKP2CEmFvjjAeupuWGi2/bGt8sL62Ul9yrUGE4iUZQ+8
# +K6knAP42K7Y0UfKMHcDoEASwRaw/QXnilhsNKYG7m0upto9eWL3adU3mL6pQm8Y
# gMi+spSpQ6dUnmEVZdOrCAD0nyLPNDXF86iVBBW9pP/ddYNGfmzt9XmDoGbXCG7J
# a9nakeIS0g4bJScGTYWTuQk4hdoCN+5XBkVM9hUDAQUFe92txBOzNGpFz1MKXY3g
# snlCkwVXBNjwuH1F4pX2/9JZEPEkmbBamcaEZOwr0ZiBCJcBWPbT4Tl+G9SNiqDP
# gF2o6wdsY0j0fdzNYuyBElJHx4UrDv0mov1rk39/ptDyDDtuaHKHh7LX1MvjE8bv
# 5A0ndXHFV8+cWnmE7GF90S3l6iSd/YepGG+cStjLk1CEXRmEAGwN/OCNqBQLSlWS
# QShWQ1jgP7An2Wxie/9HtB7mk8Ve1X/eUzgFnvY2+ezg79M=
# SIG # End signature block
