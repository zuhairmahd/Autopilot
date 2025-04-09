<#
.SYNOPSIS
Checks if a device with a given serial number is already in Intune and verifies its profile assignment status.

.DESCRIPTION
The CheckDeviceAssignment function takes a serial number as input and checks if the device is already imported into Intune. If the device is found, it further checks the deployment profile assignment status. If the device is assigned to a deployment profile, it outputs the profile name and indicates readiness for enrollment. Otherwise, it provides guidance for further action.

.PARAMETER serial
The serial number of the device to check.

.EXAMPLE
CheckDeviceAssignment -serial "123456789"
Checks if the device with serial number 123456789 is in Intune and verifies its profile assignment status.

.NOTES
Version: 3.0.0
Author: Zuhair Mahmoud
GUID: 3f2504e0-4f89-11d3-9a0c-0305e82c3301
Date: April 5, 2025
#>
function CheckDeviceAssignment() 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$serial,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )
    Write-Verbose "Received parameters: serial=$serial."
    if ($AccessToken)
    {
        Write-Verbose "Access token provided."
    }
    $success = $false
    $autoPilotDeviceURI = 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities'
    Write-Host "Checking whether the device with serial number $serial is already in Intune."
    $autopilotDevices = CallGraphAPI -AccessToken $accessToken -Uri $autoPilotDeviceURI
    Write-Verbose "Found $($autopilotDevices.value.count) Autopilot devices."
    $assignment = $autopilotDevices.value | Where-Object { $_.serialNumber -match $serialNumber }
    if ($assignment)
    {
        Write-Host 'The device is registered in Intune.' -ForegroundColor Yellow
        Write-Host 'Checking profile assignment'
        if ($assignment.deploymentProfileAssignmentStatus -eq 'assignedUnkownSyncState')
        {
            $expandedDeviceURI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotRawDevice.id)?`$expand=deploymentProfile"
            $autopilotDevice = CallGraphAPI -AccessToken $accessToken -Uri $expandedDeviceURI
            Write-Host "The device was assigned to the $($autopilotDevice.deploymentProfile.displayName) deployment profile on $($autopilotDevice.deploymentProfileAssignedDateTime)." -ForegroundColor Green
            Write-Host 'The device is ready for enrollment.' -ForegroundColor Green
            $success = $true
        }
        else
        {
            Write-Host 'The device is imported but not assigned to a deployment profile.' -ForegroundColor Yellow
            Write-Host 'Please check the Intune portal or contact an Intune administrator.'
        }
    }
    return $success
}
# SIG # Begin signature block
# MII6cAYJKoZIhvcNAQcCoII6YTCCOl0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAhM958bsfHipLB
# jGYmgwL+DeyrCl0Uopd7prv6gIDcIKCCIqYwggXMMIIDtKADAgECAhBUmNLR1FsZ
# lUgTecgRwIeZMA0GCSqGSIb3DQEBDAUAMHcxCzAJBgNVBAYTAlVTMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xSDBGBgNVBAMTP01pY3Jvc29mdCBJZGVu
# dGl0eSBWZXJpZmllZGNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDIwMB4XDTIwMDQxNjE4MzYxNloXDTQ1MDQxNjE4NDQ0MFowdzELMAkGA1UEBhMC
# VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEgMEYGA1UEAxM/TWlj
# cm9zb2Z0IElkZW50aXR5IFZlcmlmaWNhdGlvbiBSb290IENlcnRpZmljYXRlIEF1
# dGhvcml0eSAyMDIwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAs5Eq
# B4MGZ/2enfDHwLek5kIEfw+m21/71VrXRbD7dwvwgPOmbVpNeVPYoIaEV0Ugx6JU
# +8eiv4rHbjXzohXEL07jSoWWSQ3/vpnYFPa8JwfuQpsr9QuSBuT9aRNlqJFy8piE
# 64M9DuTXcRJIIscN7fZHSbef5yccXtoRP/7ismtdzZ0mF44a9N0DQJYbU3rXCbWJ
# q1al4vC1vSfnlbBQU/RTH02UWN97LbrxeKY39YpsVLNYF5rmJMjOjYsfX1lJnCMQ
# u9FYrnguHzOyntKaq6wXNGlXpToLBCcckWeeLWIvLx6+2sAgywQZyjP7ib6Y4nKg
# cjW+eeGcg2/kbRdvkPM9AIZ1OI7Q4Emau9vT+DDK1VeIaE1y079tf3HY/b0NrpJk
# SLdbb3kmtc2blSGE0e8PMj17V4zzRQdMfOBeGA41dottnss2dKsF+OBzXTJWlGeX
# JQrGNT2Ul+fBRIuA/cH49HQZ5TD2BvshVz4GHItrFYYnSXuCk8pZ6H1H6D84x1N5
# oLa04lxR77VfOMEz5ngMlVYuxUBaSMwPJMDsugl3I5k4prYc2se6ILbXN9h/N68I
# 4ztx225zG32ZcrDkhjNZdLUWAHtQbcaGE9r9xDmCPiQAmmDauqUwAVRLDStUJkTh
# 7uzBYCyTTACXLgmg120Y3PvrjOVT2AovjfVW6UCAwEAAaNUMFIwDgYDVR0PAQH/
# BAQDAgGEMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFMh+0mqFKjvKGZgEByfPUBBP
# aKiiMBAGCSsGAQQBgjcVAQQDAgEAMA0GCSqGSIb3DQEBDAUAA4ICAQCvqt3mGecs
# tFEMZTsvpUJVkqQORAoviNoA7FaJSwhYZtqVpddEMw9Jv/2B0CbEhHpAWbcUkj1x
# miGP0T8x98hJMQBCLBn9qoiu8pUbz50F60k+dKBoW+VWLGUcgn5T2lbZRhd5kkXE
# EDYIUikXyy+m8n7UaSSKHo+wcw3MHEqruqu2nkWMBSCKoMrh+MiizZ3MtkbTcMEF
# C/dHCqbx10rtVmDELAije0CwvHQnUofWvojdN4qJbmfIHfXJXaD+2qs6gNcalzwX
# NiJBHqxN1YPmPDj9TzDpVKnjtgTDMdmG7sBjhS8Ys8CA1beVsF5RTSL87Fiq6NiU
# tKUu7ZLe5xh8IVfdVWf3v23NH9Kmdyhwx+JbOlsI0ltOyACWs+GDNq+GCmVcdPbr
# rHpqdKDwS+7vlKO8UPKH7dc6MIPJ+31XvuXj+EHK5WSus6PsWOyFmszvuerzVhi5
# XHOar8V3F4NZ2zcaGHJUpUHStiN1o0Oa5Xd8lnm3QY2/7NyAoJ/Rd3VYXzUT4CUa
# Zwt9ziX6BwrkYSHY1BzlB8Y2mfSW0MYV/k7N166LndtW/QTGkr3UiOapo6q793k4
# O1/MDNA1vnQZA6bFqkyiYTaCPh3zK7yXXdtLeDstfvvgI+j17AsjNpWvmGa/U9N7
# uGlKKpZmacSUxvRfbqyYeIiABlyisuy2j
